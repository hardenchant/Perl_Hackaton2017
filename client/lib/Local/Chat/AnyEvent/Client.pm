package Local::Chat::AnyEvent::Client;

use 5.016;
use strict;
BEGIN {if($]<5.018){package experimental; use warnings::register;}} no warnings 'experimental';

use Local::Chat::Tools;
use AnyEvent::Socket;
use AnyEvent::Handle;
use Class::XSAccessor
	accessors => [qw(log h nick password rooms)],
;
use DDP;

use Local::Chat::AnyEvent::Log;

our $SEQ;

sub new {
	my $pkg = shift;
	my %args = ref $_[0] ? %{$_[0]} : @_;
	my $self = bless {
		timeout => 5,
		trace => 1,
		%args,
		handlers => {},
		wait_response => {},
		rooms => {},
	}, $pkg;

	$self->{log} //= Local::Chat::AnyEvent::Log->new();

	$self->{login} = $self->{nick};
	# nick from arguments is a desired nick for login
	# but {nick} could be changed by later events

	return $self;
}

sub on {
	my $self = shift;
	my %handlers = @_;
	for (keys %handlers) {
		$self->{handler}{$_} = $handlers{$_};
	}
}

sub event {
	my $self = shift;
	my $event = shift;
	if ($self->{handler}{$event}) {
		$self->{handler}{$event}->( @_ );
	}
	else {
		$self->log->debug("event $event discarded");
	}
}

sub connect {
	my $self = shift;
	my ($host,$port);
	if ($self->{server}) {
		($host,$port) = split /:/,$self->{server},2;
	}
	else {
		($host,$port) = @{ $self }{ qw( host port ) };
	}
	$port //= 2345;
	$self->log->info("Connecting to $host:$port");
	$self->{cw} = tcp_connect $host,$port, sub {
		my ($fh) = @_;
		if ($fh) {
			$self->setup_handle(@_);
		}
		else {
			$self->log->error("Failed to connect to $host:$port: $!");
			$self->reconnect("Failed to connect: $!");
		}
	},
	sub { # prepare
		$self->{timeout};
	};
	return;
}

sub setup_handle {
	my $self = shift;
	my ($fh,$host,$port) = @_;
	$self->log->info("Connected to $host:$port");

	weaken($self); # Weak ref must not capture $self inside handle callbacks

	$self->{h} = AnyEvent::Handle->new(
		fh => $fh,
	);

	$self->{h}->on_error( sub {
		shift;
		$self or return;
		$self->abort('Connection error: $_[0]');
	} );

	$self->{h}->on_eof(sub {
		shift; # handle
		$self->abort('Server closed the connection');
	});

	$self->start_read();
	$self->AUTH( $self->{login}, $self->{password}, sub {
		if (shift) {
			$self->event("connected");
		}
		else {
			$self->event("auth_failed", shift);
		}
	} );
}

sub start_read {
	weaken(my $self = shift);

	my $leftover = 0;
	my $parser = JSON::XS->new->utf8();
	$self->h->on_read(sub {
		$leftover += length $_[0]{rbuf};
		$parser->incr_parse(delete $_[0]{rbuf});
		while () {
			my $data;
			eval {
				$data = $parser->incr_parse();
			1} or do {
				$self->log->error("Failed to parse incoming data: $@");
				$self->abort("Failed to parse incoming data");
				return;
			};

			if (defined $data) {
				if ($self->{trace}) {
					my $copy = $JSON->encode($data);
					utf8::decode($copy);
					$self->log->_print("\e[1;34m[S2C] << ".( length($copy) > 1024 ? substr($copy,0,1024).'...' : $copy ) . "\e[0m");
				}
				$self->incoming_packet($data);
				$leftover = length($parser->incr_text);
			}
			else {
				if ($leftover > 4096) {
					$self->abort("Too big message");
				}
				last;
			}
		}
	});
}

sub abort {
	my $self = shift;
	my $reason = shift;
	$self->log->error("Aborting connection: $reason");
	$self->event("disconnected", $reason);
	$self->reconnect($reason);
}

sub reconnect {
	my $self = shift;
	my $reason = shift;

	$self->h and $self->h->destroy;

	my $waits = delete $self->{wait_response};
	
	$self->{wait_response} = {};
	$self->{rooms} = {};

	for my $cb (values %$waits) {
		$cb->(undef, $reason);
	}

	my $w;$w = AE::timer 1,0, sub {
		undef $w;
		$self->connect;
	};
	return;
}

sub incoming_packet {
	my ($self, $pkt) = @_;
	return $self->abort( "Malformed data" ) if ref $pkt ne 'HASH';
	return $self->abort( "Malformed data: no cmd" ) unless $pkt->{event};
	return $self->abort( "Malformed data: no data" )
		unless $pkt->{data} and ref $pkt->{data} eq 'HASH';

	my $data = $pkt->{data};
	# $self->log->debug("Received event (%s)", jdump $pkt);
	my $seq = $data->{seq};
	if ($self->{wait_response}{$seq}) {
		my $cb = delete($self->{wait_response}{$seq});
		if ($pkt->{event} ne 'ERROR') {
			$cb->($data);
		}
		else {
			$cb->(undef, $data->{text});
		}
	}
	given ($pkt->{event}) {
		when ('NICK') {
			$self->{nick} = $data->{nick};
		}
		when ('ROOM') {
			$self->{rooms}{ $data->{room} } = $data;
		}
		when ('JOIN') {
			if ($data->{nick} ne $self->nick) {
				# TODO
				# push @{ $self->{rooms}{ $data->{room} }{members} };
			}
		}
		when ('PART') {
			if ($data->{nick} eq $self->nick) {
				delete $self->{rooms}{ $data->{room} };
			}
			else {
				# TODO
				# push @{ $self->{rooms}{ $data->{room} }{members} };
			}
		}
		when ('KICK') {
			if ($data->{nick} eq $self->nick) {
				delete $self->{rooms}{ $data->{room} };
			}
		}
	}
	$self->event( lc($pkt->{event}), $data );
	return;
}

sub cmd {
	my $self   = shift;
	my $cb     = callable $_[-1] ? pop : undef;
	my $cmd    = shift;
	my $data   = shift // {};
	my %args   = @_;

	my $seq = ++$self->{seq};
	$data->{seq} = $seq;
	$self->write({
		v          => $args{v} // 1,
		cmd        => $cmd,
		data       => $data,
	});
	if ($cb) {
		$self->{wait_response}{$seq} = $cb;
	}
}

sub AUTH {
	my $self = shift;
	my $cb = callable $_[-1] ? pop : undef;
	my $nick = shift;
	my $pass = shift;
	$nick =~ s{^\@*}{\@};
	$self->cmd(AUTH => {
		nick     => $nick,
		defined $pass ? (
			password => $pass
		) : ()
	}, v => ($pass ? 2 : 1), $cb);
}

sub MSG {
	my $self = shift;
	my $cb = callable $_[-1] ? pop : undef;
	my $to = shift;
	my $text = shift;

	$self->cmd(MSG => {
		to => $to,
		text => $text,
	}, $cb);
}

sub JOIN {
	my $self = shift;
	my $cb = callable $_[-1] ? pop : undef;
	my $to = shift;

	$self->cmd(JOIN => {
		room => $to,
	}, $cb);
}

sub PART {
	my $self = shift;
	my $cb = callable $_[-1] ? pop : undef;
	my $to = shift;

	$self->cmd(PART => {
		room => $to,
	}, $cb);
}

sub LIST {
	my $self = shift;
	my $cb = callable $_[-1] ? pop : undef;
	my $to = shift;

	$self->cmd(LIST => {
	}, $cb);
}

sub TITLE {
	my $self = shift;
	my $cb = callable $_[-1] ? pop : undef;
	my $room = shift;
	my $text = shift;

	$self->cmd(TITLE => {
		room => $room,
		title => $text,
	}, $cb);
}

sub write {
	my $self = shift;
	my $data = shift;
	if( my $err = string_check $data ) {
		$self->log->error("$err at @{[ (caller)[1,2] ]}");
		return;
	}
	my $pkt = $JSON->encode($data);
	
	if ($self->{trace}) {
		my $copy = $pkt;
		utf8::decode($copy);
		$self->log->_print("\e[1;32m[C2S] >> ".( length($copy) > 1024 ? substr($copy,0,1024).'...' : $copy ) . "\e[0m");
	}
	$self->h->push_write($pkt . "\n");
}

1;

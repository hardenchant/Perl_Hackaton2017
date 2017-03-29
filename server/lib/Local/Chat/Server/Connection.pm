package Local::Chat::Server::Connection;

use 5.016;
use strict;
use Local::Chat::Tools;
use AnyEvent::Handle;
use Class::XSAccessor getters => [qw(log id h core server peer nick)];
use DDP;

our $SEQ;

sub new {
	my $pkg = shift;
	my $self = bless { @_ }, $pkg;
	$self->{peer} = $self->{host}.':'.$self->{port};
	$self->{log} = $self->{log}->clone( prefix => "$self->{peer}/$self->{id}" );
	$self->{trace} = 1;

	$self->setup_handle;
	$self->start_read;

	$self->log->debug("Connection ready");

	return $self;
}

sub setup_handle {
	my $self = shift;

	weaken($self); # Weak ref must not capture $self inside handle callbacks

	# select((select($self->{fh}), $|++)[0]);

	$self->{h} = AnyEvent::Handle->new(
		fh => $self->{fh},
		# autocork => 1,
		no_delay => 1,
	);

	$self->{h}->on_error( sub {
		shift;
		$self or return;
		$self->on_error(@_);
	} );
	$self->{h}->on_eof(sub {
		shift; # handle
		$self->log->debug('EOF catched on client-connection');
		$self->drop();
	});
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

			if ($data) {
				if ($self->{trace}) {
					my $copy = $JSON->encode($data);
					utf8::decode($copy);
					print "\e[1;34m[C2S] <<($self->{peer}/$self->{id}/$self->{nick}) ".( length($copy) > 1024 ? substr($copy,0,1024).'...' : $copy ) . "\e[0m\n";
				}

				$self->incoming_packet($data);
				$leftover = length($parser->incr_text);
			}
			else {
				if ($leftover > 2**17 ) {
					$self->abort("Too big message");
				}
				last;
			}
		}
	});
}

sub on_error {
	my $self = shift;
	$self->log->fatal("$_[1]");
	$self->h->destroy();
	$self->drop();
}

our %FIELDS = (
	nick     => qr(^\@\w{1,32}$),
	password => qr(^\w+$),
	room     => qr(^#\w{1,32}$),
	to       => qr(^(\w+)?([@#]\w{1,32})$),
	text     => qr(^.+$)s,
);

our %CMDS = (
	AUTH => {
		1 => { fields => [qw(nick)] },
		2 => { fields => [qw(nick password)] },
	},
	MSG => {
		1 => { fields => [qw(to text)] },
	},
);

sub incoming_packet {
	my ($self, $pkt) = @_;

=for rem
{
    "v": 1,
    "cmd": "XXX",
    "data": {
        "seq": 123456,
        ...
    },
}
=cut

	return $self->abort( "Malformed data" ) if ref $pkt ne 'HASH';
	return $self->abort( "Malformed data: no cmd" ) unless $pkt->{cmd};
	return $self->abort( "Unknown command: $pkt->{cmd}" ) unless exists $CMDS{$pkt->{cmd}};
	return $self->abort( "Unsupported command version: $pkt->{cmd} v$pkt->{v}" )
		unless exists $CMDS{$pkt->{cmd}}{ $pkt->{v} };
	return $self->abort( "Malformed data: no data" ) unless $pkt->{data};
	return $self->abort( "Malformed data: bad data format" )
		unless ref $pkt->{data} eq 'HASH';

	my $data = $pkt->{data};
	my $seq = $data->{seq};
	# return $self->abort( "Malformed data: no seq" ) unless $data->{seq};

	if (!$self->nick and $pkt->{cmd} ne 'AUTH') {
		return $self->error($seq, 'Unauthorized');
	}
	
	my $param = $CMDS{$pkt->{cmd}}{ $pkt->{v} };
	my $data = $pkt->{data};

	for my $f (@{ $param->{fields} }) {
		if ($f eq 'nick' and $data->{$f} !~ /^\@/ ) {
			$self->log->debug("Fixing up nick in cmd $pkt->{cmd}");
			$data->{$f} = "\@$data->{$f}";
		}
		return $self->abort( "Malformed: required field '$f'" )
			unless exists $data->{$f};

		return $self->error( $seq, "Malformed: validation failed '$f'")
			unless $data->{$f} =~ $FIELDS{$f};
	}
	$self->log->debug("Received cmd (%s)", jdump $pkt);

	my $method = $pkt->{cmd};

	$self->call_core($method, $data);

	# $self->$method($pkt->{v}, $data);
}

sub LIST {
	my ($self, $ver, $data) = @_;
	$self->call_core('list_rooms', $data->{seq});
}

sub set_nick {
	my $self = shift;
	my $old = $self->{nick};
	$self->{nick} = shift;
	my $seq = shift;
	$self->log->debug("User %s nick to %s", $old ? "changed":"set", $self->{nick});
	$self->log->prefix( $self->peer.'/'.$self->id.'<'.$self->{nick}.'> ' );

	$self->event(NICK => { nick => $self->nick, seq => $seq });
}

sub event {
	my $self   = shift;
	my $event  = shift;
	my $data   = shift // {};
	# my %args   = @_;

	$self->write({
		v          => 1,
		# timestamp => AE::now, # do we need it?
		event      => $event,
		data       => {
			%$data,
		},
		# $args{from} ? (
		# 	from => $self->nick, # $args{from}
		# ) : (),
		# $args{to} ? (
		# 	to => $args{to},
		# ) : (),
		# $args{seq} ? (
		# 	seq => $args{seq},
		# ) : (),
	});
}

sub error {
	my $self   = shift;
	my $seq    = shift;
	my $reason = shift // "No reason";
	$self->log->warn("Error: $reason");
	$self->event(ERROR => {
		text => $reason,
		$seq ? ( seq => $seq ) : (),
	});
}

sub abort {
	my $self = shift;
	my $reason = shift // "No reason";
	$self->log->warn("Aborting connection: $reason");
	weaken($self);
	$self->error(undef, $reason);
	$self->h->on_drain(sub { # When write-buffer became empty
		shift; # handle
		$self or return;
		$self->drop();
	});
}

sub drop {
	my $self = shift;
	$self->call_core('user_disconnect');
	$self->server->drop( $self->id );
}

sub call_core {
	my $self = shift;
	my $method = shift;
	if( $self->core->can($method) ) {
		$self->core->$method($self,@_);
	}
	else {
		$self->log->error("Can't call method '$method' on core at @{[ (caller)[1,2] ]}");
	}
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
		print "\e[1;32m[S2C] >>($self->{peer}/$self->{id}/$self->{nick}) ".( length($copy) > 1024 ? substr($copy,0,1024).'...' : $copy ) . "\e[0m\n";
	}
	$self->h->push_write($pkt . "\n");
	$self->h->on_drain(sub {
		# p $_[0];
		$_[0]->on_drain(undef);
		# $self->log->debug("Written");
		1;
	});
	return;
}


sub DESTROY {
	my $self = shift;

	$self->call_core( user_disconnect => $self );

	delete $self->server->online->{ $self->{nick} } if $self->{nick};

	$self->log->debug('Destroying');
	$self->h->destroy();
}

1;

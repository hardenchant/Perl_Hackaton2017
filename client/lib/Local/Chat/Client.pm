package Local::Chat::Client;

use 5.010;
use strict;
BEGIN {if($]<5.018){package experimental; use warnings::register;}} no warnings 'experimental';

use JSON::XS;
use AnyEvent::Util qw(fh_nonblocking);
use Time::HiRes qw(sleep time);
use IO::Socket::INET;
use IO::Select;
use Socket ':all';
use DDP;
use Data::Dumper;

BEGIN {
	binmode $_, ':utf8' for \*STDIN, \*STDOUT, \*STDERR;
}

use Class::XSAccessor accessors => [qw (
	fh remote connected rbuf trace host port sel
	on_disconnect on_fd on_hello on_idle on_msg on_error
	on_join on_part on_rename on_room on_title on_mode on_grant
	on_kick on_ban
	on_write on_read
    on_members
	nick password
) ];

use constant MAXBUF => 1024*1024;

our $JSON = JSON::XS->new->utf8->canonical;

sub set_fh {
	my $self = shift;
	my $fh = shift;
	$self->fh($fh);

	if ($self->fh) {
		fh_nonblocking( $self->fh, 1 );
		$self->remote( $self->fh->peerhost.':'.$self->fh->peerport );
	}
}

sub set_nick {
	my $self = shift;
	my $nick = shift;

	$self->nick($nick);
	$self->auth if $self->connected;
}

sub new {
	my $pkg  = shift;
	my %conf = @_;

	$conf{host} = $conf{host} or
		die "config.host required\n";

	$conf{port} = $conf{port} // 2345;
	$conf{remote} = $conf{log} // '';
	$conf{rbuf}   = $conf{rbuf} // '';
	$conf{trace} = $conf{trace} // 0;
	$conf{sel} = $conf{sel} // IO::Select->new();
	$conf{nick} =~ s{^\@*}{\@};

	my $self = bless \%conf, $pkg;
	$self->connect();
	return $self;
}

sub BUILD {
	my $self = shift;
	$self->connect();
}

sub connect {
	my $self = shift;
	return 1 if $self->connected;
	my $fh = IO::Socket::INET->new(
		PeerAddr => $self->host,
		PeerPort => $self->port,
		Proto    => 'tcp',
	) or die "Failed to connect to @{[ $self->host ]}:@{[ $self->port ]} $!\n";

	$self->connected(1);
	$self->set_fh( $fh );

	$self->auth;

	$self->sel->add($fh);
	return 1;
}

sub disconnect {
	my $self = shift;
	$self->connected(0);
	if (@_) {
		my $error = shift;
		warn "$error";
	}
	$self->sel->remove($self->fh);
	close $self->fh;
	$self->on_disconnect and
		$self->on_disconnect->($self);
}

sub on_eof {
	my $self = shift;
	$self->connected(0);
	$self->sel->remove($self->fh);
	$self->on_disconnect and
		$self->on_disconnect->($self);
}

sub ident {
	my $self = shift;
	return $self->nick.'@'.$self->remote;
}

sub log {
	my $self = shift;
	return unless $self->trace;
	my $msg;
	if (@_ > 1 and index($_[0],'%') > -1) {
		$msg = sprintf $_[0],@_[1..$#_];
	}
	else {
		$msg = "@_";
	}
	printf STDERR "%s-- %s %s%s\n", (-t STDERR ? "\e[1;35m" : "" ), $self->ident, $msg, (-t STDERR ? "\e[0m" : "" );
}

sub read : method {
	my $self = shift;
	my $buf = $self->rbuf;
	my $res = sysread $self->fh, $buf, MAXBUF-length($buf), length($buf);
	if ($res) {
		# read some from client
	}
	elsif (defined $res) {
		$self->disconnect( "Connection closed" );
		return;
	}
	elsif ($! == Errno::EAGAIN) {
		# no more data
	}
	else {
		$self->disconnect( "Connection error: $!" );
		return;
	}

	# TODO: here may be a bug

	my @lines;
	while ($buf =~ m{\G([^\n]*)\n}gc) {
		push @lines, $1;
	}
	if ($self->trace) {
		for (@lines) {
			my $copy = $_;
			utf8::decode $copy;
			printf STDERR "%s<< %s %s%s\n", (-t STDERR ? "\e[1;33m" : "" ), $self->ident, $copy, (-t STDERR ? "\e[0m" : "" );
		}
	}
	$self->rbuf( defined( pos $buf ) ? substr($buf, pos $buf) : $buf );
	if (length $self->rbuf) {
		# warn "Leftover: ".$self->rbuf;
	}
	for my $line (@lines) {
		my $incoming;
		next if $line =~ /^\s*$/;
		if ( eval { $incoming = $JSON->decode($line); 1 } ) {
			$self->process_packet($incoming);
			$self->on_read and $self->on_read->($self, $incoming);
		}
		else {
			$self->disconnect("Failed to decode incoming line: '$line': $@");
			return;
		}
	}
	# unless ($self->connected) {
	# 	$self->on_eof();
	# }
	return;
}

sub process_packet {
	my $self = shift;
	my $pkt  = shift;

	return $self->disconnect( "Malformed data" ) if ref $pkt ne 'HASH';
	return $self->disconnect( "Malformed data: no cmd" ) unless $pkt->{event};
	return $self->disconnect( "Malformed data: no data" )
		unless $pkt->{data} and ref $pkt->{data} eq 'HASH';

	my $data = $pkt->{data};

	given ($pkt->{event}) {
		when ('NICK') {
			# don't use accessor to not trigger event
			if ($self->{nick} ne $pkt->{data}{nick}) {
				$self->log("Server says our nickname should be $pkt->{data}{nick}");
				$self->{nick} = $pkt->{data}{nick};
			}
		}
		when( [qw(ERROR JOIN PART RENAME ROOM TITLE MODE GRANT MEMBERS)]) {
			my $callback = 'on_'. lc $pkt->{event};
			if ($self->can($callback)) {
				$self->$callback and
					$self->$callback->($self, $data);
			}
			else {
				warn "No callback for $callback";
			}
		}
		when ('MSG') {
			$self->on_msg and
				$self->on_msg->($self, $data);
		}
		default {
			return $self->disconnect("bad event packet ".$JSON->encode($pkt));
		}
	}

}

sub command {
	my $self = shift;
	my $command = shift;
	my $data = shift;
	my $version = shift || 1;

	my $cmd = { v => $version, cmd => $command, data => $data };
	$self->write($cmd);
	$self->on_write and $self->on_write->( $self, $cmd );
}

sub write {
	my $self = shift;
	my $arg = shift;
	ref $arg or die "Bad argument to write";
	$arg->{time} ||= time;
	my $wbuf = $JSON->encode($arg);
	if ($self->trace) {
		my $copy = $wbuf;
		utf8::decode($copy);
		printf STDERR "%s>> %s %s%s\n", (-t STDERR ? "\e[1;34m" : "" ), $self->ident, $copy, (-t STDERR ? "\e[0m" : "" );
	}
	$wbuf .= "\n";
	while (length $wbuf) {
		my $wr = syswrite($self->fh, $wbuf);
		if ($wr) {
			# my $written =
			substr($wbuf,0,$wr,'');
			# warn "written\n$written";
		}
		elsif ($! == Errno::EAGAIN) {
			sleep 0.01;
		}
		else {
			$self->disconnect( "Write failed: $!" );
			last;
		}
	}
}

sub poll {
	my $self = shift;
	while ($self->connected) {
		if ( my @handles = $self->sel->can_read(1) ) {
			for my $fd (@handles) {
				if ($fd == $self->fh) {
					#warn "self conn";
					$self->read;
					# self connection
				}
				elsif ($self->on_fd and $self->on_fd->( $self, $fd )) {
					# processed
				}
				else {
					warn "Unknown readable fd: $fd/".fileno($fd);
					$self->sel->remove($fd);
					close($fd);
				}
			}
		}
		else {
			# warn "Nothing to read";
		}
		$self->on_idle and $self->on_idle->($self);
	}
}

sub auth {
	my $self = shift;

	if ( $self->password ) {
		$self->command( 'AUTH', { nick => $self->nick, password => $self->password }, 2 );
	}
	else {
		$self->command( 'AUTH', { nick => $self->nick } );
	}
}

sub message {
	my $self = shift;
	my $pkt = shift;

	$pkt = { text => $pkt, to => '#all' } unless ref $pkt;
	$self->command( 'MSG', $pkt );
}

sub join_room {
	my $self = shift;
	my $room = shift;

	$self->command( 'JOIN' => { room => $room } );
}

sub part {
	my $self = shift;
	my $room = shift;

	$self->command( 'PART' => { room => $room } );
}

sub members {
	my $self = shift;
	my $room = shift;

	$self->command( 'MEMBERS' => { room => $room } );
}

sub kick_ban_unban {
	my $self = shift;
	my $cmd  = shift;
	my $user = shift;
	my $room = shift;

	$self->command( ( uc $cmd ) => { nick => $user, room => $room } );
}

sub title {
	my $self = shift;
	my $msg = shift;
	
	$self->command( 'TITLE' => { room => $msg->{room}, title => $msg->{title} } );
}

1;

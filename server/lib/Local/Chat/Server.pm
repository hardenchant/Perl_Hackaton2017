package Local::Chat::Server;

use 5.016;
use strict;
use AnyEvent::Handle;
use AnyEvent::Socket;
use Socket 'SOMAXCONN';
use Local::Log '$log';

use Local::Chat::Core;
use Local::Chat::Server::Connection;

use Class::XSAccessor getters => [qw ( log online core ) ];

sub new {
	my $pkg = shift;
	my $conf = shift;
	my $self = bless {}, $pkg;
	$self->{host} = $conf->{host}
		or die "config.host required\n";
	$self->{port} = $conf->{port}
		// die "config.port required\n";
	$self->{max_msg_avg} = $conf->{max_msg_avg};

	$self->{avg_ban_time} = $conf->{avg_ban_time};

	$self->{log} = $conf->{log} // $log;

	$self->{core} = Local::Chat::Core->new(
		log => $self->log,
	);

	$self->{online} = {};

	# for (@Local::Log::methods) {
	# 	$log->$_("test");
	# }
	# warn "bullshit";

	$self->{connections} = {};

	return $self;
}

sub accept {
	my $self = shift;
	$self->{aw} = tcp_server
		$self->{host}, $self->{port},
		sub { # accept callback
			my $fh = shift;
			my ($host,$port) = @_;
			$self->log->info( "Client connected from $host:$port" );
			
			my $connection = Local::Chat::Server::Connection->new(
				fh     => $fh,
				host   => $host,
				port   => $port,
				log    => $self->log,
				id     => ++$self->{seq},
				server => $self,
				core   => $self->{core},

			);
			$connection->{max_msg_avg} = $self->{max_msg_avg};
			$connection->{avg_ban_time} = $self->{avg_ban_time};
			$self->{connections}{ $connection->id } = $connection;
		},
		sub { # server prepare callback
			my ($srv,$host,$port) = @_;
			$self->{listen_host} = $host;
			$self->{listen_port} = $port;
			$self->log->debug("Server listening on tcp://$host:$port");
			return SOMAXCONN;
		}
	;
	return;
}

sub drop {
	my $self = shift;
	my $reqid = shift;

	delete $self->{connections}{ $reqid };
}


1;

package Local::Chat::Core;

use 5.016;
use strict;
use warnings;
use Local::Chat::Tools;
use Local::Chat::Server::Room;
use Class::XSAccessor accessors => [qw( online rooms log )];

use DDP;

sub new {
	my $pkg = shift;
	my $self = bless { @_ }, $pkg;

	$self->{rooms}  = {}; # { room1 => room1, room2 => room2 }
	$self->{online} = {}; # { nick => { room1 => Local::Chat::Server::Room, ... } }

	$self->rooms->{'#all'} = Local::Chat::Server::Room->new(
		name => '#all',
		log => $self->log
	);
	return $self;
}

sub randname {
	my $self = shift;
	my $nick = shift;
	for my $digits (2..5) {
		my $max = 10**$digits;
		for (1..50) {
			my $guess = $nick . int(rand($max));
			unless (exists $self->online->{$guess}) {
				return $guess;
			}
		}
	}
	return;
}

sub AUTH {
	my ($self,$conn,$data) = @_;
	# p $data;

	my ($old_nick, $new_nick) = ($conn->nick, $data->{nick});
	if ($old_nick) {
		return if $old_nick eq $new_nick;

		if ($self->online->{$new_nick}) {
			$self->log->warn('User `%s` already exists', $new_nick);
			return $conn->error($data->{seq}, 'Nick unavailable');
		}

		$self->online->{$new_nick} = delete $self->online->{$old_nick};
		$conn->set_nick($new_nick, $data->{seq}); # answer new-nick to connection

		my $rooms = $self->online->{$new_nick}{rooms};
		my %conns;
		for my $room (values %$rooms) {
			for my $c ($room->connections) {
				$conns{ 0+$c } = $c;
			}
		}

		for my $c (values %conns) {
			next if $c == $conn;
			$c->event(RENAME => { from => $old_nick, nick => $new_nick });
		}

	} else {
		if ($self->online->{$new_nick}) {
			$new_nick = $self->randname($new_nick);
		}
		$self->online->{$new_nick} = {
			conn  => $conn,
			rooms => {},
		};

		$conn->set_nick($new_nick, $data->{seq});

		$self->JOIN($conn, { room => '#all', seq => $data->{seq} });
	}
}

sub user_disconnect {
	my $self = shift;
	my $conn = shift;

	my $user = delete $self->online->{ $conn->nick };
	return unless $user;

	for my $room (values %{ $user->{rooms} }) {
		$room->PART($conn, {});
	}
}

sub JOIN {
	my $self = shift;
	my $conn = shift;
	my $data = shift;
	my $room_name = $data->{room};

	my $user = $self->online->{$conn->nick}{conn};
	my $room = $self->rooms->{$room_name} //= Local::Chat::Server::Room->new(
		admin => $user->nick,
		name  => $room_name,
		log   => $self->log->clone(prefix => "[$room_name] "),
	);

	$room->JOIN($conn, $data);
	weaken($self->rooms->{$room_name}) if $room_name ne '#all' and !isweak($self->rooms->{$room_name});
	$self->online->{ $conn->nick }{rooms}{$room_name} = $room;
}

sub PART {
	my $self = shift;
	my $conn = shift;
	my $data = shift;
	my $room_name = $data->{room};

	my $room = $self->rooms->{$room_name};
    if ($room_name eq "#all") {
        $self->log->debug('Trying to leave #all');
        return;
    }
	unless (defined $room) {
		$self->log->warn('Room `%s` not found', $room_name);
		$conn->error($data->{seq}, 'Room not found');
		return;
	}

	delete $self->online->{ $conn->nick }{rooms}{ $room->name };
	$room->PART($conn, $data);
}

sub MEMBERS {
	my $self = shift;
	my $conn = shift;
	my $data = shift;
	my $room_name = $data->{room};

	my $room = $self->rooms->{$room_name};
	return $conn->error($data->{seq}, "Room $room_name not found")
		unless $room;

	$room->MEMBERS($conn,$data);
}

sub MSG {
	my $self = shift;
	my $conn = shift;
	my $data = shift;

	my $to = $data->{to};
	if ($to =~ m/^#/) { # msg to room:
		my $room = $self->rooms->{$to};
		return $conn->error($data->{seq}, "Room not found `$to`")
			unless $room;

		return $conn->error($data->{seq}, "You're not joined into `$to`")
			unless ($room->is_member($conn));

		# ACL here:
		$self->log->debug("Deliver message to room");
		$room->MSG($conn, $data);
	}
	elsif ($to =~ /^\@/) { # for user
		my $reciever = $self->online->{$to};

		return $conn->error($data->{seq},  "Destination $to not found")
			unless $reciever;

		my $sndr = $self->online->{$conn->nick};

		
		
		$sndr->{conn}->event(
			MSG => {
				from => $conn->nick,
				to   => $to,
				text => $data->{text},				
			}
		);
		

		$reciever->{conn}->event(
			MSG => {
				from => $conn->nick,
				to   => $to,
				text => $data->{text},
			}
		);
	}
	else {
		return $conn->error($data->{seq}, "Unavailable");
	}
}


1;

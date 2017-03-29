package Local::Chat::Server::Room;

use 5.016;
use strict;
use Local::Chat::Server::Connection;
use Class::XSAccessor accessors => [qw( name title members acl moderated log )];

sub new {
	my $pkg = shift;
	my $self = bless { @_ }, $pkg;
	$self->{moderated} = "";
	$self->{members} = {};
	$self->{acl} = {};
	$self->{log} =
	$self->log->info('Room %s created', $self->name);
	return $self;
}

sub connections {
	my $self = shift;
	values %{ $self->members };
}

sub JOIN {
	my $self = shift;
	my $conn = shift;
	my $data = shift;

	$self->members->{ 0+$conn } = $conn;

	for my $c ( values %{$self->members} ) {
		$c->event(JOIN => {
			room => $self->name,
			nick => $conn->nick,
			$c == $conn ? ( seq => $data->{seq}) : (),
		});
	}
	$self->MEMBERS($conn, $data);
}

sub PART {
	my $self = shift;
	my $conn = shift;
	my $data = shift;

	for my $c (values %{$self->members}) {
		$c->event(PART => {
			room => $self->name,
			nick => $conn->nick,
			$c == $conn ? ( seq => $data->{seq}) : (),
		});
	}
	delete $self->members->{ 0+$conn };
}

sub MEMBERS {
	my $self = shift;
	my $conn = shift;
	my $data = shift;

	my @answer = ();
	for my $member ( values %{ $self->members } ) {
		push @answer, {
			nick => $member->nick,
			role => $self->acl->{ $member->nick } // 'guest',
		};
	}

	$conn->event(MEMBERS => {
		room => $self->name,
		title => $self->title,
		members => [ @answer ],
		moderated => $self->moderated,
		seq => $data->{seq},
	});
}

sub MSG {
	my $self = shift;
	my $conn = shift;
	my $data = shift;

	for my $c ( values %{$self->members}) {
		$c->event(MSG => {
			room => $self->name,
			text => $data->{text},
			from => $conn->nick,
			to   => $self->name,
			$c == $conn ? ( seq => $data->{seq}) : (),
		});
	}
}

sub is_member {
	my $self = shift;
	my $conn = shift;
	return exists $self->members->{ 0+$conn };
}

sub DESTROY {
	my $self = shift;
	$self->log->info('Room %s destroyed', $self->name);
}

1;

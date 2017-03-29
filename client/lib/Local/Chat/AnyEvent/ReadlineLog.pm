package Local::Chat::AnyEvent::ReadlineLog;

use 5.016;
use strict;
use Time::HiRes qw(gettimeofday);
use POSIX qw(strftime);
use Exporter 'import';
use AnyEvent::ReadLine::Gnu;

use parent 'Local::Chat::AnyEvent::Log';

$Local::Chat::AnyEvent::Log::log = __PACKAGE__->new();

sub _print {
	shift;
	my $data = shift;
	# warn "correct log";
	AnyEvent::ReadLine::Gnu->print($data."\n");
}

1;
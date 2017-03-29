package Local::Chat::Tools;

use 5.016;
use strict;
use Scalar::Util qw(weaken isweak);
use JSON::XS;
use DDP;
use Carp qw(croak);

use Exporter qw(import);

our @EXPORT = our @EXPORT_OK = qw( weaken isweak jdump $JSON string_check callable);

our $JSON = JSON::XS->new->utf8->allow_nonref->canonical;

BEGIN {
	$|++;
	binmode $_, ':utf8' for \*STDIN, \*STDOUT, \*STDERR;
}

sub jdump($) {
	my $str = $JSON->encode( $_[0] );
	utf8::decode($str);
	return $str;
}

my %seen;
sub _string_check;
sub _string_check {
	my $obj = shift;
	if (my $ref = ref $obj) {
		return if $seen{int $obj};
		local $seen{int $obj} = 1;
		if ($ref eq 'ARRAY') {
			_string_check $_, "array value" for @$obj;
		}
		elsif ($ref eq 'HASH') {
			_string_check $_, "hash key" for keys %$obj;
			_string_check $_, "hash value" for values %$obj;
			# _string_check $_ for %$obj;
		}
		return 1;
	}
	else {
		if (utf8::is_utf8( $obj ) or $obj =~ /^[\0-\x7f]*$/s) {
			# ok
			return 1;
		}
		else {
			my $bin = $obj;
			utf8::decode($bin);
			die "Binary or encoded unicode string".($_[0]?" in $_[0]":"").": '$bin'\n";
		}
	}
}

sub string_check {
	my $obj = shift;
	eval {
		_string_check($obj)
	} or do {
		my $e = $@;
		chomp $e;
		return $e;
	};
	return undef;
}

sub callable($) {
	UNIVERSAL::isa( $_[0], 'CODE' ) || UNIVERSAL::can($_[0], '(&{}' )
}

1;

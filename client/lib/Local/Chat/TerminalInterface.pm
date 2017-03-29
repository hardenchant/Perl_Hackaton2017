package Local::Chat::TerminalInterface;

use strict;
use warnings;
use utf8;

use Encode qw(encode_utf8);
use Term::ReadKey;

use constant {
	BLACK   => 30,
	RED     => 31,
	GREEN   => 32,
	YELLOW  => 33,
	BLUE    => "1;34",
	MAGENTA => 35,
	CYAN    => 36,
	WHITE   => 37,
};

use constant BORDER_CHAR => '─';

use Exporter 'import';

our @EXPORT = qw(BLACK RED GREEN YELLOW BLUE MAGENTA CYAN YELLOW);
our %EXPORT_TAGS = ('const' => \@EXPORT);

sub new {
	my $class   = shift;
	my %options = @_;

	my $self = {
		message_buffer => [],
		max_buffer_size => $options{buffer_size} || 150,
		output => $options{output} || \*STDOUT,
		prompt => $options{prompt} || 'Enter your message>',
		terminal_width  => 80,
		terminal_height => 25,
		output_mode => $options{output_mode} || 'normal',
		enable_border => $options{enable_border} || 1,
	};

	bless $self, $class;

	$SIG{__WARN__} = sub {
		my $msg = shift;
		for (@INC) {
			$msg =~ s{(at )\Q$_/\E(.+?line \d+\.)$}{$1$2}m and last;
		}
		$self->add_error($msg);
	};

	return $self->init;
}

sub init {
	my $self = shift;

	$| = 1;
	$self->update_terminal_size;
	$self->{message_buffer} = [];

	$SIG{WINCH} = sub {
		$self->update_terminal_size;
		$self->redraw_output;
		$self->print_prompt;
	};

	return $self;
}

sub finish {
	my $self = shift;

	if ( $self->{output_mode} eq 'reverse' ) {
		$self->_move_cursor( $self->redraw_output + 2 + ( $self->{enable_border} ? 1 : 0 ) );
		$self->_clear_screen();
	}
	else {
		$self->_move_cursor( $self->{terminal_height} );
		print {$self->{output}} "\n";
	}
	$SIG{WINCH} = 'DEFAULT';

	return $self;
}

sub update_terminal_size {
	my $self = shift;

	( $self->{terminal_width}, $self->{terminal_height} ) = GetTerminalSize();

	return $self;
}

sub add_error {
	my $self  = shift;
	my $error = shift;

	$self->_push_message( "\e[" . RED() . ";1m" . 'Error' . "\e[0m" . ': ' . $error );
}

sub add_message {
	my $self    = shift;
	my $message = shift;
	my $color   = shift;

	$message = "\e[" . $color . 'm' . $message . "\e[0m" if $color;
	$self->_push_message( $message );
}

sub print_prompt {
	my $self = shift;

	$self->draw_border;
	$self->_move_cursor( $self->{output_mode} eq 'reverse' ? 1 : $self->{terminal_height}, 1 );
	$self->_clear_line();
	print {$self->{output}} encode_utf8 $self->{prompt} . ' ';
}

sub draw_border {
	my $self = shift;

	return unless $self->{enable_border};

	$self->_move_cursor( $self->{output_mode} eq 'reverse' ? 2 : ( $self->{terminal_height} - 1 ) );
	print {$self->{output}} encode_utf8 BORDER_CHAR() x $self->{terminal_width};
}

sub redraw_output {
	my $self = shift;

	my $max_height = $self->{terminal_height} - ( 1 + ( $self->{enable_border} ? 1 : 0 ) );
	my $prefix = '    ';
	my @rendered_strings;
	foreach my $message ( @{$self->{message_buffer}} ) {
		last if @rendered_strings >= $max_height;

		if ( length $message < $self->{terminal_width} or $message =~ /\e/ ) {
			if ( $self->{output_mode} eq 'reverse' ) {
				push @rendered_strings, $message;
			}
			else {
				unshift @rendered_strings, $message;
			}
			next;
		}

		my $rendered_message = $self->_render_message( $message, $prefix );
		while ( @{$rendered_message} and @rendered_strings < $max_height ) {
			if ( $self->{output_mode} eq 'reverse' ) {
				push @rendered_strings, shift @{$rendered_message};
			}
			else {
				unshift @rendered_strings, pop @{$rendered_message};
			}
		}
	}

	$self->_save_cursor();
	if ( $self->{output_mode} eq 'reverse' ) {
		$self->_move_cursor( 2 + ( $self->{enable_border} ? 1 : 0 ), 1 );
		$self->_clear_screen();
		print {$self->{output}} encode_utf8 join "\n", @rendered_strings;
	}
	else {
		my $lines_to_clear = $self->{terminal_height} - ( 1 + ( $self->{enable_border} ? 1 : 0 ) + scalar @rendered_strings );
		for ( 1 .. $lines_to_clear ) {
			$self->_move_cursor( $_, 1 );
			$self->_clear_line();
		}
		foreach ( 1 .. scalar @rendered_strings ) {
			$self->_move_cursor( $_ + $lines_to_clear, 1 );
			$self->_clear_line();
			print {$self->{output}} encode_utf8 $rendered_strings[$_-1];
		}
	}
	$self->_restore_cursor();

	return scalar @rendered_strings;
}

sub _push_message {
	my $self    = shift;
	my $message = shift;

        if ( $message =~ /\n/ ) {
            $self->_push_message( $_ ) for split /\n/, $message;
            return;
        }
	unshift @{$self->{message_buffer}}, $message;
	splice @{$self->{message_buffer}}, $self->{max_buffer_size} if @{$self->{message_buffer}} > $self->{max_buffer_size};
	$self->redraw_output;
}

sub _render_message {
	my $self    = shift;
	my $message = shift;
	my $prefix  = shift;

	my @rows;
	my $cut_point = _search_cut_point( $message, $self->{terminal_width} );
	push @rows, substr $message, 0, $cut_point;
	$message = substr $message, $cut_point;
	while ( length $message ) {
		$message =~ s/^\s+//;
		if ( length ( $message ) + length ( $prefix ) < $self->{terminal_width} ) {
			push @rows, $prefix . $message;
			$message = '';
		}
		else {
			$cut_point = _search_cut_point( $message, $self->{terminal_width} - length $prefix );
			push @rows, $prefix . substr $message, 0, $cut_point;
			$message = substr $message, $cut_point;
		}
	}

	return \@rows;
}

sub _search_cut_point {
	my $string = shift;
	my $limit  = shift || length $string;

	my $position = index( ( reverse substr ( $string, 0, $limit ) ), ' ' );
	return $position ? ( $limit - $position ) : $limit;
}

sub _save_cursor {
	my $self = shift;

	return print {$self->{output}} "\e7";
}

sub _restore_cursor {
	my $self = shift;

	return print {$self->{output}} "\e8";
}

sub _move_cursor {
	my $self = shift;
	my $row  = shift || '';
	my $col  = shift || '';

	return print {$self->{output}} "\e[${row};${col}H";
}

sub _clear_line {
	my $self = shift;
	my $mode = shift || 2;

	return print {$self->{output}} "\e[${mode}K";
}

sub _clear_screen {
	my $self = shift;
	my $mode = shift || '';

	return print {$self->{output}} "\e[${mode}J";
}

1;

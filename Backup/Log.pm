package Backup::Log;
use strict;
use warnings;

# Defines severities of messages to log
my $TYPES;

my $logfile;
 
sub new {
	my ($class, %args) = @_;
	my $self  = \%args;
	bless $self, $class;
	if (!$self->{TYPES}) {
		$self->{TYPES} = ['ERROR', 'DEBUG', 'INFO'];
	}
	if (!defined($self->{prefixes})) {
		$self->{prefixes} = [];
	}

	return $self;
}

# Creates the time string for log messages
# Usage: getTimestring($unixTimeValue)
sub getTimestring {
	my $self = shift;
	my $t = shift;
	$t = time if !$t;
	my @T = localtime($t);
	my $time = sprintf("%02d/%02d/%04d %02d:%02d:%02d",
	           $T[3], $T[4]+1, $T[5]+1900, $T[2], $T[1], $T[0]);
	return $time;
}
 
# logs an error message
# Usage: logError($message);
sub error {
	my $self = shift;
	my $s = shift;
	$self->log($s, 'ERROR');
}
 
# logs an information message
# Usage: logInfo($message);
sub info {
	my $self = shift;
	my $s = shift;
	$self->log($s, 'INFO');
}
 
# logs a debug message
# Usage: logDebug($message);
sub debug {
	my $self = shift;
	my $s = shift;
	$self->log($s, 'DEBUG');
}
 
# logs a single entry with given message severity
# Usage: logEntry($message, $severity);
sub log {
	my $self = shift;
	my $s = shift;
	my $type = shift;
	return if !grep(/^$type$/, @{$self->{TYPES}});
 
	# build timestamp and string
	$type = $self->rpad($type, 5);
	my $time = $self->getTimestring();
	$s =~ s/\n/\n$time $type - /g;

	# build additional prefixes
	my $prefix = '';
	if (scalar(@{$self->{prefixes}}) > 0) {
		my $p;
		foreach $p (@{$self->{prefixes}}) {
			$prefix .= '['.sprintf('%-'.$p->{size}.'s', $p->{prefix}).']';
		}
	}
 
	# print to STDOUT if required
	my $out = "$time [$type]$prefix $s\n";
	if (!$self->{logfile} || $self->{stdout}) {
		print $out;
	}
	if ($self->{logfile}) {
		if (open(LOGOUT, ">>".$self->{logfile})) {
			print LOGOUT $out;
			close(LOGOUT);
		} else {
			print $out;
		}
	}
}
 
# Right pads a string
# Usage: rpad($string, $maxlen[, $padchar]);
sub rpad {
	my $self = shift;
	my $s = shift;
	my $len = shift;
	my $char = shift;
 
	$char = ' ' if !$char;
	$s .= $char while (length($s) < $len);
	return $s;
}

sub getPrefixLog {
	my $self   = shift;
	my $prefix = shift;
	my $size   = shift;
	$size = length($prefix) if !$size;

	my @P;
	push(@P, @{$self->{prefixes}});
	push(@P, { 'prefix' => $prefix, 'size' => $size});
	return Backup::Log->new('TYPES' => $self->{TYPES}, 'logfile' => $self->{logfile}, 'prefixes' => \@P, 'stdout' => $self->{stdout});
}

1;

package Backup::Executor;
use strict;
use Backup::Log;

sub new {
	my ($class, %args) = @_;
	my $self = \%args;
	bless $self, $class;
	if (defined($self->{logfile})) {
		unlink($self->{logfile});
		$self->{log} = Backup::Log->new('logfile' => $self->{logfile});
	}
	return $self;
}

sub execute {
	my $self = shift;
	my $cmd  = shift;
	my $rc   = 1;

	# We need to grep the output
	$self->{log}->info('> '.$cmd);
	$cmd .= ' 2>&1';
	if (open(FIN, "$cmd|")) {
		while (<FIN>) {
			chomp;
			my $line = $_;
			$self->{log}->info($line);
		}
		close(FIN);
		$rc = $? >> 8;
	} else {
	}
	
	return $rc;
}

1;


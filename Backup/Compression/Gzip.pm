package Backup::Compression::Gzip;
use strict;


sub new {
	my ($class, %args) = @_;
	my $self = \%args;
	bless $self, $class;
	return $self;
}

sub compress {
	my $self = shift;
	my $file = shift;

	my $cmd = $self->{config}->{gzip}.' -f "'.$file.'"';
	my $rc  = 0;
	if (!$self->{config}->{dryRun}) {
		$rc = $self->{executor}->execute($cmd);
	}
	if ($rc) {
		$self->{log}->error('Compressing '.$file.' failed. See '.$self->{executor}->{logfile});
		return 0;
	} else {
		$self->{log}->debug('Compressed: '.$file);
	}
	return $file.'.gz';
}

1;


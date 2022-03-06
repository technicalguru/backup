package Backup::Transfer::Rsync;
use strict;

sub new {
	my ($class, %args) = @_;
	my $self = \%args;
	bless $self, $class;
	return $self;
}

sub transfer {
	my $self  = shift;
	my $files = shift;

	# local and remote directories
	my $rootDir   = $self->{config}->{rootDir};
	$rootDir      = '' if !$rootDir;
	my $localDir  = $self->{config}->{backupDir};
	my $rsync     = $self->{config}->{rsync}.' '.$self->{config}->{rsyncopts};
	my $remote    = $self->{config}->{username}.'@'.$self->{config}->{hostname}.':'.$rootDir;

	# Just start the sync
	my $cmd = $rsync.' -a --delete '.$localDir.'/'.' '.$remote;
	my $rc  = 0;
	if (!$self->{config}->{dryRun}) {
		$self->{log}->info($cmd);
		#$rc = $self->{executor}->execute($cmd);
		#$rc = $rc >> 8;
	} else {
		$self->{log}->info($cmd);
	}
	if ($rc) {
		$self->{log}->error('Error on '.$file.'. See '.$self->{executor}->{logfile});
		$self->{error} = 1;
	} else {
		$self->{log}->debug('Transferred: '.$file);
		$count++;
	}

	#$self->{log}->info(scalar($files).' files transferred');
}

1;


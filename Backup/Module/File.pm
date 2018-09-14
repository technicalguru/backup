package Backup::Module::File;
use strict;
use Backup::Log;
use File::Temp qw/ :POSIX /;

sub new {
	my ($class, %args) = @_;
	my $self = \%args;
	bless $self, $class;
	if (!defined($self->{log})) {
		$self->{log} = Backup::Log->new();
	}
	$self->{error} = 0;
	return $self;
}

sub name {
	my $self = shift;
	return $self->{name};
}

sub backup {
	my $self = shift;
	my $type = shift;
	my @RC = ();
	my $d;

	# Which directories
	my @DIRS;
	if ($type eq 'hourly') {
		@DIRS = @{$self->{config}->{'hourly'}};
	} else {
		@DIRS = @{$self->{config}->{'daily'}};
	}

	if (scalar(@DIRS) > 0) {
		# get the temporary file
		my $file = tmpnam().'.tar.gz';

		# Full or incremental?
		my $tarType = 'full';
		if (($type eq 'hourly') || ($type eq 'daily')) {
			$tarType = 'inc';
		}

		# TAR options
		my $opts = $self->{config}->{'taropts'};
		if ($tarType eq 'inc') {
			my $date = $self->getLastFullBackupTimestamp();
			if ($date) {
				$opts .= ' --newer="'.$date.'"';
			} else {
				$tarType = 'full';
			}
		}

		# Logging
		if ($tarType eq 'full') {
			$self->{log}->info('Creating full backup...');
		} else {
			$self->{log}->info('Creating incremental backup...');
		}
		foreach $d (@DIRS) {
			$self->{log}->debug('Creating backup of '.$d);
		}

		# The TAR command (includes GZIP)
		my $cmd  = $self->{config}->{'tar'}.' -czf "'.$file.'" '.$opts.' '.join(' ', @DIRS);
		my $rc = 0;
		if (!$self->{config}->{dryRun}) {
			$rc = $self->{executor}->execute($cmd);
		}
		if ($rc) {
			$self->{log}->error('TAR command failed. See '.$self->{executor}->{logfile});
			$self->{error} = 1;
		} else {
			$self->{log}->info(scalar(@DIRS).' files/dirs in backup');
			push(@RC, {'name' => $self->{name}.'-'.$tarType, 'noSubDir' => 1, 'filename' => $file, 'needsCompression' => 0});
		}

		# Save the timestamp
		if ($tarType eq 'full' && !$self->{config}->{dryRun}) {
			my $now = `LC_ALL=en_US.utf8 date +%d-%b`;
			chomp($now);
			my $dir = $self->getTimestampFilename();
			$dir =~ s#^.*/##;
			$self->{main}->mkDirs($dir);
			system("echo \"$now\" >".$self->getTimestampFilename());
		}
	} else {
		$self->{log}->info('Nothing to do');
	}

	return @RC;
}

sub getLastFullBackupTimestamp {
	my $self = shift;

	my $file = $self->getTimestampFilename();
	return '' if !-e $file;
	my $rc = `cat $file`;
	chomp($rc);
	return $rc;
}

sub getTimestampFilename {
	my $self = shift;
	return $self->{config}->{timestampFile};
}

1;


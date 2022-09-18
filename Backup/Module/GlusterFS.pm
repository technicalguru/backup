package Backup::Module::GlusterFS;
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
	if (!defined($self->{config}->{mountPath})) {
		$self->{config}->{mountPath} = '/mnt/backup';
	}
	if (!-e $self->{config}->{mountPath}) {
		mkdir($self->{config}->{mountPath});
	}
	$self->{error} = 0;
	return $self;
}

sub backup {
	my $self = shift;
	my $type = shift;
	my @RC = ();
	my $d;

	# Which directories
	my $FS;
	if ($type eq 'hourly') {
		$FS = $self->{config}->{'hourly'};
	} else {
		$FS = $self->{config}->{'daily'};
	}

	if (scalar(keys(%{$FS})) > 0) {
		# Full or incremental?
		my $tarType = 'full';
		if (($type eq 'hourly') || ($type eq 'daily')) {
			$tarType = 'inc';
		}

		# TAR options
		my $opts = $self->{config}->{'taropts'};
		$opts   .= ' --directory='.$self->{config}->{mountPath};
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

		# Each filesystem separately
		my $fsname;
		foreach $fsname (sort(keys(%{$FS}))) {
			my $fsdir = $FS->{$fsname};

			# get the temporary file
			my $file = tmpnam().'.tar.gz';

			$self->{log}->debug('Creating backup of '.$fsdir);

			# Unmount any existing FS (just in case);
			my $cmd = 'umount '.$self->{config}->{mountPath}.' 2>/dev/null';
			$self->{executor}->execute($cmd);

			# Mount the FS
			$cmd = 'mount -t glusterfs '.$fsdir.' '.$self->{config}->{mountPath};
			my $rc = $self->{executor}->execute($cmd);
			if ($rc) {
				$self->{log}->error('MOUNT command failed. See '.$self->{executor}->{logfile});
				$self->{error} = 1;
			} else {
				$cmd = $self->{config}->{'tar'}.' -czf "'.$file.'" '.$opts.' '.$self->{config}->{mountPath};
				$rc  = 0;
				if (!$self->{config}->{dryRun}) {
					$rc = $self->{executor}->execute($cmd);
				}
				if ($rc) {
					$self->{log}->error('TAR command failed. See '.$self->{executor}->{logfile});
					$self->{error} = 1;
					unlink($file);
				} else {
					$self->{log}->info($fsname.' archived');
					push(@RC, {'name' => $fsname.'-'.$tarType, 'targetDir' => $fsname, 'noSubDir' => 1, 'filename' => $file, 'needsCompression' => 0});
				}
			}

			# Unmount FS again;
			$cmd = 'umount '.$self->{config}->{mountPath}.' 2>/dev/null';
			$self->{executor}->execute($cmd);
		}

		# Finally save the timestamp
		if (!$self->{error} && ($tarType eq 'full') && !$self->{config}->{dryRun}) {
			my $now = `LC_ALL=en_US.utf8 date +%d-%b`;
			chomp($now);
			my $dir = $self->getTimestampFilename();
			$dir =~ s#/[^/]+$##;
			$self->{main}->mkDirs($dir);
			system("echo \"$now\" >".$self->getTimestampFilename());
		} elsif ($self->{error}) {
			# Unlink all created files again
			my $file;
			foreach $file (@RC) {
				unlink($file->{filename});
			}
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


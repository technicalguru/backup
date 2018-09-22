package Backup::Main;
use strict;
use Backup::Log;
use Backup::Executor;

my @MONNAME = ('January', 'February', 'March', 'April',
              'May', 'June', 'July', 'August',
              'September', 'October', 'November', 'December'
);
my @WEEKDAYS = ('Sunday', 'Monday', 'Tuesday', 'Wednesday',
                'Thursday', 'Friday', 'Saturday', 'Sunday'
);


sub new {
	my ($class, %args) = @_;
	my $self  = \%args;
	bless $self, $class;
	# Sanity checks
	if (!$self->{config}) {
		die "You need to provide a configuration\n";
	}

	# Initialize
	$self->checkDirectories();
	my @T = localtime(time);
	$self->{timestamp} = \@T;
	if (!$self->{backupType}) {
		$self->computeBackupType();
	}
	$self->computeTimeString();
	if (!$self->{log}) {
		$self->{log} = Backup::Log->new();
	}
	$self->{prefixSize} = $self->getPrefixSize(keys(%{$self->{config}->{modules}}));

	return $self;
}

sub backup {
	my $self = shift;
	my $rc = 0;

	if ($self->{config}->{dryRun}) {
		$self->{log}->info('Running in dry mode...');
	}

	# Load modules
	return 0 if !$self->loadModules();

	# perform the backup in each module
	return 0 if !$self->backupModules();

	if (scalar(@{$self->{files}}) > 0) {
		# Compress files
		$self->compressFiles();

		# Copy files to backup location
		$self->copyFiles();

		# Transfer files to remote location
		$self->transferFiles();

		# Notify errors
		$self->notify();

		# Cleanup
		$self->cleanup();

		# Finally, tell the total backupDir size
		my $backupDir = $self->{config}->{paths}->{backupDir};
		my $size = `du -hs "$backupDir"`;
		chomp($size);
		$self->{log}->info('Total Backup Size: '.$size);
	} else {
		$self->{log}->info('No backup was produced');
	}

	return 1;
}

sub computeBackupType {
	my $self = shift;

	my @T    = @{$self->{timestamp}};
	if ($T[2] != $self->{config}->{dailyBackupHour}) {
		# not daily hour? - return hourly
		$self->{backupType} = 'hourly';
	} elsif ($T[3] == $self->{config}->{monthlyDay}) {
		# 1st of month - monthly
		$self->{backupType} = 'monthly';
	} elsif ($T[6] == $self->{config}->{weeklyWeekday}) {
		# Saturday - weekly
		$self->{backupType} = 'weekly';
	} else {
		# ordinary day
		$self->{backupType} = 'daily';
	}
}

sub computeTimeString {
	my $self = shift;
	my $type = $self->{backupType};
	my @T    = @{$self->{timestamp}};

	if ($type eq 'hourly') {
		$self->{timestring} = 'hour-'.$T[2];
	} elsif ($type eq 'monthly') {
		$self->{timestring} = $MONNAME[$T[4]];
	} elsif ($type eq 'weekly') {
		$self->{timestring} = 'week-'.(`date +%V` % 4);
	} else {
		$self->{timestring} = $WEEKDAYS[$T[6]];
	}
}

sub checkDirectories {
	my $self = shift;
	$self->mkDirs($self->{config}->{paths}->{backupDir});
	$self->mkDirs($self->{config}->{paths}->{logDir});
}

sub mkDirs {
	my $self = shift;
	my $dir  = shift;

	if (!$self->{config}->{dryRun}) {
		my @PARTS = split(/\//, $dir);
		my $check = '';
		my $p;
		foreach $p (@PARTS) {
			$check .= '/'.$p;
			if (!-d $check) {
				mkdir($check) || die "Cannot create directory $check\n";
			}
		}
	}
}

sub loadModules {
	my $self    = shift;
	my @modules = ();
	my $logDir  = $self->{config}->{paths}->{logDir};
	my ($name, $fname);

	foreach $name (keys(%{$self->{config}->{modules}})) {
		my $config = $self->{config}->{modules}->{$name};
		$self->copyConfig($config, 'dryRun');
		my $class  = $config->{module};
		eval {
			(my $pkg = $class) =~ s|::|/|g;
			require "$pkg.pm";
			import $class;
		};
		$fname       = $name;
		$fname       =~ tr/a-z/A-Z/;
		my $executor = Backup::Executor->new('logfile' => $logDir.'/'.$fname.'-'.$self->{timestring}.'.log');
		push(@modules, $class->new('name' => $name, 'log' => $self->{log}->getPrefixLog($name, $self->{prefixSize}), 'config' => $config, 'executor' => $executor, 'main' => $self));
	}
	$self->{modules} = \@modules;
}

sub copyConfig {
	my $self   = shift;
	my $config = shift;
	my @VALUES = @_;
	my $v;

	foreach $v (@VALUES) {
		if (defined($self->{config}->{$v})) {
			$config->{$v} = $self->{config}->{$v};
		}
	}
}

sub backupModules {
	my $self = shift;
	my @FILES = ();
	my ($module);

	foreach $module (sort(@{$self->{modules}})) {
		if ($module->{config}->{enabled}) {
			my @MF = $module->backup($self->{backupType});
			if ($module->{error}) {
				$module->{log}->error('FAILED');
				$self->{error} = 1;
			} else {
				my $desc;
				foreach $desc (@MF) {
					$desc->{module} = $module->{name};
					push(@FILES, $desc);
				}
			}
		}
	}

	$self->{files} = \@FILES;
}

sub compressFiles {
	my $self = shift;

	my $logDir   = $self->{config}->{paths}->{logDir};
	my $executor = Backup::Executor->new('logfile' => $logDir.'/COMPRESS-'.$self->{timestring}.'.log');
	my $config   = $self->{config}->{compression};
	$self->copyConfig($config, 'dryRun');
	my $class    = $config->{module};
	eval {
		(my $pkg = $class) =~ s|::|/|g;
		require "$pkg.pm";
		import $class;
	};
	my $module   = $class->new('log' => $self->{log}->getPrefixLog($config->{name}, $self->{prefixSize}), 'config' => $config, 'executor' => $executor, 'main' => $self);

	# Compress all the backup files
	$module->{log}->info('Compressing backup files...');
	my $backupDesc;
	my $count = 0;
	foreach $backupDesc (@{$self->{files}}) {
		$backupDesc->{transfer} = 1;
		if ($backupDesc->{needsCompression}) {
			my $rc = $module->compress($backupDesc->{filename});
			if (!$rc) {
				$backupDesc->{transfer} = 0;
				$self->{error} = 1;
			} else {
				$backupDesc->{filename} = $rc;
				$count++;
			}
		}
	}
	$module->{log}->info($count.' files compressed');

}

sub copyFiles {
	my $self = shift;

	# Copy files to their backup location
	my $log      =  $self->{log}->getPrefixLog('Copy', $self->{prefixSize});
	$log->info('Copying backup files...');
	my $logDir   = $self->{config}->{paths}->{logDir};
	my $executor = Backup::Executor->new('logfile' => $logDir.'/COPY-'.$self->{timestring}.'.log');
	my $backupDesc;
	my $count = 0;
	foreach $backupDesc (@{$self->{files}}) {
		if ($backupDesc->{transfer}) {
			my $targetDir  = $backupDesc->{module}.'/'.$backupDesc->{name};
			my $filename   = $backupDesc->{filename};
			my $fileext    = $filename;
			my $targetName = $backupDesc->{name};
			if ($backupDesc->{noSubDir}) {
				$targetDir  = $backupDesc->{module};
			}
			$targetName    =~ s#^.*/##;
			$fileext       =~ s/^[^\.]+//;
			$filename      = $targetName.'-'.$self->{timestring}.$fileext;
			# Ensure target
			$self->mkDirs($self->{config}->{paths}->{backupDir}.'/'.$targetDir);
			# Copy
			my $cmd        = 'cp "'.$backupDesc->{filename}.'" "'.$self->{config}->{paths}->{backupDir}.'/'.$targetDir.'/'.$filename.'"';
			my $rc         = 0;
			if (!$self->{config}->{dryRun}) {
				$rc        = $executor->execute($cmd);
			}
			if ($rc) {
				$log->error('Copying failed. See '.$executor->{logfile});
				$self->{error} = 1;
				$backupDesc->{transfer} = 0;
			} else {
				$backupDesc->{transferFile} = $targetDir.'/'.$filename;
				$log->debug('Copied: '.$backupDesc->{filename}.' => '.$backupDesc->{transferFile});
				$count++;
			}
		}
	}
	$log->info($count.' files copied');
}

sub transferFiles {
	my $self = shift;

	if ($self->{config}->{transfer}->{enabled}) {
		my $logDir   = $self->{config}->{paths}->{logDir};
		my $executor = Backup::Executor->new('logfile' => $logDir.'/TRANSFER-'.$self->{timestring}.'.log');
		my $config   = $self->{config}->{transfer};
		$config->{backupDir} = $self->{config}->{paths}->{backupDir};
		$self->copyConfig($config, 'dryRun');
		my $class    = $config->{module};
		eval {
			(my $pkg = $class) =~ s|::|/|g;
			require "$pkg.pm";
			import $class;
		};
		my $module   = $class->new('log' => $self->{log}->getPrefixLog($config->{name}, $self->{prefixSize}), 'config' => $config, 'executor' => $executor, 'main' => $self);

		# Transfer all the backup files
		$module->{log}->info('Transferring files to remote location...');
		my $backupDesc;
		my @files = ();
		foreach $backupDesc (@{$self->{files}}) {
			if ($backupDesc->{transfer}) {
				push(@files, $backupDesc->{transferFile});
			}
		}
		$module->transfer(\@files);
	}
}

sub notify {
	my $self = shift;

	if ($self->{error} && $self->{config}->{notification} && $self->{config}->{notification}->{enabled}) {
		my $logDir   = $self->{config}->{paths}->{logDir};
		my $executor = Backup::Executor->new('logfile' => $logDir.'/NOTIFY-'.$self->{timestring}.'.log');
		my $config   = $self->{config}->{notification};
		$self->copyConfig($config, 'dryRun');
		my $class    = $config->{module};
		eval {
			(my $pkg = $class) =~ s|::|/|g;
			require "$pkg.pm";
			import $class;
		};
		my $module   = $class->new('log' => $self->{log}->getPrefixLog($config->{name}, $self->{prefixSize}), 'config' => $config, 'executor' => $executor, 'main' => $self);

		# Notify the log
		$module->notify($self->{log}->{logfile});
	}
}

sub cleanup {
	my $self = shift;

	my $backupDesc;
	my $count = 0;
	foreach $backupDesc (@{$self->{files}}) {
		unlink($backupDesc->{filename});
	}
	$self->{log}->info('Cleaned up temporary files');
}

sub getPrefixSize {
	my $self = shift;
	my @values = @_;
	my $rc = 0;

	my $v;
	foreach $v (@values) {
		$rc = length($v) if length($v) > $rc;
	}

	return $rc;
}

1;

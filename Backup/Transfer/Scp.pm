package Backup::Transfer::Scp;
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

	# Open SSH connection
	$self->openSsh();

	if (!$self->{error}) {
		# We will need the remote dir list to create remote dirs
		$self->retrieveRemoteDirectoryList();
	}

	if (!$self->{error}) {
		# local and remote directories
		my $rootDir   = $self->{config}->{rootDir};
		$rootDir      = '' if !$rootDir;
		my $localDir  = $self->{config}->{backupDir};
		my $scp       = $self->{config}->{scp}.' '.$self->{config}->{scpopts};
		my $remote    = $self->{config}->{username}.'@'.$self->{config}->{hostname}.':'.$rootDir;

		# Transfer each file
		my $file;
		my $count = 0;
		foreach $file (@{$files}) {
			my $dir = $file;
			$dir =~ s#/[^/]+$##;

			# Transfer it
			$self->checkRemoteDir("$rootDir/$dir");
			my $cmd = $scp.' '.$localDir.'/'.$file.' '.$remote.'/'.$dir.'/';
			my $rc  = 0;
			if (!$self->{config}->{dryRun}) {
				$rc = $self->{executor}->execute($cmd);
				$rc = $rc >> 8;
			}
			if ($rc) {
				$self->{log}->error('Error on '.$file.'. See '.$self->{executor}->{logfile});
				$self->{error} = 1;
			} else {
				$self->{log}->debug('Transferred: '.$file);
				$count++;
			}
		}

		$self->{log}->info($count.' files transferred');
	}
	$self->closeSsh();
}

sub openSsh {
	my $self = shift;
	my $cmd  = $self->getSshCommand();
	if (!open(SSHOUT, "|$cmd >/dev/null")) {
		$self->{error} = 1;
	}
}

sub closeSsh {
	my $self = shift;
	print SSHOUT "exit\n";
}

sub getSshCommand {
	my $self = shift;
	return $self->{config}->{ssh}.' '.$self->{config}->{sshopts}.' -l '.$self->{config}->{username}.' '.$self->{config}->{hostname}.' 2>&1';
}

sub retrieveRemoteDirectoryList {
	my $self = shift;

	# find /home/ralph -type d
	my @dirs = ();
	my $cmd  = '(echo "find '.$self->{config}->{rootDir}.' -type d"; echo "exit") | '.$self->getSshCommand();
	$self->{executor}->{log}->info('> '.$cmd);
	if (open(FIN, $cmd.' 2>'.$self->{executor}->{logfile}.'|')) {
		my $l = $self->{config}->{rootDir};
		while (<FIN>) {
			chomp;
			my $line = $_;
			if ($line =~ /^$l/) {
				push(@dirs, $line);
			}
		}
		close(FIN);
		$self->{remoteDirs} = \@dirs;
	} else {
		$self->{log}->error('Cannot read remote directories');
		$self->{error} = 1;
	}
}

sub checkRemoteDir {
	my $self = shift;
	my $dir  = shift;

	if (!$self->remoteDirExists($dir)) {
		my $cmd = "mkdir -p $dir";
		if (!$self->{config}->{dryRun}) {
			print SSHOUT "$cmd\n";
		} else {
			$self->{log}->debug('SSH: '.$cmd);
		}
		push(@{$self->{remoteDirs}}, $dir);
	}
}

sub remoteDirExists {
	my $self = shift;
	my $dir  = shift;
	my $d;

	foreach $d (@{$self->{remoteDirs}}) {
		return 1 if $d eq $dir;
	}

	return 0;
}

1;


package Backup::Transfer::NcFtp;
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

	# We will need the remote dir list to create remote dirs
	$self->retrieveRemoteDirectoryList();

	if (!$self->{error}) {
		# The command and local/remote root
		my $cmd       = $self->getFtpCommand().' >'.$self->{executor}->{logfile}.' 2>&1';
		my $rootDir   = $self->{config}->{rootDir};
		$rootDir      = '' if !$rootDir;
		my $backupDir = $self->{config}->{backupDir};

		# Login
		if (open(FTPOUT, "|$cmd")) {
			print FTPOUT "binary\n";
			print FTPOUT "set auto-resume yes\n";

			# Transfer each file
			my $file;
			my $count = 0;
			foreach $file (@{$files}) {
				my $dir = $file;
				$dir =~ s#/[^/]+$##;
				$self->checkRemoteDir("$rootDir/$dir");
				$self->sendFtpCmd("cd $rootDir/$dir");
				$self->sendFtpCmd("put $backupDir/$file");
				$self->{log}->debug('Transferred: '.$file);
				$count++;
			}

			# Logout
			print FTPOUT "quit\n";
			close(FTPOUT);

			my $rc = $? >> 8;
			if ($rc) {
				$self->{log}->error('Errors occurred. See '.$self->{executor}->{logfile});
				$self->{error} = 1;
			}
			$self->{log}->info($count.' files transferred');
		}
	}
}

sub getFtpCommand {
	my $self = shift;
	return $self->{config}->{ncftp}.' -u '.$self->{config}->{username}.' -p '.$self->{config}->{password}.' '.$self->{config}->{host};
}

sub sendFtpCmd {
	my $self = shift;
	my $cmd  = shift;

	$self->{log}->debug('FTP Command: '.$cmd);
	if (!$self->{config}->{dryRun}) {
		print FTPOUT "$cmd\n";
	}
}

sub retrieveRemoteDirectoryList {
	my $self = shift;

	my @dirs = ();
	my $cmd  = '(echo "cd /"; echo "ls -laR"; echo "quit") | '.$self->getFtpCommand();
	$self->{executor}->{log}->info('> '.$cmd);
	if (open(FIN, $cmd.' 2>'.$self->{executor}->{logfile}.'|')) {
		while (<FIN>) {
			chomp;
			my $line = $_;
			if ($line =~ /^([^\s]+):$/) {
				push(@dirs, $1);
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

	my @PARTS = split('/', $dir);
	my $d = '';
	my $part;
	foreach $part (@PARTS) {
		$d .= '/'.$part;
		$d =~ s#^//#/#;
		if (!$self->remoteDirExists($d)) {
			$self->sendFtpCmd("mkdir $d");
			push(@{$self->{remoteDirs}}, $d);
		}
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


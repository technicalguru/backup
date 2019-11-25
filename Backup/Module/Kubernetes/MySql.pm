package Backup::Module::Kubernetes::MySql;
use strict;
use File::Temp qw/ :POSIX /;

sub new {
	my ($class, %args) = @_;
	my $self = \%args;
	bless $self, $class;
	$self->{error} = 0;
	return $self;
}

sub backup {
	my $self = shift;
	my $type = shift;
	my @RC = ();

	my $mysql = $self->getMySqlInfos($type);
	if (scalar(keys(%{$mysql})) > 0) {
		my $name;
		my $count = 0;
		foreach $name (keys(%{$mysql})) {
			my $dumpfile = $self->dumpMySql($mysql->{$name});
			if ($dumpfile) {
				$self->{log}->debug('Exporting container DB '.$name.'...done');
				push (@RC, {'name' => 'mysql/'.$name, 'filename' => $dumpfile, 'needsCompression' => 1});
				$count++;
			} else {
				$self->{log}->error('Exporting container DB '.$name.'...failed');
				$self->{log}->error('   See '.$self->{executor}->{logfile});
				$self->{error} = 1;
			}
		}
		$self->{log}->info($count.' databases exported');
	} else {
		$self->{log}->info('Nothing to do');
	}

	return @RC;
}

sub dumpMySql {
	my $self = shift;
	my $info = shift;

	my $dumpfile  = tmpnam().'.sql';
	my $errorfile = $self->{executor}->{logfile};
	my $cmd       = $self->{main}->{config}->{'kubectl'}.' exec '.$info->{pod}.' -n '.$info->{namespace}.' -c '.$info->{container}.' -- sh -c \'exec mysqldump --all-databases -uroot -p"$MYSQL_ROOT_PASSWORD"\' >"'.$dumpfile.'" 2>>"'.$errorfile.'"';
	if (open(FOUT, ">>$errorfile")) {
		print FOUT "> $cmd\n";
		close(FOUT);
	}
	my $rc = 0;
	if (!$self->{config}->{dryRun}) {
		$rc = system($cmd) >> 8;
	}
	return $dumpfile if !$rc;
	unlink($dumpfile);
	return '';
}

sub getMySqlInfos {
	my $self = shift;
	my $type = shift;

	my $info    = $self->{main}->getContainerInfos($type, 'mysql');
	my $mariadb = $self->{main}->getContainerInfos($type, 'mariadb');
	my $rc   = {};
	if ($type eq 'hourly') {
	} else {
		$rc = $info;
		my $name;
		foreach $name (keys(%{$mariadb})) {
			$rc->{$name} = $mariadb->{$name};
		}
	}
	return $rc;
}

1;


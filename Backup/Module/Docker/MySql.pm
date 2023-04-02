package Backup::Module::Docker::MySql;
use strict;
use Backup::Main;
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
		my $id;
		my $count = 0;
		foreach $id (keys(%{$mysql})) {
			my $name = $mysql->{$id}->{name};
			$name    = $1 if !$name;
			if ($mysql->{$id}->{running}) {
				my $dumpfile = $self->dumpMySql($id);
				if ($dumpfile) {
					$self->{log}->debug('Exporting container DB '.$name.'...done');
					push (@RC, {'name' => 'mysql/'.$name, 'filename' => $dumpfile, 'needsCompression' => 1});
					$count++;
				} else {
					$self->{log}->error('Exporting container DB '.$name.'...failed');
					$self->{log}->error('   See '.$self->{executor}->{logfile});
					$self->{error} = 1;
				}
			} else {
				$self->{log}->info('Skipping container '.$name.' - not running');
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
	my $id   = shift;

	my $dumpfile  = Backup::Main::tempname($self->{config}).'.sql';
	my $errorfile = $self->{executor}->{logfile};
	my $cmd       = $self->{main}->{config}->{'docker'}.' exec -ti '.$id.' sh -c \'exec mysqldump --all-databases -uroot -p"$MYSQL_ROOT_PASSWORD"\' >"'.$dumpfile.'" 2>>"'.$errorfile.'"';
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

	my $info = $self->{main}->getContainerInfos($type, 'mysql');
	my $rc   = {};
	if ($type eq 'hourly') {
	} else {
		$rc = $info;
	}
	return $rc;
}

1;


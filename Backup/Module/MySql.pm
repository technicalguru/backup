package Backup::Module::MySql;
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

sub backup {
	my $self = shift;
	my $type = shift;
	my @RC = ();

	# which databases?
	my @DATABASES = $self->getDatabases($type);
	if (scalar(@DATABASES) > 0) {
		# dump the databases
		my $dbname;
		my $count = 0;
		foreach $dbname (@DATABASES) {
			my $file = $self->exportDatabase($dbname);
			if ($file) {
				$self->{log}->debug('Exporting database '.$dbname.'...done');
				push(@RC, {'name' => $dbname, 'filename' => $file, 'needsCompression' => 1});
				$count++;
			} else {
				$self->{log}->error('Exporting database '.$dbname.'...failed');
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

sub exportDatabase {
	my $self   = shift;
	my $dbname = shift;

	my $dumpfile = tmpnam().'.sql';
	my $cmd = $self->{config}->{mysqldump}.
			" \"--user=".$self->{config}->{username}."\"".
			" \"--password=".$self->{config}->{password}."\"".
			" --host=".$self->{config}->{hostname}.
			" --quote-names".
			" --skip-lock-tables".
			" --opt".
			" --databases $dbname \"--result-file=$dumpfile\"";
	my $rc = 0;
	if (!$self->{config}->{dryRun}) {
		$rc = $self->{executor}->execute($cmd);
	}
	return $dumpfile if !$rc;
	unlink($dumpfile);
	return 0;
}

sub getDatabases {
	my $self = shift;
	my $type = shift;
	my @RC = ();

	# hourly backups defined?
	if ($type eq 'hourly') {
		return @{$self->{config}->{hourly}};
	}

	# only selected databases?
	if (defined($self->{config}->{daily}) && (scalar(@{$self->{config}->{daily}}) > 0)) {
		return @{$self->{config}->{daily}};
	}

	# get all databases
	my $cmd = $self->{config}->{mysql}." \"--user=".$self->{config}->{username}."\"".
		" \"--password=".$self->{config}->{password}."\"".
		" --host=".$self->{config}->{hostname}.
		" --batch".
		" --skip-column-names -e \"show databases\"";
	$self->{executor}->{log}->info($cmd);
	if (open(FIN, "$cmd 2>".$self->{executor}->{logfile}."|")) {
		while (<FIN>) {
			chomp;
			my $line = $_;
			next if $line eq 'information_schema';
			next if $line eq 'performance_schema';
			push(@RC, $line);
		}
		close(FIN);
	}

	return @RC;
}

1;


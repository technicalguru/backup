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
	my $self  = shift;
	my $type  = shift;
	my @RC    = ();
	my $count = 0;
	
	# which databases?
	my $INSTANCES = $self->getInstances($type);
	if (scalar(keys(%{$INSTANCES})) > 0) {
		my $name;
		foreach $name (keys(%{$INSTANCES})) {
			# Which databases do we need to export?
			my $instance = $INSTANCES->{$name};
			# Make sure all information is present
			$instance->{hostname} = 'localhost' if !defined($instance->{hostname});
			$instance->{port}     = 3306        if !defined($instance->{port});
			my @SCHEMAS = $self->getSchemas($instance, $type);
			my $schema;
			foreach $schema (@SCHEMAS) {
				my $tmpfile = $self->exportDatabase($instance, $schema);
				if ($tmpfile) {
					$self->{log}->debug('Exporting database '.$name.'/'.$schema.'...done');
					push(@RC, {'name' => $name.'/'.$schema, 'filename' => $tmpfile, 'needsCompression' => 1});
					$count++;
				} else {
					$self->{log}->error('Exporting database '.$name.'/'.$schema.'...failed');
					$self->{log}->error('   See '.$self->{executor}->{logfile});
					$self->{error} = 1;
				}
			}
		}
		$self->{log}->info($count.' databases exported');
	} else {
		$self->{log}->info('Nothing to do');
	}

	return @RC;
}

sub exportDatabase {
	my $self     = shift;
	my $instance = shift;
	my $schema   = shift;

	my $dumpfile = tmpnam().'.sql';
	my $mysqldumpopts = defined($self->{config}->{mysqldumpopts}) ? $self->{config}->{mysqldumpopts} : '';
	my $cmd = $self->{config}->{mysqldump}.
			" --host=".$instance->{hostname}.
			" --port=".$instance->{port}.
			" \"--user=".$instance->{username}."\"".
			" \"--password=".$instance->{password}."\" ".
			$mysqldumpopts.' '.
			" --quote-names".
			" --skip-lock-tables".
			" --opt".
			" --databases $schema \"--result-file=$dumpfile\"";
	my $rc = 0;
	if (!$self->{config}->{dryRun}) {
		$rc = $self->{executor}->execute($cmd);
	}
	return $dumpfile if !$rc;
	unlink($dumpfile);
	return 0;
}

# This shall return now objects of MySqlInstance
sub getInstances {
	my $self = shift;
	my $type = shift;
	my %RC = ();
	my $name;

	# hourly backups defined?
	if ($type eq 'hourly') {
		foreach $name (keys(%{$self->{config}->{instances}})) {
			my $instance = $self->{config}->{instances}->{$name};
			if (defined($instance->{hourly}) && (scalar(@{$instance->{hourly}}) > 0)) {
				$RC{$name} = $instance;
			}
		}
		return \%RC;
	}

	# only selected databases on daily base?
	foreach $name (keys(%{$self->{config}->{instances}})) {
		my $instance = $self->{config}->{instances}->{$name};
		if (!defined($instance->{daily}) || (scalar(@{$instance->{daily}}) > 0)) {
			$RC{$name} = $instance;
		}
	}

	return \%RC;
}

sub getSchemas {
	my $self     = shift;
	my $instance = shift;
	my $type     = shift;
	my @RC;

	if ($type eq 'hourly') {
		if (defined($instance->{hourly}) && (scalar(@{$instance->{hourly}}) > 0)) {
			return @{$instance->{hourly}};
		}
	}

	if (defined($instance->{daily}) && (scalar(@{$instance->{daily}}) > 0)) {
		return @{$instance->{daily}};
	}

	# otherwise return all instances defined
	my $cmd = $self->{config}->{mysql}." \"--user=".$instance->{username}."\"".
		" \"--password=".$instance->{password}."\"".
		" --host=".$instance->{hostname}.
		" --port=".$instance->{port}.
		" --batch".
		" --skip-column-names -e \"show databases\"";
	$self->{executor}->{log}->info($cmd);
	if (open(FIN, "$cmd 2>".$self->{executor}->{logfile}."|")) {
		while (<FIN>) {
			chomp;
			my $line = $_;
			next if $line eq 'information_schema';
			next if $line eq 'performance_schema';
			next if $line eq 'mysql';
			next if $line eq 'sys';
			push(@RC, $line);
		}
		close(FIN);
	}

	return @RC;
}

1;


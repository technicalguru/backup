package Backup::Module::Kubernetes::MySqlAutoDiscover;
use strict;
use File::Temp qw/ :POSIX /;
use Number::Format 'format_number';

sub new {
	my ($class, %args) = @_;
	my $self = \%args;
	bless $self, $class;
	$self->{error} = 0;
	return $self;
}

sub backup {
	my $self  = shift;
	my $type  = shift;
	my @RC    = ();
	my $count = 0;
	my $todo  = 0;
	my ($svc, $labelName);

	# Find the services
	my $services = $self->{main}->invokeKubectl('get svc --all-namespaces');
	foreach $svc (@{$services->{items}}) {
		my $found = 1;
		foreach $labelName (keys(%{$self->{config}->{serviceLabels}})) {
			if (!defined($svc->{metadata}->{labels}->{$labelName}) || ($svc->{metadata}->{labels}->{$labelName} ne $self->{config}->{serviceLabels}->{$labelName})) {
				$found = 0;
				last;
			}
		}
		if ($found) {
			my $name = $svc->{metadata}->{namespace}.'/'.$svc->{metadata}->{name};
			#$self->{log}->info($svc->{metadata}->{namespace}.'/'.$svc->{metadata}->{name});
			my @SCHEMAS = $self->getSchemas($svc, $type);
			my $schema;
			foreach $schema (@SCHEMAS) {
				$todo++;
				my $tmpfile = $self->exportDatabase($svc, $schema);
				if ($tmpfile) {
					my $size = -e $tmpfile ? -s $tmpfile : 0;
					# We directly out this one as it can last a while
					$self->{log}->info('Exporting database '.$name.'/'.$schema.'...done ('.$self->formatSize($size).' Bytes)');
					push(@RC, {'name' => $self->{name}.'/'.$name.'/'.$schema, 'filename' => $tmpfile, 'needsCompression' => 1});
					$count++;
				} else {
					$self->{log}->error('Exporting database '.$name.'/'.$schema.'...failed');
					$self->{log}->error('   See '.$self->{executor}->{logfile});
					$self->{error} = 1;
				}
			}
		}
	}
	if ($count > 0) {
		$self->{log}->info($count.' databases exported');
	} elsif ($todo == 0) {
		$self->{log}->info('Nothing to do');
	}
	return @RC;
}

sub getSchemas {
	my $self = shift;
	my $svc  = shift;
	my $type = shift;
	my @RC   = ();

	if ($type eq 'hourly') {
		if (defined($svc->{metadata}->{labels}->{"technicalguru/backup-hourly"})) {
			@RC = $self->splitSchemaList($svc->{metadata}->{labels}->{"technicalguru/backup-hourly"});
			return @RC if scalar(@RC);
		}
		return @RC;
	}

	if (defined($svc->{metadata}->{labels}->{"technicalguru/backup-dailly"})) {
		@RC = $self->splitSchemaList($svc->{metadata}->{labels}->{"technicalguru/backup-dailly"});
		return @RC if scalar(@RC);
	}

	# otherwise return all instances defined
	my $podName  = $self->getPodName($svc->{metadata}->{name}.'-backup');
	my $cmd = "run $podName -n ".$svc->{metadata}->{namespace}." -ti --image=mariadb --restart=Never --rm -- bash -c \"sleep 3 \&\& ".
		"mysql ".
		" --user=".$self->{config}->{username}.
		" --password=".$self->{config}->{password}.
		" --host=".$svc->{metadata}->{name}.'.'.$svc->{metadata}->{namespace}.'.svc.cluster.local '.
		" --port=".@{$svc->{spec}->{ports}}[0]->{port}.
		" --batch".
		" --skip-column-names -e \\\"show databases\\\"".
		"\"";
	my @LINES = $self->{main}->invokeKubectl($cmd, 'lines');
	if (!defined(scalar(@LINES))) {
#		$self->{log}->error("Cannot retrieve database list");
#		return ();
	}

	my $line;
	foreach $line (@LINES) {
		next if $line eq 'information_schema';
		next if $line eq 'performance_schema';
		next if $line eq 'mysql';
		next if $line eq 'pma';
		next if $line eq 'phpmyadmin';
		next if $line eq 'sys';
		next if $line =~ /pod .* deleted/;
		push(@RC, $line);
	}
	#$self->{log}->info(join(' - ', @RC));

	return @RC;
}

sub getPodName {
	my $self     = shift;
	my $baseName = shift;
	$self->{podBaseIndex} = time if !defined($self->{podBaseIndex});
	$self->{podIndex}     = 0    if !defined($self->{podIndex});
	$self->{podIndex}++;
	return $baseName.'-'.$self->{podBaseIndex}.'-'.$self->{podIndex};
}

sub exportDatabase {
	my $self   = shift;
	my $svc    = shift;
	my $schema = shift;

	my $dumpfile      = tmpnam().'.sql';
	my $podName       = $self->getPodName($svc->{metadata}->{name}.'-backup');
	my $mysqldumpopts = defined($self->{config}->{mysqldumpopts}) ? $self->{config}->{mysqldumpopts} : '';
	my $cmd           = "run $podName -n ".$svc->{metadata}->{namespace}." -ti --image=mariadb --restart=Never --rm -- bash -c \"sleep 3 \&\& ".
		"mysqldump".
		" --user=".$self->{config}->{username}.
		" --password=".$self->{config}->{password}.
		" --host=".$svc->{metadata}->{name}.'.'.$svc->{metadata}->{namespace}.".svc.cluster.local".
		" --port=".@{$svc->{spec}->{ports}}[0]->{port}.
		" --quote-names".
		" $mysqldumpopts".
		" --skip-lock-tables".
		" --opt".
		" --databases".
		" $schema".
		"\"".
		" >$dumpfile";
	# $self->{log}->info($yamlfile);

	if (!$self->{config}->{dryRun}) {
		my $rc = $self->{main}->invokeKubectl($cmd, 'lines');
		if (defined($rc)) {
			# Return the dumpfile
			return $dumpfile;
		} else {
			# Export failed
			unlink($dumpfile);
			return 0;
		}
	}
	
	if ($self->{config}->{dryRun}) {
		return $dumpfile;
	}
	return 0;
}

sub splitSchemaList {
	my $self = shift;
	my $list = shift;
	my $s;
	my @RC   = ();

	foreach $s (split(/[ ,;]+/, $list)) {
		if ($s !~ /^\s*$/) {
			push(@RC, $s);
		}
	}
	return @RC;
}

sub formatSize {
	my $self  = shift;
	my $bytes = shift;

	return format_number($bytes);
}

1;


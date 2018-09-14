package Backup::Module::Kubernetes;
#use strict;
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
	$self->{prefixSize} = $self->{main}->getPrefixSize(keys(%{$self->{config}->{modules}}));
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

	# Load the modules
	my $module;
	my @modules = ();
	foreach $module (keys(%{$self->{config}->{modules}})) {
		my $moduleConfig = $self->{config}->{modules}->{$module};
		$self->{main}->copyConfig($moduleConfig, 'dryRun');
		my $moduleClass  = $moduleConfig->{module};
		eval {
			(my $pkg = $moduleClass) =~ s|::|/|g;
			require "$pkg.pm";
			import $moduleClass;
		};
		push(@modules, $moduleClass->new('log' => $self->{log}->getPrefixLog($module, $self->{prefixSize}), 'config' => $moduleConfig, 'executor' => $self->{executor}, 'main' => $self));
	}

	# Let modules do their job
	foreach $module (@modules) {
		if ($self->{config}->{modules}->{$module->name()}->{enabled}) {
			my @MF = $module->backup($type);
			if ($module->{error}) {
				$self->{error} = 1;
			} elsif (scalar(@MF) > 0) {
				push(@RC, @MF);
			}
		}
	}
	return @RC;
}

sub getContainerInfos {
	my $self   = shift;
	my $type   = shift;
	my $search = shift;

	my $rc = {};
	my %INFOS;
	my ($ns, $pod, $container, $image);

	if ($self->{config}->{'kubectl'}) {
		if ($type eq 'hourly') {
			return $self->{config}->{'hourly'};
		}

		my $cmd = $self->{config}->{'kubectl'}.' get pods --all-namespaces -o jsonpath=\'{range .items[*]}{@.metadata.namespace}{" "}{@.metadata.name}{" "}{@.spec.containers[*].name}{" "}{@.spec..image}{" "}{"\n"}{end}\'|grep '.$search.':';
		if (open(FIN, "$cmd|")) {
			while (<FIN>) {
				chomp;
				my $line = $_;
				($ns, $pod, $container, $image) = split(/\s+/, $line);
				$INFOS{$ns}{$pod}{$container} = $image;
			}

			foreach $ns (keys(%INFOS)) {
				my $nscount = scalar(keys(%{$INFOS{$ns}}));
				foreach $pod (keys(%{$INFOS{$ns}})) {
					my $podcount = scalar(keys(%{$INFOS{$ns}{$pod}}));
					foreach $container (keys(%{$INFOS{$ns}{$pod}})) {
						if ($nscount == 1) {
							if ($podcount == 1) {
								$rc->{$ns} = { 'namespace' => $ns, 'pod'=> $pod, 'container' => $container};
							} else {
								$rc->{"$ns/$container"} = { 'namespace' => $ns, 'pod'=> $pod, 'container' => $container};
							}
						} else {
							if ($podcount == 1) {
								$rc->{"$ns/$pod"} = { 'namespace' => $ns, 'pod'=> $pod, 'container' => $container};
							} else {
								$rc->{"$ns/$pod/$container"} = { 'namespace' => $ns, 'pod'=> $pod, 'container' => $container};
							}
						}
					}
				}
			}
		}
	}

	return $rc;
}

1;


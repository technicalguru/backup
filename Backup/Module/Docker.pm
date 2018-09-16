package Backup::Module::Docker;
use strict;
use Backup::Log;

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
		push(@modules, $moduleClass->new('name' => $module, 'log' => $self->{log}->getPrefixLog($module, $self->{prefixSize}), 'config' => $moduleConfig, 'executor' => $self->{executor}, 'main' => $self));
	}

	# Let modules do their job
	foreach $module (@modules) {
		if ($self->{config}->{modules}->{$module->{name}}->{enabled}) {
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

	if ($self->{config}->{'docker'}) {
		my $cmd = $self->{config}->{'docker'}.' ps -a --format "{{.ID}} | {{.Status}} | {{.Names}}" --filter ancestor='.$search;
		if (open(FIN, "$cmd|")) {
			while (<FIN>) {
				chomp;
				my $line = $_;
				my ($id, $status, $name) = split(/\s*\|\s*/, $line);
				my $running = $status =~ /^Up/i ? 1 : 0;
				$rc->{$id} = { 'name' => $name, 'running' => $running };
			}
		}
	}

	return $rc;
}
1;


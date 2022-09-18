package Backup::Configuration;
use strict;
use Backup::Log;
use JSON::Parse 'parse_json';

my $CONFIG_DIR  = '/etc/backup';
my $CONFIG_FILE = $CONFIG_DIR.'/main.json';

sub new {
	my ($class, %args) = @_;
	my $self = \%args;
	bless $self, $class;
	if (!defined($self->{log})) {
		$self->{log} = Backup::Log->new();
	}
	$self->{error} = 0;
	$self->load();
	return $self;
}

sub load {
	my $self = shift;
	my $json = '{}';
	my $config = $CONFIG_FILE;
	$config = $self->{configFile} if defined($self->{configFile});

	$self->{log}->info('Configuration file: '.$config);
	if (open(FIN, "<$config")) {
		local $/= undef;
		$json = <FIN>;
		close(FIN);
	} else {
		$self->{log}->error('Cannot read file: '.$config);
		$self->{error} = 1;
	}
	$self->{config} = parse_json($json);
}

1;


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
	if (open(FIN, "<$CONFIG_FILE")) {
		local $/= undef;
		$json = <FIN>;
		close(FIN);
	} else {
		$self->{log}->error('Cannot read file: '.$CONFIG_FILE);
		$self->{error} = 1;
	}
	$self->{config} = parse_json($json);
}

1;


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

sub name {
	my $self = shift;
	return $self->{name};
}

sub backup {
	my $self = shift;
	my @RC = ();

	return @RC;
}

1;


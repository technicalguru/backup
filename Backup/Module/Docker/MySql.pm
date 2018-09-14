package Backup::Module::Docker::MySql;
use strict;
use File::Temp qw/ :POSIX /;


sub new {
	my ($class, %args) = @_;
	my $self = \%args;
	bless $self, $class;
	$self->{error} = 0;
	return $self;
}


1;


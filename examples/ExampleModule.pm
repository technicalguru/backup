package examples::ExampleModule;
use strict;
use File::Temp qw/ :POSIX /;

sub new {
	my ($class, %args) = @_;
	my $self = \%args;
	bless $self, $class;
	$self->{error} = 0;
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

	my $file = tmpnam().'.txt';
	my $rc   = system('echo "Hello World" >'.$file);
	if ($rc) {
		$self->{log}->error('Cannot create file: '.$file);
	} else {
		push(@RC, {'name' => 'hello-world', 'filename' => $file, 'needsCompression' => 1});
	}

	return @RC;
}

1;


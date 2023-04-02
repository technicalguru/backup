package examples::ExampleModule;
use strict;
use Backup::Main;

sub new {
	my ($class, %args) = @_;
	my $self = \%args;
	bless $self, $class;
	$self->{error} = 0;
	return $self;
}

sub backup {
	my $self = shift;
	# Type tells the type of the backup: hourly, daily, weekly, monthly
	my $type = shift;
	my @RC = ();

	my $file = Backup::Main::tempname($self->{config}).'.txt';
	my $rc   = 0;

	# Make sure you do not produce a backup when dry-run is active
	if (!$self->{config}->{dryRun}) {
		$rc = system('echo "Hello World" >'.$file);
	} else {
		# In dry-run tell what you would do
		$self->{log}->debug('Hello World debug file created');
	}
	if ($rc) {
		# Always log an error
		$self->{log}->error('Cannot create file: '.$file);
	} else {
		# Return value:
		#    'name'             the name of the backup 
		#    'filename'         the file that contains the backup (temporary file, will be deleted)
		#    'noSubDir'         1 when any sub directory in backup paths shall be flattened (Default: 0)
		#    'targetDir'        a sub directory structure to be used before appending the sub structure and path (optional)
		#    'needsCompression' whether a compression shall be run on the file
		push(@RC, {'name' => 'hello-world', 'filename' => $file, 'targetDir' => 'my-structure', 'noSubDir' => 1, 'needsCompression' => 1});
	}

	# Return all backup file descriptions produced
	return @RC;
}

1;


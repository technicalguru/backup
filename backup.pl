#!/usr/bin/env perl 
use strict;
use warnings;
use diagnostics;
use strict;
# Find modules regardless how the script was called
use File::Basename;
use Cwd qw(abs_path);
use lib dirname (abs_path(__FILE__));
# Load basic modules
use JSON::Parse 'parse_json';
use Getopt::Long;
use Pod::Usage;
use Backup::Main;
use Backup::Log;
use Backup::Executor;
use Backup::Configuration;
use Backup::Module::MySql;

# Checking comand line options
my $help = 0;
my $backupType = undef;
my $configFile = undef;
my $dryRun = 0;
my $debug = 0;
GetOptions(
	'help'          => \$help,       # show help
	'type=s'        => \$backupType, # type of backup
	'config-file=s' => \$configFile, # Configuration file
	'dry-run'       => \$dryRun,     # do not change anything
	'verbose'       => \$debug       # debug output
) or showHelp(1);

if ($help) {
	showHelp(0);
}
if (@ARGV || ($backupType && !grep(/^$backupType$/, ('hourly', 'daily', 'weekly', 'monthly', 'mobile')))) {
	showHelp(1);
}

# Initializing
my $log        = Backup::Log->new('TYPES' => ['ERROR', 'INFO'], 'stdout' => 1);
my $config     = Backup::Configuration->new('log' => $log, 'configFile' => $configFile);
$config->{config}->{backupType} = $backupType;
if ($dryRun) {
	$config->{config}->{dryRun} = 1;
}
if ($debug || $dryRun) {
	push(@{$log->{TYPES}}, 'DEBUG');
}

if (!$config->{error}) {
	# Configuring...
	my $main = Backup::Main->new('config' => $config->{config}, 'log' => $log, 'backupType' => $backupType);

	# Calculate log file
	my $logfile = $main->{config}->{paths}->{logDir}.'/backup-'.$main->{timestring}.'.log';
	system("cp /dev/null $logfile");
	$log->{logfile} = $logfile;

	# Start the backup
	$log->info("============================ BACKUP START - ".$main->{backupType}.' ============================');
	$main->backup();
	$log->info("============================= BACKUP END - ".$main->{backupType}.' =============================');
	exit 0;
}

sub showHelp {
	my $exit = shift;

	pod2usage({-exitval => $exit, -verbose => 1});
}

exit 1;

__END__

=head1 NAME

Performing a backup

=head1 SYNOPSIS

backup.pl [options]

For a complete description of /etc/backup/main.json, please visit https://github.com/technicalguru/backup

=head1 OPTIONS

=over 4

=item B<--help>

Print this help message

=item B<--type=(hourly|daily|weekly|monthly|mobile)>

Type of backup to perform. The type will be set automatically when the option is missing.

=item B<--config-file=path>

The path to the main configuration file (default: /etc/backup/main.json).

=item B<--dry-run>

Perform a dry run only (do not change anything). This will set --verbose, too.

=item B<--verbose>

Show debug output.

=cut


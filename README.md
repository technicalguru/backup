# backup
A Perl-based backup/archiving solution for Linux machines.

I have been an administrator of Linux machines for many years. Since then I had been using my
own little backup script that also fulfills archiving purposes. This GitHub project makes
my work available to everyone and basically is a complete rewrite of the original code. The
new version can now be enhanced easily by new types of backups (as it was required for some
Kubernetes and Docker databases) as well as by new types of compression, notification or
transfers to remote backup locations. 

Features:
* full modular design
* Comes with modules for:
  * Filesystem backups
  * MySQL database backups
  * MySQL database backups from Kubernetes pods
  * MySQL database backups from Docker containers
  * FTP transfer to remote backup location
* extendable by custom backup modules
* GZIP compression of backup files (other types can be plugged in)
* supports hourly, daily, weekly and monthly backups
* keeps archived versions of backups
* notification by email (other types can be plugged in) when errors occur


# Installation and Configuration

* Prerequisites:
  * Perl 5.22 or above
  * `cpan install: JSON::Parse`
* `git clone https://github.com/technicalguru/backup`
* Create /etc/backup/main.json from example

# Testing your backup

* Create backup and log directory (will not be created in test mode)
* `backup.pl --dry-run --type=daily`

# Running a backup

* `backup.pl`
* For cronjob: create a shell file, e.g.

```bash
#!/bin/bash

/usr/local/backup/backup.pl
```
* Define the backup job in ```/etc/crontab```, e.g.:

```crontab
0 * * * * root /usr/local/backup/backup.sh >/var/log/backup/cronjob.log 2>&1
```

# Command Line Options

* `--dry-run` - perform a dry run, do not change anything (will set log level to verbose)
* `--verbose` - set log level to verbose. 
* `--type=(hourly|daily|weekly|monthly)` - perform the given type of backup
* `--help` - show the usage help text

# Writing your own Backup Module

see examples/ExampleModule.pm


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

Clone git repo
Create /etc/backup/main.json from example

# Testing your backup

backup.pl --dry-run --type=daily

# Running a backup

backup.pl

# Command Line Options

--dry-run
--verbose
--type=(hourly|daily|weekly|monthly)
--help

# Writing your own Backup Module

see examples/ExampleModule.pm


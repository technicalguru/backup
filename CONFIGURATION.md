# Configuration

## Location and Format

All configuration needs to be located at `/etc/backup`. It is currently not possible to read the configuration
from any other location.

The configuration must be a text file `main.json` containing strictly valid JSON according to RFC 7159. This specifically requires:

* no single quotes (') instead of double quotes ("),
* no numbers with leading zeros, like 0123. 
* no control characters (0x00 - 0x1F) in strings, 
* no missing commas between array or hash elements like ["a" "b"], 
* no trailing commas like ["a","b","c",]. 
* no trailing non-whitespace, like the second "]" in ["a"]].

An example can be found at [```examples/main.json```](examples/main.json).

# Structure

## Name

```json
	"hostname" : "my-hostname",
```

This information will be used in notifications only and has no further meaning.

## Backup Times

```json
	"dailyBackupHour" : 13,
	"weeklyWeekday"   : 6,
	"monthlyDay"      : 1,
```

| Name | Value | Description |
| ---- | ----- | ----------- |
| dailyBackupHour | integer 0-23 | The hour when a daily backup shall be made instead of an hourly backup |
| weeklyWeekday | integer 0-6 | The weekday (0=Sunday...6=Saturday) when a weekly backup shall be made instead of a daily backup |
| monthlyDay | integer 1-28 | The day of month when a monthly backup shall be made instead of a daily backup |

## Paths

```json
	"paths" : {
		"backupDir" : "/var/backup",
		"logDir"    : "/var/log/backup"
	}
```

| Name | Value | Description |
| ---- | ----- | ----------- |
| backupDir | string | The absolute path where all backups shall be stored |
| logDir | string | The absolute path where log files will be stored |

## Backup Modules

All backups are performed by modules. This enabled new types of backups when
a simple file backup is not sufficient. Modules are defined as follows:

```json
	"modules" : {
		"myModuleName" : {
			"module"  : "Perl::Module::Name",
			"enabled" : true
		}
	}
```

You can give individual names to your modules. These names will be used:

* to enable different module configurations even when the same module is being used
* to store backups in individual paths in your backup directory
* to label all log messages

| Name | Value | Description |
| ---- | ----- | ----------- |
| module | string | The Perl module name being used |
| enabled | boolean | Whether the defined module is active or not |

Additional module configuration can appear - depending on the Perl module.

## Compression Module

A compression step will be performed after all modules made their backup. The module
is defined as follows:

```json
	"compression" : {
		"name"    : "MyCompression",
		"module"  : "Perl::Module::Name",
		"enabled" : true
	}
```

Please check the individual compression module for the correct configuration.

| Name | Value | Description |
| ---- | ----- | ----------- |
| name | string | The individual name that shall be used in log messages |
| module | string | The Perl module name being used |
| enabled | boolean | Whether the defined module is active or not |

## Transfer Module

All backup files that were created can be transferred to a remote location.
This transfer is configured as follows:

```json
	"transfer" : {
		"name"    : "MyTransfer",
		"module"  : "Perl::Module::Name",
		"enabled" : true
	},
```

Please check the individual transfer module for the correct configuration.

| Name | Value | Description |
| ---- | ----- | ----------- |
| name | string | The individual name that shall be used in log messages |
| module | string | The Perl module name being used |
| enabled | boolean | Whether the defined module is active or not |

## Notification Module

The backup program will send out a notification when errors occurred.
Configure this notification as follows:

```json
	notification" : {
		"name"    : "MyNotification",
		"module"  : "Perl::Module::Name",
		"enabled" : true
	}
```

Please check the individual notification module for the correct configuration.

| Name | Value | Description |
| ---- | ----- | ----------- |
| name | string | The individual name that shall be used in log messages |
| module | string | The Perl module name being used |
| enabled | boolean | Whether the defined module is active or not |

# File Module

## Description

This module performs a TAR-based filesystem backup. All backups will be full backups of
the specified directories except daily backups. These daily backups are performed 
incrementally since last full backup.

## Configuration

```json
	"modules" : {
		"myFileBackup" : {
			"module"        : "Perl::Module::File",
			"enabled"       : true,
			"timestampFile" : "/var/backup/LastFullBackup.timestamp",
			"tar"           : "/bin/tar",
			"taropts"       : "--exclude-from=/etc/backup/exclude-files-from-backup",
			"hourly"        : [ ],
			"daily"         : [ "/home", "/etc", "/var" ]
		}
	}
```

| Name | Value | Description |
| ---- | ----- | ----------- |
| timestampFile | string | The path of the file where the module can save the timestamp of its last full backup (required for incremental backups) |
| tar | string | The path of the TAR binary, usually at ```/bin/tar``` |
| taropts | string | Additional options for TAR, e.g. exclude file |
| hourly | list of strings | The path names to backup at each hour |
| daily | list of strings | The path names to backup at daily, weekly and monthly backups (hourly paths shall be included here) |

# GlusterFS Module

## Description

This module performs a TAR-based gluster volume backup. All backups will be full backups of
the specified volumes except daily or hourly backups. These daily and hourly backups are performed 
incrementally since last full backup.

## Configuration

```json
	"modules" : {
		"myGlusterBackup" : {
			"module"        : "Perl::Module::GlusterFS",
			"enabled"       : true,
			"mountPath"     : "/mnt/backup",
			"timestampFile" : "/var/backup/myGlusterBackup/LastFullBackup.timestamp",
			"tar"           : "/bin/tar",
			"taropts"       : "--exclude-from=/etc/backup/exclude-files-from-backup",
			"hourly"        : { },
			"daily"         : { 
				"myVolume1": "gluster-server.domain.com:/glusterpath1",
				"myVolume2": "gluster-server.domain.com:/glusterpath2"
			}
		}
	}
```

| Name | Value | Description |
| ---- | ----- | ----------- |
| mountPath | string | the local path to use for mounting the volumes (Default: /mnt/backup) |
| timestampFile | string | The path of the file where the module can save the timestamp of its last full backup (required for incremental backups) |
| tar | string | The path of the TAR binary, usually at ```/bin/tar``` |
| taropts | string | Additional options for TAR, e.g. exclude file |
| hourly | map of paths | A map of names to GlusterFS URLs to backup at each hour |
| daily | map of paths | A map of names to GlusterFS URLs to backup at daily, weekly and monthly backups (hourly paths shall be included here) |

Please notice that the path maps define a logical name for the volume that later can be found in the backup.

# MySQL Module

## Description

This module connects to any MySQL server and performs a mysqldump. It requires a MySQL
client to be available on the host.

It is possible to define a list of databases that are dumped in hourly backups and in 
daily backups. Weekly and monthly backups will use the daily configuration.

## Configuration

```json
	"modules" : {
		"MySQLBackup"      : {
			"module"        : "Backup::Module::MySql",
			"enabled"       : true,
			"mysql"         : "/usr/bin/mysql",
			"mysqldump"     : "/usr/bin/mysqldump",
			"mysqldumpopts" : "--column-statistics=0",
			"instances"     : {
				"instance-name" : {
					"hostname" : "mysql-host",
					"port"     : 3306,
					"username" : "mysql-user",
					"password" : "mysql-password"
					"hourly"   : [ ],
					"daily"    : [ ]
				}
			}
		},
	}
```

| Name | Value | Description |
| ---- | ----- | ----------- |
| mysql | string | The path of the mysql client binary, usually at ```/usr/bin/mysql``` |
| mysqldump | string | The path of the mysqldump binary, usually at ```/usr/bin/mysqldump``` |
| mysqldumpopts | string | Options to be passed additionally to mysqldump, e.g. for specifics |
| instances | object | Definition of instances to backup with a logical name, you can give multiple instances with different names |
| hostname | string | The MySQL hostname, usually ```localhost``` or ```127.0.0.1``` (Default: localhost) |
| port | number | The port number on the MySQL host, usually ```3306``` (Default: 3306) |
| username | string | The login user at MySQL to be used |
| password| string | The password to be used at MySQL |
| hourly | list of strings | The schemas to backup at each hour. An empty list will not perform an hourly backup. |
| daily | list of strings | The schemas to backup at daily, weekly and monthly backups. An empty list will backup all schemas of that instance |

# Kubernetes Modules

## Description

Kubernetes is specific as usually the data is hidden in pods and containers.
Although container technology is intended to be stateless, you might have some information 
in a few containers that change frequently and cannot be restored when the container is lost.
The Kubernetes modules give you the possibility to extract this information from these
pods and containers and store it on your host.

The Kubernetes module is a meta module that delegates backup tasks to individual sub-modules.
This configuration is alike the main backup script.

## Configuration

```json
	"modules" : {
		"MyKubernetes" : {
			"module"    : "Backup::Module::Kubernetes",
			"enabled"   : true,
			"kubectl"   : "/usr/bin/kubectl",
			"modules"   : {
			}
		}
	}
```

| Name | Value | Description |
| ---- | ----- | ----------- |
| kubectl | string | The path of the Kubernetes kubectl binary, usually at ```/usr/bin/kubectl``` |
| modules | object | The definition of the sub-modules (see subsequent sections) |

## Kubernetes MySQL Module (Deprecated, use MySqlAutoDiscover)

This module connects to a running MySQL container inside Kubernetes and performs a 
mysqldump. This module will auto-discover all containers that derive from the official
mysql DockerHub image.

```json
	"modules" : {
		"MyKubernetes" : {
			"modules"   : {
				"MySQLBackup" : {
					"enabled"   : true,
					"module"    : "Backup::Module::Kubernetes::MySql",
					"hourly"    : [ ],
					"daily"     : [ ]
				}
			}
		}
	}
```

| Name | Value | Description |
| ---- | ----- | ----------- |
| hourly | list of strings | The container names to backup at each hour. An empty list will not perform an hourly backup. |
| daily | list of strings | The container names to backup at daily, weekly and monthly backups. An empty list will backup all containers. |

**Note** The naming scheme for the container names is currently under development. It is advisable to use an empty list at the moment.

## Kubernetes MySqlAutoDiscover Module

This module uses the Kubernetes API to find services matching a defined set of labels. As databases are usually accessed through services
this is the better approach to find databases and export. 

```json
	"modules" : {
				"MySQL" : {
					"enabled"       : true,
					"module"        : "Backup::Module::Kubernetes::MySqlAutoDiscover",
					"serviceLabels" : {
						"technicalguru/backup-class": "mariadb"
					},
					"username"  : "root",
					"password"  : "password"
				}
			}
		}
	}
```

| Name | Value | Description |
| ---- | ----- | ----------- |
| serviceLabels | list of string-value pairs | The labels that a service has to match in order to be included in the backup. |
| username | string | The backup user to be used on all services |
| password | string | the password on all services for the backup user |

Please use another logical module section when your backup users and passwords differ. You need to adjust the selecting labels then.

You can refine the schemas to be included in different backup types by using additional labels:

| Label | Value | Description |
| ---- | ----- | ----------- |
| technicalguru/backup-hourly | string | The schema names (comma-separated) to backup at each hour. An empty list or missing label will not perform an hourly backup. |
| technicalguru/backup-daily | string | The schema names (comma-separated) to backup at daily, weekly and monthly backups. An empty list or missing label will backup all schemas. |

# Docker Module

## Description

Docker is specific as usually the data is hidden in containers.
Although container technology is intended to be stateless, you might have some information 
in a few containers that change frequently and cannot be restored when the container is lost.
The Docker modules give you the possibility to extract this information from these
containers and store it on your host.

The Docker module is a meta module that delegates backup tasks to individual sub-modules.
This configuration is alike the main backup script.

## Configuration

```json
	"modules" : {
		"MyDocker" : {
			"module"    : "Backup::Module::Docker",
			"enabled"   : false,
			"docker"    : "/usr/bin/docker",
			"modules"   : {
			}
		}
	}
```

| Name | Value | Description |
| ---- | ----- | ----------- |
| docker | string | The path of the docker binary, usually at ```/usr/bin/docker``` |
| modules | object | The definition of the sub-modules (see subsequent sections) |

## Docker  MySQL Module

This module connects to a running MySQL container and performs a 
mysqldump. This module will auto-discover all containers that derive from the official
mysql DockerHub image.

```json
	"modules" : {
		"MyDocker" : {
			"modules"   : {
				"MySQLBackup" : {
					"enabled"   : true,
					"module"    : "Backup::Module::Docker::MySql",
					"hourly"    : [ ],
					"daily"     : [ ]
				}
			}
		}
	}
```

| Name | Value | Description |
| ---- | ----- | ----------- |
| hourly | list of strings | The container names to backup at each hour. An empty list will not perform an hourly backup. |
| daily | list of strings | The container names to backup at daily, weekly and monthly backups. An empty list will backup all containers. |

**Note** The naming scheme for the container names is currently under development. It is advisable to use an empty list at the moment.

# Compression Module Gzip

## Description

This module compresses backup files using gzip. It requires gzip to be installed on
your host.

## Configuration

```json
	"compression" : {
		"name"      : "GZIP",
		"module"    : "Backup::Compression::Gzip",
		"gzip"      : "/bin/gzip"
	}
```

| Name | Value | Description |
| ---- | ----- | ----------- |
| gzip | string | The path to the GZIP binary, usually at ```/bin/gzip``` |

# Transfer Module NcFtp

## Description

This module transfers backup files to remote destinations using ncftp. It requires ncftp to be installed on
your host.

## Configuration

```json
	"transfer"      : {
		"name"      : "MyFTP",
		"enabled"   : true,
		"module"    : "Backup::Transfer::NcFtp",
		"ncftp"     : "/usr/bin/ncftp",
		"host"      : "your-ftp-server-hostname",
		"username"  : "ftp-username",
		"password"  : "ftp-password",
		"rootDir"   : "/remote/path"
	}
```

| Name | Value | Description |
| ---- | ----- | ----------- |
| ncftp | string | The path to the ncftp binary, usually at ```/usr/bin/ncftp``` |
| host | string | The hostname of the remote FTP server |
| username | string | The FTP login username |
| password | string | The FTP password |
| rootDir | string | The remote path where the backups shall be stored at the FTP server |

# Transfer Module Scp

## Description

This module transfers backup files to remote destinations using scp. It requires ssh and scp to be installed on
your host. It will also need an SSH identity file to connect to the remote site to avoid password-based authentication.

## Configuration

```json
	"transfer"      : {
		"name"      : "MySCP",
		"enabled"   : true,
		"module"    : "Backup::Transfer::Scp",
		"ssh"       : "/usr/bin/ssh",
		"sshopts"   : "-T -i /path/to/id_rsa",
		"scp"       : "/usr/bin/scp",
		"scpopts"   : "-Bpq -i /path/to/id_rsa",
		"username"  : "my-remote-user",
		"rootDir"   : "/remote/root/path",
		"hostname"  : "remote.server.de"
	}
```

| Name | Value | Description |
| ---- | ----- | ----------- |
| ssh | string | The path to the ssh binary, usually at ```/usr/bin/ssh``` |
| sshopts | string | Options to pass to SSH in order to configure connection. You shall always include -T and -i options |
| scp | string | The path to the scp binary, usually at ```/usr/bin/scp``` |
| scpopts | string | Options to pass to SCP in order to configure connection. You shall always include -Bpq and -i options |
| username | string | The remote login name |
| rootDir | string | The remote path where the backups shall be stored at the server |
| host | string | The hostname of the remote server |

# Transfer Module Rsync

## Description

This module transfers backup files to remote destinations using rsync. It requires rsync to be installed on
your host. It will also need an SSH identity file to connect to the remote site to avoid password-based authentication.

## Configuration

```json
	"transfer"      : {
		"name"      : "MyRsync",
		"enabled"   : true,
		"module"    : "Backup::Transfer::Rsync",
		"rsync"     : "/usr/bin/rsync",
		"rsyncopts" : "-e 'ssh -i /path/to/id_rsa'",
		"username"  : "my-remote-user",
		"rootDir"   : "/remote/root/path",
		"hostname"  : "remote.server.de"
	}
```

| Name | Value | Description |
| ---- | ----- | ----------- |
| rsync | string | The path to the rsync binary, usually at ```/usr/bin/ssh``` |
| rsyncopts | string | Options to pass to rsync in order to configure connection. You shall always include --e option |
| username | string | The remote login name |
| rootDir | string | The remote path where the backups shall be stored at the server |

# Notification Module Email

## Description

This module will email the log file of a failed backup to a defined recipient. It requires sendmail to be
installed on your host.

## Configuration

```json
	"notification" : {
		"name"      : "Email",
		"module"    : "Backup::Notification::Email",
		"enabled"   : true,
		"method"    : "sendmail",
		"sendmail"  : "/usr/sbin/sendmail",
		"sender"    : "sender@example.com",
		"senderName": "Linux Backup",
		"recipient" : "recipient@example.com"
	}
```

| Name | Value | Description |
| ---- | ----- | ----------- |
| method | string | The method to be used for email notification. Currently only ```/sendmail``` is implemented. |
| sendmail | string | (for sendmail only) The path to the sendmail binary, usually at ```/usr/sbin/sendmail``` |
| sender | string | The e-mail address to be used as sender of the email. |
| senderName | string | The sender name to be used. |
| recipient | string | The e-mail address of the recipient of the email. |


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

# Structure

## Name

```json
...
	"hostname" : "my-hostname",
...
```

This information will be used in notifications only and has no further meaning.

## Backup Times

```json
...
	"dailyBackupHour" : 13,
	"weeklyWeekday"   : 6,
	"monthlyDay"      : 1,
...
```

| Name | Value | Description |
| ---- | ----- | ----------- |
| dailyBackupHour | integer 0-23 | The hour when a daily backup shall be made instead of an hourly backup |
| weeklyWeekday | integer 0-6 | The weekday (0=Sunday...6=Saturday) when a weekly backup shall be made instead of a daily backup |
| monthlyDay | integer 1-28 | The day of month when a monthly backup shall be made instead of a daily backup |

## Paths

```json
...
	"paths" : {
		"backupDir" : "/var/backup",
		"logDir"    : "/var/log/backup"
	},
...
```

| Name | Value | Description |
| ---- | ----- | ----------- |
| backupDir | string | The absolute path where all backups shall be stored |
| logDir | string | The absolute path where log files will be stored |

## Backup Modules

All backups are performed by modules. This enabled new types of backups when
a simple file backup is not sufficient. Modules are defined as follows:

```json
...
	"modules" : {
		"myModuleName" : {
			"module"  : "Perl::Module::Name",
			"enabled" : true,
			...
		}
		...
	},
...
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
...
	"compression" : {
		"name"    : "MyCompression",
		"module"  : "Perl::Module::Name",
		"enabled" : true,
		...
	},
...
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
...
	"transfer" : {
		"name"    : "MyTransfer",
		"module"  : "Perl::Module::Name",
		"enabled" : true,
		...
	},
...
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
...
	"notification" : {
		"name"    : "MyNotification",
		"module"  : "Perl::Module::Name",
		"enabled" : true,
		...
	},
...
```

Please check the individual notification module for the correct configuration.

| Name | Value | Description |
| ---- | ----- | ----------- |
| name | string | The individual name that shall be used in log messages |
| module | string | The Perl module name being used |
| enabled | boolean | Whether the defined module is active or not |

# File Module

# MySQL Module

# Kubernetes Module

# Docker Module

# Compression Module Gzip

# Transfer Module NcFtp

# Transfer Module Scp

# Notification Module Email


| Master Branch | Development Branch |
| ------------- |-------------|
|[![Build status](https://ci.appveyor.com/api/projects/status/lut7acvgp6y35h32/branch/master?svg=true)](https://ci.appveyor.com/project/sanderstad/dbaclone/branch/master) | [![Build status](https://ci.appveyor.com/api/projects/status/lut7acvgp6y35h32/branch/development?svg=true)](https://ci.appveyor.com/project/sanderstad/dbaclone/branch/development) |

# dbaclone

<img src="https://psdatabaseclone.org/wp-content/uploads/2018/07/PSDatabaseClone_Logo_128.png" align="left" with="128px" height="131px"/> dbaclone is a PowerShell module for creating SQL Server database images and clones.
It enables administrator to supply environments with database copies that are a fraction of the original size.

Do you have any ideas for new commands? Please propose them as [issues](https://github.com/sqlcollaborative/dbaclone/issues) and let us know what you'd like to see.
Bug reports should also be filed under this repository's issues section.

Take a look at the [wiki](https://github.com/sqlcollaborative/dbaclone/wiki) to get more information on how to install, configure and use dbaclone.

## Why use dbaclone

* Save lots of space provisioning data to other locations
* Spend less time provisioning databases
* Create multiple local copies of a database from the same image
* Make sure there tests are accurate with up-to-date data

## Usage scenarios

There are multiple scenarios where you could use the module with

* Supply developers with a local copy of the database
* Provision non-production servers with production data
* Implement a CI/CD pipeline with production like copies

## Prerequisites

As with every piece of software we need to set some prerequisites to make this module work.

* Windows 10 (Professional, Enterprise or Education) or Windows Server 2012 R2 (Standard, Enterprise or Datacenter) and up
* PowerShell 5 or above
* SQL Server instance for saving image and clone information (dbaclone database)
* SQL Server instance to create the images (can be the same as for saving the information)
* Enough space to save to save one copy of the database (size of the image is the size of the database)

## How does it work

The process consists of the following steps:

1. Setup the module
2. Create an image of the database
3. Create a clone based on an image

It's that easy.

## Planned for future releases

* Default directories for the images
* Creation of multiple disks for a single database to rebuild original file structure

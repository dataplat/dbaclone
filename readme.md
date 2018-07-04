## PSDatabaseClone
<img src="https://www.sqlstad.nl/wp-content/uploads/2018/07/PSDatabaseClone_Logo_128.png" align="left" with="128px" height="131px"/> PSDatabaseClone is a PowerShell module for creating SQL Server database images and clones.
It enables administrator to supply environments with database copies that are a fraction of the original size.

Do you have any ideas for new commands? Please propose them as <a href="https://psdatabaseclone.io/issues" target="_blank">issues</a> and let us know what you'd like to see. Bug reports should also be filed under this repository's issues section.

## Usage scenarios

There are multiple scenarios where you could use the module with
* Supply developers with a local copy of the database
* Provision non-production servers with production data
* Implement a CI/CD pipeline with production like copies

## Why use PSDatabaseClone

* Save lots of space supplying data to other locations
* Spend less time provisioning databases
* Create multiple local copies of a database
* Make sure there tests are accurate with up-to-date data

## Prerequisites

As with every piece of software we need to set some prerequisites to make this module work.

* Windows 10 (Professional, Enterprise or Education) or Windows Server 2012 R2 (Standard, Enterprise or Datacenter) and up
* PowerShell 5 or above
* Hyper-V
* SQL Server instance meant

## How does it work

The process consists of the following steps:

1. Create an image of the database
2. Create a clone based on an image







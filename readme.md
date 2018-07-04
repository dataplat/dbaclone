<img src="https://www.sqlstad.nl/wp-content/uploads/2018/07/PSDatabaseClone_Logo_128.png" alt="psdatabaseclone logo" style="float: left; width: 128px;"> PSDatabaseClone is a PowerShell module for creating SQL Server database images and clones.
It enables administrator to supply environments with database copies that are a fraction of the original size.

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







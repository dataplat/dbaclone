PSDatabaseClone is a PowerShell module for creating SQL Server database images and clones.
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
* Make sure there tests are


## Prerequisites

As with every piece of software we need to set some prerequisites to make this module work.

* PowerShell 5 or above
* Hyper-V
* SQL Server instance meant

## How does it work

The process consists of the following steps:

1. Create an image of the database
2. Create a clone based on an image







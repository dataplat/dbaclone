## PSDatabaseClone
<img src="https://www.sqlstad.nl/wp-content/uploads/2018/07/PSDatabaseClone_Logo_128.png" align="left" with="128px" height="131px"/> PSDatabaseClone is a PowerShell module for creating SQL Server database images and clones.
It enables administrator to supply environments with database copies that are a fraction of the original size.

Do you have any ideas for new commands? Please propose them as <a href="https://psdatabaseclone.io/issues" target="_blank">issues</a> and let us know what you'd like to see. Bug reports should also be filed under this repository's issues section.

<br/>

## Why use PSDatabaseClone

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
* Hyper-V Optional Feature (Windows 10) or Hyper-V Feature (Windows Server)
* SQL Server instance for saving image and clone information (PSDatabaseClone database)
* SQL Server instance to create the images (can be the same as for saving the information)
* Enough space to save to save one copy of the database (size of the image is the size of the database)

## How does it work

The process consists of the following steps:

1. Setup the module
2. Create an image of the database
3. Create a clone based on an image

It's that easy.

## Setup

### Step 1 - Setting up the module
The module needs a central place to save all information about the hosts, images and clones

Execute the following command to setup the module
```powershell
Set-PSDCConfiguration -SqlInstance SQLDB1 -SqlCredential (Get-Credential)
```

This will setup the module to use "SQLDB1" as the database server to host the PSDatabaseClone database.
It will also show a window to insert the credentials for the connection. The database will be called "PSDatabaseClone".

### Step 2 - Create your first image
This is where it gets exciting, you're going to create your image of a database.

For the clones to be able to connect you need to have a share that's accessible for users that will have the clones and the administrators that create the images.

Execute the following command to create an image for the database "DB1" from instance SQLDB1. Instance SQLDB2 is used to create the image.
During the process a new backup will be generated.

```powershell
New-PDCImage -SourceSqlInstance SQLDB1 -DestinationSqlInstance SQLDB2 -ImageNetworkPath \\fileserver\psdatabaseclone\images -Database DB1 -CreateFullBackup
```

### Step 3 - Create a clone
You have done the hard work of creating the image and make sure it's accessible for everyone.

Now it's time to create a clone.

Execute the following command to create a clone

```powershell
New-PDCClone -SqlInstance SQLDB3 -Destination C:\PSDatabaseClone\clones -CloneName DB1_Clone1 -Database DB1 -LatestImage
```

This will look into the central database if there is an image for database "DB1". The clone will be called "DB1_Clone1" and will be placed on the instance SQLDB3.

## Examples

Create an image creating a full backup

```powershell
New-PDCImage -SourceSqlInstance SQLDB1 -DestinationSqlInstance SQLDB2 -ImageNetworkPath \\fileserver\psdatabaseclone\images -Database DB1 -CreateFullBackup
```

Create an image for multiple databases using the latest full backup

```powershell
New-PDCImage -SourceSqlInstance SQLDB1 -DestinationSqlInstance SQLDB2 -ImageNetworkPath \\fileserver\psdatabaseclone\images -Database DB1, DB2 -UseLastFullBackup
```

Create a clone based on the latest image of database DB1

```powershell
New-PDCClone -SqlInstance SQLDB1 -Destination C:\PSDatabaseClone\clones -CloneName DB1_Clone1 -Database DB1 -LatestImage
```

Get the clones for host HOST1

```powershell
Get-PDCClone -HostName HOST1
```

Remove the clones

```powershell
Remove-PDCClone -HostName HOST1 -Database DB1_Clone1, DB2_Clone1
```

Remove the clones using the Get-PDCClone

```powershell
Get-PDCClone -Database DB1_Clone1, DB2_Clone1 | Remove-PDCClone
```

Remove the image

```powershell
Remove-PDCImage -ImageLocation \\fileserver\psdatabaseclone\images\DB1_20180703085917.vhdx
```

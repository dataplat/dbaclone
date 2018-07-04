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

1. Create an image of the database
2. Create a clone based on an image

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

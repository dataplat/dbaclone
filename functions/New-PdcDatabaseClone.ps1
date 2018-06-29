function New-PdcDatabaseClone {
<#
.SYNOPSIS
    New-PdcDatabaseClone creates a new clone

.DESCRIPTION
    New-PdcDatabaseClone willcreate a new clone based on an image.
    The clone will be created in a certain directory, mounted and attached to a database server.

.PARAMETER SqlInstance
    SQL Server name or SMO object representing the SQL Server to connect to

.PARAMETER SqlCredential
    Allows you to login to servers using SQL Logins as opposed to Windows Auth/Integrated/Trusted. To use:

    $scred = Get-Credential, then pass $scred object to the -SqlCredential parameter.

    Windows Authentication will be used if SqlCredential is not specified. SQL Server does not accept Windows credentials being passed as credentials.
    To connect as a different Windows user, run PowerShell as that user.

.PARAMETER ParentVhd
    Points to the parent VHD to create the clone from

.PARAMETER Destination
    Destination directory to save the clone to

.PARAMETER CloneName
    Name of the clone

.PARAMETER Database
    Database name for the clone

.PARAMETER Disabled
    Registers the clone in the configuration as disabled.
    If this setting is used the clone will not be recovered when the repair command is run

.PARAMETER Force
    Forcefully create items when needed

.NOTES
    Author: Sander Stad (@sqlstad, sqlstad.nl)

    Website: https://psdatabaseclone.io
    Copyright: (C) Sander Stad, sander@sqlstad.nl
    License: MIT https://opensource.org/licenses/MIT

.LINK
    https://psdatabaseclone.io/

.EXAMPLE
    New-PdcDatabaseClone -SqlInstance SQLDB1 -ParentVhd C:\Temp\images\DB1_20180623203204.vhdx -Destination C:\Temp\clones\ -CloneName DB1_Clone1

    Create a new clone based on the image DB1_20180623203204.vhdx and attach the database to SQLDB1 as DB1_Clone1

.EXAMPLE
    New-PdcDatabaseClone -SqlInstance SQLDB1 -Database DB1, DB2 -LatestImage

    Create a new clone on SQLDB1 for the databases DB1 and DB2 with the latest image for those databases

.EXAMPLE
    New-PdcDatabaseClone -SqlInstance SQLDB1, SQLDB2 -Database DB1 -LatestImage

    Create a new clone on SQLDB1 and SQLDB2 for the databases DB1 with the latest image
#>
    [CmdLetBinding(DefaultParameterSetName = 'ByLatest')]
    param(
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias("ServerInstance", "SqlServerSqlServer")]
        [object[]]$SqlInstance,

        [System.Management.Automation.PSCredential]
        $SqlCredential,

        [parameter(Mandatory = $true, ParameterSetName = "ByParent")]
        [string]$ParentVhd,

        [string]$Destination,

        [string]$CloneName,

        [parameter(Mandatory = $true, ParameterSetName = "ByLatest")]
        [string[]]$Database,

        [parameter(Mandatory = $true, ParameterSetName = "ByLatest")]
        [switch]$LatestImage,

        [switch]$Disabled,

        [switch]$Force
    )

    begin {

        Write-PSFMessage -Message "Started image creation" -Level Output

        # Test the module database setup
        $result = Test-PdcConfiguration

        if(-not $result.Check){
            Stop-PSFFunction -Message $result.Message -Target $result -Continue
            return
        }

        # Random string
        $random = -join ((65..90) + (97..122) | Get-Random -Count 5 | ForEach-Object {[char]$_})

        # Check the disabled parameter
        $active = 1
        if ($Disabled) {
            $active = 0
        }
    }

    process {
        # Test if there are any errors
        if (Test-PSFFunctionInterrupt) { return }

        # Loop through all the instances
        foreach ($instance in $SqlInstance) {

            # Try connecting to the instance
            Write-PSFMessage -Message "Attempting to connect to Sql Server $SqlInstance.." -Level Output
            try {
                $server = Connect-DbaInstance -SqlInstance $SqlInstance -SqlCredential $SqlCredential
            }
            catch {
                Stop-PSFFunction -Message "Could not connect to Sql Server instance $SqlInstance" -ErrorRecord $_ -Target $SqlInstance
                return
            }

            # Check destination
            if (-not $Destination) {
                $Destination = "$($server.DefaultFile)\clone"
            }
            else {
                # Remove the last "\" from the path it would mess up the mount of the VHD
                if ($Destination.EndsWith("\")) {
                    $Destination = $Destination.Substring(0, $Destination.Length - 1)
                }

                if (-not (Test-Path -Path $Destination)) {
                    Stop-PSFFunction -Message "Could not find destination path $Destination" -Target $SqlInstance
                    return
                }
            }

            # Loopt through all the databases
            foreach ($db in $Database) {

                # Check for the parent
                if ($LatestImage) {
                    $query = "
                        SELECT TOP ( 1 )
                                [ImageLocation],
                                [SizeMB],
                                [DatabaseName],
                                [DatabaseTimestamp],
                                [CreatedOn]
                        FROM [dbo].[Image]
                        WHERE DatabaseName = '$db'
                        ORDER BY CreatedOn DESC;
                    "

                    try {
                        $result = Invoke-DbaSqlQuery -SqlInstance $ecDatabaseServer -Database $ecDatabaseName -Query $query

                        # Check the results
                        if ($result -eq $null) {
                            Stop-PSFFunction -Message "No image could be found for database $db" -Target $ecDatabaseServer -Continue
                        }
                        else {
                            $ParentVhd = $result.ImageLocation
                        }
                    }
                    catch {
                        Stop-PSFFunction -Message "Could not execute query to retrieve latest image" -Target $ecDatabaseServer -Continue
                    }
                }

                # Take apart the vhd directory
                if (Test-Path -Path $ParentVhd) {
                    $parentVhdFileName = $ParentVhd.Split("\")[-1]
                    $parentVhdFile = $parentVhdFileName.Split(".")[0]
                }
                else {
                    Stop-PSFFunction -Message "Parent vhd could not be found" -Target $SqlInstance
                    return
                }

                # Check clone name parameter
                if (-not $CloneName) {
                    $cloneDatabase = $parentVhdFile
                    $CloneName = $parentVhdFile
                    $mountDirectory = "$($parentVhdFile)_$random"
                }
                elseif ($CloneName) {
                    $cloneDatabase = $CloneName
                    $mountDirectory = "$($CloneName)_$random"
                }

                # Check if the database is already present
                if ($server.Databases.Name -contains $cloneDatabase) {
                    Stop-PSFFunction -Message "Database $cloneDatabase is already present on $SqlInstance" -Target $SqlInstance
                    return
                }

                # Setup access path location
                $accessPath = "$Destination\$mountDirectory"

                # Check if access path is already present
                if (-not (Test-Path -Path $accessPath)) {
                    try {
                        $null = New-Item -Path $accessPath -ItemType Directory -Force
                    }
                    catch {
                        Stop-PSFFunction -Message "Couldn't create access path directory" -ErrorRecord $_ -Target $accessPath -Continue
                    }
                }

                # Check if the clone vhd does not yet exist
                if (Test-Path -Path "$Destination\$CloneName.vhdx") {
                    Stop-PSFFunction -Message "Clone $CloneName already exists" -ErrorRecord $_ -Target $accessPath -Continue
                }

                # Create the new child vhd
                try {
                    Write-PSFMessage -Message "Creating clone from $ParentVhd" -Level Verbose

                    $vhd = New-VHD -ParentPath $ParentVhd -Path "$Destination\$CloneName.vhdx" -Differencing
                }
                catch {
                    Stop-PSFFunction -Message "Could not create clone" -Target $vhd -Continue
                }

                # Mount the vhd
                try {
                    Write-PSFMessage -Message "Mounting clone" -Level Verbose

                    # Mount the disk
                    $null = Mount-VHD -Path "$Destination\$CloneName.vhdx" -NoDriveLetter

                    # Get the disk based on the name of the vhd
                    $disk = Get-Disk | Where-Object {$_.Location -eq "$Destination\$CloneName.vhdx"}

                }
                catch {
                    Stop-PSFFunction -Message "Couldn't mount vhd $vhdPath" -ErrorRecord $_ -Target $disk -Continue
                }

                # Check if the disk is offline
                if ($disk.OperationalStatus -eq 'Offline') {
                    $null = Initialize-Disk -Number $disk.DiskNumber -PartitionStyle GPT -ErrorAction SilentlyContinue
                }

                try {
                    # Get the partition based on the disk
                    $partition = Get-Partition -Disk $disk

                    # Create an access path for the disk
                    $null = Add-PartitionAccessPath -DiskNumber $disk.DiskNumber -PartitionNumber $partition.PartitionNumber -AccessPath $accessPath -ErrorAction Ignore
                }
                catch {
                    Stop-PSFFunction -Message "Couldn't create access path for partition" -ErrorRecord $_ -Target $partition -Continue
                }

                # Get all the files of the database
                $databaseFiles = Get-ChildItem -Path $accessPath -Recurse | Where-Object {-not $_.PSIsContainer}

                # Setup the database filestructure
                $dbFileStructure = New-Object System.Collections.Specialized.StringCollection

                # Loop through each of the database files and add them to the file structure
                foreach ($dbFile in $databaseFiles) {
                    $dbFileStructure.Add($dbFile.FullName)
                }

                # Mount the database
                try {
                    Write-PSFMessage -Message "Mounting database from clone" -Level Verbose

                    $null = Mount-DbaDatabase -SqlInstance $SqlInstance -Database $cloneDatabase -FileStructure $dbFileStructure
                }
                catch {
                    Stop-PSFFunction -Message "Couldn't mount database $cloneDatabase" -Target $SqlInstance -Continue
                }

                # Write the data to the database
                try {
                    # Get the data of the host
                    $computerinfo = [System.Net.Dns]::GetHostByName(($env:computerName))

                    $hostname = $env:computerName
                    $ipAddress = $computerinfo.AddressList[0]
                    $fqdn = $computerinfo.HostName

                    # Setup the query to check of the host is already added
                    $query = "
                        IF EXISTS (SELECT HostName FROM Host WHERE HostName ='$hostname')
                        BEGIN
                            SELECT CAST(1 AS BIT) AS HostKnown;
                        END;
                        ELSE
                        BEGIN
                            SELECT CAST(0 AS BIT) AS HostKnown;
                        END;
                    "

                    # Execute the query
                    $result = Invoke-DbaSqlQuery -SqlInstance $ecDatabaseServer -Database $ecDatabaseName -Query $query

                    # Add the host if the host is known
                    if (-not $result.HostKnown) {
                        Write-PSFMessage -Message "Adding host $hostname to database" -Level Verbose

                        $query = "
                            DECLARE @HostID INT;
                            EXECUTE dbo.Host_New @HostID = @HostID OUTPUT, -- int
                                                @HostName = '$hostname',   -- varchar(100)
                                                @IPAddress = '$ipAddress', -- varchar(20)
                                                @FQDN = '$fqdn'			   -- varchar(255)

                            SELECT @HostID AS HostID
                        "

                        Write-PSFMessage -Message "Query New Host`n$query" -Level Debug

                        $hostId = (Invoke-DbaSqlQuery -SqlInstance $ecDatabaseServer -Database $ecDatabaseName -Query $query).HostID
                    }
                    else {
                        Write-PSFMessage -Message "Selecting host $hostname from database" -Level Verbose
                        $query = "SELECT HostID FROM Host WHERE HostName = '$hostname'"

                        $hostId = (Invoke-DbaSqlQuery -SqlInstance $ecDatabaseServer -Database $ecDatabaseName -Query $query).HostID
                    }


                    # Get the image id from the database
                    Write-PSFMessage -Message "Selecting image from database" -Level Verbose
                    $query = "SELECT ImageID FROM dbo.Image WHERE ImageLocation = '$ParentVhd'"
                    $imageId = (Invoke-DbaSqlQuery -SqlInstance $ecDatabaseServer -Database $ecDatabaseName -Query $query).ImageID

                    if ($imageId -ne $null) {

                        $cloneLocation = "$Destination\$CloneName.vhdx"

                        # Setup the query to add the clone to the database
                        Write-PSFMessage -Message "Adding clone $cloneLocation to database" -Level Verbose
                        $query = "
                            DECLARE @CloneID INT;
                            EXECUTE dbo.Clone_New @CloneID = @CloneID OUTPUT,                   -- int
                                                @ImageID = $imageId,		                    -- int
                                                @HostID = $hostId,			                    -- int
                                                @CloneLocation = '$cloneLocation',	            -- varchar(255)
                                                @AccessPath = '$accessPath',                    -- varchar(255)
                                                @SqlInstance = '$($server.DomainInstanceName)', -- varchar(50)
                                                @DatabaseName = '$cloneDatabase',                    -- varchar(100)
                                                @IsEnabled = $active                            -- bit
                        "

                        Write-PSFMessage -Message "Query New Clone`n$query" -Level Debug

                        # execute the query
                        $null = Invoke-DbaSqlQuery -SqlInstance $ecDatabaseServer -Database $ecDatabaseName -Query $query
                    }
                    else {
                        Stop-PSFFunction -Message "Image couldn't be found" -Target $imageName -ErrorRecord $_ -Continue
                    }

                }
                catch {
                    Stop-PSFFunction -Message "Couldn't add image to database" -Target $imageName -ErrorRecord $_ -Continue
                }

                # Add the results to the custom object
                [PSCustomObject]@{
                    ImageID       = $imageId
                    HostID        = $hostId
                    CloneLocation = $cloneLocation
                    AccessPath    = $accessPath
                    SqlInstance   = $server.DomainInstanceName
                    DatabaseName  = $cloneDatabase
                    IsEnabled     = $active
                }

            } # End for each database

        } # End for each sql instance

    } # End process

    end {
        # Test if there are any errors
        if (Test-PSFFunctionInterrupt) { return }

        Write-PSFMessage -Message "Finished creating database clone" -Level Verbose
    }
}
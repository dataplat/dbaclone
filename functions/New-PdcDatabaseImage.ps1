function New-PdcDatabaseImage {
<#
.SYNOPSIS
    New-PdcDatabaseImage creates a new image

.DESCRIPTION
    New-PdcDatabaseImage will create a new image based on a SQL Server database

    The command will either create a full backup or use the last full backup to create the image.

    Every image is created with the name of the database and a time stamp yyyyMMddHHmmss i.e "DB1_20180622171819.vhdx"

.PARAMETER SourceSqlInstance
    Source SQL Server name or SMO object representing the SQL Server to connect to.
    This will be where the database is currently located

.PARAMETER SourceSqlCredential
    Allows you to login to servers using SQL Logins as opposed to Windows Auth/Integrated/Trusted. To use:

    $scred = Get-Credential, then pass $scred object to the -SourceSqlCredential parameter.

    Windows Authentication will be used if SqlCredential is not specified. SQL Server does not accept Windows credentials being passed as credentials.
    To connect as a different Windows user, run PowerShell as that user.

.PARAMETER DestinationSqlInstance
    SQL Server name or SMO object representing the SQL Server to connect to.
    This is the server to use to temporarily restore the database to create the image.

.PARAMETER DestinationSqlCredential
    Allows you to login to servers using SQL Logins as opposed to Windows Auth/Integrated/Trusted. To use:

    $scred = Get-Credential, then pass $scred object to the -DestinationSqlCredential parameter.

    Windows Authentication will be used if SqlCredential is not specified. SQL Server does not accept Windows credentials being passed as credentials.
    To connect as a different Windows user, run PowerShell as that user.

.PARAMETER DestinationCredential
    Allows you to login to other parts of a system like folders. To use:

    $scred = Get-Credential, then pass $scred object to the -DestinationCredential parameter.

.PARAMETER ImageLocalPath
    Network path where to save the image. This has to be a UNC path

.PARAMETER ImageLocalPath
    Local path where to save the image

.PARAMETER Database
    Databases to create an image of

.PARAMETER CreateFullBackup
    Create a new full backup of the database. The backup will be saved in the default backup directory

.PARAMETER UseLastFullBackup
    Use the last full backup created for the database

.PARAMETER Force
    Forcefully execute commands when needed

.NOTES
    Author: Sander Stad (@sqlstad, sqlstad.nl)

    Website: https://psdatabaseclone.io
    Copyright: (C) Sander Stad, sander@sqlstad.nl
    License: MIT https://opensource.org/licenses/MIT

.LINK
    https://psdatabaseclone.io/

.EXAMPLE
    New-PdcDatabaseImage -SourceSqlInstance SQLDB1 -DestinationSqlInstance SQLDB2 -ImageLocalPath C:\Temp\images\ -Database DB1 -CreateFullBackup

    Create an image for databas DB1 from SQL Server SQLDB1. The temporary destination will be SQLDB2.
    The image will be saved in C:\Temp\images.
.EXAMPLE
    New-PdcDatabaseImage -SourceSqlInstance SQLDB1 -DestinationSqlInstance SQLDB2 -ImageLocalPath C:\Temp\images\ -Database DB1 -UseLastFullBackup

    Create an image from the database DB1 on SQLDB1 using the last full backup and use SQLDB2 as the temporary database server.
    The image is written to c:\Temp\images
#>
    [CmdLetBinding()]
    param(
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias("SourceServerInstance", "SourceSqlServerSqlServer")]
        [object]$SourceSqlInstance,

        [System.Management.Automation.PSCredential]
        $SourceSqlCredential,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias("DestinationServerInstance", "DestinationSqlServerSqlServer")]
        [object]$DestinationSqlInstance,

        [System.Management.Automation.PSCredential]
        $DestinationSqlCredential,

        [System.Management.Automation.PSCredential]
        $DestinationCredential,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ImageNetworkPath,

        [string]$ImageLocalPath,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object[]]$Database,

        [switch]$CreateFullBackup,

        [switch]$UseLastFullBackup,

        [switch]$Force

    )

    begin {

        # Test the module database setup
        $result = Test-PdcConfiguration -SqlInstance $ecDatabaseServer -SqlCredential $SqlCredential -Database $ecDatabaseName

        if(-not $result.Check){
            Stop-PSFFunction -Message $result.Message -Target $result -Continue
            return
        }

        $pdcSqlInstance = Get-PSFConfigValue -FullName psdatabaseclone.database.Server
        $pdcDatabase = Get-PSFConfigValue -FullName psdatabaseclone.database.name


        Write-PSFMessage -Message "Started image creation" -Level Output

        # Try connecting to the instance
        Write-PSFMessage -Message "Attempting to connect to Sql Server $SourceSqlInstance.." -Level Output
        try {
            $SourceServer = Connect-DbaInstance -SqlInstance $SourceSqlInstance -SqlCredential $SourceSqlCredential
        }
        catch {
            Stop-PSFFunction -Message "Could not connect to Sql Server instance $SourceSqlInstance" -ErrorRecord $_ -Target $SourceSqlInstance
        }

        # Cleanup the values in the network path
        if ($ImageNetworkPath.EndsWith("\")) {
            $ImageNetworkPath = $ImageNetworkPath.Substring(0, $ImageNetworkPath.Length - 1)
        }

        # Make up the data from the network path
        try {
            [uri]$uri = New-Object System.Uri($ImageNetworkPath)
            $networkHost = $uri.Host
        }
        catch {
            Stop-PSFFunction -Message "The image network path $ImageNetworkPath is not valid" -ErrorRecord $_ -Target $ImageNetworkPath
            return
        }

        # Setup the computer object
        $computer = [PsfComputer]$networkHost

        if (-not $computer.IsLocalhost) {
            $command = "Convert-PdcLocalUncPathToLocalPath -UncPath '$ImageNetworkPath'"
            $commandGetLocalPath = [ScriptBlock]::Create($command)
        }

        # Get the local path from the network path
        if (-not $ImageLocalPath) {
            if ($computer.IsLocalhost) {
                $ImageLocalPath = Convert-PdcLocalUncPathToLocalPath -UncPath $ImageNetworkPath
                Write-PSFMessage -Message "Converted '$ImageNetworkPath' to '$ImageLocalPath'" -Level Verbose
            }
            else {
                $ImageLocalPath = Invoke-PSFCommand -ComputerName $computer -ScriptBlock $commandGetLocalPath -Credential $DestinationCredential
            }
        }

        # Check the image local path
        if ($ImageLocalPath) {
            if ((Test-DbaSqlPath -Path $ImageLocalPath -SqlInstance $SourceSqlInstance -SqlCredential $DestinationCredential) -ne $true) {
                Stop-PSFFunction -Message "Image local path $ImageLocalPath is not valid directory or can't be reached." -Target $SourceSqlInstance
                return
            }

            # Clean up the paths
            if ($ImageLocalPath.EndsWith("\")) {
                $ImageLocalPath = $ImageLocalPath.Substring(0, $ImageLocalPath.Length - 1)
            }

            $imagePath = $ImageLocalPath

        }

        # Check the database parameter
        if ($Database) {
            foreach ($db in $Database) {
                if ($db -notin $SourceServer.Databases.Name) {
                    Stop-PSFFunction -Message "Database $db cannot be found on instance $SourceSqlInstance" -Target $SourceSqlInstance
                }

                $DatabaseCollection = $SourceServer.Databases | Where-Object { $_.Name -in $Database }
            }
        }
        else {
            Stop-PSFFunction -Message "Please supply a database to create an image for" -Target $SourceSqlInstance -Continue
        }

        # Set time stamp
        $timestamp = Get-Date -format "yyyyMMddHHmmss"

    }

    process {
        # Test if there are any errors
        if (Test-PSFFunctionInterrupt) { return }

        # Loop through each of the databases
        foreach ($db in $DatabaseCollection) {
            Write-PSFMessage -Message "Creating image for database $db from $SourceSqlInstance" -Level Verbose

            # Check the database size to the available disk space
            $availableMB = (Get-PSDrive -Name $ImageLocalPath.Substring(0, 1)).Free / 1MB
            $dbSizeMB = $db.Size

            if ($availableMB -lt $dbSizeMB) {
                Stop-PSFFunction -Message "Size of database $($db.Name) does not find within the image local path" -Target $db -Continue
            }

            # Setup the image variables
            $imageName = "$($db.Name)_$timestamp"

            # Setup the access path
            $accessPath = "$($ImageLocalPath)\$imageName"

            # Setup the vhd path
            $vhdPath = "$($accessPath).vhdx"

            if ($CreateFullBackup) {
                # Create the backup
                Write-PSFMessage -Message "Creating new full backup for database $db" -Level Verbose
                Backup-DbaDatabase -SqlInstance $SourceSqlInstance -Database $db.Name

                # Get the last full backup
                Write-PSFMessage -Message "Trying to retrieve the last full backup for $db" -Level Verbose
                $lastFullBackup = Get-DbaBackupHistory -SqlServer $SourceSqlInstance -Databases $db.Name -LastFull -Credential $SourceSqlCredential
            }
            elseif ($UseLastFullBackup) {
                Write-PSFMessage -Message "Trying to retrieve the last full backup for $db" -Level Verbose

                # Get the last full backup
                $lastFullBackup = Get-DbaBackupHistory -SqlServer $SourceSqlInstance -Databases $db.Name -LastFull -Credential $SourceSqlCredential
            }

            # try to create the new VHD
            try {
                Write-PSFMessage -Message "Create the vhd $imageName.vhdx" -Level Verbose
                $vhdDisk = New-PdcVhdDisk -Destination $imagePath -FileName "$imageName.vhdx"
            }
            catch {
                Stop-PSFFunction -Message "Couldn't create vhd $imageName" -Target "$imageName.vhd" -ErrorRecord $_ -Continue
            }

            # Try to initialize the vhd
            try {
                Write-PSFMessage -Message "Initializing the vhd $imageName.vhd" -Level Verbose

                $diskResult = Initialize-PdcVhdDisk -Path $vhdPath -Credential $DestinationCredential
            }
            catch {
                Stop-PSFFunction -Message "Couldn't initialize vhd $vhdPath" -Target $imageName -ErrorRecord $_ -Continue
            }

            # try to create access path
            try {

                # Check if access path is already present
                if (-not (Test-Path -Path $accessPath)) {
                    try {
                        New-Item -Path $accessPath -ItemType Directory -Force | Out-Null
                    }
                    catch {
                        Stop-PSFFunction -Message "Couldn't create access path directory" -ErrorRecord $_ -Target $accessPath -Continue
                    }
                }

                # Create an access path for the disk
                $disk = $diskResult.Disk
                $partition = $diskResult.Partition

                # Add the access path to the mounted disk
                Add-PartitionAccessPath -DiskNumber $disk.DiskNumber -PartitionNumber $partition.PartitionNumber -AccessPath $accessPath -ErrorAction Ignore
            }
            catch {
                Stop-PSFFunction -Message "Couldn't create access path for partition" -ErrorRecord $_ -Target $diskResult.partition
            }

            # # Create folder structure for image
            $imageDataFolder = "$($imagePath)\$imageName\Data"
            $imageLogFolder = "$($imagePath)\$imageName\Log"

            # Check if image folder structure exist
            if (-not (Test-Path -Path $imageDataFolder)) {
                try {
                    Write-PSFMessage -Message "Creating data folder for image" -Level Verbose
                    $null = New-Item -Path $imageDataFolder -ItemType Directory
                }
                catch {
                    Stop-PSFFunction -Message "Couldn't create image data folder" -Target $imageName -ErrorRecord $_ -Continue
                }
            }

            if (-not (Test-Path -Path $imageLogFolder)) {
                try {
                    Write-PSFMessage -Message "Creating transaction log folder for image" -Level Verbose
                    $null = New-Item -Path $imageLogFolder -ItemType Directory
                }
                catch {
                    Stop-PSFFunction -Message "Couldn't create image data folder" -Target $imageName -ErrorRecord $_ -Continue
                }
            }

            # Setup the temporary database name
            $tempDbName = "$($db.Name)-PSDatabaseClone"

            # Restore database to image folder
            try {
                Write-PSFMessage -Message "Restoring database $db on $DestinationSqlInstance" -Level Verbose

                $restore = Restore-DbaDatabase -SqlInstance $DestinationSqlInstance -SqlCredential $DestinationSqlCredential `
                    -DatabaseName $tempDbName -Path $lastFullBackup `
                    -DestinationDataDirectory $imageDataFolder `
                    -DestinationLogDirectory $imageLogFolder
            }
            catch {
                Stop-PSFFunction -Message "Couldn't restore database $db as $tempDbName on $DestinationSqlInstance" -Target $restore -ErrorRecord $_ -Continue
            }

            # Detach database
            try {
                Write-PSFMessage -Message "Detaching database $tempDbName on $DestinationSqlInstance" -Level Verbose

                $query = "EXEC master.dbo.sp_detach_db @dbname = N'$tempDbName'"

                Invoke-DbaSqlQuery -SqlInstance $DestinationSqlInstance -SqlCredential $DestinationSqlCredential -Query $query
            }
            catch {
                Stop-PSFFunction -Message "Couldn't detach database $db as $tempDbName on $DestinationSqlInstance" -Target $imageName -ErrorRecord $_ -Continue
            }

            # Dismount the vhd
            try {
                Write-PSFMessage -Message "Dismounting vhd" -Level Verbose
                Dismount-VHD -Path $vhdPath

                Remove-Item -Path $accessPath -Force
            }
            catch {
                Stop-PSFFunction -Message "Couldn't dismount vhd" -Target $imageName -ErrorRecord $_ -Continue
            }

            # Write the data to the database
            try {
                $imageLocation = "$($uri.LocalPath)\$imageName.vhdx"
                $sizeMB = $dbSizeMB
                $databaseName = $db.Name
                $databaseTS = $lastFullBackup.Start

                $query = "
                    DECLARE @ImageID INT;
                    EXECUTE dbo.Image_New @ImageID = @ImageID OUTPUT,				  -- int
                                        @ImageLocation = '$imageLocation',			  -- varchar(255)
                                        @SizeMB = $sizeMB,							  -- int
                                        @DatabaseName = '$databaseName',			  -- varchar(100)
                                        @DatabaseTimestamp = '$databaseTS'           -- datetime
                "

                Write-PSFMessage -Message "Query New Image`n$query" -Level Debug

                Write-PSFMessage -Message "Saving image information in database" -Level Verbose

                Invoke-DbaSqlQuery -SqlInstance $pdcSqlInstance -Database $pdcDatabase -Query $query

            }
            catch {
                Stop-PSFFunction -Message "Couldn't add image to database" -Target $imageName -ErrorRecord $_ -Continue
            }

            # Add the results to the custom object
            [PSCustomObject]@{
                Location  = $imageLocation
                Size      = $sizeMB
                Database  = $databaseName
                Timestamp = $databaseTS
            }

        } # for each database

    } # end process

    end {
        # Test if there are any errors
        if (Test-PSFFunctionInterrupt) { return }

        Write-PSFMessage -Message "Finished creating database image" -Level Verbose
    }

}
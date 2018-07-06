function New-PSDCClone {
    <#
.SYNOPSIS
    New-PSDCClone creates a new clone

.DESCRIPTION
    New-PSDCClone willcreate a new clone based on an image.
    The clone will be created in a certain directory, mounted and attached to a database server.

.PARAMETER SqlInstance
    SQL Server name or SMO object representing the SQL Server to connect to

.PARAMETER SqlCredential
    Allows you to login to servers using SQL Logins as opposed to Windows Auth/Integrated/Trusted. To use:

    $scred = Get-Credential, then pass $scred object to the -SqlCredential parameter.

    Windows Authentication will be used if SqlCredential is not specified. SQL Server does not accept Windows credentials being passed as credentials.
    To connect as a different Windows user, run PowerShell as that user.

.PARAMETER Credential
    Allows you to login to servers using Windows Auth/Integrated/Trusted. To use:

    $scred = Get-Credential, then pass $scred object to the -Credential parameter.

.PARAMETER ParentVhd
    Points to the parent VHD to create the clone from

.PARAMETER Destination
    Destination directory to save the clone to

.PARAMETER CloneName
    Name of the clone

.PARAMETER Database
    Database name for the clone

.PARAMETER LatestImage
    Automatically get the last image ever created for an specific database

.PARAMETER Disabled
    Registers the clone in the configuration as disabled.
    If this setting is used the clone will not be recovered when the repair command is run

.PARAMETER Force
    Forcefully create items when needed

.PARAMETER EnableException
    By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
    This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
    Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

.PARAMETER WhatIf
    If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.

.PARAMETER Confirm
    If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.

.NOTES
    Author: Sander Stad (@sqlstad, sqlstad.nl)

    Website: https://psdatabaseclone.io
    Copyright: (C) Sander Stad, sander@sqlstad.nl
    License: MIT https://opensource.org/licenses/MIT

.LINK
    https://psdatabaseclone.io/

.EXAMPLE
    New-PSDCClone -SqlInstance SQLDB1 -ParentVhd C:\Temp\images\DB1_20180623203204.vhdx -Destination C:\Temp\clones\ -CloneName DB1_Clone1

    Create a new clone based on the image DB1_20180623203204.vhdx and attach the database to SQLDB1 as DB1_Clone1

.EXAMPLE
    New-PSDCClone -SqlInstance SQLDB1 -Database DB1, DB2 -LatestImage

    Create a new clone on SQLDB1 for the databases DB1 and DB2 with the latest image for those databases

.EXAMPLE
    New-PSDCClone -SqlInstance SQLDB1, SQLDB2 -Database DB1 -LatestImage

    Create a new clone on SQLDB1 and SQLDB2 for the databases DB1 with the latest image
#>
    [CmdLetBinding(DefaultParameterSetName = 'ByLatest', SupportsShouldProcess = $true)]
    param(
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [object[]]$SqlInstance,
        [System.Management.Automation.PSCredential]
        $SqlCredential,
        [System.Management.Automation.PSCredential]
        $Credential,
        [parameter(Mandatory = $true, ParameterSetName = "ByParent")]
        [string]$ParentVhd,
        [string]$Destination,
        [string]$CloneName,
        [parameter(Mandatory = $true, ParameterSetName = "ByLatest")]
        [string[]]$Database,
        [parameter(Mandatory = $true, ParameterSetName = "ByLatest")]
        [switch]$LatestImage,
        [switch]$Disabled,
        [switch]$Force,
        [switch]$EnableException
    )

    begin {

        # Test the module database setup
        try {
            Test-PSDCConfiguration -EnableException
        }
        catch {
            Stop-PSFFunction -Message "Something is wrong in the module configuration" -ErrorRecord $_ -Continue
        }

        $pdcSqlInstance = Get-PSFConfigValue -FullName psdatabaseclone.database.server
        $pdcDatabase = Get-PSFConfigValue -FullName psdatabaseclone.database.name

        Write-PSFMessage -Message "Started image creation" -Level Verbose

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
            Write-PSFMessage -Message "Attempting to connect to Sql Server $SqlInstance.." -Level Verbose
            try {
                $server = Connect-DbaInstance -SqlInstance $SqlInstance -SqlCredential $SqlCredential
            }
            catch {
                Stop-PSFFunction -Message "Could not connect to Sql Server instance $SqlInstance" -ErrorRecord $_ -Target $SqlInstance
            }

            # Setup the computer object
            $computer = [PsfComputer]$server.Name

            # Check destination
            if (-not $Destination) {
                $Destination = "$($server.DefaultFile)\clone"
            }
            else {
                # If the destination is a network path
                if ($Destination.StartsWith("\\")) {
                    Write-PSFMessage -Message "The destination cannot be an UNC path. Trying to convert to local path" -Level Verbose

                    try {
                        # Check if computer is local
                        if ($computer.IsLocalhost) {
                            $Destination = Convert-PSDCLocalUncPathToLocalPath -UncPath $Destination -Credential $Credential
                        }
                        else {
                            $command = [ScriptBlock]::Create("Convert-PSDCLocalUncPathToLocalPath -UncPath '$Destination'")
                            $Destination = Invoke-PSFCommand -ComputerName $computer -ScriptBlock $command -Credential $Credential
                        }
                    }
                    catch {
                        Stop-PSFFunction -Message "Something went wrong getting the local image path" -Target $Destination
                        return
                    }
                }

                # Remove the last "\" from the path it would mess up the mount of the VHD
                if ($Destination.EndsWith("\")) {
                    $Destination = $Destination.Substring(0, $Destination.Length - 1)
                }

                # Test if the destination can be reached
                if (-not (Test-Path -Path $Destination -Credential $Credential)) {
                    Stop-PSFFunction -Message "Could not find destination path $Destination" -Target $SqlInstance
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
                        $result = Invoke-DbaSqlQuery -SqlInstance $pdcSqlInstance -SqlCredential $SqlCredential -Database $pdcDatabase -Query $query -EnableException

                        # Check the results
                        if ($null -eq $result) {
                            Stop-PSFFunction -Message "No image could be found for database $db" -Target $pdcSqlInstance -Continue
                        }
                        else {
                            $ParentVhd = $result.ImageLocation
                        }
                    }
                    catch {
                        Stop-PSFFunction -Message "Could not execute query to retrieve latest image" -Target $pdcSqlInstance -ErrorRecord $_ -Continue
                    }
                }

                # Take apart the vhd directory
                if (Test-Path -Path $ParentVhd) {
                    $parentVhdFileName = $ParentVhd.Split("\")[-1]
                    $parentVhdFile = $parentVhdFileName.Split(".")[0]
                }
                else {
                    Stop-PSFFunction -Message "Parent vhd could not be found" -Target $SqlInstance -Continue
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
                }

                # Setup access path location
                $accessPath = "$Destination\$mountDirectory"

                # Check if access path is already present
                if (-not (Test-Path -Path $accessPath -Credential $sou)) {
                    try {
                        # Check if computer is local
                        if ($computer.IsLocalhost) {

                        }
                        else {
                            $command = [ScriptBlock]::Create("")
                            $Destination = Invoke-PSFCommand -ComputerName $computer -ScriptBlock $command -Credential $Credential
                        }
                        $null = New-Item -Path $accessPath -ItemType Directory -Credential $Credential -Force
                    }
                    catch {
                        Stop-PSFFunction -Message "Couldn't create access path directory" -ErrorRecord $_ -Target $accessPath -Continue
                    }
                }

                # Check if the clone vhd does not yet exist
                if (Test-Path -Path "$Destination\$CloneName.vhdx" -Credential $DestinationCredential) {
                    Stop-PSFFunction -Message "Clone $CloneName already exists" -Target $accessPath -Continue
                }

                # Create the new child vhd
                try {
                    Write-PSFMessage -Message "Creating clone from $ParentVhd" -Level Verbose

                    # Check if computer is local
                    if ($computer.IsLocalhost) {

                    }
                    else {
                        $command = [ScriptBlock]::Create("")
                        $Destination = Invoke-PSFCommand -ComputerName $computer -ScriptBlock $command -Credential $Credential
                    }
                    $vhd = New-VHD -ParentPath $ParentVhd -Path "$Destination\$CloneName.vhdx" -Differencing
                }
                catch {
                    Stop-PSFFunction -Message "Could not create clone" -Target $vhd -Continue
                }

                # Mount the vhd
                try {
                    Write-PSFMessage -Message "Mounting clone" -Level Verbose

                    # Check if computer is local
                    if ($computer.IsLocalhost) {

                    }
                    else {
                        $command = [ScriptBlock]::Create("")
                        $Destination = Invoke-PSFCommand -ComputerName $computer -ScriptBlock $command -Credential $Credential
                    }
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
                    # Check if computer is local
                    if ($computer.IsLocalhost) {
                        $null = Initialize-Disk -Number $disk.DiskNumber -PartitionStyle GPT -ErrorAction SilentlyContinue
                    }
                    else {
                        $command = [ScriptBlock]::Create("Initialize-Disk -Number $($disk.DiskNumber) -PartitionStyle GPT -ErrorAction SilentlyContinue")
                        $null = Invoke-PSFCommand -ComputerName $computer -ScriptBlock $command -Credential $Credential
                    }
                }

                try {
                    # Check if computer is local
                    if ($computer.IsLocalhost) {
                        # Get the partition based on the disk
                        $partition = Get-Partition -Disk $disk

                        # Create an access path for the disk
                        $null = Add-PartitionAccessPath -DiskNumber $disk.Number -PartitionNumber $partition[1].PartitionNumber -AccessPath $accessPath -ErrorAction Ignore
                    }
                    else {
                        $command = [ScriptBlock]::Create("Get-Partition -Disk $disk")
                        $partition = Invoke-PSFCommand -ComputerName $computer -ScriptBlock $command -Credential $Credential

                        $command = [ScriptBlock]::Create("Add-PartitionAccessPath -DiskNumber $($disk.Number) -PartitionNumber $($partition[1].PartitionNumber) -AccessPath $accessPath -ErrorAction Ignore")
                        $null = Invoke-PSFCommand -ComputerName $computer -ScriptBlock $command -Credential $Credential
                    }

                }
                catch {
                    Stop-PSFFunction -Message "Couldn't create access path for partition" -ErrorRecord $_ -Target $partition -Continue
                }

                # Get all the files of the database
                # Check if computer is local
                if ($computer.IsLocalhost) {
                    $databaseFiles = Get-ChildItem -Path $accessPath -Recurse | Where-Object {-not $_.PSIsContainer}
                }
                else {
                    $command = [ScriptBlock]::Create("Get-ChildItem -Path $accessPath -Recurse | Where-Object {-not $($_.PSIsContainer)}")
                    $databaseFiles = Invoke-PSFCommand -ComputerName $computer -ScriptBlock $command -Credential $Credential
                }


                # Setup the database filestructure
                $dbFileStructure = New-Object System.Collections.Specialized.StringCollection

                # Loop through each of the database files and add them to the file structure
                foreach ($dbFile in $databaseFiles) {
                    $null = $dbFileStructure.Add($dbFile.FullName)
                }

                # Mount the database
                try {
                    Write-PSFMessage -Message "Mounting database from clone" -Level Verbose

                    # Check if computer is local
                    if ($computer.IsLocalhost) {
                        $null = Mount-DbaDatabase -SqlInstance $SqlInstance -Database $cloneDatabase -FileStructure $dbFileStructure
                    }
                    else {
                        $command = [ScriptBlock]::Create("Mount-DbaDatabase -SqlInstance $SqlInstance -Database $cloneDatabase -FileStructure $dbFileStructure")
                        $null = Invoke-PSFCommand -ComputerName $computer -ScriptBlock $command -Credential $Credential
                    }
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
                    $result = Invoke-DbaSqlQuery -SqlInstance $pdcSqlInstance -SqlCredential $SqlCredential -Database $pdcDatabase -Query $query -EnableException
                }
                catch {
                    Stop-PSFFunction -Message "Couldnt execute query to see if host was known" -Target $query -ErrorRecord $_ -Continue
                }

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

                    try {
                        $hostId = (Invoke-DbaSqlQuery -SqlInstance $pdcSqlInstance -SqlCredential $SqlCredential -Database $pdcDatabase -Query $query -EnableException).HostID
                    }
                    catch {
                        Stop-PSFFunction -Message "Couldnt execute query for adding host" -Target $query -ErrorRecord $_ -Continue
                    }
                }
                else {
                    Write-PSFMessage -Message "Selecting host $hostname from database" -Level Verbose
                    $query = "SELECT HostID FROM Host WHERE HostName = '$hostname'"

                    try {
                        $hostId = (Invoke-DbaSqlQuery -SqlInstance $pdcSqlInstance -SqlCredential $SqlCredential -Database $pdcDatabase -Query $query -EnableException).HostID
                    }
                    catch {
                        Stop-PSFFunction -Message "Couldnt execute query for retrieving host id" -Target $query -ErrorRecord $_ -Continue
                    }
                }


                # Get the image id from the database
                Write-PSFMessage -Message "Selecting image from database" -Level Verbose
                try {
                    $query = "SELECT ImageID, ImageName FROM dbo.Image WHERE ImageLocation = '$ParentVhd'"
                    $resultImage = Invoke-DbaSqlQuery -SqlInstance $pdcSqlInstance -SqlCredential $SqlCredential -Database $pdcDatabase -Query $query -EnableException
                }
                catch {
                    Stop-PSFFunction -Message "Couldnt execute query for retrieving image id" -Target $query -ErrorRecord $_ -Continue
                }


                if ($null -ne $resultImage.ImageID) {

                    $cloneLocation = "$Destination\$CloneName.vhdx"

                    # Setup the query to add the clone to the database
                    Write-PSFMessage -Message "Adding clone $cloneLocation to database" -Level Verbose
                    $query = "
                                DECLARE @CloneID INT;
                                EXECUTE dbo.Clone_New @CloneID = @CloneID OUTPUT,                   -- int
                                                    @ImageID = $($resultImage.ImageID),		        -- int
                                                    @HostID = $hostId,			                    -- int
                                                    @CloneLocation = '$cloneLocation',	            -- varchar(255)
                                                    @AccessPath = '$accessPath',                    -- varchar(255)
                                                    @SqlInstance = '$($server.DomainInstanceName)', -- varchar(50)
                                                    @DatabaseName = '$cloneDatabase',               -- varchar(100)
                                                    @IsEnabled = $active                            -- bit

                                SELECT @CloneID AS CloneID
                            "

                    Write-PSFMessage -Message "Query New Clone`n$query" -Level Debug

                    # execute the query
                    try {
                        $result = Invoke-DbaSqlQuery -SqlInstance $pdcSqlInstance -SqlCredential $SqlCredential -Database $pdcDatabase -Query $query -EnableException
                    }
                    catch {
                        Stop-PSFFunction -Message "Couldnt execute query for adding clone" -Target $query -ErrorRecord $_ -Continue
                    }

                }
                else {
                    Stop-PSFFunction -Message "Image couldn't be found" -Target $imageName -Continue
                }

                # Add the results to the custom object
                [PSDCClone]$clone = New-Object PSDCClone

                $clone.CloneID = $result.CloneID
                $clone.CloneLocation = $cloneLocation
                $clone.AccessPath = $accessPath
                $clone.SqlInstance = $server.DomainInstanceName
                $clone.DatabaseName = $cloneDatabase
                $clone.IsEnabled = $active
                $clone.ImageID = $resultImage.ImageID
                $clone.ImageName = $resultImage.ImageName
                $clone.ImageLocation = $ParentVhd
                $clone.HostName = $hostname

                return $clone

            } # End for each database

        } # End for each sql instance

    } # End process

    end {
        # Test if there are any errors
        if (Test-PSFFunctionInterrupt) { return }

        Write-PSFMessage -Message "Finished creating database clone" -Level Verbose
    }
}

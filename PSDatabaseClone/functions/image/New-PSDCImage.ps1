function New-PSDCImage {
    <#
    .SYNOPSIS
        New-PSDCImage creates a new image

    .DESCRIPTION
        New-PSDCImage will create a new image based on a SQL Server database

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

    .PARAMETER SourceCredential
        Allows you to login to other parts of a system like folders. To use:

        $scred = Get-Credential, then pass $scred object to the -SourceCredential parameter.

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

    .PARAMETER PSDCSqlCredential
        Allows you to login to servers using SQL Logins as opposed to Windows Auth/Integrated/Trusted.
        This works similar as SqlCredential but is only meant for authentication to the PSDatabaseClone database server and database.

        By default the script will try to retrieve the configuration value "psdatabaseclone.informationstore.credential"

    .PARAMETER ImageNetworkPath
        Network path where to save the image. This has to be a UNC path

    .PARAMETER ImageLocalPath
        Local path where to save the image

    .PARAMETER Database
        Databases to create an image of

    .PARAMETER VhdType
        The type of the harddisk. This can either by VHD (version 1) or VHDX (version 2)
        The default is VHDX.

    .PARAMETER CreateFullBackup
        Create a new full backup of the database. The backup will be saved in the default backup directory

    .PARAMETER UseLastFullBackup
        Use the last full backup created for the database

    .PARAMETER CopyOnlyBackup
        Create a backup as COPY_ONLY

    .PARAMETER MaskingConfigFile
        Configuration file that contains the which tables and columns need to be masked

    .PARAMETER Force
        Forcefully execute commands when needed

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

        Website: https://psdatabaseclone.org
        Copyright: (C) Sander Stad, sander@sqlstad.nl
        License: MIT https://opensource.org/licenses/MIT

    .LINK
        https://psdatabaseclone.org/

    .EXAMPLE
        New-PSDCImage -SourceSqlInstance SQLDB1 -DestinationSqlInstance SQLDB2 -ImageLocalPath C:\Temp\images\ -Database DB1 -CreateFullBackup

        Create an image for databas DB1 from SQL Server SQLDB1. The temporary destination will be SQLDB2.
        The image will be saved in C:\Temp\images.
    .EXAMPLE
        New-PSDCImage -SourceSqlInstance SQLDB1 -DestinationSqlInstance SQLDB2 -ImageLocalPath C:\Temp\images\ -Database DB1 -UseLastFullBackup

        Create an image from the database DB1 on SQLDB1 using the last full backup and use SQLDB2 as the temporary database server.
        The image is written to c:\Temp\images
    #>
    [CmdLetBinding(SupportsShouldProcess = $true)]
    [OutputType('PSDCImage')]

    param(
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [object]$SourceSqlInstance,
        [System.Management.Automation.PSCredential]
        $SourceSqlCredential,
        [System.Management.Automation.PSCredential]
        $SourceCredential,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [object]$DestinationSqlInstance,
        [System.Management.Automation.PSCredential]
        $DestinationSqlCredential,
        [System.Management.Automation.PSCredential]
        $DestinationCredential,
        [System.Management.Automation.PSCredential]
        $PSDCSqlCredential,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object[]]$Database,
        [string]$ImageNetworkPath,
        [string]$ImageLocalPath,
        [ValidateSet('VHD', 'VHDX', 'vhd', 'vhdx')]
        [string]$VhdType,
        [switch]$CreateFullBackup,
        [switch]$UseLastFullBackup,
        [switch]$CopyOnlyBackup,
        [string]$MaskingConfigFile,
        [switch]$Force,
        [switch]$EnableException
    )

    begin {
        # Check if the console is run in Administrator mode
        if ( -not (Test-PSDCElevated) ) {
            Stop-PSFFunction -Message "Module requires elevation. Please run the console in Administrator mode"
        }

        # Check if the setup has ran
        if (-not (Get-PSFConfigValue -FullName psdatabaseclone.setup.status)) {
            Stop-PSFFunction -Message "The module setup has NOT yet successfully run. Please run 'Set-PSDCConfiguration'"
            return
        }

        # Checking parameters
        if (-not $ImageNetworkPath) {
            Stop-PSFFunction -Message "Please enter the network path where to save the images"
            return
        }

        # Check the vhd type
        if (-not $VhdType) {
            Write-PSFMessage -Message "Setting vhd type to 'VHDX'" -Level Verbose
            $VhdType = 'VHDX'
        }

        # Get the information store
        $informationStore = Get-PSFConfigValue -FullName psdatabaseclone.informationstore.mode

        if ($informationStore -eq 'SQL') {
            # Get the module configurations
            $pdcSqlInstance = Get-PSFConfigValue -FullName psdatabaseclone.database.Server
            $pdcDatabase = Get-PSFConfigValue -FullName psdatabaseclone.database.name
            if (-not $PSDCSqlCredential) {
                $pdcCredential = Get-PSFConfigValue -FullName psdatabaseclone.informationstore.credential -Fallback $null
            }
            else {
                $pdcCredential = $PSDCSqlCredential
            }

            # Test the module database setup
            if ($PSCmdlet.ShouldProcess("Test-PSDCConfiguration", "Testing module setup")) {
                try {
                    Test-PSDCConfiguration -SqlCredential $pdcCredential -EnableException
                }
                catch {
                    Stop-PSFFunction -Message "Something is wrong in the module configuration" -ErrorRecord $_ -Continue
                }
            }
        }

        Write-PSFMessage -Message "Started image creation" -Level Verbose

        # Try connecting to the instance
        Write-PSFMessage -Message "Attempting to connect to Sql Server $SourceSqlInstance.." -Level Verbose
        try {
            $sourceServer = Connect-DbaInstance -SqlInstance $SourceSqlInstance -SqlCredential $SourceSqlCredential
        }
        catch {
            Stop-PSFFunction -Message "Could not connect to Sql Server instance $SourceSqlInstance" -ErrorRecord $_ -Target $SourceSqlInstance
            return
        }

        # Cleanup the values in the network path
        if ($ImageNetworkPath.EndsWith("\")) {
            $ImageNetworkPath = $ImageNetworkPath.Substring(0, $ImageNetworkPath.Length - 1)
        }

        # Make up the data from the network path
        try {
            [uri]$uri = New-Object System.Uri($ImageNetworkPath)
            $uriHost = $uri.Host
        }
        catch {
            Stop-PSFFunction -Message "The image network path $ImageNetworkPath is not valid" -ErrorRecord $_ -Target $ImageNetworkPath
            return
        }

        # Setup the computer object
        $computer = [PsfComputer]$uriHost

        if (-not $computer.IsLocalhost) {
            # Get the result for the remote test
            $resultPSRemote = Test-PSDCRemoting -ComputerName $computer -Credential $Credential

            # Check the result
            if ($resultPSRemote.Result) {
                $command = [scriptblock]::Create("Import-Module PSDatabaseClone -Force")

                try {
                    Invoke-PSFCommand -ComputerName $computer -ScriptBlock $command -Credential $Credential
                }
                catch {
                    Stop-PSFFunction -Message "Couldn't import module remotely" -Target $command
                    return
                }
            }
            else {
                Stop-PSFFunction -Message "Couldn't connect to host remotely.`nVerify that the specified computer name is valid, that the computer is accessible over the network, and that a firewall exception for the WinRM service is enabled and allows access from this computer" -Target $resultPSRemote -Continue
            }
        }

        # Get the local path from the network path
        if (-not $ImageLocalPath) {
            if ($PSCmdlet.ShouldProcess($ImageNetworkPath, "Converting UNC path to local path")) {
                try {
                    # Check if computer is local
                    if ($computer.IsLocalhost) {
                        $ImageLocalPath = Convert-PSDCLocalUncPathToLocalPath -UncPath $ImageNetworkPath -EnableException
                    }
                    else {
                        $command = "Convert-PSDCLocalUncPathToLocalPath -UncPath `"$ImageNetworkPath`" -EnableException"
                        $commandGetLocalPath = [ScriptBlock]::Create($command)
                        $ImageLocalPath = Invoke-PSFCommand -ComputerName $computer -ScriptBlock $commandGetLocalPath -Credential $DestinationCredential

                        if (-not $ImageLocalPath) {
                            return
                        }
                    }

                    Write-PSFMessage -Message "Converted '$ImageNetworkPath' to '$ImageLocalPath'" -Level Verbose

                }
                catch {
                    Stop-PSFFunction -Message "Something went wrong getting the local image path" -Target $ImageNetworkPath
                    return
                }
            }
        }
        else {
            # Cleanup the values in the network path
            if ($ImageLocalPath.EndsWith("\")) {
                $ImageLocalPath = $ImageLocalPath.Substring(0, $ImageLocalPath.Length - 1)
            }

            # Check if the assigned value in the local path corresponds to the one retrieved
            try {
                # Check if computer is local
                if ($computer.IsLocalhost) {
                    $convertedLocalPath = Convert-PSDCLocalUncPathToLocalPath -UncPath $ImageNetworkPath -EnableException
                }
                else {
                    $command = "Convert-PSDCLocalUncPathToLocalPath -UncPath `"$ImageNetworkPath`" -EnableException"
                    $commandGetLocalPath = [ScriptBlock]::Create($command)
                    $convertedLocalPath = Invoke-PSFCommand -ComputerName $computer -ScriptBlock $commandGetLocalPath -Credential $DestinationCredential
                }

                Write-PSFMessage -Message "Converted '$ImageNetworkPath' to '$ImageLocalPath'" -Level Verbose

                # Check if the ImageLocalPath and convertedLocalPath are the same
                if ($ImageLocalPath -ne $convertedLocalPath) {
                    Stop-PSFFunction -Message "The local path '$ImageLocalPath' is not the same location as the network path '$ImageNetworkPath'" -Target $ImageNetworkPath
                    return
                }

            }
            catch {
                Stop-PSFFunction -Message "Something went wrong getting the local image path" -Target $ImageNetworkPath
                return
            }
        }

        # Check the image local path
        if ($PSCmdlet.ShouldProcess("Verifying image local path")) {
            if ((Test-DbaPath -Path $ImageLocalPath -SqlInstance $SourceSqlInstance -SqlCredential $DestinationCredential) -ne $true) {
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
                if ($db -notin $sourceServer.Databases.Name) {
                    Stop-PSFFunction -Message "Database $db cannot be found on instance $SourceSqlInstance" -Target $SourceSqlInstance
                }
            }

            $DatabaseCollection = $sourceServer.Databases | Where-Object { $_.Name -in $Database }
        }
        else {
            Stop-PSFFunction -Message "Please supply a database to create an image for" -Target $SourceSqlInstance -Continue
        }

        # Check the data masking file
        if($MaskingConfigFile -and -not (Test-Path -Path $MaskingConfigFile -Credential $SourceCredential)){
            Stop-PSFFunction -Message "Could not find the data masking configuration file" -Target $MaskingConfigFile -Continue
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

            if ($PSCmdlet.ShouldProcess($db, "Checking available disk space for database")) {
                # Check the database size to the available disk space
                if ($computer.IsLocalhost) {
                    $availableMB = (Get-PSDrive -Name $ImageLocalPath.Substring(0, 1)).Free / 1MB
                }
                else {
                    $command = [ScriptBlock]::Create("(Get-PSDrive -Name $($ImageLocalPath.Substring(0, 1)) ).Free / 1MB")
                    $availableMB = Invoke-PSFCommand -ComputerName $computer -ScriptBlock $commandGetLocalPath -Credential $DestinationCredential
                }

                $dbSizeMB = $db.Size

                if ($availableMB -lt $dbSizeMB) {
                    Stop-PSFFunction -Message "Size of database $($db.Name) does not fit within the image local path" -Target $db -Continue
                }
            }

            # Setup the image variables
            $imageName = "$($db.Name)_$timestamp"

            # Setup the access path
            $accessPath = "$ImageLocalPath\$imageName"

            # Setup the vhd path
            $vhdPath = "$($accessPath).$($VhdType.ToLower())"

            if ($CreateFullBackup) {
                if ($PSCmdlet.ShouldProcess($db, "Creating full backup for database $db")) {

                    # Create the backup
                    Write-PSFMessage -Message "Creating new full backup for database $db" -Level Verbose
                    $lastFullBackup = Backup-DbaDatabase -SqlInstance $SourceSqlInstance -SqlCredential $SourceSqlCredential -Database $db.Name -CopyOnly:$CopyOnlyBackup
                }
            }
            elseif ($UseLastFullBackup) {
                Write-PSFMessage -Message "Trying to retrieve the last full backup for $db" -Level Verbose

                # Get the last full backup
                $lastFullBackup = Get-DbaBackupHistory -SqlServer $SourceSqlInstance -SqlCredential $SourceSqlCredential -Databases $db.Name -LastFull
            }

            if ($PSCmdlet.ShouldProcess("$imageName", "Creating the vhd")) {
                # try to create the new VHD
                try {
                    Write-PSFMessage -Message "Create the vhd $imageName" -Level Verbose

                    # Check if computer is local
                    if ($computer.IsLocalhost) {
                        $null = New-PSDCVhdDisk -Destination $imagePath -Name $imageName -VhdType $VhdType
                    }
                    else {
                        $command = [ScriptBlock]::Create("New-PSDCVhdDisk -Destination '$imagePath' -Name $imageName -VhdType $VhdType")
                        $null = Invoke-PSFCommand -ComputerName $computer -ScriptBlock $command -Credential $DestinationCredential
                    }

                }
                catch {
                    Stop-PSFFunction -Message "Couldn't create vhd(x) $imageName" -Target $imageName -ErrorRecord $_ -Continue
                }
            }


            if ($PSCmdlet.ShouldProcess("$imageName", "Initializing the vhd")) {
                # Try to initialize the vhd
                try {
                    Write-PSFMessage -Message "Initializing the vhd $imageName" -Level Verbose

                    # Check if computer is local
                    if ($computer.IsLocalhost) {
                        $diskResult = Initialize-PSDCVhdDisk -Path $vhdPath -Credential $DestinationCredential
                    }
                    else {
                        $command = [ScriptBlock]::Create("Initialize-PSDCVhdDisk -Path $vhdPath")
                        $diskResult = Invoke-PSFCommand -ComputerName $computer -ScriptBlock $command -Credential $DestinationCredential
                    }
                }
                catch {
                    Stop-PSFFunction -Message "Couldn't initialize vhd $vhdPath" -Target $imageName -ErrorRecord $_ -Continue
                }
            }

            # try to create access path
            try {
                # Check if access path is already present
                if (-not (Test-Path -Path $accessPath)) {
                    if ($PSCmdlet.ShouldProcess($accessPath, "Creating access path $accessPath")) {
                        try {
                            # Check if computer is local
                            if ($computer.IsLocalhost) {
                                $null = New-Item -Path $accessPath -ItemType Directory -Force
                            }
                            else {
                                $command = [ScriptBlock]::Create("New-Item -Path $accessPath -ItemType Directory -Force")
                                $null = Invoke-PSFCommand -ComputerName $computer -ScriptBlock $command -Credential $DestinationCredential
                            }
                        }
                        catch {
                            Stop-PSFFunction -Message "Couldn't create access path directory" -ErrorRecord $_ -Target $accessPath -Continue
                        }
                    }
                }

                # Get the properties of the disk and partition
                $disk = $diskResult.Disk
                $partition = $diskResult.Partition

                if ($PSCmdlet.ShouldProcess($accessPath, "Adding access path '$accessPath' to mounted disk")) {
                    # Add the access path to the mounted disk
                    if ($computer.IsLocalhost) {
                        $null = Add-PartitionAccessPath -DiskNumber $disk.Number -PartitionNumber $partition[1].PartitionNumber -AccessPath $accessPath -ErrorAction SilentlyContinue
                    }
                    else {
                        $command = [ScriptBlock]::Create("Add-PartitionAccessPath -DiskNumber $($disk.Number) -PartitionNumber $($partition[1].PartitionNumber) -AccessPath $accessPath -ErrorAction SilentlyContinue")
                        $null = Invoke-PSFCommand -ComputerName $computer -ScriptBlock $command -Credential $DestinationCredential
                    }
                }

            }
            catch {
                Stop-PSFFunction -Message "Couldn't create access path for partition" -ErrorRecord $_ -Target $diskResult.partition
            }

            # # Create folder structure for image
            $imageDataFolder = "$($imagePath)\$imageName\Data"
            $imageLogFolder = "$($imagePath)\$imageName\Log"

            # Check if image data folder exist
            if (-not (Test-Path -Path $imageDataFolder)) {
                if ($PSCmdlet.ShouldProcess($accessPath, "Creating data folder in vhd")) {
                    try {
                        Write-PSFMessage -Message "Creating data folder for image" -Level Verbose

                        # Check if computer is local
                        if ($computer.IsLocalhost) {
                            $null = New-Item -Path $imageDataFolder -ItemType Directory
                        }
                        else {
                            $command = [ScriptBlock]::Create("New-Item -Path $imageDataFolder -ItemType Directory")
                            $null = Invoke-PSFCommand -ComputerName $computer -ScriptBlock $command -Credential $DestinationCredential
                        }
                    }
                    catch {
                        Stop-PSFFunction -Message "Couldn't create image data folder" -Target $imageName -ErrorRecord $_ -Continue
                    }
                }
            }

            # Test if the image log folder exists
            if (-not (Test-Path -Path $imageLogFolder)) {
                if ($PSCmdlet.ShouldProcess($accessPath, "Creating log folder in vhd")) {
                    try {
                        Write-PSFMessage -Message "Creating transaction log folder for image" -Level Verbose

                        # Check if computer is local
                        if ($computer.IsLocalhost) {
                            $null = New-Item -Path $imageLogFolder -ItemType Directory
                        }
                        else {
                            $command = [ScriptBlock]::Create("New-Item -Path $imageLogFolder -ItemType Directory")
                            $null = Invoke-PSFCommand -ComputerName $computer -ScriptBlock $command -Credential $DestinationCredential
                        }

                    }
                    catch {
                        Stop-PSFFunction -Message "Couldn't create image data folder" -Target $imageName -ErrorRecord $_ -Continue
                    }
                }
            }

            # Setup the temporary database name
            $tempDbName = "$($db.Name)-PSDatabaseClone"

            if ($PSCmdlet.ShouldProcess($tempDbName, "Restoring database")) {
                # Restore database to image folder
                try {
                    Write-PSFMessage -Message "Restoring database $db on $DestinationSqlInstance" -Level Verbose
                    $restore = Restore-DbaDatabase -SqlInstance $DestinationSqlInstance -SqlCredential $DestinationSqlCredential `
                        -DatabaseName $tempDbName -Path $lastFullBackup `
                        -DestinationDataDirectory $imageDataFolder `
                        -DestinationLogDirectory $imageLogFolder `
                        -WithReplace -EnableException
                }
                catch {
                    Stop-PSFFunction -Message "Couldn't restore database $db as $tempDbName on $DestinationSqlInstance.`n$($_)" -Target $restore -ErrorRecord $_ -Continue
                }
            }

            # Apply data masking
            if($MaskingConfigFile){

                # Check the recovery model of the database
                $dbRecoveryModel = Get-DbaDbRecoveryModel -SqlInstance $DestinationSqlInstance -SqlCredential $DestinationSqlCredential -Database $tempDbName

                # Set the recovery model to simple to minimize growth during data masking
                if($dbRecoveryModel.RecoveryModel -ne 'Simple'){
                    try{
                        $null = Set-DbaDbRecoveryModel -SqlInstance $DestinationSqlInstance -SqlCredential $DestinationSqlCredential -Database $tempDbName -RecoveryModel Simple -Confirm:$false -EnableException
                    }
                    catch{
                        Stop-PSFFunction -Message "Couldn't change recovery model for database" -Target $restore -ErrorRecord $_ -Continue
                    }

                    [bool]$recoveryModelChanged = $true
                }
                else{
                    [bool]$recoveryModelChanged = $false
                }

                # Execute the data masking
                try{
                    Invoke-PSDCDataMasking -SqlInstance $DestinationSqlInstance -SqlCredential $DestinationSqlCredential -Database $tempDbName -MaskingConfigFile $MaskingConfigFile -EnableException
                }
                catch{
                    Stop-PSFFunction -Message "Something went wrong masking the data" -Target $MaskingConfigFile -ErrorRecord $_ -Continue
                }

                # Change back the recovery model to it's original setting
                if($recoveryModelChanged){
                    try{
                        $null = Set-DbaDbRecoveryModel -SqlInstance $DestinationSqlInstance -SqlCredential $DestinationSqlCredential -Database $tempDbName -RecoveryModel $dbRecoveryModel.RecoveryModel -Confirm:$false -EnableException
                    }
                    catch{
                        Stop-PSFFunction -Message "Couldn't change recovery model for database back to original" -Target $restore -ErrorRecord $_ -Continue
                    }
                }

            }

            # Detach database
            if ($PSCmdlet.ShouldProcess($tempDbName, "Detaching database")) {
                try {
                    Write-PSFMessage -Message "Detaching database $tempDbName on $DestinationSqlInstance" -Level Verbose
                    $null = Dismount-DbaDatabase -SqlInstance $DestinationSqlInstance -Database $tempDbName -SqlCredential $DestinationSqlCredential -Force
                }
                catch {
                    Stop-PSFFunction -Message "Couldn't detach database $db as $tempDbName on $DestinationSqlInstance" -Target $db -ErrorRecord $_ -Continue
                }
            }

            if ($PSCmdlet.ShouldProcess($vhdPath, "Dismounting the vhd")) {
                # Dismount the vhd
                try {
                    Write-PSFMessage -Message "Dismounting vhd" -Level Verbose

                    # Check if computer is local
                    if ($computer.IsLocalhost) {
                        # Dismount the VHD
                        $null = Dismount-DiskImage -ImagePath $vhdPath

                        # Remove the access path
                        $null = Remove-Item -Path $accessPath -Force
                    }
                    else {
                        $command = [ScriptBlock]::Create("Dismount-DiskImage -ImagePath $vhdPath")
                        $null = Invoke-PSFCommand -ComputerName $computer -ScriptBlock $command -Credential $DestinationCredential

                        $command = [ScriptBlock]::Create("Remove-Item -Path $accessPath -Force")
                        $null = Invoke-PSFCommand -ComputerName $computer -ScriptBlock $command -Credential $DestinationCredential
                    }
                }
                catch {
                    Stop-PSFFunction -Message "Couldn't dismount vhd" -Target $imageName -ErrorRecord $_ -Continue
                }
            }

            # Write the data to the database
            $imageLocation = "$($uri.LocalPath)\$imageName.vhdx"
            $sizeMB = $dbSizeMB
            $databaseName = $db.Name
            $databaseTS = $lastFullBackup.Start

            if ($informationStore -eq 'SQL') {
                $query = "
                DECLARE @ImageID INT;
                EXECUTE dbo.Image_New @ImageID = @ImageID OUTPUT,				  -- int
                                    @ImageName = '$imageName',                    -- varchar(100)
                                    @ImageLocation = '$imageLocation',			  -- varchar(255)
                                    @SizeMB = $sizeMB,							  -- int
                                    @DatabaseName = '$databaseName',			  -- varchar(100)
                                    @DatabaseTimestamp = '$databaseTS'           -- datetime

                SELECT @ImageID as ImageID
            "

                # Add image to database
                if ($PSCmdlet.ShouldProcess($imageName, "Adding image to database")) {
                    try {
                        Write-PSFMessage -Message "Saving image information in database" -Level Verbose

                        $result += Invoke-DbaQuery -SqlInstance $pdcSqlInstance -SqlCredential $pdcCredential -Database $pdcDatabase -Query $query -EnableException
                        $imageID = $result.ImageID
                    }
                    catch {
                        Stop-PSFFunction -Message "Couldn't add image to database" -Target $imageName -ErrorRecord $_
                    }
                }
            }
            elseif ($informationStore -eq 'File') {
                [array]$images = $null

                # Get all the images
                try {
                    $images = Get-PSDCImage
                }
                catch {
                    Stop-PSFFunction -Message "Couldn't get images" -Target $imageName -ErrorRecord $_
                    return
                }


                # Setup the new image id
                if ($images.Count -ge 1) {
                    $imageID = ($images[-1].ImageID | Sort-Object ImageID) + 1
                }
                else {
                    $imageID = 1
                }

                # Add the new information to the array
                $images += [PSCustomObject]@{
                    ImageID           = $imageID
                    ImageName         = $imageName
                    ImageLocation     = $imageLocation
                    SizeMB            = $sizeMB
                    DatabaseName      = $databaseName
                    DatabaseTimestamp = $databaseTS
                    CreatedOn         = (Get-Date -format "yyyyMMddHHmmss")
                }

                # Test if the JSON folder can be reached
                if (-not (Test-Path -Path "PSDCJSONFolder:\")) {
                    $command = [scriptblock]::Create("Import-Module PSDatabaseClone -Force")

                    try {
                        Invoke-PSFCommand -ComputerName $computer -ScriptBlock $command -Credential $Credential
                    }
                    catch {
                        Stop-PSFFunction -Message "Couldn't import module remotely" -Target $command
                        return
                    }
                }

                # Set the image file
                $jsonImageFile = "PSDCJSONFolder:\images.json"

                # Convert the data back to JSON
                $images | ConvertTo-Json | Set-Content $jsonImageFile
            }

            # Add the results to the custom object
            [PSDCImage]$image = New-Object PSDCImage

            $image.ImageID = $imageID
            $image.ImageName = $imageName
            $image.ImageLocation = $imageLocation
            $image.SizeMB = $sizeMB
            $image.DatabaseName = $databaseName
            $image.DatabaseTimestamp = $databaseTS

            return $image

        } # for each database

    } # end process

    end {
        # Test if there are any errors
        if (Test-PSFFunctionInterrupt) { return }

        Write-PSFMessage -Message "Finished creating database image" -Level Verbose
    }

}

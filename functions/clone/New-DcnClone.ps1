function New-DcnClone {
    <#
    .SYNOPSIS
        New-DcnClone creates a new clone

    .DESCRIPTION
        New-DcnClone willcreate a new clone based on an image.
        The clone will be created in a certain directory, mounted and attached to a database server.

    .PARAMETER SqlInstance
        SQL Server name or SMO object representing the SQL Server to connect to

    .PARAMETER SqlCredential
        Allows you to login to servers using SQL Logins as opposed to Windows Auth/Integrated/Trusted. To use:

        $scred = Get-Credential, then pass $scred object to the -SqlCredential parameter.

        Windows Authentication will be used if SqlCredential is not specified. SQL Server does not accept Windows credentials being passed as credentials.
        To connect as a different Windows user, run PowerShell as that user.

    .PARAMETER DcnSqlCredential
        Allows you to login to servers using SQL Logins as opposed to Windows Auth/Integrated/Trusted.
        This works similar as SqlCredential but is only meant for authentication to the dbaclone database server and database.

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

    .PARAMETER SkipDatabaseMount
        If this parameter is used, the database will not be mounted.

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

        Website: https://psdatabaseclone.org
        Copyright: (C) Sander Stad, sander@sqlstad.nl
        License: MIT https://opensource.org/licenses/MIT

    .LINK
        https://psdatabaseclone.org/

    .EXAMPLE
        New-DcnClone -SqlInstance SQLDB1 -ParentVhd C:\Temp\images\DB1_20180623203204.vhdx -Destination C:\Temp\clones\ -CloneName DB1_Clone1

        Create a new clone based on the image DB1_20180623203204.vhdx and attach the database to SQLDB1 as DB1_Clone1

    .EXAMPLE
        New-DcnClone -SqlInstance SQLDB1 -Database DB1, DB2 -LatestImage

        Create a new clone on SQLDB1 for the databases DB1 and DB2 with the latest image for those databases

    .EXAMPLE
        New-DcnClone -SqlInstance SQLDB1, SQLDB2 -Database DB1 -LatestImage

        Create a new clone on SQLDB1 and SQLDB2 for the databases DB1 with the latest image
    #>
    [CmdLetBinding(DefaultParameterSetName = 'ByLatest', SupportsShouldProcess = $true)]

    param(
        [DbaInstanceParameter]$SqlInstance,
        [PSCredential]$SqlCredential,
        [PSCredential]$DcnSqlCredential,
        [PSCredential]$Credential,
        [parameter(Mandatory = $true, ParameterSetName = "ByParent")]
        [string]$ParentVhd,
        [string]$Destination,
        [string]$CloneName,
        [parameter(Mandatory = $true, ParameterSetName = "ByLatest")]
        [string[]]$Database,
        [parameter(Mandatory = $true, ParameterSetName = "ByLatest")]
        [switch]$LatestImage,
        [switch]$Disabled,
        [switch]$SkipDatabaseMount,
        [switch]$Force,
        [switch]$EnableException
    )

    begin {
        # Check if the console is run in Administrator mode
        if ( -not (Test-PSFPowerShell -Elevated) ) {
            Stop-PSFFunction -Message "Module requires elevation. Please run the console in Administrator mode" -Continue
        }

        if (-not (Test-DcnModule -SetupStatus)) {
            Stop-PSFFunction -Message "The module setup has NOT yet successfully run. Please run 'Set-DcnConfiguration'" -Continue
        }

        if (-not $SqlInstance) {
            $SkipDatabaseMount = $true
        }

        if (-not $Destination -and -not $SqlInstance) {
            Stop-PSFFunction -Message "Please enter a destination or enter a SQL Server instance" -Continue
        }

        if (-not $Destination -and $SkipDatabaseMount) {
            Stop-PSFFunction -Message "Please enter a destination when using -SkipDatabaseMount" -Continue
        }

        # Check the available images
        if (-not $ParentVhd) {
            $images = Get-DcnImage

            if ($Database -notin $images.DatabaseName) {
                Stop-PSFFunction -Message "There is no image for database '$Database'" -Continue
            }
        }

        # Get the information store
        $informationStore = Get-PSFConfigValue -FullName dbaclone.informationstore.mode

        if ($informationStore -eq 'SQL') {
            # Get the module configurations
            $pdcSqlInstance = Get-PSFConfigValue -FullName dbaclone.database.Server
            $pdcDatabase = Get-PSFConfigValue -FullName dbaclone.database.name
            if (-not $DcnSqlCredential) {
                $pdcCredential = Get-PSFConfigValue -FullName dbaclone.informationstore.credential -Fallback $null
            }
            else {
                $pdcCredential = $DcnSqlCredential
            }

            # Test the module database setup
            if ($PSCmdlet.ShouldProcess("Test-DcnConfiguration", "Testing module setup")) {
                try {
                    Test-DcnConfiguration -SqlCredential $pdcCredential -EnableException
                }
                catch {
                    Stop-PSFFunction -Message "Something is wrong in the module configuration" -ErrorRecord $_ -Continue
                }
            }
        }

        Write-PSFMessage -Message "Started clone creation" -Level Verbose

        # Check the disabled parameter
        $active = 1
        if ($Disabled) {
            $active = 0
        }

        # Set the location where to save the diskpart command
        $diskpartScriptFile = Get-PSFConfigValue -FullName dbaclone.diskpart.scriptfile -Fallback "$env:APPDATA\dbaclone\diskpartcommand.txt"

        if (-not (Test-Path -Path $diskpartScriptFile)) {
            try {
                $null = New-Item -Path $diskpartScriptFile -ItemType File
            }
            catch {
                Stop-PSFFunction -Message "Could not create diskpart script file" -ErrorRecord $_ -Continue
            }
        }
    }

    process {
        # Test if there are any errors
        if (Test-PSFFunctionInterrupt) { return }

        # Loop through all the instances
        #foreach ($instance in $SqlInstance) {
        if ($SqlInstance) {
            if (-not $SkipDatabaseMount) {
                # Try connecting to the instance
                Write-PSFMessage -Message "Attempting to connect to Sql Server $SqlInstance.." -Level Verbose
                try {
                    $server = Connect-DbaInstance -SqlInstance $SqlInstance -SqlCredential $SqlCredential
                }
                catch {
                    Stop-PSFFunction -Message "Could not connect to Sql Server instance $instance" -ErrorRecord $_ -Target $instance
                    return
                }
            }

            # Setup the computer object
            $computer = [PsfComputer]$server.ComputerName
        }
        else {
            $computer = [PsfComputer]"$($env:COMPUTERNAME)"
        }

        if (-not $computer.IsLocalhost) {
            # Get the result for the remote test
            $resultPSRemote = Test-DcnRemoting -ComputerName $computer.ComputerName -Credential $Credential

            # Check the result
            if ($resultPSRemote.Result) {
                $command = [scriptblock]::Create("Import-Module dbaclone")

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


        # Check destination
        if (-not $Destination) {
            $Destination = Join-PSFPath -Path $server.DefaultFile -Child "clone"
        }
        else {
            # If the destination is a network path
            if ($Destination.StartsWith("\\")) {
                Write-PSFMessage -Message "The destination cannot be an UNC path. Trying to convert to local path" -Level Verbose

                if ($PSCmdlet.ShouldProcess($Destination, "Converting UNC path '$Destination' to local path")) {
                    try {
                        # Check if computer is local
                        if ($computer.IsLocalhost) {
                            $Destination = Convert-DcnUncPathToLocalPath -UncPath $Destination
                        }
                        else {
                            $command = [ScriptBlock]::Create("Convert-DcnUncPathToLocalPath -UncPath `"$Destination`"")
                            $Destination = Invoke-PSFCommand -ComputerName $computer -ScriptBlock $command -Credential $Credential
                        }
                    }
                    catch {
                        Stop-PSFFunction -Message "Something went wrong getting the local image path" -Target $Destination
                        return
                    }
                }
            }

            # Remove the last "\" from the path it would mess up the mount of the VHD
            if ($Destination.EndsWith("\")) {
                $Destination = $Destination.Substring(0, $Destination.Length - 1)
            }

            # Test if the destination can be reached
            # Check if computer is local
            if ($computer.IsLocalhost) {
                if (-not (Test-Path -Path $Destination)) {
                    Stop-PSFFunction -Message "Could not find destination path $Destination" -Target $SqlInstance
                }
            }
            else {
                $command = [ScriptBlock]::Create("Test-Path -Path '$Destination'")
                $result = Invoke-PSFCommand -ComputerName $computer -ScriptBlock $command -Credential $Credential
                if (-not $result) {
                    Stop-PSFFunction -Message "Could not find destination path $Destination" -Target $SqlInstance
                }
            }

        }

        # Loopt through all the databases
        foreach ($db in $Database) {

            if (-not $ParentVhd) {

                if ($LatestImage) {
                    $images = Get-DcnImage -Database $db
                    $result = $images[-1] | Sort-Object CreatedOn
                }

                # Check the results
                if ($null -eq $result) {
                    Stop-PSFFunction -Message "No image could be found for database $db" -Target $pdcSqlInstance -Continue
                }
                else {
                    $ParentVhd = $result.ImageLocation
                }
            }

            # Take apart the vhd directory
            if ($PSCmdlet.ShouldProcess($ParentVhd, "Setting up parent VHD variables")) {
                $uri = new-object System.Uri($ParentVhd)
                $vhdComputer = [PsfComputer]$uri.Host

                if ($vhdComputer.IsLocalhost) {
                    if ((Test-Path -Path $ParentVhd)) {
                        $parentVhdFileName = $ParentVhd.Split("\")[-1]
                        $parentVhdFile = $parentVhdFileName.Split(".")[0]
                    }
                    else {
                        Stop-PSFFunction -Message "Parent vhd could not be found" -Target $SqlInstance -Continue
                    }
                }
                else {
                    $command = [scriptblock]::Create("Test-Path -Path '$ParentVhd'")
                    $result = Invoke-PSFCommand -ComputerName $vhdComputer -ScriptBlock $command -Credential $Credential
                    if ($result) {
                        $parentVhdFileName = $ParentVhd.Split("\")[-1]
                        $parentVhdFile = $parentVhdFileName.Split(".")[0]
                    }
                    else {
                        Stop-PSFFunction -Message "Parent vhd could not be found" -Target $SqlInstance -Continue
                    }
                }
            }

            # Check clone name parameter
            if ($PSCmdlet.ShouldProcess($ParentVhd, "Setting up clone variables")) {
                if (-not $CloneName) {
                    $cloneDatabase = $parentVhdFile
                    $CloneName = $parentVhdFile
                    $mountDirectory = "$($parentVhdFile)"
                }
                elseif ($CloneName) {
                    $cloneDatabase = $CloneName
                    $mountDirectory = "$($CloneName)"
                }
            }

            # Check if the database is already present
            if (-not $SkipDatabaseMount) {
                if ($PSCmdlet.ShouldProcess($cloneDatabase, "Verifying database existence")) {
                    if ($server.Databases.Name -contains $cloneDatabase) {
                        Stop-PSFFunction -Message "Database $cloneDatabase is already present on $SqlInstance" -Target $SqlInstance
                    }
                }
            }

            # Setup access path location
            $accessPath = Join-PSFPath -Path $Destination -Child $mountDirectory

            # Check if access path is already present
            if ($PSCmdlet.ShouldProcess($accessPath, "Testing existence access path $accessPath and create it")) {
                if ($computer.IsLocalhost) {
                    if (-not (Test-Path -Path $accessPath)) {
                        try {
                            $null = New-Item -Path $accessPath -ItemType Directory -Force
                        }
                        catch {
                            Stop-PSFFunction -Message "Couldn't create access path directory" -ErrorRecord $_ -Target $accessPath -Continue
                        }
                    }
                }
                else {
                    $command = [ScriptBlock]::Create("Test-Path -Path '$accessPath'")
                    $result = Invoke-PSFCommand -ComputerName $computer -ScriptBlock $command -Credential $Credential
                    if (-not $result) {
                        try {
                            $command = [ScriptBlock]::Create("New-Item -Path '$accessPath' -ItemType Directory -Force")
                            $null = Invoke-PSFCommand -ComputerName $computer -ScriptBlock $command -Credential $Credential
                        }
                        catch {
                            Stop-PSFFunction -Message "Couldn't create access path directory" -ErrorRecord $_ -Target $accessPath -Continue
                        }
                    }
                }
            }

            # Check if the clone vhd does not yet exist
            $clonePath = Join-PSFPath -Path $Destination -Child "$($CloneName).vhdx"
            if ($computer.IsLocalhost) {
                if (Test-Path -Path "$($clonePath)" -Credential $DestinationCredential) {
                    Stop-PSFFunction -Message "Clone $CloneName already exists" -Target $accessPath -Continue
                }
            }
            else {
                $command = [ScriptBlock]::Create("Test-Path -Path `"$($clonePath)`"")
                $result = Invoke-PSFCommand -ComputerName $computer -ScriptBlock $command -Credential $Credential
                if ($result) {
                    Stop-PSFFunction -Message "Clone $CloneName already exists" -Target $accessPath -Continue
                }
            }

            # Create the new child vhd
            if ($PSCmdlet.ShouldProcess($ParentVhd, "Creating clone")) {
                try {
                    Write-PSFMessage -Message "Creating clone from $ParentVhd" -Level Verbose

                    $command = "create vdisk file='$($clonePath)' parent='$ParentVhd'"

                    # Check if computer is local
                    if ($computer.IsLocalhost) {
                        # Set the content of the diskpart script file
                        Set-Content -Path $diskpartScriptFile -Value $command -Force

                        $script = [ScriptBlock]::Create("diskpart /s $diskpartScriptFile")
                        $null = Invoke-PSFCommand -ScriptBlock $script
                    }
                    else {
                        $command = [ScriptBlock]::Create("New-VHD -ParentPath $ParentVhd -Path `"$($clonePath)`" -Differencing")
                        $vhd = Invoke-PSFCommand -ComputerName $computer -ScriptBlock $command -Credential $Credential

                        if (-not $vhd) {
                            return
                        }
                    }

                }
                catch {
                    Stop-PSFFunction -Message "Could not create clone" -Target $vhd -Continue -ErrorRecord $_
                }
            }

            # Mount the vhd
            if ($PSCmdlet.ShouldProcess("$($clonePath)", "Mounting clone clone")) {
                try {
                    Write-PSFMessage -Message "Mounting clone" -Level Verbose

                    # Check if computer is local
                    if ($computer.IsLocalhost) {
                        # Mount the disk
                        $null = Mount-DiskImage -ImagePath "$($clonePath)"

                        # Get the disk based on the name of the vhd
                        $diskImage = Get-DiskImage -ImagePath $clonePath
                        $disk = Get-Disk | Where-Object Number -eq $diskImage.Number
                    }
                    else {
                        # Mount the disk
                        $command = [ScriptBlock]::Create("Mount-DiskImage -ImagePath `"$($clonePath)`"")
                        $null = Invoke-PSFCommand -ComputerName $computer -ScriptBlock $command -Credential $Credential

                        # Get the disk based on the name of the vhd
                        $command = [ScriptBlock]::Create("
                                `$diskImage = Get-DiskImage -ImagePath $($clonePath)
                                Get-Disk | Where-Object Number -eq $($diskImage.Number)
                            ")
                        $disk = Invoke-PSFCommand -ComputerName $computer -ScriptBlock $command -Credential $Credential
                    }
                }
                catch {
                    Stop-PSFFunction -Message "Couldn't mount vhd $vhdPath" -ErrorRecord $_ -Target $disk -Continue
                }
            }

            # Check if the disk is offline
            if ($PSCmdlet.ShouldProcess($disk.Number, "Initializing disk")) {
                # Check if computer is local
                if ($computer.IsLocalhost) {
                    $null = Initialize-Disk -Number $disk.Number -PartitionStyle GPT -ErrorAction SilentlyContinue
                }
                else {
                    $command = [ScriptBlock]::Create("Initialize-Disk -Number $($disk.Number) -PartitionStyle GPT -ErrorAction SilentlyContinue")

                    $null = Invoke-PSFCommand -ComputerName $computer -ScriptBlock $command -Credential $Credential
                }
            }

            # Mounting disk to access path
            if ($PSCmdlet.ShouldProcess($disk.Number, "Mounting volume to accesspath")) {
                try {
                    # Check if computer is local
                    if ($computer.IsLocalhost) {
                        # Get the partition based on the disk
                        $partition = Get-Partition -Disk $disk | Where-Object { $_.Type -ne "Reserved" } | Select-Object -First 1

                        # Create an access path for the disk
                        $null = Add-PartitionAccessPath -DiskNumber $disk.Number -PartitionNumber $partition.PartitionNumber -AccessPath $accessPath -ErrorAction SilentlyContinue
                    }
                    else {
                        $command = [ScriptBlock]::Create("Get-Partition -DiskNumber $($disk.Number)")
                        $partition = Invoke-PSFCommand -ComputerName $computer -ScriptBlock $command -Credential $Credential | Where-Object { $_.Type -ne "Reserved" } | Select-Object -First 1

                        $command = [ScriptBlock]::Create("Add-PartitionAccessPath -DiskNumber $($disk.Number) -PartitionNumber $($partition.PartitionNumber) -AccessPath '$accessPath' -ErrorAction Ignore")

                        $null = Invoke-PSFCommand -ComputerName $computer -ScriptBlock $command -Credential $Credential
                    }

                }
                catch {
                    Stop-PSFFunction -Message "Couldn't create access path for partition" -ErrorRecord $_ -Target $partition -Continue
                }
            }

            # Set privileges for access path
            try {
                # Check if computer is local
                if ($computer.IsLocalhost) {
                    Set-DcnPermission -Path $accessPath
                }
                else {
                    [string]$commandText = "Set-DcnPermission -Path '$($accessPath)'"

                    $command = [scriptblock]::Create($commandText)

                    $null = Invoke-PSFCommand -ComputerName $computer -ScriptBlock $command -Credential $DestinationCredential
                }
            }
            catch {
                Stop-PSFFunction -Message "Couldn't create access path directory" -ErrorRecord $_ -Target $accessPath -Continue
            }

            if (-not $SkipDatabaseMount) {
                # Get all the files of the database
                if ($computer.IsLocalhost) {
                    $databaseFiles = Get-ChildItem -Path $accessPath -Filter *.*df -Recurse
                }
                else {
                    $commandText = "Get-ChildItem -Path '$accessPath' -Filter *.*df -Recurse"
                    $command = [ScriptBlock]::Create($commandText)
                    $databaseFiles = Invoke-PSFCommand -ComputerName $computer -ScriptBlock $command -Credential $Credential
                }

                # Setup the database filestructure
                $dbFileStructure = New-Object System.Collections.Specialized.StringCollection

                # Loop through each of the database files and add them to the file structure
                foreach ($dbFile in $databaseFiles) {
                    $null = $dbFileStructure.Add($dbFile.FullName)
                }

                # Mount the database
                if ($PSCmdlet.ShouldProcess($cloneDatabase, "Mounting database $cloneDatabase")) {
                    try {
                        Write-PSFMessage -Message "Mounting database from clone" -Level Verbose
                        $null = Mount-DbaDatabase -SqlInstance $server -SqlCredential $SqlCredential -Database $cloneDatabase -FileStructure $dbFileStructure
                    }
                    catch {
                        Stop-PSFFunction -Message "Couldn't mount database $cloneDatabase" -ErrorRecord $_ -Target $instance -Continue
                    }
                }
            }

            # Write the data to the database
            try {
                # Get the data of the host
                if ($computer.IsLocalhost) {
                    $computerinfo = [System.Net.Dns]::GetHostByName(($env:computerName))

                    $hostname = $computerinfo.HostName
                    $ipAddress = $computerinfo.AddressList[0]
                    $fqdn = $computerinfo.HostName
                }
                else {
                    $command = [scriptblock]::Create('[System.Net.Dns]::GetHostByName(($env:computerName))')
                    $computerinfo = Invoke-PSFCommand -ComputerName $computer -ScriptBlock $command -Credential $Credential

                    $command = [scriptblock]::Create('$env:COMPUTERNAME')
                    $result = Invoke-PSFCommand -ComputerName $computer -ScriptBlock $command -Credential $Credential

                    $hostname = $result.ToString()
                    $ipAddress = $computerinfo.AddressList[0]
                    $fqdn = $computerinfo.HostName
                }

                if ($informationStore -eq 'SQL') {
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
                    $hostKnown = (Invoke-DbaQuery -SqlInstance $pdcSqlInstance -SqlCredential $pdcCredential -Database $pdcDatabase -Query $query -EnableException).HostKnown
                }
                elseif ($informationStore -eq 'File') {
                    $hosts = Get-ChildItem -Path DCNJSONFolder:\ -Filter *hosts.json | ForEach-Object { Get-Content $_.FullName | ConvertFrom-Json }

                    $hostKnown = [bool]($hostname -in $hosts.HostName)
                }
            }
            catch {
                Stop-PSFFunction -Message "Couldnt execute query to see if host was known" -Target $query -ErrorRecord $_ -Continue
            }

            # Add the host if the host is known
            if (-not $hostKnown) {
                if ($PSCmdlet.ShouldProcess($hostname, "Adding hostname to database")) {

                    if ($informationStore -eq 'SQL') {

                        Write-PSFMessage -Message "Adding host $hostname to database" -Level Verbose

                        $query = "
                                DECLARE @HostID INT;
                                EXECUTE dbo.Host_New @HostID = @HostID OUTPUT, -- int
                                                    @HostName = '$hostname',   -- varchar(100)
                                                    @IPAddress = '$ipAddress', -- varchar(20)
                                                    @FQDN = '$fqdn'			   -- varchar(255)

                                SELECT @HostID AS HostID
                            "

                        try {
                            $hostID = (Invoke-DbaQuery -SqlInstance $pdcSqlInstance -SqlCredential $pdcCredential -Database $pdcDatabase -Query $query -EnableException).HostID
                        }
                        catch {
                            Stop-PSFFunction -Message "Couldnt execute query for adding host" -Target $query -ErrorRecord $_ -Continue
                        }
                    }
                    elseif ($informationStore -eq 'File') {
                        [array]$hosts = $null

                        # Get all the images
                        $hosts = Get-ChildItem -Path DCNJSONFolder:\ -Filter *hosts.json | ForEach-Object { Get-Content $_.FullName | ConvertFrom-Json }

                        # Setup the new host id
                        if ($hosts.Count -ge 1) {
                            $hostID = ($hosts[-1].HostID | Sort-Object HostID) + 1
                        }
                        else {
                            $hostID = 1
                        }

                        # Add the new information to the array
                        $hosts += [PSCustomObject]@{
                            HostID    = $hostID
                            HostName  = $hostname
                            IPAddress = $ipAddress.IPAddressToString
                            FQDN      = $fqdn
                        }

                        # Test if the JSON folder can be reached
                        if (-not (Test-Path -Path "DCNJSONFolder:\")) {
                            $command = [scriptblock]::Create("Import-Module dbaclone -Force")

                            try {
                                Invoke-PSFCommand -ComputerName $computer -ScriptBlock $command -Credential $Credential
                            }
                            catch {
                                Stop-PSFFunction -Message "Couldn't import module remotely" -Target $command
                                return
                            }
                        }

                        # Setup the json file
                        $jsonHostFile = "DCNJSONFolder:\hosts.json"

                        # Convert the data back to JSON
                        $hosts | ConvertTo-Json | Set-Content $jsonHostFile
                    }
                }
            }
            else {
                if ($informationStore -eq 'SQL') {
                    Write-PSFMessage -Message "Selecting host $hostname from database" -Level Verbose
                    $query = "SELECT HostID FROM Host WHERE HostName = '$hostname'"

                    try {
                        $hostID = (Invoke-DbaQuery -SqlInstance $pdcSqlInstance -SqlCredential $pdcCredential -Database $pdcDatabase -Query $query -EnableException).HostID
                    }
                    catch {
                        Stop-PSFFunction -Message "Couldnt execute query for retrieving host id" -Target $query -ErrorRecord $_ -Continue
                    }
                }
                elseif ($informationStore -eq 'File') {
                    $hostID = ($hosts | Where-Object { $_.Hostname -eq $hostname } | Select-Object HostID -Unique).HostID
                }
            }

            # Setup the clone location
            $cloneLocation = "$($clonePath)"

            if ($informationStore -eq 'SQL') {
                # Get the image id from the database
                Write-PSFMessage -Message "Selecting image from database" -Level Verbose
                try {
                    $query = "SELECT ImageID, ImageName FROM dbo.Image WHERE ImageLocation = '$ParentVhd'"
                    $image = Invoke-DbaQuery -SqlInstance $pdcSqlInstance -SqlCredential $pdcCredential -Database $pdcDatabase -Query $query -EnableException
                }
                catch {
                    Stop-PSFFunction -Message "Couldnt execute query for retrieving image id" -Target $query -ErrorRecord $_ -Continue
                }

                if ($PSCmdlet.ShouldProcess("$($clonePath)", "Adding clone to database")) {
                    if ($null -ne $image.ImageID) {
                        # Setup the query to add the clone to the database
                        Write-PSFMessage -Message "Adding clone $cloneLocation to database" -Level Verbose
                        $query = "
                                DECLARE @CloneID INT;
                                EXECUTE dbo.Clone_New @CloneID = @CloneID OUTPUT,                   -- int
                                                    @ImageID = $($image.ImageID),             -- int
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
                            $result = Invoke-DbaQuery -SqlInstance $pdcSqlInstance -SqlCredential $pdcCredential -Database $pdcDatabase -Query $query -EnableException
                            $cloneID = $result.CloneID
                        }
                        catch {
                            Stop-PSFFunction -Message "Couldnt execute query for adding clone" -Target $query -ErrorRecord $_ -Continue
                        }

                    }
                    else {
                        Stop-PSFFunction -Message "Image couldn't be found" -Target $imageName -Continue
                    }
                }
            }
            elseif ($informationStore -eq 'File') {
                # Get the image
                $image = Get-DcnImage -ImageLocation $ParentVhd

                [array]$clones = $null

                # Get all the images
                $clones = Get-DcnClone

                # Setup the new image id
                if ($clones.Count -ge 1) {
                    $cloneID = ($clones[-1].CloneID | Sort-Object CloneID) + 1
                }
                else {
                    $cloneID = 1
                }

                # Add the new information to the array
                $clones += [PSCustomObject]@{
                    CloneID       = $cloneID
                    ImageID       = $image.ImageID
                    ImageName     = $image.ImageName
                    ImageLocation = $ParentVhd
                    HostID        = $hostId
                    HostName      = $hostname
                    CloneLocation = $cloneLocation
                    AccessPath    = $accessPath
                    SqlInstance   = $($server.DomainInstanceName)
                    DatabaseName  = $cloneDatabase
                    IsEnabled     = $active
                }

                # Test if the JSON folder can be reached
                if (-not (Test-Path -Path "DCNJSONFolder:\")) {
                    $command = [scriptblock]::Create("Import-Module dbaclone -Force")

                    try {
                        Invoke-PSFCommand -ComputerName $computer -ScriptBlock $command -Credential $Credential
                    }
                    catch {
                        Stop-PSFFunction -Message "Couldn't import module remotely" -Target $command
                        return
                    }
                }

                # Set the clone file
                $jsonCloneFile = "DCNJSONFolder:\clones.json"

                # Convert the data back to JSON
                $clones | ConvertTo-Json | Set-Content $jsonCloneFile
            }

            if (-not $SkipDatabaseMount) {
                $cloneInstance = $server.DomainInstanceName
            }
            else {
                $cloneInstance = $null
            }

            # Add the results to the custom object
            [PSCustomObject]@{
                CloneID       = $cloneID
                CloneLocation = $cloneLocation
                AccessPath    = $accessPath
                SqlInstance   = $cloneInstance
                DatabaseName  = $cloneDatabase
                IsEnabled     = $active
                ImageID       = $image.ImageID
                ImageName     = $image.ImageName
                ImageLocation = $ParentVhd
                HostName      = $hostname
            }
        } # End for each database
        #} # End for each sql instance
    } # End process

    end {
        # Test if there are any errors
        if (Test-PSFFunctionInterrupt) { return }

        Write-PSFMessage -Message "Finished creating database clone" -Level Verbose
    }
}

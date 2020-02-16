function Invoke-DcnRepairClone {
    <#
    .SYNOPSIS
        Invoke-DcnRepairClone repairs the clones

    .DESCRIPTION
        Invoke-DcnRepairClone has the ability to repair the clones when they have gotten disconnected from the image.
        In such a case the clone is no longer available for the database server and the database will either not show
        any information or the database will have the status (Recovery Pending).

        By running this command all the clones will be retrieved from the database for a certain host.

    .PARAMETER HostName
        Set on or more hostnames to retrieve the configurations for

    .PARAMETER SqlCredential
        Allows you to login to servers using SQL Logins as opposed to Windows Auth/Integrated/Trusted. To use:

        $scred = Get-Credential, then pass $scred object to the -SqlCredential parameter.

        Windows Authentication will be used if SqlCredential is not specified. SQL Server does not accept Windows credentials being passed as credentials.
        To connect as a different Windows user, run PowerShell as that user.

    .PARAMETER Credential
        Allows you to login to servers using SQL Logins as opposed to Windows Auth/Integrated/Trusted.
        This works similar as SqlCredential but is only meant for authentication to the the host

    .PARAMETER DcnSqlCredential
        Allows you to login to servers using SQL Logins as opposed to Windows Auth/Integrated/Trusted.
        This works similar as SqlCredential but is only meant for authentication to the PSDatabaseClone database server and database.

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .PARAMETER WhatIf
        If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.

    .PARAMETER Confirm
        If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.

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
        Invoke-DcnRepairClone -Hostname Host1

        Repair the clones for Host1

    #>

    [CmdLetBinding(SupportsShouldProcess = $true)]

    param(
        [Parameter(Mandatory = $true)]
        [string[]]$HostName,
        [PSCredential]$SqlCredential,
        [PSCredential]$Credential,
        [PSCredential]$DcnSqlCredential,
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
    }

    process {
        # Test if there are any errors
        if (Test-PSFFunctionInterrupt) { return }

        # Loop through each of the hosts
        foreach ($hst in $HostName) {

            # Setup the computer object
            $computer = [PSFComputer]$hst

            if (-not $computer.IsLocalhost) {
                # Get the result for the remote test
                $resultPSRemote = Test-DcnRemoting -ComputerName $hst -Credential $Credential

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

            # Get the clones
            [array]$results = Get-DcnClone -HostName $hst

            # Loop through the results
            foreach ($result in $results) {

                $server = Connect-DbaInstance -SqlInstance $result.SqlInstance -SqlCredential $SqlCredential

                # Get the databases
                Write-PSFMessage -Message "Retrieve the databases for $($result.SqlInstance)" -Level Verbose
                $databases = $server.Databases

                $image = Get-DcnImage -ImageID $result.ImageID

                # Check if the parent of the clone can be reached
                try {
                    $null = New-PSDrive -Name ImagePath -Root (Split-Path $image.ImageLocation) -Credential $Credential -PSProvider FileSystem
                }
                catch {
                    Stop-PSFFunction -Message "Could not create drive for image path '$($image.ImageLocation)'" -ErrorRecord $_ -Continue
                }

                # Test if the image still exists
                if (Test-Path -Path "ImagePath:\$($image.ImageName).vhdx") {
                    # Mount the clone
                    try {
                        Write-PSFMessage -Message "Mounting vhd $($result.CloneLocation)" -Level Verbose

                        if (Test-Path -Path $result.CloneLocation) {
                            $disk = Get-Disk | Where-Object Location -eq $result.CloneLocation

                            if (-not $disk) {
                                # Check if computer is local
                                if ($PSCmdlet.ShouldProcess("Mounting $($result.CloneLocation)")) {
                                    if ($computer.IsLocalhost) {
                                        $null = Mount-DiskImage -ImagePath $result.CloneLocation -NoDriveLetter
                                    }
                                    else {
                                        $command = [ScriptBlock]::Create("Mount-DiskImage -ImagePath '$($result.CloneLocation)' -NoDriveLetter -ErrorAction SilentlyContinue")
                                        $null = Invoke-PSFCommand -ComputerName $computer -ScriptBlock $command -Credential $Credential
                                    }
                                }
                            }
                        }
                        else {
                            Stop-PSFFunction -Message "Couldn't find clone file '$($result.CloneLocation)'" -Target $result -Continue
                        }
                    }
                    catch {
                        Stop-PSFFunction -Message "Couldn't mount vhd" -Target $result -ErrorRecord $_ -Continue
                    }
                }
                else {
                    Stop-PSFFunction -Message "Vhd $($result.CloneLocation) cannot be mounted because image path cannot be reached" -Target $image -Continue
                }

                # Remove the PS Drive
                try {
                    $null = Remove-PSDrive -Name ImagePath
                }
                catch {
                    Stop-PSFFunction -Message "Could not remove drive 'ImagePath'" -ErrorRecord $_ -Continue
                }

                # Check if the database is already attached
                if ($result.DatabaseName -in $databases.Name) {
                    $db = $databases | Where-Object Name -eq $result.DatabaseName

                    if ($db.Status -eq 'RecoveryPending') {
                        try {
                            Write-PSFMessage -Message "Setting database offline" -Level Verbose
                            $db.SetOffline()

                            Write-PSFMessage -Message "Setting database online" -Level Verbose
                            $db.SetOnline()
                        }
                        catch {
                            Stop-PSFFunction -Message "Could not detach database [$($result.DatabaseName)]" -ErrorRecord $_ -Continue
                        }
                    }
                    else {
                        try {
                            Detach-DbaDatabase -SqlInstance $result.SQLInstance -SqlCredential $SqlCredential -Database $result.DatabaseName
                        }
                        catch {
                            Stop-PSFFunction -Message "Could not detach database [$($result.DatabaseName)]" -ErrorRecord $_ -Continue
                        }
                    }
                }
                else {
                    # Get all the files of the database
                    if ($PSCmdlet.ShouldProcess("Retrieving database files from $($result.AccessPath)")) {
                        # Check if computer is local
                        if ($computer.IsLocalhost) {
                            $databaseFiles = Get-ChildItem -Path $result.AccessPath -Recurse | Where-Object { -not $_.PSIsContainer }
                        }
                        else {
                            $commandText = "Get-ChildItem -Path $($result.AccessPath) -Recurse | " + 'Where-Object {-not $_.PSIsContainer}'
                            $command = [ScriptBlock]::Create($commandText)
                            $databaseFiles = Invoke-PSFCommand -ComputerName $computer -ScriptBlock $command -Credential $Credential
                        }
                    }

                    # Setup the database filestructure
                    $dbFileStructure = New-Object System.Collections.Specialized.StringCollection

                    # Loop through each of the database files and add them to the file structure
                    foreach ($dbFile in $databaseFiles) {
                        $dbFileStructure.Add($dbFile.FullName) | Out-Null
                    }

                    Write-PSFMessage -Message "Mounting database from clone" -Level Verbose

                    # Mount the database using the config file
                    if ($PSCmdlet.ShouldProcess("Mounting database $($result.DatabaseName) to $($result.SQLInstance)")) {
                        try {
                            $null = Mount-DbaDatabase -SqlInstance $result.SQLInstance -Database $result.DatabaseName -FileStructure $dbFileStructure
                        }
                        catch {
                            Stop-PSFFunction -Message "Couldn't mount database $($result.DatabaseName)" -Target $result.DatabaseName -Continue
                        }
                    }
                }
            } # End for ech result
        } # End for each host
    } # End process

    end {
        # Test if there are any errors
        if (Test-PSFFunctionInterrupt) { return }

        Write-PSFMessage -Message "Finished repairing clones" -Level Verbose
    }

}

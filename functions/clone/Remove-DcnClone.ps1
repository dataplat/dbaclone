function Remove-DcnClone {
    <#
    .SYNOPSIS
        Remove-DcnClone removes one or more clones from a host

    .DESCRIPTION
        Remove-DcnClone is able to remove one or more clones from a host.
        The command looks up all the records dor a particular hostname.
        It will remove the database from the database server and all related files.

        The filter parameters Database and ExcludeDatabase work like wildcards.
        There is no need to include the asterisk (*). See the examples for more details

    .PARAMETER HostName
        The hostname to filter on

    .PARAMETER SqlCredential
        Allows you to login to servers using SQL Logins as opposed to Windows Auth/Integrated/Trusted. To use:

        $scred = Get-Credential, then pass $scred object to the -SqlCredential parameter.

        Windows Authentication will be used if SqlCredential is not specified. SQL Server does not accept Windows credentials being passed as credentials.
        To connect as a different Windows user, run PowerShell as that user.

    .PARAMETER DcnSqlCredential
        Allows you to login to servers using SQL Logins as opposed to Windows Auth/Integrated/Trusted.
        This works similar as SqlCredential but is only meant for authentication to the dbaclone database server and database.

    .PARAMETER Credential
        Allows you to login to systems using a credential. To use:

        $scred = Get-Credential, then pass $scred object to the -Credential parameter.

    .PARAMETER Database
        Allows to filter to include specific databases

    .PARAMETER ExcludeDatabase
        Allows to filter to exclude specific databases

    .PARAMETER All
        Remove all the clones

    .PARAMETER InputObject
        The input object that is used for pipeline use

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
        Remove-DcnClone -HostName Host1 -Database Clone1

        Removes the clones that are registered at Host1 and have the text "Clone1"

    .EXAMPLE
        Remove-DcnClone -HostName Host1, Host2, Host3 -Database Clone

        Removes the clones that are registered at multiple hosts and have the text "Clone"

    .EXAMPLE
        Remove-DcnClone -HostName Host1

        Removes all clones from Host1

    #>

    [CmdLetBinding(DefaultParameterSetName = "HostName", SupportsShouldProcess = $true, ConfirmImpact = 'High')]

    param(
        [parameter(ParameterSetName = "HostName")]
        [string[]]$HostName,
        [PSCredential]$SqlCredential,
        [PSCredential]$DcnSqlCredential,
        [PSCredential]$Credential,
        [string[]]$Database,
        [string[]]$ExcludeDatabase,
        [switch]$All,
        [parameter(ValueFromPipeline = $true, ParameterSetName = "Clone")]
        [object[]]$InputObject,
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

        # Get the information store
        $informationStore = Get-PSFConfigValue -FullName dbaclone.informationstore.mode

        if ($informationStore -eq 'SQL') {
            # Get the module configurations
            [DbaInstanceParameter]$pdcSqlInstance = Get-PSFConfigValue -FullName dbaclone.database.Server
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

        # Get all the items
        $items = @()
        $items += Get-DcnClone

        if (-not $All) {
            if ($HostName) {
                Write-PSFMessage -Message "Filtering hostnames" -Level Verbose
                $items = $items | Where-Object { $_.HostName -in $HostName }
            }

            if ($Database) {
                Write-PSFMessage -Message "Filtering included databases" -Level Verbose
                $items = $items | Where-Object { $_.DatabaseName -in $Database }
            }

            if ($ExcludeDatabase) {
                Write-PSFMessage -Message "Filtering excluded databases" -Level Verbose
                $items = $items | Where-Object { $_.DatabaseName -notin $Database }
            }
        }

        # Append the items
        $InputObject += $items

    }

    process {
        # Test if there are any errors
        if (Test-PSFFunctionInterrupt) { return }

        Write-PSFMessage -Message "Started removing database clones" -Level Verbose

        # Group the objects to make it easier to go through
        [array]$clones = $InputObject | Group-Object SqlInstance

        # Loop through each of the host names
        foreach ($clone in $clones) {

            # Connect to the instance
            if (-not $null -eq $clone.Name) {
                Write-PSFMessage -Message "Attempting to connect to clone database server $($clone.Name).." -Level Verbose
                try {
                    $server = Connect-DbaInstance -SqlInstance $clone.Name -SqlCredential $SqlCredential -SqlConnectionOnly
                }
                catch {
                    Stop-PSFFunction -Message "Could not connect to Sql Server instance $($clone.Name)" -ErrorRecord $_ -Target $clone.Name -Continue
                }
            }

            # Loop through each of the results
            foreach ($item in $clone.Group) {

                # Setup the computer object
                $computer = [PsfComputer]$item.HostName

                if (-not $computer.IsLocalhost) {
                    # Get the result for the remote test
                    try {
                        $resultPSRemote = Test-DcnRemoting -ComputerName $item.HostName -Credential $Credential -EnableException

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
                    catch {
                        Stop-PSFFunction -Message "Something went wrong testing if the host is remote" -Target $item -ErrordRecord $_
                        return
                    }
                }

                if (-not $null -eq $item.SqlInstance) {
                    $server = Connect-DbaInstance -SqlInstance $item.SqlInstance -SqlCredential $SqlCredential

                    if ($item.DatabaseName -in $server.Databases.Name) {
                        if ($PSCmdlet.ShouldProcess($item.DatabaseName, "Removing database $($item.DatabaseName)")) {
                            # Remove the database
                            try {
                                Write-PSFMessage -Message "Removing database $($item.DatabaseName) from $($item.SqlInstance)" -Level Verbose

                                $null = Remove-DbaDatabase -SqlInstance $item.SqlInstance -SqlCredential $SqlCredential -Database $item.DatabaseName -Confirm:$false -EnableException
                            }
                            catch {
                                Stop-PSFFunction -Message "Could not remove database $($item.DatabaseName) from $server" -ErrorRecord $_ -Target $server -Continue
                            }
                        }
                    }
                    else {
                        Write-PSFMessage -Level Verbose -Message "Could not find database [$($item.DatabaseName)] on $($item.SqlInstance)"
                    }
                }

                if ($PSCmdlet.ShouldProcess($item.CloneLocation, "Dismounting the vhd")) {
                    # Dismounting the vhd
                    try {
                        if ($computer.IsLocalhost) {
                            if (Test-Path -Path $item.CloneLocation) {
                                Write-PSFMessage -Message "Dismounting disk '$($item.CloneLocation)' from $($item.HostName)" -Level Verbose
                                $null = Dismount-DiskImage -ImagePath $item.CloneLocation
                            }
                            else {
                                Write-PSFMessage -Level Verbose -Message "Could not find clone file '$($item.CloneLocation)'"
                            }
                        }
                        else {
                            $command = [ScriptBlock]::Create("Test-Path -Path '$($item.CloneLocation)'")
                            $result = Invoke-PSFCommand -ComputerName $item.HostName -ScriptBlock $command -Credential $Credential
                            if ($result) {
                                Write-PSFMessage -Message "Dismounting disk '$($item.CloneLocation)' from $($item.HostName)" -Level Verbose
                                $command = [scriptblock]::Create("Dismount-DiskImage -ImagePath '$($item.CloneLocation)'")
                                $null = Invoke-PSFCommand -ComputerName $item.HostName -ScriptBlock $command -Credential $Credential
                            }
                            else{
                                Write-PSFMessage -Level Verbose -Message "Could not find clone file '$($item.CloneLocation)'"
                            }
                        }
                    }
                    catch {
                        Stop-PSFFunction -Message "Could not dismount vhd $($item.CloneLocation)" -ErrorRecord $_ -Target $result -Continue
                    }
                }

                if ($PSCmdlet.ShouldProcess($item.CloneLocation, "Removing clone files and folders")) {
                    # Remove clone file and related access path
                    try {
                        if ($computer.IsLocalhost) {
                            if (Test-Path -Path $item.AccessPath) {
                                Write-PSFMessage -Message "Removing vhd access path" -Level Verbose
                                $null = Remove-Item -Path "$($item.AccessPath)" -Credential $Credential -Force
                            }

                            if (Test-Path -Path $item.CloneLocation) {
                                Write-PSFMessage -Message "Removing vhd" -Level Verbose
                                $null = Remove-Item -Path "$($item.CloneLocation)" -Credential $Credential -Force
                            }
                        }
                        else {
                            $command = [scriptblock]::Create("Test-Path -Path '$($item.AccessPath)'")
                            $result = Invoke-PSFCommand -ComputerName $item.HostName -ScriptBlock $command -Credential $Credential
                            if ($result) {
                                Write-PSFMessage -Message "Removing vhd access path" -Level Verbose
                                $command = [scriptblock]::Create("Remove-Item -Path '$($item.AccessPath)' -Force")
                                $null = Invoke-PSFCommand -ComputerName $item.HostName -ScriptBlock $command -Credential $Credential
                            }

                            $command = [scriptblock]::Create("Test-Path -Path '$($item.CloneLocation)'")
                            $result = Invoke-PSFCommand -ComputerName $item.HostName -ScriptBlock $command -Credential $Credential
                            if ($result) {
                                Write-PSFMessage -Message "Removing vhd" -Level Verbose
                                $command = [scriptblock]::Create("Remove-Item -Path '$($item.CloneLocation)' -Force")
                                $null = Invoke-PSFCommand -ComputerName $item.HostName -ScriptBlock $command -Credential $Credential
                            }
                        }
                    }
                    catch {
                        Stop-PSFFunction -Message "Could not remove clone files" -ErrorRecord $_ -Target $result -Continue
                    }
                }

                if ($PSCmdlet.ShouldProcess("Clone ID: $($item.CloneID)", "Deleting clone from database")) {
                    #Check if the VHD has been removed before we remove it from the database
                    $cloneVHDExists = $true;
                    if ($computer.IsLocalhost) {
                        $cloneVHDExists = Test-Path -Path $item.CloneLocation;
                    }
                    else {
                        $command = [scriptblock]::Create("Test-Path -Path '$($item.CloneLocation)'")
                        $cloneVHDExists = Invoke-PSFCommand -ComputerName $item.HostName -ScriptBlock $command -Credential $Credential
                    }

                    if (-not $cloneVHDExists) {
                        if ($informationStore -eq 'SQL') {
                            # Removing records from database
                            try {
                                $query = "DELETE FROM dbo.Clone WHERE CloneID = $($item.CloneID);"

                                $null = Invoke-DbaQuery -SqlInstance $pdcSqlInstance -SqlCredential $pdcCredential -Database $pdcDatabase -Query $query -EnableException
                            }
                            catch {
                                Stop-PSFFunction -Message "Could not remove clone record from database" -ErrorRecord $_ -Target $query -Continue
                            }
                        }
                        elseif ($informationStore -eq 'File') {
                            [array]$cloneData = $null
                            [array]$newCloneData = $null

                            $cloneData = Get-DcnClone

                            $newCloneData = $cloneData | Where-Object { $_.CloneID -ne $item.CloneID }

                            # Set the clone file
                            $jsonCloneFile = "DCNJSONFolder:\clones.json"

                            # Convert the data back to JSON
                            if ($newCloneData.Count -ge 1) {
                                $newCloneData | ConvertTo-Json | Set-Content $jsonCloneFile
                            }
                            else {
                                Clear-Content -Path $jsonCloneFile
                            }
                        }
                    }
                    else {
                        Write-PSFMessage -Message "Clone '$($item.ImageLocation)' exists. Skipping 'Deleting clone from database'" -Level Warning
                    }
                }
            } # End for each group item
        } # End for each clone
    } # End process

    end {
        # Test if there are any errors
        if (Test-PSFFunctionInterrupt) { return }

        Write-PSFMessage -Message "Finished removing database clone(s)" -Level Verbose
    }
}

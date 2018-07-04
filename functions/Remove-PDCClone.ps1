function Remove-PDCClone {
    <#
.SYNOPSIS
    Remove-PDCClone removes one or more clones from a host

.DESCRIPTION
    Remove-PDCClone is able to remove one or more clones from a host.
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

    Website: https://psdatabaseclone.io
    Copyright: (C) Sander Stad, sander@sqlstad.nl
    License: MIT https://opensource.org/licenses/MIT

.LINK
    https://psdatabaseclone.io/

.EXAMPLE
    Remove-PDCClone -HostName Host1 -Database Clone1

    Removes the clones that are registered at Host1 and have the text "Clone1"

.EXAMPLE
    Remove-PDCClone -HostName Host1, Host2, Host3 -Database Clone

    Removes the clones that are registered at multiple hosts and have the text "Clone"

.EXAMPLE
    Remove-PDCClone -HostName Host1

    Removes all clones from Host1

#>
    [CmdLetBinding(DefaultParameterSetName = "HostName", SupportsShouldProcess = $true,
        ConfirmImpact = 'High')]

    param(
        [parameter(ParameterSetName = "HostName")]
        [string[]]$HostName,
        [System.Management.Automation.PSCredential]
        $SqlCredential,
        [System.Management.Automation.PSCredential]
        $Credential,
        [string[]]$Database,
        [string[]]$ExcludeDatabase,
        [switch]$All,
        [parameter(ValueFromPipeline = $true, ParameterSetName = "Clone")]
        [object[]]$InputObject,
        [switch]$EnableException
    )

    begin {

        # Test the module database setup
        try {
            Test-PDCConfiguration -EnableException
        }
        catch {
            Stop-PSFFunction -Message "Something is wrong in the module configuration" -ErrorRecord $_ -Continue
        }

        $pdcSqlInstance = Get-PSFConfigValue -FullName psdatabaseclone.database.server
        $pdcDatabase = Get-PSFConfigValue -FullName psdatabaseclone.database.name

        if (-not $HostName -and -not $InputObject) {

            if(-not $PSCmdlet.ShouldProcess("All hosts" , "Delete all clones on all hosts?`nIf not please say no and use -HostName and/or -Database")){
                return
            }

        }

        Write-PSFMessage -Message "Started removing database clones" -Level Verbose

        # Get all the items
        $items = Get-PDCClone

        if (-not $All) {
            if ($HostName) {
                Write-PSFMessage -Message "Filtering hostnames" -Level Verbose
                $items = $items | Where-Object {$_.HostName -in $HostName}
            }

            if ($Database) {
                Write-PSFMessage -Message "Filtering included databases" -Level Verbose
                $items = $items | Where-Object {$_.DatabaseName -in $Database}
            }

            if ($ExcludeDatabase) {
                Write-PSFMessage -Message "Filtering excluded databases" -Level Verbose
                $items = $items | Where-Object {$_.DatabaseName -notin $Database}
            }
        }

        # Append the items
        $InputObject += $items

    }

    process {
        # Test if there are any errors
        if (Test-PSFFunctionInterrupt) { return }

        # Group the objects to make it easier to go through
        $clones = $InputObject | Group-Object SqlInstance

        # Loop through each of the host names
        foreach ($clone in $clones) {

            # Connect to the instance
            Write-PSFMessage -Message "Attempting to connect to clone database server $($clone.Name).." -Level Verbose
            try {
                $server = Connect-DbaInstance -SqlInstance $clone.Name -SqlCredential $SqlCredential -SqlConnectionOnly
            }
            catch {
                Stop-PSFFunction -Message "Could not connect to Sql Server instance $($clone.Name)" -ErrorRecord $_ -Target $clone.Name -Continue
            }

            # Loop through each of the results
            foreach ($item in $clone.Group) {

                # Remove the database
                try {
                    Write-PSFMessage -Message "Removing database $($item.DatabaseName) from $($item.SqlInstance)" -Level Verbose

                    $null = Remove-DbaDatabase -SqlInstance $item.SqlInstance -SqlCredential $SqlCredential -Database $item.DatabaseName -Confirm:$false -EnableException
                }
                catch {
                    Stop-PSFFunction -Message "Could not remove database $($item.DatabaseName) from $server" -ErrorRecord $_ -Target $server -Continue
                }

                # Dismounting the vhd
                try {
                    Write-PSFMessage -Message "Dismounting disk $($item.DatabaseName) from $($item.SqlInstance)" -Level Verbose
                    $null = Dismount-VHD -Path $item.CloneLocation
                }
                catch {
                    Stop-PSFFunction -Message "Could not dismount vhd $($item.CloneLocation)" -ErrorRecord $_ -Target $result -Continue
                }

                # Remove clone file and related access path
                try {
                    Write-PSFMessage -Message "Removing vhd access path" -Level Verbose
                    $null = Remove-Item -Path $item.AccessPath -Credential $Credential -Force

                    Write-PSFMessage -Message "Removing vhd" -Level Verbose
                    $null = Remove-Item -Path $item.CloneLocation -Credential $Credential -Force
                }
                catch {
                    Stop-PSFFunction -Message "Could not remove clone files" -ErrorRecord $_ -Target $result -Continue
                }

                # Removing records from database
                try {
                    $query = "
                        DELETE c
                        FROM dbo.Clone AS c
                            INNER JOIN dbo.Host AS h
                                ON h.HostID = h.HostID
                        WHERE h.HostName = '$($item.HostName)'
                            AND c.CloneLocation = '$($item.CloneLocation)';
                    "

                    Invoke-DbaSqlQuery -SqlInstance $pdcSqlInstance -Database $pdcDatabase -Query $query -EnableException
                }
                catch {
                    Stop-PSFFunction -Message "Could not remove clone record from database" -ErrorRecord $_ -Target $query -Continue
                }
            } # end for each group item

        } # End for each clone

    } # End process

    end {
        # Test if there are any errors
        if (Test-PSFFunctionInterrupt) { return }

        Write-PSFMessage -Message "Finished removing database clone(s)" -Level Verbose
    }
}
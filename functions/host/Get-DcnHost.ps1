function Get-DcnHost {
    <#
    .SYNOPSIS
        Get-DcnHost get all the hosts that have clones

    .DESCRIPTION
        Get-DcnHost will retrieve the hosts that have clones
        By default all the hosts are returned

    .PARAMETER SqlCredential
        Allows you to login to servers using SQL Logins as opposed to Windows Auth/Integrated/Trusted. To use:

        $scred = Get-Credential, then pass $scred object to the -SqlCredential parameter.

        Windows Authentication will be used if SqlCredential is not specified. SQL Server does not accept Windows credentials being passed as credentials.
        To connect as a different Windows user, run PowerShell as that user.

    .PARAMETER DcnSqlCredential
        Allows you to login to servers using SQL Logins as opposed to Windows Auth/Integrated/Trusted.
        This works similar as SqlCredential but is only meant for authentication to the PSDatabaseClone database server and database.

    .PARAMETER Credential
        Allows you to login to servers or use authentication to access files and folder/shares

        $scred = Get-Credential, then pass $scred object to the -Credential parameter.

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
        Get-DcnHost

        Get all the hosts

    #>

    [CmdLetBinding()]

    param(
        [PSCredential]$SqlCredential,
        [PSCredential]$DcnSqlCredential,
        [PSCredential]$Credential,
        [switch]$EnableException
    )

    begin {
        # Check if the setup has ran
        if (-not (Test-DcnModule -SetupStatus)) {
            Stop-PSFFunction -Message "The module setup has NOT yet successfully run. Please run 'Set-DcnConfiguration'" -Continue
        }

        # Get the information store
        $informationStore = Get-PSFConfigValue -FullName psdatabaseclone.informationstore.mode

        if ($informationStore -eq 'SQL') {

            # Get the module configurations
            [DbaInstanceParameter]$pdcSqlInstance = Get-PSFConfigValue -FullName psdatabaseclone.database.Server
            $pdcDatabase = Get-PSFConfigValue -FullName psdatabaseclone.database.name
            if (-not $DcnSqlCredential) {
                $pdcCredential = Get-PSFConfigValue -FullName psdatabaseclone.informationstore.credential -Fallback $null
            }
            else {
                $pdcCredential = $DcnSqlCredential
            }

            # Test the module database setup
            try {
                Test-DcnConfiguration -SqlCredential $pdcCredential -EnableException
            }
            catch {
                Stop-PSFFunction -Message "Something is wrong in the module configuration" -ErrorRecord $_ -Continue
            }

            $query = "SELECT DISTINCT h.HostName FROM dbo.Host AS h"

            try {
                $results = @()
                $results += Invoke-DbaQuery -SqlInstance $pdcSqlInstance -SqlCredential $DcnSqlCredential -Database $pdcDatabase -Query $query -As PSObject
            }
            catch {
                Stop-PSFFunction -Message "Could retrieve images from database $pdcDatabase" -ErrorRecord $_ -Target $query
            }
        }
        elseif ($informationStore -eq 'File') {
            try {
                if (Test-Path -Path "DCNJSONFolder:\") {
                    # Get the clones
                    $results = Get-ChildItem -Path "DCNJSONFolder:\" -Filter "*clones.json" | ForEach-Object { Get-Content $_.FullName | ConvertFrom-Json }
                }
                else {
                    Stop-PSFFunction -Message "Could not reach image information location 'DCNJSONFolder:\'" -ErrorRecord $_ -Target "DCNJSONFolder:\"
                    return
                }
            }
            catch {
                Stop-PSFFunction -Message "Couldn't get results from JSN folder" -Target "DCNJSONFolder:\" -ErrorRecord $_
            }
        }
    }

    process {
        # Test if there are any errors
        if (Test-PSFFunctionInterrupt) { return }

        foreach ($result in $results) {

            [pscustomobject]@{
                HostName = $result.HostName
            }
        }
    }

    end {
        # Test if there are any errors
        if (Test-PSFFunctionInterrupt) { return }

        Write-PSFMessage -Message "Finished retrieving host(s)" -Level Verbose
    }
}

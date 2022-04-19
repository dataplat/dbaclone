﻿function Get-DcnClone {
    <#
    .SYNOPSIS
        Get-DcnClone get on or more clones

    .DESCRIPTION
        Get-DcnClone will retrieve the clones and apply filters if needed.
        By default all the clones are returned

    .PARAMETER SqlCredential
        Allows you to login to servers using SQL Logins as opposed to Windows Auth/Integrated/Trusted. To use:

        $scred = Get-Credential, then pass $scred object to the -SqlCredential parameter.

        Windows Authentication will be used if SqlCredential is not specified. SQL Server does not accept Windows credentials being passed as credentials.
        To connect as a different Windows user, run PowerShell as that user.

    .PARAMETER DcnSqlCredential
        Allows you to login to servers using SQL Logins as opposed to Windows Auth/Integrated/Trusted.
        This works similar as SqlCredential but is only meant for authentication to the dbaclone database server and database.

    .PARAMETER Credential
        Allows you to login to servers or use authentication to access files and folder/shares

        $scred = Get-Credential, then pass $scred object to the -Credential parameter.

    .PARAMETER HostName
        Filter based on the hostname

    .PARAMETER Database
        Filter based on the database

    .PARAMETER ImageID
        Filter based on the image id

    .PARAMETER ImageName
        Filter based on the image name

    .PARAMETER ImageLocation
        Filter based on the image location

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
        Get-DcnClone

        Get all the clones

    .EXAMPLE
        Get-DcnClone -HostName host1, host2

        Retrieve the clones for host1 and host2

    .EXAMPLE
        Get-DcnClone -Database DB1

        Get all the clones that have the name DB1

    .EXAMPLE
        Get-DcnClone -ImageName DB1_20180703085917

        Get all the clones that were made with image "DB1_20180703085917"
    #>

    [CmdLetBinding()]

    param(
        [PSCredential]$SqlCredential,
        [PSCredential]$DcnSqlCredential,
        [PSCredential]$Credential,
        [string[]]$HostName,
        [string[]]$Database,
        [int[]]$ImageID,
        [string[]]$ImageName,
        [string[]]$ImageLocation,
        [switch]$EnableException
    )

    begin {
        # Check if the setup has ran
        if (-not (Test-DcnModule -SetupStatus)) {
            Stop-PSFFunction -Message "The module setup has NOT yet successfully run. Please run 'Set-DcnConfiguration'" -Continue
        }

        # Get the information store
        $informationStore = Get-PSFConfigValue -FullName dbaclone.informationstore.mode

        if ($informationStore -eq 'SQL') {

            # Get the module configurations
            $pdcSqlInstance = Get-PSFConfigValue -FullName dbaclone.database.server
            $pdcDatabase = Get-PSFConfigValue -FullName dbaclone.database.name
            if (-not $DcnSqlCredential) {
                $pdcCredential = Get-PSFConfigValue -FullName dbaclone.informationstore.credential -Fallback $null
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

            $query = "
                SELECT c.CloneID,
                    c.CloneLocation,
                    c.AccessPath,
                    c.SqlInstance,
                    c.DatabaseName,
                    c.IsEnabled,
                    i.ImageID,
                    i.ImageName,
                    i.ImageLocation,
                    i.SqlServerRelease,
                    i.SqlServerVersion,
                    h.HostName
                FROM dbo.Clone AS c
                    INNER JOIN dbo.Host AS h
                        ON h.HostID = c.HostID
                    INNER JOIN dbo.Image AS i
                        ON i.ImageID = c.ImageID;
            "

            try {
                $results = @()
                $results = Invoke-DbaQuery -SqlInstance $pdcSqlInstance -SqlCredential $pdcCredential -Database $pdcDatabase -Query $query -As PSObject
            }
            catch {
                Stop-PSFFunction -Message "Could not execute query" -ErrorRecord $_ -Target $query
            }
        }
        elseif ($informationStore -eq 'File') {
            # Create the PS Drive and get the results
            try {
                if (($true -eq (Get-PSFConfigValue -FullName dbaclone.setup.status)) -and (Test-Path -Path "DCNJSONFolder:\")) {
                    # Get the clones
                    $results = Get-ChildItem -Path "DCNJSONFolder:\" -Filter "*clones.json" | ForEach-Object { Get-Content $_.FullName | ConvertFrom-Json }
                }
                else {
                    Stop-PSFFunction -Message "Could not reach clone information location 'DCNJSONFolder:\'" -ErrorRecord $_ -Target "DCNJSONFolder:\"
                    return
                }
            }
            catch {
                Stop-PSFFunction -Message "Couldn't get results from JSN folder" -ErrorRecord $_ -Target "DCNJSONFolder:\"
                return
            }
        }

        # Filter host name
        if ($HostName) {
            $results = $results | Where-Object { $_.HostName -in $HostName }
        }

        # Filter image id
        if ($Database) {
            $results = $results | Where-Object { $_.DatabaseName -in $Database }
        }

        # Filter image id
        if ($ImageID) {
            $results = $results | Where-Object { $_.ImageID -in $ImageID }
        }

        # Filter image name
        if ($ImageName) {
            $results = $results | Where-Object { $_.ImageName -in $ImageName }
        }

        # Filter image location
        if ($ImageLocation) {
            $results = $results | Where-Object { $_.ImageLocation -in $ImageLocation }
        }

    }

    process {

        # Test if there are any errors
        if (Test-PSFFunctionInterrupt) { return }

        # Convert the results to the DCLClone data type
        foreach ($result in $results) {

            [pscustomobject]@{
                CloneID          = $result.CloneID
                CloneLocation    = $result.CloneLocation
                AccessPath       = $result.AccessPath
                SqlInstance      = $result.SqlInstance
                DatabaseName     = $result.DatabaseName
                IsEnabled        = $result.IsEnabled
                ImageID          = $result.ImageID
                ImageName        = $result.ImageName
                ImageLocation    = $result.ImageLocation
                SqlServerRelease = $result.SqlServerRelease
                SqlServerVersion = $result.SqlServerVersion
                HostName         = $result.HostName
            }
        }
    }

    end {

        # Test if there are any errors
        if (Test-PSFFunctionInterrupt) { return }

        Write-PSFMessage -Message "Finished retrieving clone(s)" -Level Verbose

    }
}

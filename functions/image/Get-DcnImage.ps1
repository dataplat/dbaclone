function Get-DcnImage {
    <#
    .SYNOPSIS
        Get-DcnImage get on or more clones

    .DESCRIPTION
        Get-DcnImage will retrieve the clones and apply filters if needed.
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

    .PARAMETER ImageID
        Filter based on the image id

    .PARAMETER ImageName
        Filter based on the image name

    .PARAMETER ImageLocation
        Filter based on the image location

    .PARAMETER Database
        Filter based on the database

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
        Get-DcnImage

        Get all the images

    .EXAMPLE
        Get-DcnImage -ImageName DB1_20180704220944, DB2_20180704221144

        Retrieve the images for DB1_20180704220944, DB2_20180704221144

    .EXAMPLE
        Get-DcnImage -ImageLocation "\\fileserver1\dbaclone\images\DB1_20180704220944.vhdx"

        Get all the images that are the same as the image location

    .EXAMPLE
        Get-DcnImage -Database DB1, DB2

        Get all the images that were made for databases DB1 and DB2
    #>

    [CmdLetBinding()]

    param(
        [PSCredential]$SqlCredential,
        [PSCredential]$DcnSqlCredential,
        [PSCredential]$Credential,
        [int[]]$ImageID,
        [string[]]$ImageName,
        [string[]]$ImageLocation,
        [string[]]$Database,
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
            [DbaInstanceParameter]$pdcSqlInstance = Get-PSFConfigValue -FullName dbaclone.database.Server
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
                SELECT ImageID,
                    ImageName,
                    ImageLocation,
                    SizeMB,
                    DatabaseName,
                    DatabaseTimestamp,
                    CreatedOn
                FROM dbo.Image;
            "

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
                if (($true -eq (Get-PSFConfigValue -FullName dbaclone.setup.status)) -and (Test-Path -Path "DCNJSONFolder:\")) {
                    # Get the clones
                    $results = Get-ChildItem -Path "DCNJSONFolder:\" -Filter "*images.json" | ForEach-Object { Get-Content $_.FullName | ConvertFrom-Json }
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

        # Filter database
        if ($Database) {
            $results = $results | Where-Object { $_.DatabaseName -in $Database }
        }
    }

    process {
        # Test if there are any errors
        if (Test-PSFFunctionInterrupt) { return }

        foreach ($result in $results) {

            [pscustomobject]@{
                ImageID           = $result.ImageID
                ImageName         = $result.ImageName
                ImageLocation     = $result.ImageLocation
                SizeMB            = $result.SizeMB
                DatabaseName      = $result.DatabaseName
                DatabaseTimestamp = $result.DatabaseTimestamp
                CreatedOn         = $result.CreatedOn
            }
        }
    }

    end {
        # Test if there are any errors
        if (Test-PSFFunctionInterrupt) { return }

        Write-PSFMessage -Message "Finished retrieving image(s)" -Level Verbose
    }
}

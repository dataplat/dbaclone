function Remove-PDCImage {
    <#
.SYNOPSIS
    Remove-PDCImage removes one or more images

.DESCRIPTION
    The command will remove an image from PSDatabaseClone.
    It will also remove all the clones associated with it on the hosts.

.PARAMETER ImageLocation
    Location of the image as it's saved in the database or can be seen on the file system.

.PARAMETER Credential
    Allows you to login to servers using  Windows Auth/Integrated/Trusted. To use:

    $scred = Get-Credential, then pass $scred object to the -Credential parameter.

.PARAMETER Force
    Forcefully remove the items.

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
    Remove-PDCImage -ImageLocation "\\server1\images\DB1_20180703193345.vhdx"

    Remove an image
#>
    [CmdLetBinding(SupportsShouldProcess = $true)]

    param(
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]$ImageLocation,
        [System.Management.Automation.PSCredential]
        $Credential,
        [switch]$Force,
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

        # Get the database values
        $pdcSqlInstance = Get-PSFConfigValue -FullName psdatabaseclone.database.server
        $pdcDatabase = Get-PSFConfigValue -FullName psdatabaseclone.database.name

        Write-PSFMessage -Message "Started removing database images" -Level Verbose
    }

    process {
        # Test if there are any errors
        if (Test-PSFFunctionInterrupt) { return }

        foreach ($image in $ImageLocation) {

            $query = "
                SELECT c.CloneLocation,
                        c.AccessPath,
                        c.SqlInstance,
                        c.DatabaseName,
                        h.HostName,
                        h.IPAddress,
                        h.FQDN,
                        i.ImageLocation
                FROM dbo.Image as i
                    INNER JOIN dbo.Clone AS c
                        ON c.ImageID = i.ImageID
                    INNER JOIN dbo.Host AS h
                        ON h.HostID = c.HostID
                WHERE i.ImageLocation = '$image'
                ORDER BY h.HostName;
            "

            # Try to get the neccesary info from the EasyClone database
            try {
                Write-PSFMessage -Message "Retrieving data for image '$image'" -Level Verbose
                $results = Invoke-DbaSqlQuery -SqlInstance $pdcSqlInstance -Database $pdcDatabase -Query $query -As PSObject

                # Check the results
                if ($results.Count -ge 1) {

                    # Loop through the results
                    foreach ($result in $results) {

                        # Remove the clones for the host
                        try {
                            Write-PSFMessage -Message "Removing clones for host $($result.HostName) and database $($result.DatabaseName)" -Level Verbose
                            Remove-PDCClone -HostName $result.HostName -Database $result.DatabaseName -Credential $Credential -Confirm:$false
                        }
                        catch {
                            Stop-PSFFunction -Message "Couldn't remove clones from host $($result.HostName)" -ErrorRecord $_ -Target $result -Continue
                        }
                    }
                }
                else {
                    Write-PSFMessage -Message "No clones were found created with image $image" -Level Verbose
                }
            }
            catch {
                Stop-PSFFunction -Message "Couldn't retrieve clone records for host $hst" -ErrorRecord $_  -Target $hst -Continue
            }

            # Remove the image from the file system
            try {
                if (Test-Path -Path $image -Credential $Credential) {
                    Write-PSFMessage -Message "Removing image '$image' from file system" -Level Verbose
                    $null = Remove-Item -Path $image -Credential $Credential -Force:$Force
                }
                else {
                    Write-PSFMessage -Message "Couldn't find image $image" -Level Verbose
                }
            }
            catch {
                Stop-PSFFunction -Message "Couldn't remove image '$image' from file system" -ErrorRecord $_ -Target $result
            }

            # Remove the image from the database
            try {
                $query = "DELETE FROM dbo.Image WHERE ImageLocation = '$image'"

                $null = Invoke-DbaSqlQuery -SqlInstance $pdcDatabaseServer -Database $pdcDatabaseName -Query $query
            }
            catch {
                Stop-PSFFunction -Message "Couldn't remove image '$image' from database" -ErrorRecord $_ -Target $result
            }

        } # End for each image

    } # End process

    end {
        # Test if there are any errors
        if (Test-PSFFunctionInterrupt) { return }

        Write-PSFMessage -Message "Finished removing database image(s)" -Level Verbose
    }

}
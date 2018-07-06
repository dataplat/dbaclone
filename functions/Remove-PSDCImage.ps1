function Remove-PSDCImage {
    <#
    .SYNOPSIS
        Remove-PSDCImage removes one or more images

    .DESCRIPTION
        The command will remove an image from PSDatabaseClone.
        It will also remove all the clones associated with it on the hosts.

    .PARAMETER ImageID
        Remove images based on the image id

    .PARAMETER ImageName
        Remove images based on the image name

    .PARAMETER ImageLocation
        Location of the image as it's saved in the database or can be seen on the file system.

    .PARAMETER Database
        Remove images based on the database

    .PARAMETER ExcludeDatabase
        Filter the images based on the excluded database

    .PARAMETER Credential
        Allows you to login to servers using  Windows Auth/Integrated/Trusted. To use:

        $scred = Get-Credential, then pass $scred object to the -Credential parameter.

    .PARAMETER Force
        Forcefully remove the items.

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
        Remove-PSDCImage -ImageLocation "\\server1\images\DB1_20180703193345.vhdx"

        Remove an image

    .EXAMPLE
        Get-PSDCImage -Database DB1 | Remove-PSDCImage

        Remove all images and clones based on database DB1
    #>
    [CmdLetBinding(DefaultParameterSetName = "ImageLocation", SupportsShouldProcess = $true,
        ConfirmImpact = 'High')]

    param(
        [int[]]$ImageID,
        [string[]]$ImageName,
        [parameter(ParameterSetName = "ImageLocation")]
        [string[]]$ImageLocation,
        [string[]]$Database,
        [string[]]$ExcludeDatabase,
        [System.Management.Automation.PSCredential]
        $Credential,
        [switch]$Force,
        [parameter(ValueFromPipeline = $true, ParameterSetName = "Image")]
        [object[]]$InputObject,
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

        # Get the database values
        $pdcSqlInstance = Get-PSFConfigValue -FullName psdatabaseclone.database.server
        $pdcDatabase = Get-PSFConfigValue -FullName psdatabaseclone.database.name

        Write-PSFMessage -Message "Started removing database images" -Level Verbose

        # Get all the items
        $items = Get-PSDCImage

        if ($ImageID) {
            Write-PSFMessage -Message "Filtering image ids" -Level Verbose
            $items = $items | Where-Object {$_.ImageID -in $ImageID}
        }

        if ($ImageName) {
            Write-PSFMessage -Message "Filtering image name" -Level Verbose
            $items = $items | Where-Object {$_.ImageName -in $ImageName}
        }

        if ($ImageLocation) {
            Write-PSFMessage -Message "Filtering image locations" -Level Verbose
            $items = $items | Where-Object {$_.ImageLocation -in $ImageLocation}
        }

        if ($Database) {
            Write-PSFMessage -Message "Filtering databases" -Level Verbose
            $items = $items | Where-Object {$_.DatabaseName -in $Database}
        }

        if ($ExcludeDatabase) {
            Write-PSFMessage -Message "Filtering excluded databases" -Level Verbose
            $items = $items | Where-Object {$_.DatabaseName -notin $Database}
        }

        # Append the items
        $InputObject += $items
    }

    process {
        # Test if there are any errors
        if (Test-PSFFunctionInterrupt) { return }

        # Group the objects to make it easier to go through
        $images = $InputObject | Group-Object ImageID

        foreach ($image in $images) {

            # Loop through each of the results
            foreach ($item in $image.Group) {

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
                WHERE i.ImageID = $($item.ImageID)
                ORDER BY h.HostName;
            "

                # Try to get the neccesary info from the EasyClone database
                try {
                    Write-PSFMessage -Message "Retrieving data for image '$($item.Name)'" -Level Verbose
                    $results = @()
                    $results += Invoke-DbaSqlQuery -SqlInstance $pdcSqlInstance -Database $pdcDatabase -Query $query

                    # Check the results
                    if ($results.Count -ge 1) {

                        # Loop through the results
                        foreach ($result in $results) {

                            # Remove the clones for the host
                            try {
                                Write-PSFMessage -Message "Removing clones for host $($result.HostName) and database $($result.DatabaseName)" -Level Verbose
                                Remove-PSDCClone -HostName $result.HostName -Database $result.DatabaseName -Credential $Credential -Confirm:$false
                            }
                            catch {
                                Stop-PSFFunction -Message "Couldn't remove clones from host $($result.HostName)" -ErrorRecord $_ -Target $result -Continue
                            }
                        }
                    }
                    else {
                        Write-PSFMessage -Message "No clones were found created with image $($image.Name)" -Level Verbose
                    }
                }
                catch {
                    Stop-PSFFunction -Message "Couldn't retrieve clone records for host $($result.HostName)" -ErrorRecord $_  -Target $hst -Continue
                }

                # Remove the image from the file system
                try {
                    if (Test-Path -Path $item.ImageLocation -Credential $Credential) {
                        Write-PSFMessage -Message "Removing image '$($item.ImageLocation)' from file system" -Level Verbose
                        $null = Remove-Item -Path $item.ImageLocation -Credential $Credential -Force:$Force
                    }
                    else {
                        Write-PSFMessage -Message "Couldn't find image $($item.ImageLocation)" -Level Verbose
                    }
                }
                catch {
                    Stop-PSFFunction -Message "Couldn't remove image '$($item.ImageLocation)' from file system" -ErrorRecord $_ -Target $result
                }

                # Remove the image from the database
                try {
                    $query = "DELETE FROM dbo.Image WHERE ImageID = $($item.ImageID)"

                    $null = Invoke-DbaSqlQuery -SqlInstance $pdcSqlInstance -Database $pdcDatabase -Query $query
                }
                catch {
                    Stop-PSFFunction -Message "Couldn't remove image '$($item.ImageLocation)' from database" -ErrorRecord $_ -Target $query
                }

            } # End for each item in group

        } # End for each image

    } # End process

    end {
        # Test if there are any errors
        if (Test-PSFFunctionInterrupt) { return }

        Write-PSFMessage -Message "Finished removing database image(s)" -Level Verbose
    }

}

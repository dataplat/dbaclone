function Remove-PSDCUnusedImage {
    <#
    .SYNOPSIS
        Remove-PSDCImage removes one or more images

    .DESCRIPTION
        The command will remove an image from PSDatabaseClone.
        It will also remove all the clones associated with it on the hosts.

    .PARAMETER Database
        Remove images based on the database

    .PARAMETER Keep
        The number of images to keep

    .PARAMETER PSDCSqlCredential
        Allows you to login to servers using SQL Logins as opposed to Windows Auth/Integrated/Trusted.
        This works similar as SqlCredential but is only meant for authentication to the PSDatabaseClone database server and database.

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

        Website: https://psdatabaseclone.org
        Copyright: (C) Sander Stad, sander@sqlstad.nl
        License: MIT https://opensource.org/licenses/MIT

    .LINK
        https://psdatabaseclone.org/

    .EXAMPLE
        Remove-PSDCImage -ImageLocation "\\server1\images\DB1_20180703193345.vhdx"

        Remove an image

    .EXAMPLE
        Get-PSDCImage -Database DB1 | Remove-PSDCImage

        Remove all images and clones based on database DB1
    #>
    [CmdLetBinding(DefaultParameterSetName = "ImageLocation",
        ConfirmImpact = 'High')]

    param(
        [string[]]$Database,
        [int]$Keep = 0,
        [System.Management.Automation.PSCredential]
        $PSDCSqlCredential,
        [System.Management.Automation.PSCredential]
        $Credential,
        [switch]$Force,
        [object[]]$InputObject,
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

        # Get all the items
        $items = Get-PSDCImage

        if ($Database) {
            Write-PSFMessage -Message "Filtering databases" -Level Verbose
            $items = $items | Where-Object {$_.DatabaseName -in $Database}
        }

        # Append the items
        $InputObject += $items
    }

    process {
        # Test if there are any errors
        if (Test-PSFFunctionInterrupt) { return }

        Write-PSFMessage -Message "Started removing database images" -Level Verbose

        # Group the objects to make it easier to go through
        $images = $InputObject | Group-Object ImageID

        foreach ($image in $images) {
            $clones = Get-PSDCClone -ImageID $item.ImageID
            if ($clones.Count -ge 1)
            {
                $images.Remove($image)
            }
        }

        $images = $images | Sort-Object -Property CreatedOn -Descending | Select-Object -Skip $Keep

        if ($images.Count -eq 0) {
            Stop-PSFFunction -Message "No images to remove"
        }

        foreach ($image in $images) {
            Remove-PSDCImage -ImageID $image.ImageID
        }

    } # End process

    end {
        # Test if there are any errors
        if (Test-PSFFunctionInterrupt) { return }

        Write-PSFMessage -Message "Finished removing unused database image(s)" -Level Verbose
    }

}
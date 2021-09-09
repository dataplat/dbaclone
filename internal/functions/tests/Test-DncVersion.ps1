function Test-DcnVersion {
    <#
    .SYNOPSIS
        Test the version of the current module

    .DESCRIPTION
        Test if the current version of the module is up-to-date with the PSGallery

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

        Website: https://dbaclone.org
        Copyright: (C) Sander Stad, sander@sqlstad.nl
        License: MIT https://opensource.org/licenses/MIT

    .LINK
        https://dbaclone.org/

    .EXAMPLE
        Test-DcnVersion

        Test the configuration of the module retrieving the set configurations

    #>

    [OutputType("System.Boolean")]

    [CmdLetBinding()]

    param(
        [switch]$EnableException
    )

    Write-PSFMessage -Message "Checking module version" -Level Verbose

    $currentVersion = ((Get-Module -ListAvailable dbaclone) | Sort-Object Version -Descending  | Select-Object -ExpandProperty Version -First 1).tostring()
    $latestVersion = Find-Module -Repository PSGallery -Name dbaclone | Select-Object -ExpandProperty Version

    if ($currentVersion -eq $latestVersion) {
        return $true
    }
    else {
        return $false
    }
}

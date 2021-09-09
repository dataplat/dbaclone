function Test-DcnVersion {
    <#
    .SYNOPSIS
        Test the version of the current module

    .DESCRIPTION
        Test if the current version of the module is up-to-date with the PSGallery

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

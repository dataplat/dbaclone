function Convert-PSDCLocalUncPathToLocalPath {
    <#
    .SYNOPSIS
        Convert a UNC path on a computer to a local path.

    .DESCRIPTION
        In some cases you want to convert a UNC path to a local path.
        This function will look up which path belongs to the UNC path by supplying only the UNC path

    .PARAMETER UncPath
        UNC path to convert to local path

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
        Convert-PSDCLocalUncPathToLocalPath -UncPath "\\server1\share1"

        Convert path "\\server1\share1" to a local path from server1
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$UncPath,
        [switch]$EnableException
    )

    # Create the object
    try {
        $uri = New-Object System.Uri($UncPath)
    }
    catch {
        Stop-PSFFunction -Message "Something went wrong converting the UncPath $UncPath to URI" -Target $UncPath -ErrorRecord $_
    }

    # Check if the path is a valid UNC path
    if (-not $uri.IsUnc) {
        Stop-PSFFunction -Message "The path $UncPath is not a valid UNC path" -Target $UncPath
    }

    # Get the local shares from the coputer
    $localShares = Get-SmbShare

    # Split up the unc path
    $uncArray = $uri.AbsolutePath -split '/'

    # Check if the
    if (($uncArray.Length -lt 2) -or (-not $uncArray[1])) {
        Stop-PSFFunction -Message "Could not map un path $UncPath. Make sure it consists of at least two segments i.e \\server\directory or \\server\c$)" -Target $uri
    }

    # Get the share
    $share = $localShares | Where-Object { $_.Name -eq $uncArray[1] }

    # Check if something returned
    if (!$share) {
        Stop-PSFFunction -Message "The unc path could not be mapped to a share" -Target $localShares
    }

    # Rebuild the array so we have a the same construction with folders
    $uncArray[1] = $share.Path
    $uncArray = $uncArray[1..($uncArray.Length - 1)]

    return ($uncArray -join '\') -replace '\\\\', '\'
}

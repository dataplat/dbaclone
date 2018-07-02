function Convert-PDCLocalUncPathToLocalPath {
<#
.SYNOPSIS
    Convert a UNC path on a computer to a local path.

.DESCRIPTION
    In some cases you want to convert a UNC path to a local path.
    This function will look up which path belongs to the UNC path by supplying only the UNC path

.PARAMETER UncPath
    UNC path to convert to local path

.NOTES
    Author: Sander Stad (@sqlstad, sqlstad.nl)

    Website: https://psdatabaseclone.io
    Copyright: (C) Sander Stad, sander@sqlstad.nl
    License: MIT https://opensource.org/licenses/MIT

.LINK
    https://psdatabaseclone.io/

.EXAMPLE
    Convert-PDCLocalUncPathToLocalPath -UncPath "\\server\share"

#>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$UncPath
    )

    # Create the object
    try {
        $uri = New-Object System.Uri($UncPath)
    }
    catch {
        Stop-PSFFunction -Message "Something went wrong converting the UncPath $UncPath to URI" -Target $UncPath -ErrorRecord $_
        return
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
        return
    }

    # Get the share
    $share = $localShares | Where-Object { $_.Name -eq $uncArray[1] }

    # Check if something returned
    if (!$share) {
        Stop-PSFFunction -Message "The unc path could not be mapped to a share" -Target $localShares
        return
    }

    # Rebuild the array so we have a the same construction with folders
    $uncArray[1] = $share.Path
    $uncArray = $uncArray[1..($uncArray.Length - 1)]

    return ($uncArray -join '\') -replace '\\\\', '\'
}
function Test-PSDCElevated {
    <#
    .SYNOPSIS
        Test-PSDCElevated tests if the command window is elevated

    .DESCRIPTION
        For the module to work properly the command screen needs to be elevated (Administrator mode)

    .NOTES
        Author: Sander Stad (@sqlstad, sqlstad.nl)

        Website: https://psdatabaseclone.org
        Copyright: (C) Sander Stad, sander@sqlstad.nl
        License: MIT https://opensource.org/licenses/MIT

    .LINK
        https://psdatabaseclone.org/

    .EXAMPLE
        Test-PSDCElevated

        Test if the current window is elevated
    #>

    [OutputType([bool])]

    $elevated = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    # Test the result
    if ( -not $elevated ) {
        return $false
    }
    else{
        return $true
    }
}
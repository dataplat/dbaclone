function Test-PSDCDatabaseClone {

    <#
    .SYNOPSIS
        Tests for conditions in the PSDatabaseClone module.

    .DESCRIPTION
        This helper command can evaluate various runtime conditions, such as:
		- Configuration

    .PARAMETER SetupStatus
        Setup status should be set.

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
        Test-PSDCDatabaseClone -SetupStatus

        Return true if the status if correct, if not returns false
    #>

    param(
        [switch]$SetupStatus
    )

    begin {

    }

    process {
        # Region Setup status
        if ($SetupStatus) {
            if (-not (Get-PSFConfigValue -FullName psdatabaseclone.setup.status)) {
                return $false
            }
            else {
                return $true
            }
        }

        return $true
    }

    end {

    }

}
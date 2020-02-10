function Test-PSDCDatabaseClone {

    <#
    .SYNOPSIS
        Tests for conditions in the PSDatabaseClone module.

    .DESCRIPTION
        This helper command can evaluate various runtime conditions, such as:
        - Configuration
        - Windows version

    .PARAMETER IsLocal
        Returns if the computer given is local

    .PARAMETER SetupStatus
        Setup status should be set.

    .PARAMETER WindowsVersion
        The windows version should be in the supported version list

        Windows version should be in
            - 'Microsoft Windows 10 Pro',
            - 'Microsoft Windows 10 Enterprise',
            - 'Microsoft Windows 10 Education',
            - 'Microsoft Windows Server 2008 R2 Standard',
            - 'Microsoft Windows Server 2008 R2 Enterprise',
            - 'Microsoft Windows Server 2008 R2 Datacenter'
            - 'Microsoft Windows Server 2012 R2 Standard',
            - 'Microsoft Windows Server 2012 R2 Enterprise',
            - 'Microsoft Windows Server 2012 R2 Datacenter',
            - 'Microsoft Windows Server 2016 Standard',
            - 'Microsoft Windows Server 2016 Enterprise',
            - 'Microsoft Windows Server 2016 Datacenter'
            - 'Microsoft Windows Server 2019 Datacenter'

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

    .EXAMPLE
        Test-PSDCDatabaseClone -WindowsVersion

        Return true if the windows version is supported, if not returns false
    #>

    param(
        [PSFComputer]$IsLocal,
        [switch]$SetupStatus,
        [switch]$WindowsVersion
    )

    begin {

    }

    process {
        #region Is Local
        if ($IsLocal) {
            $computer = [PsfComputer]$IsLocal

            return $computer.IsLocalhost
        }
        # endregion Is Local

        # region Setup status
        if ($SetupStatus) {
            if (-not (Get-PSFConfigValue -FullName psdatabaseclone.setup.status)) {
                return $false
            }
            else {
                return $true
            }
        }
        # endregion Setup Status

        #region Windows Version
        if ($WindowsVersion) {
            $supportedVersions = @(
                'Microsoft Windows 10 Pro',
                'Microsoft Windows 10 Enterprise',
                'Microsoft Windows 10 Education',
                'Microsoft Windows Server 2008 R2 Standard',
                'Microsoft Windows Server 2008 R2 Enterprise',
                'Microsoft Windows Server 2008 R2 Datacenter'
                'Microsoft Windows Server 2012 R2 Standard',
                'Microsoft Windows Server 2012 R2 Enterprise',
                'Microsoft Windows Server 2012 R2 Datacenter',
                'Microsoft Windows Server 2016 Standard',
                'Microsoft Windows Server 2016 Enterprise',
                'Microsoft Windows Server 2016 Datacenter'
                'Microsoft Windows Server 2019 Datacenter'
            )

            # Get the OS details
            $osDetails = Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Description, Name, OSType, Version

            $windowsEdition = ($osDetails.Caption).Replace(" Evaluation", "").Trim()

            # Check which version of windows we're dealing with
            if ($windowsEdition -notin $supportedVersions ) {
                if ($windowsEdition -like '*Windows 7*') {
                    return $false
                    #Stop-PSFFunction -Message "Module does not work on Windows 7" -Target $OSDetails -FunctionName 'Pre Import'
                }
                else {
                    #Stop-PSFFunction -Message "Unsupported version of Windows." -Target $OSDetails -FunctionName 'Pre Import'
                    return $false
                }
            }
        }
        # endregion Windows version

        return $true
    }

    end {

    }

}
function Set-DcnPermission {
    <#
    .SYNOPSIS
        New-DcnClone creates a new clone

    .DESCRIPTION
        New-DcnClone willcreate a new clone based on an image.
        The clone will be created in a certain directory, mounted and attached to a database server.

    .PARAMETER Path
        Path to set the permissions for

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
        Set-DcnPermission -Path "C:\projects\dbaclone\clone\AW2017-C1\"

        Set the permissions for the path
    #>

    [CmdLetBinding()]

    param(
        [string]$Path,
        [switch]$EnableException
    )

    begin {
        if (-not $Path) {
            Stop-PSFFunction -Message "Please enter a path"
        }
        else {
            if (-not (Test-Path -Path $Path)) {
                Stop-PSFFunction -Message "Could not enter path. Please check if the path is valid and reachable."
            }
        }
    }

    process {
        if (Test-PSFFunctionInterrupt) { return }

        $everyone = [System.Security.Principal.WellKnownSidType]::WorldSid
        $sid = New-Object System.Security.Principal.SecurityIdentifier($everyone, $Null)

        $group = New-Object System.Security.Principal.NTAccount("Everyone")

        $accessRule = New-Object System.Security.AccessControl.FilesystemAccessrule($sid, "FullControl", "Allow")
        $accessRule = New-Object System.Security.AccessControl.FilesystemAccessrule("Everyone", "FullControl", "Allow")

        foreach ($file in $(Get-ChildItem -Path "$Path" -Recurse)) {
            Write-PSFMessage -Level Verbose -Message "Setting permissions for '$($file.FullName)'"
            $acl = Get-Acl $file.Fullname

            # Add this access rule to the ACL
            $acl.SetAccessRule($accessRule)
            $acl.SetOwner($group)

            try {
                # Write the changes to the object
                Set-Acl -Path $file.Fullname -AclObject $acl
            }
            catch {
                Stop-PSFFunction -Message "Could not set permissions for '$($file.FullName)'" -Target $file -ErrorRecord $_ -Continue
            }
        }
    }
}
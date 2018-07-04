function New-PDCVhdDisk {
<#
.SYNOPSIS
    New-PDCVhdDisk creates a new VHD

.DESCRIPTION
    New-PDCVhdDisk will create a new VHD.

.PARAMETER Destination
    The destination path of the VHD

.PARAMETER Name
    The name of the VHD

.PARAMETER FileName
    The file name of the VHD

.PARAMETER Size
    The size of the VHD.

.PARAMETER FixedSize
    Set the VHD to have a fixed size or not.
    Be careful using this parameter. Fixed will make the VHD use the space assigned in -Size

.PARAMETER ReadOnly
    Set the VHD to readonly

.PARAMETER Force
    Forcefully create the neccesary items

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
    New-PDCVhdDisk -Destination C:\temp -Name Database1 -Size 1GB

    Creates a dynamic VHD in C:\Temp named Database1.vhdx with a size of 1GB

#>

    [CmdLetBinding()]

    param(
        [parameter(Mandatory = $true)]
        [string]$Destination,
        [string]$Name,
        [string]$FileName,
        [uint64]$Size = 64TB,
        [switch]$FixedSize,
        [switch]$ReadOnly,
        [switch]$Force,
        [switch]$EnableException
    )

    begin {
        # Check the destination path
        if (-not (Test-Path $Destination)) {
            try {
                Write-PSFMessage -Message "Creating destination directory $Destination" -Level Verbose
                $null = New-Item -Path $Destination -ItemType Directory -Force
            }
            catch {
                Stop-PSFFunction -Message "Couldn't create directory $Destination" -ErrorRecord $_ -Target $Destination -Continue
            }
        }

        # Check the name and file name parameters
        if (-not $Name -and -not $FileName) {
            Stop-PSFFunction -Message "Either set the Name or FileName parameter"
        }
        else {
            if (-not $FileName) {
                $FileName = "$Name.vhdx"
                Write-PSFMessage -Message "Setting file name to $FileName" -Level Verbose
            }
            elseif ($FileName) {
                if (($FileName -notlike "*.vhd") -and ($FileName -notlike "*.vhdx")) {
                    Stop-PSFFunction -Message "The filename needs to have the .vhd or .vhdx extension" -Target $FileName -Continue
                }
            }
        }

        # Set the vhd path
        if ($Destination.EndsWith("\")) {
            $vhdPath = "$Destination$FileName"
        }
        else {
            $vhdPath = "$Destination\$FileName"
        }

        Write-PSFMessage -Message "Vhd path set to $vhdPath" -Level Verbose

        # Check if the file does not yet exist
        if (Test-Path $vhdPath) {
            Stop-PSFFunction -Message "The vhd file already exists" -Continue
        }

        # Check the size of the file
        if ($Size -lt 3MB) {
            Stop-PSFFunction -Message "The size of the vhd cannot be smaller than 3MB" -Continue
        }
    }

    process {
        # Test if there are any errors
        if (Test-PSFFunctionInterrupt) { return }

        # Check if the file needs to have a fixed size
        try {
            if ($FixedSize) {
                $null = New-VHD -Path $vhdPath -SizeBytes $Size -Fixed
            }
            else {
                $null = New-VHD -Path $vhdPath -SizeBytes $Size -Dynamic
            }
        }
        catch {
            Stop-PSFFunction -Message "Something went wrong creating the vhd" -ErrorRecord $_ -Continue
        }
    }

    end {
        # Test if there are any errors
        if (Test-PSFFunctionInterrupt) { return }

        Write-PSFMessage "Finished creating vhd file" -Level Verbose
    }
}






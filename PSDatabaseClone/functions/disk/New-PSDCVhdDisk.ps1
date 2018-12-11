function New-PSDCVhdDisk {
    <#
    .SYNOPSIS
        New-PSDCVhdDisk creates a new VHD

    .DESCRIPTION
        New-PSDCVhdDisk will create a new VHD.

    .PARAMETER Destination
        The destination path of the VHD

    .PARAMETER Name
        The name of the VHD

    .PARAMETER FileName
        The file name of the VHD

    .PARAMETER VhdType
        The type of the harddisk. This can either by VHD (version 1) or VHDX (version 2)
        The default is VHDX.

    .PARAMETER Size
        The size of the VHD in MB.
        If no size is used the default will be set to the type of VHD.
        The default for VHD is 2 TB and for VHDX 64TB

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

        Website: https://psdatabaseclone.org
        Copyright: (C) Sander Stad, sander@sqlstad.nl
        License: MIT https://opensource.org/licenses/MIT

    .LINK
        https://psdatabaseclone.org/

    .EXAMPLE
        New-PSDCVhdDisk -Destination C:\temp -Name Database1 -Size 1GB

        Creates a dynamic VHD in C:\Temp named Database1.vhdx with a size of 1GB

    #>

    [CmdLetBinding(SupportsShouldProcess = $true)]
    [OutputType('System.String')]

    param(
        [parameter(Mandatory = $true)]
        [string]$Destination,
        [string]$Name,
        [string]$FileName,
        [ValidateSet('VHD', 'VHDX', 'vhd', 'vhdx')]
        [string]$VhdType,
        [uint64]$Size,
        [switch]$FixedSize,
        [switch]$ReadOnly,
        [switch]$Force,
        [switch]$EnableException
    )

    begin {
        # Check if the console is run in Administrator mode
        if ( -not (Test-PSDCElevated) ) {
            Stop-PSFFunction -Message "Module requires elevation. Please run the console in Administrator mode"
        }

        # Check the destination path
        if (-not (Test-Path $Destination)) {
            if ($PSCmdlet.ShouldProcess($Destination, "Creating destination directory")) {
                try {
                    Write-PSFMessage -Message "Creating destination directory $Destination" -Level Verbose
                    $null = New-Item -Path $Destination -ItemType Directory -Force
                }
                catch {
                    Stop-PSFFunction -Message "Couldn't create directory $Destination" -ErrorRecord $_ -Target $Destination -Continue
                }
            }
        }

        # Check the vhd type
        if (-not $VhdType) {
            Write-PSFMessage -Message "Setting vhd type to 'VHDX'" -Level Verbose
            $VhdType = 'VHDX'
        }

        # Make sure thevalue is in uppercase all th time
        $VhdType = $VhdType.ToUpper()

        # Check the size of the file
        if (-not $Size) {
            switch ($VhdType) {
                'VHD' { $Size = 2048MB }
                'VHDX' { $Size = 64TB }
            }
        }
        else {
            if ($VhdType -eq 'VHD' -and $Size -gt 2TB) {
                Stop-PSFFunction -Message "Size cannot exceed 2TB when using VHD type."
            }
            elseif ($VhdType -eq 'VHDX' -and $Size -gt 64TB) {
                Stop-PSFFunction -Message "Size cannot exceed 64TB when using VHDX type."
            }

            if ($Size -lt 3MB) {
                Stop-PSFFunction -Message "The size of the vhd cannot be smaller than 3MB" -Continue
            }
        }

        # Make sure the size in MB instead of some other version
        $Size = $Size / 1MB

        # Check the name and file name parameters
        if (-not $Name -and -not $FileName) {
            Stop-PSFFunction -Message "Either set the Name or FileName parameter"
        }
        else {
            if (-not $FileName) {
                $FileName = "$Name.$($VhdType.ToLower())"
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
            if(-not $Force){
                Stop-PSFFunction -Message "The vhd file already exists" -Continue
            }
            else{
                try{
                    Remove-Item -Path $vhdPath -Force:$Force
                }
                catch{
                    Stop-PSFFunction -Message "Could not remove VHD '$vhdPath'" -Continue -ErrorRecord $_
                }
            }
        }

        # Set the location where to save the diskpart command
        $diskpartScriptFile = Get-PSFConfigValue -FullName psdatabaseclone.diskpart.scriptfile #-Fallback "$env:APPDATA\psdatabaseclone\diskpartcommand.txt"

        if(-not (Test-Path -Path $diskpartScriptFile)){
            try{
                $null = New-Item -Path $diskpartScriptFile -ItemType File
            }
            catch{
                Stop-PSFFunction -Message "Could not create diskpart script file" -ErrorRecord $_ -Continue
            }
        }
    }

    process {
        # Test if there are any errors
        if (Test-PSFFunctionInterrupt) { return }

        if ($PSCmdlet.ShouldProcess($vhdPath, "Creating VHD")) {
            # Check if the file needs to have a fixed size
            try {
                if ($FixedSize) {
                    $command = "create vdisk file='$vhdPath' maximum=$Size type=fixed"
                }
                else {
                    $command = "create vdisk file='$vhdPath' maximum=$Size type=expandable"
                }

                # Set the content of the diskpart script file
                Set-Content -Path $diskpartScriptFile -Value $command -Force

                $script = [ScriptBlock]::Create("diskpart /s $diskpartScriptFile")
                Invoke-PSFCommand -ScriptBlock $script

            }
            catch {
                Stop-PSFFunction -Message "Something went wrong creating the vhd" -ErrorRecord $_ -Continue
            }
        }
    }

    end {
        # Clean up the script file for diskpart
        Remove-Item $diskpartScriptFile -Force

        # Test if there are any errors
        if (Test-PSFFunctionInterrupt) { return }

        Write-PSFMessage "Finished creating vhd file" -Level Verbose
    }
}






function Initialize-PSDCVhdDisk {
    <#
    .SYNOPSIS
        Initialize-PSDCVhdDisk initialized the VHD

    .DESCRIPTION
        Initialize-PSDCVhdDisk will initialize the VHD.
        It mounts the disk, creates a volume, creates the partition and sets it to active

    .PARAMETER Path
        The path to the VHD

    .PARAMETER Credential
        Allows you to use credentials for creating items in other locations To use:

        $scred = Get-Credential, then pass $scred object to the -Credential parameter.

    .PARAMETER PartitionStyle
        A partition can either be initialized as MBR or as GPT. GPT is the default.

    .PARAMETER AllocationUnitSize
        Set the allocation unit size for the disk.
        By default it's 64 KB because that's what SQL Server tends to write most of the time.

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
        Initialize-PSDCVhdDisk -Path $path

        Initialize the disk pointing to the path with all default settings

    .EXAMPLE
        Initialize-PSDCVhdDisk -Path $path -AllocationUnitSize 4KB

        Initialize the disk and format the partition with a 4Kb allocation unit size

    #>

    [CmdLetBinding(SupportsShouldProcess = $true)]

    Param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [System.Management.Automation.PSCredential]
        $Credential,
        [ValidateSet('GPT', 'MBR')]
        [string]$PartitionStyle = 'GPT',
        [int]$AllocationUnitSize = 64KB,
        [switch]$EnableException
    )

    begin {
        # Check the path to the vhd
        if (-not (Test-Path -Path $Path -Credential $Credential)) {
            Stop-PSFFunction -Message "Vhd path cannot be found" -Target $Path -Continue
        }
    }

    process {
        # Test if there are any errors
        if (Test-PSFFunctionInterrupt) { return }

        # Get all the disks
        $disks = Get-Disk | Select-Object Number, Location, OperationalStatus

        # Check if disk is already mounted
        if ($disks.Location -contains $Path) {
            Write-PSFMessage -Message "Vhd is already mounted" -Level Warning

            # retrieve the specific disk
            $disk = $disks | Where-Object Location -eq $Path
        }
        else {
            if ($PSCmdlet.ShouldProcess("Mounting disk")) {
                # Mount the vhd
                try {
                    Write-PSFMessage -Message "Mounting disk $disk" -Level Verbose

                    # Mount the disk
                    Mount-DiskImage -ImagePath $Path

                    # Get the disk
                    $disk = Get-Disk | Where-Object Location -eq $Path
                }
                catch {
                    Stop-PSFFunction -Message "Couldn't mount vhd" -Target $Path -ErrorRecord $_ -Continue
                }
            }
        }

        if ($PSCmdlet.ShouldProcess($disk, "Initializing disk")) {
            # Check if the disk is already initialized
            if ($disk.PartitionStyle -eq 'RAW') {
                try {
                    Write-PSFMessage -Message "Initializing disk $disk" -Level Verbose
                    $disk | Initialize-Disk -PartitionStyle $PartitionStyle -Confirm:$false
                }
                catch {
                    Stop-PSFFunction -Message "Couldn't initialize disk" -Target $disk -ErrorRecord $_ -Continue
                }
            }
        }

        if ($PSCmdlet.ShouldProcess($disk, "Partitioning volume")) {
            # Create the partition, set the drive letter and format the volume
            try {
                $volume = Get-Disk -Number $disk.Number | New-Partition -UseMaximumSize | Format-Volume -FileSystem NTFS -NewFileSystemLabel "PSDatabaseClone" -AllocationUnitSize $AllocationUnitSize -Confirm:$false
            }
            catch {
                # Dismount the drive
                Dismount-DiskImage -DiskImage $Path

                Stop-PSFFunction -Message "Couldn't create the partition" -Target $disk -ErrorRecord $_ -Continue
            }
        }

        # Add the results to the custom object
        [PSCustomObject]@{
            Disk      = $disk
            Partition = (Get-Partition -Disk $disk)
            Volume    = $volume
        }

    }

    end {
        # Test if there are any errors
        if (Test-PSFFunctionInterrupt) { return }

        Write-PSFMessage -Message "Finished initializing disk(s)" -Level Verbose
    }

}

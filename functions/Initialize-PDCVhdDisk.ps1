function Initialize-PDCVhdDisk {
<#
.SYNOPSIS
    Initialize-PDCVhdDisk initialized the VHD

.DESCRIPTION
    Initialize-PDCVhdDisk will initialize the VHD.
    It mounts the disk, creates a volume, creates the partition and sets it to active

.PARAMETER Path
    The path to the VHD

.PARAMETER Credential
    Allows you to use credentials for creating items in other locations To use:

    $scred = Get-Credential, then pass $scred object to the -Credential parameter.

.NOTES
    Author: Sander Stad (@sqlstad, sqlstad.nl)

    Website: https://psdatabaseclone.io
    Copyright: (C) Sander Stad, sander@sqlstad.nl
    License: MIT https://opensource.org/licenses/MIT

.LINK
    https://psdatabaseclone.io/

.EXAMPLE
    Initialize-PDCVhdDisk -Path $path

    Initialize the disk pointing to the path with all default settings

.EXAMPLE
    Initialize-PDCVhdDisk -Path $path -AllocationUnitSize 4KB

    Initialize the disk and format the partition with a 4Kb allocation unit size

#>

    [CmdLetBinding()]

    Param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [System.Management.Automation.PSCredential]
        $Credential,
        [ValidateSet('GPT', 'MBR')]
        [string]$PartitionStyle = 'GPT',
        [int]$AllocationUnitSize = 64KB
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
            $disk = $disks | Where-Object {$_.Location -eq $Path}
        }
        else {
            # Mount the vhd
            try {
                Write-PSFMessage -Message "Mounting disk $disk" -Level Verbose

                $disk = Mount-VHD -Path $Path -PassThru | Get-Disk
            }
            catch {
                Stop-PSFFunction -Message "Couldn't mount vhd" -Target $Path -ErrorRecord $_ -Continue
            }
        }

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

        # Create the partition, set the drive letter and format the volume
        try {
            $volume = Get-Disk -Number $disk.DiskNumber | New-Partition -UseMaximumSize | Format-Volume -FileSystem NTFS -NewFileSystemLabel "PSDatabaseClone" -AllocationUnitSize $AllocationUnitSize -Confirm:$false
        }
        catch {
            # Dismount the drive
            Dismount-VHD -Path $Path

            Stop-PSFFunction -Message "Couldn't create the partition" -Target $disk -ErrorRecord $_ -Continue
        }

        # Add the results to the custom object
        [PSCustomObject]@{
            Disk       = $disk
            Partition  = (Get-Partition -Disk $disk)
            Volume     = $volume
        }

    }

    end {
        # Test if there are any errors
        if (Test-PSFFunctionInterrupt) { return }

        Write-PSFMessage -Message "Finished initializing disk(s)" -Level Verbose
    }

}
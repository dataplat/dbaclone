$commandname = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
. "$PSScriptRoot\..\..\..\..\build\appveyor-constants.ps1"
#. "$PSScriptRoot\..\constants.ps1"

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        [object[]]$params = (Get-ChildItem Function:\Initialize-PSDCVhdDisk).Parameters.Keys
        $knownParameters = 'Path', 'Credential', 'PartitionStyle', 'AllocationUnitSize', 'EnableException'
        It "Should contain our specific parameters" {
            ( (Compare-Object -ReferenceObject $knownParameters -DifferenceObject $params -IncludeEqual | Where-Object SideIndicator -eq "==").Count ) | Should Be $knownParameters.Count
        }
    }
}

<# Describe "$commandname Unit Tests" {

    BeforeAll {
        New-PSDCVhdDisk -Destination $imagefolder -Name "TestImage1" -Size 1GB
        New-PSDCVhdDisk -Destination $imagefolder -Name "TestImage2"
    }

    Context "Initialize disk with MBR" {
        $disk = Initialize-PSDCVhdDisk -Path "$($imagefolder)\TestImage1.vhdx" -PartitionStyle MBR

        It "Disk Should be online" {
            $disk.Disk.IsOffline | Should Be $false
        }

        It "Disk Partition style should be RAW" {
            $disk.Disk.PartitionStyle | Should Be 'RAW'
        }

        It "Disk Partition should be online" {
            $disk.Partition.IsOffline | Should Be $false
        }

        It "Disk Partition number should be 1" {
            $disk.Partition.PartitionNumber | Should Be 1
        }

        It "Disk Volume file system should be NTFS" {
            $disk.Volume.FileSystem | Should Be 'NTFS'
        }

        It "Disk Volume size should be 1GB" {
            '{0:N0}' -f ($disk.Volume.Size / 1GB) | Should Be 1
        }


    }

    Context "Initialize disk with GPT" {
        $disk = Initialize-PSDCVhdDisk -Path "$($imagefolder)\TestImage2.vhdx" -PartitionStyle GPT

        It "Disk Should be online" {
            $disk.Disk.IsOffline | Should Be $false
        }

        It "Disk Partition style should be RAW" {
            $disk.Disk.PartitionStyle | Should Be 'RAW'
        }

        It "Disk Volume file system should be NTFS" {
            $disk.Volume.FileSystem | Should Be 'NTFS'
        }

        It "Disk Volume size should be 64TB " {
            '{0:N0}' -f ($disk.Volume.Size / 1TB) | Should Be 64
        }
    }

    AfterAll {
        Dismount-DiskImage -ImagePath "$($imagefolder)\TestImage1.vhdx"
        Dismount-DiskImage -ImagePath "$($imagefolder)\TestImage2.vhdx"

        $null = Remove-Item -Path "$($imagefolder)\TestImage1.vhdx" -Force
        $null = Remove-Item -Path "$($imagefolder)\TestImage2.vhdx" -Force
    }

} #>
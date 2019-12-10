$commandname = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
. "$PSScriptRoot\..\constants.ps1"
#. "$PSScriptRoot\..\constants.ps1"

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        [object[]]$params = (Get-ChildItem Function:\New-PSDCVhdDisk).Parameters.Keys
        $knownParameters = 'Destination', 'Name', 'FileName', 'VhdType', 'Size', 'FixedSize', 'ReadOnly', 'Force', 'EnableException'
        It "Should contain our specific parameters" {
            ( (Compare-Object -ReferenceObject $knownParameters -DifferenceObject $params -IncludeEqual | Where-Object SideIndicator -eq "==").Count ) | Should Be $knownParameters.Count
        }
    }
}

<# Describe "$commandname Unit Tests" {
    Context "Create new VHD with defaults" {
        # Create the vhd
        New-PSDCVhdDisk -Destination $imagefolder -Name TestImage1

        It "[$($imagefolder)\TestImage1.vhdx] Should exist" {
            Test-Path -Path "$($imagefolder)\TestImage1.vhdx" | Should Be $true
        }

    }

    Context "Create new VHD with file name" {
        # Create the vhd
        New-PSDCVhdDisk -Destination $imagefolder -FileName "TestImage2.vhdx"

        It "[$($imagefolder)\TestImage2.vhdx] Should exist" {
            Test-Path -Path "$($imagefolder)\TestImage2.vhdx" | Should Be $true
        }

    }

    Context "Create VHDs with different types" {
        New-PSDCVhdDisk -Destination $imagefolder -Name "TestImage3" -VhdType VHD

        It "[$($imagefolder)\TestImage3.vhd] Should exist" {
            Test-Path -Path "$($imagefolder)\TestImage3.vhd" | Should Be $true
        }
    }

    Context "Create VHDs specific size" {
        New-PSDCVhdDisk -Destination $imagefolder -Name "TestImage4" -VhdType VHD -FixedSize -Size 10MB

        It "[$($imagefolder)\TestImage4.vhd] Should exist" {
            Test-Path -Path "$($imagefolder)\TestImage4.vhd" | Should Be $true
        }

        It "[$($imagefolder)\TestImage4.vhd] Should be 10 MB" {
            '{0:N0}' -f ((Get-Item "$($imagefolder)\TestImage4.vhd").Length / 1MB) | Should Be 10
        }
    }

    AfterAll {
        Remove-Item -Path "$($imagefolder)\TestImage1.vhdx"
        Remove-Item -Path "$($imagefolder)\TestImage2.vhdx"
        Remove-Item -Path "$($imagefolder)\TestImage3.vhd"
        Remove-Item -Path "$($imagefolder)\TestImage4.vhd"
    }

} #>
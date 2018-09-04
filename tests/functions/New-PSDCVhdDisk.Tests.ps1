$commandname = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
. "$PSScriptRoot\..\constants.ps1"

Describe "$commandname Unit Tests" {
    Context "Create new VHD with defaults" {
        # Create the vhd
        New-PSDCVhdDisk -Destination $script:imagefolder -Name TestImage1

        It "[$($script:imagefolder)\TestImage1.vhdx] Should exist" {
            Test-Path -Path "$($script:imagefolder)\TestImage1.vhdx" | Should Be $true
        }

    }

    Context "Create new VHD with file name" {
        # Create the vhd
        New-PSDCVhdDisk -Destination $script:imagefolder -FileName "TestImage2.vhdx"

        It "[$($script:imagefolder)\TestImage2.vhdx] Should exist" {
            Test-Path -Path "$($script:imagefolder)\TestImage2.vhdx" | Should Be $true
        }

    }

    Context "Create VHDs with different types" {
        New-PSDCVhdDisk -Destination $script:imagefolder -Name "TestImage3" -VhdType VHD

        It "[$($script:imagefolder)\TestImage3.vhd] Should exist" {
            Test-Path -Path "$($script:imagefolder)\TestImage3.vhd" | Should Be $true
        }
    }

    Context "Create VHDs specific size" {
        New-PSDCVhdDisk -Destination $script:imagefolder -Name "TestImage4" -VhdType VHD -FixedSize -Size 10MB

        It "[$($script:imagefolder)\TestImage4.vhd] Should exist" {
            Test-Path -Path "$($script:imagefolder)\TestImage4.vhd" | Should Be $true
        }

        It "[$($script:imagefolder)\TestImage4.vhd] Should be 10 MB" {
            '{0:N0}' -f ((Get-Item "$($script:imagefolder)\TestImage4.vhd").Length / 1MB) | Should Be 10
        }
    }

    AfterAll {
        Remove-Item -Path "$($script:imagefolder)\TestImage1.vhdx"
        Remove-Item -Path "$($script:imagefolder)\TestImage2.vhdx"
        Remove-Item -Path "$($script:imagefolder)\TestImage3.vhd"
        Remove-Item -Path "$($script:imagefolder)\TestImage4.vhd"
    }

}
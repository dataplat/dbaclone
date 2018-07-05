$moduleRoot = (Resolve-Path "$PSScriptRoot\..\..").Path
$commandname = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
$rootPath = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

. "$rootPath\tests\constants.ps1"

Describe "$commandname Unit Tests" {

    BeforeAll {
        # Get a random value for the database name
        $random = Get-Random

        $name = "Test_VHD_$($random)"
        $destination = "$moduleRoot\tests"
        $path = "$destination\$name.vhdx"
    }

    Context "Create VHD with -FileName parameter" {
        $null = New-PDCVhdDisk -Destination $destination -FileName "$name.vhdx"

        It "Should be true" {
            (Test-Path -Path $path) | Should Be $true
        }

        Remove-Item -Path $path -Force
    }

    Context "Create VHD with -Name parameter" {
        $null = New-PDCVhdDisk -Destination $destination -Name $name

        It "Should be true" {
            (Test-Path -Path $path) | Should Be $true

        }

        Remove-Item -Path $path -Force
    }

}

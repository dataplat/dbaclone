$commandname = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
$rootPath = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

Write-Host -Object "Running $PSCommandpath" -ForegroundColor Cyan

. "$rootPath\tests\constants.ps1"

Describe "$commandname Unit Tests" {

    BeforeAll {
        # Get a random value for the database name
        $random = Get-Random

        $filename = "Test_VHD_$($random).vhdx"
        $name = "Test_VHD_$($random)"
        $destination = "$rootPath\tests"
        $path = "$destination\$filename"
    }

    Context "Create VHD with file name" {
        It -Skip "Should be successful" {
            $null = New-PDCVhdDisk -Destination $destination -FileName "$name.vhdx"

            (Test-Path -Path $path) | Should -Be $true
        }

        Remove-Item -Path $path -Force
    }

    Context "Create VHD with name" {
        It -Skip "Should be successful" {
            $null = New-PDCVhdDisk -Destination $destination -Name $name

            (Test-Path -Path $path) | Should -Be $true

        }

        Remove-Item -Path $path -Force
    }

}

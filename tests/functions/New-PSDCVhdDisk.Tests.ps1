$moduleRoot = (Resolve-Path "$PSScriptRoot\..\..").Path
$commandname = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
$rootPath = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

. "$rootPath\tests\constants.ps1"

Describe "$commandname Unit Tests" {

    BeforeAll {
        # Get a random value for the database name
        $random = Get-Random
        $destination = $script:imagefolder
        $name = "Test_VHD_$($random)"
        $path = "$destination\$name.vhdx"
    }

    Context "Create VHD with -FileName parameter" {
        $null = New-PSDCVhdDisk -Destination $destination -FileName "$name.vhdx" #-ErrorAction SilentlyContinue

        It "Should be true" {
            (Test-Path -Path $path) | Should Be $true
        }

        Remove-Item -Path $path -Force
    }

    Context "Create VHD with -Name parameter" {
        $null = New-PSDCVhdDisk -Destination $destination -Name $name #-ErrorAction SilentlyContinue

        It "Should be true" {
            (Test-Path -Path $path) | Should Be $true

        }

        Remove-Item -Path $path -Force
    }

}

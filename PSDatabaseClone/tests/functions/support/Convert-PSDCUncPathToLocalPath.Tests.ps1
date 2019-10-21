$commandname = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
. "$PSScriptRoot\..\constants.ps1"
#. "$PSScriptRoot\..\constants.ps1"

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        [object[]]$params = (Get-ChildItem Function:\Convert-PSDCUncPathToLocalPath).Parameters.Keys
        $knownParameters = 'UncPath', 'EnableException'
        It "Should contain our specific parameters" {
            ( (Compare-Object -ReferenceObject $knownParameters -DifferenceObject $params -IncludeEqual | Where-Object SideIndicator -eq "==").Count ) | Should Be $knownParameters.Count
        }
    }
}

Describe "$CommandName Integration Tests" -Tag "IntegrationTests" {

    BeforeAll {
        if (-not (Test-Path -Path $script:workingfolder)) {
            New-Item -Path $script:workingfolder -ItemType Directory
        }

        if (-not (Get-SmbShare -Name $script:psdcshare -ErrorAction SilentlyContinue)) {
            New-SMBShare -Name $script:psdcshare -Path $script:workingfolder -FullAccess Everyone
        }

        $shares = Get-SmbShare
    }

    Context "Convert UNC to local path" {
        It "Share should exist" {
            $shares.Name | Should -Contain $script:psdcshare
        }

        $result = Convert-PSDCUncPathToLocalPath -UncPath "\\127.0.0.1\$($script:psdcshare)"

        It "Result should be the same as local path" {
            $result | Should -Be $script:workingfolder
        }
    }

    AfterAll {
        if (Test-Path -Path $script:workingfolder) {
            Remove-Item -Path $script:workingfolder -Confirm:$false -Force -Recurse
        }
    }

}
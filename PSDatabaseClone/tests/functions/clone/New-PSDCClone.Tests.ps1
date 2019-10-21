$commandname = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
. "$PSScriptRoot\..\..\..\..\build\appveyor-constants.ps1"
#. "$PSScriptRoot\..\constants.ps1"

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        [object[]]$params = (Get-ChildItem Function:\New-PSDCClone).Parameters.Keys
        $knownParameters = 'SqlInstance', 'SqlCredential', 'PSDCSqlCredential', 'Credential', 'ParentVhd', 'Destination', 'CloneName', 'Database', 'LatestImage', 'Disabled', 'Force', 'EnableException'
        It "Should contain our specific parameters" {
            ( (Compare-Object -ReferenceObject $knownParameters -DifferenceObject $params -IncludeEqual | Where-Object SideIndicator -eq "==").Count ) | Should Be $knownParameters.Count
        }
    }
}
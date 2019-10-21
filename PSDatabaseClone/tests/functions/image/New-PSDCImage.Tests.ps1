$commandname = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
. "$PSScriptRoot\..\constants.ps1"
#. "$PSScriptRoot\..\constants.ps1"

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        [object[]]$params = (Get-ChildItem Function:\New-PSDCImage).Parameters.Keys
        $knownParameters = 'SourceSqlInstance', 'SourceSqlCredential', 'SourceCredential', 'DestinationSqlInstance', 'DestinationSqlCredential', 'DestinationCredential', 'PSDCSqlCredential', 'Database', 'ImageNetworkPath', 'ImageLocalPath', 'VhdType', 'CreateFullBackup', 'UseLastFullBackup', 'CopyOnlyBackup', 'MaskingFile', 'Force', 'EnableException'
        It "Should contain our specific parameters" {
            ( (Compare-Object -ReferenceObject $knownParameters -DifferenceObject $params -IncludeEqual | Where-Object SideIndicator -eq "==").Count ) | Should Be $knownParameters.Count
        }
    }
}

<# Describe "$commandname Unit Tests" {

    BeforeAll {
        # get the databases
        $databases = Get-DbaDatabase -SqlInstance localhost | Select-Object Name

        # Create database if it doesn't exist
        if ($databases.Name -notcontains 'DB1') {
            # Create the database
            Invoke-DbaQuery -SqlInstance localhost -Database master -Query "CREATE DATABASE [DB1]"
        }
    }

    Context "Create image with defaults and a new backup" {
        $image = New-PSDCImage -SourceSqlInstance localhost -DestinationSqlInstance localhost -ImageNetworkPath "\\localhost\C$\projects\" -Database DB1 -CreateFullBackup -CopyOnlyBackup -EnableException

        It "Image object cannot be null" {
            $image | Should Not Be $null
        }

        It "Image Path Should exist" {
            Test-Path -Path $image.ImageLocation | Should Be $true
        }

        $null = Remove-Item -Path $image.ImageLocation -Force
    }

    Context "Create image with defaults and an existing backup" {
        # Create the backup
        Backup-DbaDatabase -SqlInstance localhost -Database DB1

        # Create the image with the last backup
        $image = New-PSDCImage -SourceSqlInstance localhost -DestinationSqlInstance localhost -ImageNetworkPath "\\localhost\C$\projects\" -Database DB1 -UseLastFullBackup

        It "Image object cannot be null" {
            $image | Should Not Be $null
        }

        It "Image Path Should exist" {
            Test-Path -Path $image.ImageLocation | Should Be $true
        }

        $null = Remove-Item -Path $image.ImageLocation -Force
    }

} #>
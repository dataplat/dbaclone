$commandname = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
. "$PSScriptRoot\..\constants.ps1"

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        [object[]]$params = (Get-ChildItem Function:\New-PSDCImage).Parameters.Keys
        $knownParameters = 'SourceSqlInstance', 'SourceSqlCredential', 'SourceCredential', 'DestinationSqlInstance', 'DestinationSqlCredential', 'DestinationCredential', 'PSDCSqlCredential', 'Database', 'ImageNetworkPath', 'ImageLocalPath', 'VhdType', 'CreateFullBackup', 'UseLastFullBackup', 'CopyOnlyBackup', 'MaskingFile', 'Force', 'EnableException'
        It "Should contain our specific parameters" {
            ( (Compare-Object -ReferenceObject $knownParameters -DifferenceObject $params -IncludeEqual | Where-Object SideIndicator -eq "==").Count ) | Should Be $knownParameters.Count
        }
    }
}

Describe "$CommandName Integration Tests" -Tag "IntegrationTests" {

    BeforeAll {
        if (-not (Test-Path -Path $script:imagefolder)) {
            New-Item -Path $script:imagefolder -ItemType Directory
        }

        $sourceServer = Connect-DbaInstance -SqlInstance $script:sourcesqlinstance

        if ($sourceServer.Databases.Name -notcontains $script:database) {
            $query = "CREATE DATABASE $($script:database)"
            $sourceServer.Query($query)

            Invoke-DbaQuery -SqlInstance $script:sourcesqlinstance -Database $script:database -File "$($PSScriptRoot)\..\database.sql"
        }

        $null = Set-PSDCConfiguration -InformationStore File -Path $script:workingfolder -Force -EnableException

        if (-not (Get-SmbShare -Name $script:psdcshare -ErrorAction SilentlyContinue)) {
            New-SMBShare -Name $script:psdcshare -Path $script:workingfolder -FullAccess Everyone
        }
    }

    Context "Create an image with full backup" {
        $destServer = Connect-DbaInstance -SqlInstance $script:destinationsqlinstance

        $params = @{
            SourceSqlInstance      = $script:sourcesqlinstance
            DestinationSqlInstance = $script:destinationsqlinstance
            Database               = $script:database
            ImageNetworkPath       = "\\127.0.0.1\$($script:psdcshare)\$($script:images)"
            CreateFullBackup       = $true
        }

        $image = New-PSDCImage @params

        It "Image object cannot be null" {
            $image | Should -Not -Be $null
        }

        It "Image path should exist" {
            Test-Path -Path $image.ImageLocation | Should -Be $true
        }

        $null = Remove-Item -Path $image.ImageLocation -Force
    }

    Context "Create image with defaults and an existing backup" {
        # Create the backup
        Backup-DbaDatabase -SqlInstance $script:sourcesqlinstance -Database $script:database

        # Create the image with the last backup
        $params = @{
            SourceSqlInstance      = $script:sourcesqlinstance
            DestinationSqlInstance = $script:destinationsqlinstance
            Database               = $script:database
            ImageNetworkPath       = "\\127.0.0.1\$($script:psdcshare)\$($script:images)"
            UseLastFullBackup      = $true
        }

        $image = New-PSDCImage @params

        It "Image object cannot be null" {
            $image | Should -Not -Be $null
        }

        It "Image Path Should exist" {
            Test-Path -Path $image.ImageLocation | Should -Be $true
        }

        $null = Remove-Item -Path $image.ImageLocation -Force
    }

    AfterAll {
        if ($sourceServer.Databases.Name -contains $script:database) {
            $null = Remove-DbaDatabase -SqlInstance $script:sourcesqlinstance -Database $script:database -Confirm:$false
        }

        if ($destServer.Databases.Name -contains $script:database) {
            $null = Remove-DbaDatabase -SqlInstance $script:destinationsqlinstance -Database $script:database -Confirm:$false
        }

        if ((Get-SmbShare -Name $script:psdcshare -ErrorAction SilentlyContinue)) {
            Remove-SmbShare -Name $script:psdcshare -Confirm:$false
        }
    }

}
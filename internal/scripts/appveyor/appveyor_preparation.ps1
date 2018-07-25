Add-AppveyorTest -Name "appveyor.prep" -Framework NUnit -FileName "appveyor.prep.ps1" -Outcome Running
$sw = [system.diagnostics.stopwatch]::startNew()

# Get PSScriptAnalyzer (to check warnings)
Write-Host -Object "appveyor.prep: Install PSScriptAnalyzer" -ForegroundColor DarkGreen
Install-Module -Name PSScriptAnalyzer -Force -SkipPublisherCheck | Out-Null

# Get Pester (to run tests)
Write-Host -Object "appveyor.prep: Install Pester" -ForegroundColor DarkGreen
choco install pester | Out-Null

# Get dbatools
Write-Host -Object "appveyor.prep: Install dbatools" -ForegroundColor DarkGreen
Install-Module -Name dbatools | Out-Null

# Get PSFramework
Write-Host -Object "appveyor.prep: Install PSFramework" -ForegroundColor DarkGreen
Install-Module -Name PSFramework | Out-Null

# Get Hyper-V-PowerShell
Write-Host -Object "appveyor.prep: Install Hyper-V-PowerShell" -ForegroundColor DarkGreen
Install-WindowsFeature -Name Hyper-V-PowerShell

# Creating config files
Write-Host -Object "appveyor.prep: Creating configurations files" -ForegroundColor DarkGreen
$configPath = "c:\projects\config"

$null = New-Item -Path "$configPath\hosts.json" -Force:$Force
$null = New-Item -Path "$configPath\images.json" -Force:$Force
$null = New-Item -Path "$configPath\clones.json" -Force:$Force

# Setting configurations
Write-Host -Object "appveyor.prep: Setting configurations" -ForegroundColor DarkGreen
Set-PSFConfig -Module PSDatabaseClone -Name setup.status -Value $true -Validation bool
Set-PSFConfig -Module PSDatabaseClone -Name informationstore.mode -Value 'File'
Set-PSFConfig -Module PSDatabaseClone -Name informationstore.path -Value "$configPath" -Validation string

# Registering configurations
Write-Host -Object "appveyor.prep: Registering configurations" -ForegroundColor DarkGreen
Get-PSFConfig -FullName psdatabaseclone.setup.status | Register-PSFConfig -Scope SystemDefault
Get-PSFConfig -FullName psdatabaseclone.informationstore.mode | Register-PSFConfig -Scope SystemDefault
Get-PSFConfig -FullName psdatabaseclone.informationstore.path | Register-PSFConfig -Scope SystemDefault

$sw.Stop()
Update-AppveyorTest -Name "appveyor.prep" -Framework NUnit -FileName "appveyor.prep.ps1" -Outcome Passed -Duration $sw.ElapsedMilliseconds
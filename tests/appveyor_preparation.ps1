Add-AppveyorTest -Name "appveyor.prep" -Framework NUnit -FileName "appveyor.prep.ps1" -Outcome Running
$sw = [system.diagnostics.stopwatch]::startNew()

#Get PSScriptAnalyzer (to check warnings)
Write-Host -Object "appveyor.prep: Install PSScriptAnalyzer" -ForegroundColor DarkGreen
Install-Module -Name PSScriptAnalyzer -Force -SkipPublisherCheck | Out-Null

#Get Pester (to run tests)
Write-Host -Object "appveyor.prep: Install Pester" -ForegroundColor DarkGreen
choco install pester | Out-Null

#Get dbatools
Write-Host -Object "appveyor.prep: Install dbatools" -ForegroundColor DarkGreen
Install-Module -Name dbatools | Out-Null

#Get PSFramework
Write-Host -Object "appveyor.prep: Install PSFramework" -ForegroundColor DarkGreen
Install-Module -Name PSFramework | Out-Null

#$osDetails = Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Description, Name, OSType, Version
#Write-Host $osDetails

# Installing Hyper-V
Write-Host -Object "appveyor.prep: Install Hyper-V"
Install-WindowsFeature -Name Hyper-V

Write-Host -Object "appveyor.prep: Install Hyper-V PowerShell module"
Install-WindowsFeature -Name Install-WindowsFeature -Name Hyper-V-PowerShell

$sw.Stop()
Update-AppveyorTest -Name "appveyor.prep" -Framework NUnit -FileName "appveyor.prep.ps1" -Outcome Passed -Duration $sw.ElapsedMilliseconds
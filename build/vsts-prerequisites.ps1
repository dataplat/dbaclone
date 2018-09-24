Write-Host "Installing Pester" -ForegroundColor Cyan
Install-Module Pester -Force -SkipPublisherCheck
Write-Host "Installing PSFramework" -ForegroundColor Cyan
Install-Module PSFramework -Force -SkipPublisherCheck
Write-Host "Installing dbatools" -ForegroundColor Cyan
Install-Module dbatools -Force -SkipPublisherCheck

# Importing constants
$rootPath = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. "$rootPath\build\PSDatabaseClone\PSDatabaseClone\tests\constants.ps1"

# Creating folder
Write-Host -Object "Creating image and clone directories" -ForegroundColor Cyan
if (-not (Test-Path -Path $script:workingfolder)) {
    $null = New-Item -Path $script:workingfolder -ItemType Directory -Force
}
if (-not (Test-Path -Path $script:imagefolder)) {
    $null = New-Item -Path $script:imagefolder -ItemType Directory -Force
}
if (-not (Test-Path -Path $script:clonefolder)) {
    $null = New-Item -Path $script:clonefolder -ItemType Directory -Force
}
if (-not (Test-Path -Path $script:jsonfolder)) {
    $null = New-Item -Path $script:jsonfolder -ItemType Directory -Force
}

# Set permissions on folders
$accessRule = New-Object System.Security.AccessControl.FilesystemAccessrule("Everyone", "FullControl", "Allow")
$acl = Get-Acl $script:imagefolder
# Add this access rule to the ACL
$acl.SetAccessRule($accessRule)
# Write the changes to the object
Set-Acl -Path $script:imagefolder -AclObject $acl

# Creating config files
Write-Host "Creating configurations files" -ForegroundColor Cyan

$null = New-Item -Path "$($script:jsonfolder)\hosts.json" -Force:$Force
$null = New-Item -Path "$($script:jsonfolder)\images.json" -Force:$Force
$null = New-Item -Path "$($script:jsonfolder)\clones.json" -Force:$Force

# Setting configurations
Write-Host "Setting configurations" -ForegroundColor Cyan
Set-PSFConfig -Module PSDatabaseClone -Name setup.status -Value $true -Validation bool
Set-PSFConfig -Module PSDatabaseClone -Name informationstore.mode -Value 'File'
Set-PSFConfig -Module PSDatabaseClone -Name informationstore.path -Value "$($script:jsonfolder)" -Validation string
Set-PSFConfig -Module psdatabaseclone -Name diskpart.scriptfile -Value $script:workingfolder

# Registering configurations
Write-Host -Object "appveyor.prep: Registering configurations" -ForegroundColor Cyan
Get-PSFConfig -FullName psdatabaseclone.setup.status | Register-PSFConfig -Scope SystemDefault
Get-PSFConfig -FullName psdatabaseclone.informationstore.mode | Register-PSFConfig -Scope SystemDefault
Get-PSFConfig -FullName psdatabaseclone.informationstore.path | Register-PSFConfig -Scope SystemDefault
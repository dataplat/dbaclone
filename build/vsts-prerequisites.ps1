Write-Host "Installing Pester" -ForegroundColor Cyan
Install-Module Pester -Force -SkipPublisherCheck
Write-Host "Installing PSFramework" -ForegroundColor Cyan
Install-Module PSFramework -Force -SkipPublisherCheck
Write-Host "Installing dbatools" -ForegroundColor Cyan
Install-Module dbatools -Force -SkipPublisherCheck


. "$($publishDir.FullName)\build\vsts-constants.ps1"

# Creating folder
Write-Host -Object "Creating image and clone directories" -ForegroundColor Cyan
if (-not (Test-Path -Path $workingfolder)) {
    $null = New-Item -Path $workingfolder -ItemType Directory -Force
}
if (-not (Test-Path -Path $imagefolder)) {
    $null = New-Item -Path $imagefolder -ItemType Directory -Force
}
if (-not (Test-Path -Path $clonefolder)) {
    $null = New-Item -Path $clonefolder -ItemType Directory -Force
}
if (-not (Test-Path -Path $jsonfolder)) {
    $null = New-Item -Path $jsonfolder -ItemType Directory -Force
}

# Set permissions on folders
$accessRule = New-Object System.Security.AccessControl.FilesystemAccessrule("Everyone", "FullControl", "Allow")
$acl = Get-Acl $imagefolder
# Add this access rule to the ACL
$acl.SetAccessRule($accessRule)
# Write the changes to the object
Set-Acl -Path $imagefolder -AclObject $acl

# Creating config files
Write-Host "Creating configurations files" -ForegroundColor Cyan

$null = New-Item -Path "$($jsonfolder)\hosts.json" -Force:$Force
$null = New-Item -Path "$($jsonfolder)\images.json" -Force:$Force
$null = New-Item -Path "$($jsonfolder)\clones.json" -Force:$Force

# Setting configurations
Write-Host "Setting configurations" -ForegroundColor Cyan
Set-PSFConfig -Module PSDatabaseClone -Name setup.status -Value $true -Validation bool
Set-PSFConfig -Module PSDatabaseClone -Name informationstore.mode -Value 'File'
Set-PSFConfig -Module PSDatabaseClone -Name informationstore.path -Value "$($jsonfolder)" -Validation string
Set-PSFConfig -Module psdatabaseclone -Name diskpart.scriptfile -Value $workingfolder

# Registering configurations
Write-Host -Object "appveyor.prep: Registering configurations" -ForegroundColor Cyan
Get-PSFConfig -FullName psdatabaseclone.setup.status | Register-PSFConfig -Scope SystemDefault
Get-PSFConfig -FullName psdatabaseclone.informationstore.mode | Register-PSFConfig -Scope SystemDefault
Get-PSFConfig -FullName psdatabaseclone.informationstore.path | Register-PSFConfig -Scope SystemDefault
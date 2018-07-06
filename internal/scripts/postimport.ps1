# Add all things you want to run after importing the main code

# Load Configurations
foreach ($file in (Get-ChildItem "$ModuleRoot\internal\configurations\*.ps1" -ErrorAction Ignore)) {
    . Import-ModuleFile -Path $file.FullName
}

# Load Tab Expansion
foreach ($file in (Get-ChildItem "$ModuleRoot\internal\tepp\*.tepp.ps1" -ErrorAction Ignore)) {
    . Import-ModuleFile -Path $file.FullName
}

# Load Tab Expansion Assignment
. Import-ModuleFile -Path "$ModuleRoot\internal\tepp\assignment.ps1"

# Load License
. Import-ModuleFile -Path "$ModuleRoot\internal\scripts\license.ps1"

# Check if the configuration has been set
$server = Get-PSFConfigValue psdatabaseclone.database.server
$database = Get-PSFConfigValue psdatabaseclone.database.name

if (($server -eq $null) -or ($database -eq $null)) {
    Write-PSFMessage -Message "The module is not yet configured. Please run Set-PdcConfiguration to make the neccesary changes" -Level Warning
}

$TypeAliasTable = @{
    PSDCClone = "PSDatabaseClone.Parameter.Clone"
    PSDCImage = "PSDatabaseClone.Parameter.Image"
}

Set-PSFTypeAlias -Mapping $TypeAliasTable

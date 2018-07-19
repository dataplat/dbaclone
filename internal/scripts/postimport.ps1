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

# Check if the setup has run successfully
if(-not (Get-PSFConfigValue -FullName psdatabaseclone.setup.status -Fallback $false)){
    Write-PSFMessage -Message "Setup for the module has not yet run. Starting" -Level Host

    Set-PSDCConfiguration -InputPrompt
}

# Check if the configuration has been set
if (-not (Get-PSFConfigValue -FullName psdatabaseclone.setup.status)) {
    Write-PSFMessage -Message "The module is not yet configured. Please run Set-PSDCConfiguration to make the neccesary changes" -Level Warning
}

# Check the information mode
if((Get-PSFConfigValue -FullName psdatabaseclone.informationstore.mode) -eq 'File'){
    # Get the json file
    $jsonFolder = Get-PSFConfigValue -FullName psdatabaseclone.informationstore.path

    # Create a PS Drive
    if (-not [bool](Get-PSDrive -Name PSDCJSONFolder -Scope Script)) {
        try {
            $null = New-PSDrive -Name PSDCJSONFolder -Root $jsonFolder -Credential $Credential -PSProvider FileSystem -Scope Script
        }
        catch {
            Stop-PSFFunction -Message "Couldn't create PS Drive" -Target $jsonFolder -ErrorRecord $_
        }
    }
}

# Import the types
$TypeAliasTable = @{
    PSDCClone = "PSDatabaseClone.Parameter.Clone"
    PSDCImage = "PSDatabaseClone.Parameter.Image"
}

Set-PSFTypeAlias -Mapping $TypeAliasTable

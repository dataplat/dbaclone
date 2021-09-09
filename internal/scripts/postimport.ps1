# Add all things you want to run after importing the main code

# Load Configurations
foreach ($file in (Get-ChildItem "$($script:ModuleRoot)\internal\configurations\*.ps1" -ErrorAction Ignore)) {
	. Import-ModuleFile -Path $file.FullName
}

# Load Scriptblocks
foreach ($file in (Get-ChildItem "$($script:ModuleRoot)\internal\scriptblocks\*.ps1" -ErrorAction Ignore)) {
	. Import-ModuleFile -Path $file.FullName
}

# Load Tab Expansion
foreach ($file in (Get-ChildItem "$($script:ModuleRoot)\internal\tepp\*.tepp.ps1" -ErrorAction Ignore)) {
	. Import-ModuleFile -Path $file.FullName
}

# Load Tab Expansion Assignment
. Import-ModuleFile -Path "$($script:ModuleRoot)\internal\tepp\assignment.ps1"

# Load License
. Import-ModuleFile -Path "$($script:ModuleRoot)\internal\scripts\license.ps1"

# Check the information mode
if ([bool](Get-PSFConfigValue -FullName dbaclone.informationstore.mode) -eq 'File') {
	# Get the json file
	$jsonFolder = Get-PSFConfigValue -FullName dbaclone.informationstore.path
	$jsonCred = Get-PSFConfigValue -FullName dbaclone.informationstore.credential -Fallback $null

	# Create a PS Drive
	if (-not [bool](Get-PSDrive -Name DCNJSONFolder -Scope Global -ErrorAction SilentlyContinue)) {
		try {
			$null = New-PSDrive -Name DCNJSONFolder -Root $jsonFolder -Credential $jsonCred -PSProvider FileSystem -Scope Global

			while ((Get-PSDrive | Select-Object -ExpandProperty Name) -notcontains 'DCNJSONFolder') {
				Start-Sleep -Milliseconds 500
			}
		}
		catch {
			Stop-PSFFunction -Message "Couldn't create PS Drive" -Target $jsonFolder -ErrorRecord $_
		}
	}
}

# Check if window is in elevated mode
if ( -not (Test-PSFPowerShell -Elevated) ) {
	Stop-PSFFunction -Message "Module requires elevation. Please run the console in Administrator mode" -FunctionName 'Post Import'
}

if (-not (Test-DcnModule -WindowsVersion)) {
	Stop-PSFFunction -Message "Unsupported version of Windows" -FunctionName 'Post Import'
}

# Check if the configuration has been set
if (-not (Test-DcnModule -SetupStatus)) {
	Write-PSFMessage -Message "The module is not yet configured. Please run Set-DcnConfiguration to make the neccesary changes" -Level Warning
}

# Check the version of the module
if (-not (Test-DcnVersion)) {
	Write-PSFMessage -Message "The module is not up-to-date. Please update the module to be sure to have the latest version." -Level Warning
}

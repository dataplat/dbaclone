# Add all things you want to run before importing the main code
# Check if window is in elevated mode
$elevated = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ( -not $elevated ) {
	Stop-PSFFunction -Message "Module requires elevation" -Target $SqlInstance
}

# Check if the Hyper-V optional feature is enabled
$feature = Get-WindowsOptionalFeature -FeatureName 'Microsoft-Hyper-V-All' -Online
if($feature.State -ne "Enabled"){
	Write-PSFMessage -Message 'Please enable the Hyper-V feature with "Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V –All"' -Level Warning
}

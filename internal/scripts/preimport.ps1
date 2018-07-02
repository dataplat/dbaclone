# Check if window is in elevated mode
$elevated = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ( -not $elevated ) {
    Stop-PSFFunction -Message "Module requires elevation" -Target $elevated  -FunctionName 'Pre Import'
}

# Set the supported version of Windows
$supportedVersions = @(
    'Microsoft Windows 10 Pro',
    'Microsoft Windows 10 Enterprise',
    'Microsoft Windows 10 Education',
    'Microsoft Windows Server 2012 R2 Standard',
    'Microsoft Windows Server 2012 R2 Enterprise'
)

# Get the OS details
$osDetails = Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Description, Name, OSType, Version

# Check which version of windows we're dealing with
if ($osDetails.Caption -in $supportedVersions ) {
    if ($osDetails.Caption -like '*Windows 10*') {
        Stop-PSFFunction -Message "Module can only work on Windows 10 Pro, Enterprise or Education" -Target $OSDetails -FunctionName 'Pre Import'
    }
    elseif ($osDetails.Caption -like '*Windows Server*') {
        Stop-PSFFunction -Message "Module can only work on Windows Server 2012 R2 and up, Enterprise or Education" -Target $OSDetails -FunctionName 'Pre Import'
    }
}

# Check if the Hyper-V feature is enabled
if ($osDetails.Caption -like '*Windows 10*') {
    $feature = Get-WindowsOptionalFeature -FeatureName 'Microsoft-Hyper-V-All' -Online
    if ($feature.State -ne "Enabled") {
        Write-PSFMessage -Message 'Please enable the Hyper-V feature with "Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V–All"' -Level Warning  -FunctionName 'Pre Import'
    }
}
elseif ($osDetails.Caption -like '*Windows Server*') {
    $feature = Get-WindowsFeature -Name 'Hyper-V'
    if (-not $feature.Installed) {
        Write-PSFMessage -Message 'Please enable the Hyper-V feature with "Install-WindowsFeature -Name Hyper-V"' -Level Warning  -FunctionName 'Pre Import'
    }
}

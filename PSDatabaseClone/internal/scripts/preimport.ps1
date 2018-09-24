# Set the supported version of Windows
$supportedVersions = @(
    'Microsoft Windows 10 Pro',
    'Microsoft Windows 10 Enterprise',
    'Microsoft Windows 10 Education',
    'Microsoft Windows Server 2012 R2 Standard',
    'Microsoft Windows Server 2012 R2 Enterprise',
    'Microsoft Windows Server 2012 R2 Datacenter'
)

# Get the OS details
$osDetails = Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Description, Name, OSType, Version

# Check which version of windows we're dealing with
if ($osDetails.Caption -notin $supportedVersions ) {
    if ($osDetails.Caption -like '*Windows 7*') {
        Stop-PSFFunction -Message "Module does not work on Windows 7" -Target $OSDetails -FunctionName 'Pre Import'
    }
    else {
        Stop-PSFFunction -Message "Unsupported version of Windows." -Target $OSDetails -FunctionName 'Pre Import'
    }
}



function Test-PSDCHyperVEnabled {

    param(
        [string]$HostName = $env:COMPUTERNAME
    )

    $osDetails = Get-CimInstance Win32_OperatingSystem -ComputerName $HostName | Select-Object Caption, Description, Name, OSType, Version

    # Check if the Hyper-V feature is enabled
    if ($osDetails.Caption -like '*Windows 10*') {
        $feature = Get-WindowsOptionalFeature -FeatureName 'Microsoft-Hyper-V-All' -Online
        if ($feature.State -eq "Enabled") {
            return $true
        }
        else{
            return $false
        }
    }
    elseif ($osDetails.Caption -like '*Windows Server*') {
        $feature = Get-WindowsFeature -Name 'Hyper-V'
        if ($feature.Installed) {
            return $true
        }
        else{
            return $false
        }
    }

}
function Test-PSDCHyperVEnabled {
    <#
    .SYNOPSIS
        Test-PSDCHyperVEnabled tests if Hyper-V is enabled

    .DESCRIPTION
        For the module to work properly the module needs Hyper-V to be enabled
        The function tests is that's the case

    .PARAMETER HostName
        Hostname to check. The default is the current hostname

    .PARAMETER Credential
        Allows you to login to servers using Windows Auth/Integrated/Trusted. To use:

        $scred = Get-Credential, then pass $scred object to the -Credential parameter.

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .PARAMETER WhatIf
        If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.

    .PARAMETER Confirm
        If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.

    .NOTES
        Author: Sander Stad (@sqlstad, sqlstad.nl)

        Website: https://psdatabaseclone.io
        Copyright: (C) Sander Stad, sander@sqlstad.nl
        License: MIT https://opensource.org/licenses/MIT

    .LINK
        https://psdatabaseclone.io/

    .EXAMPLE
        Test-PSDCHyperVEnabled -HostName APPSRV1

        Test if APPSRV1 has Hyper-V enabled

    .EXAMPLE
        Test-PSDCHyperVEnabled

        Test if the current host has Hyper-V enabled
    #>

    [CmdLetbinding()]

    [OutputType([bool])]

    param(
        [string]$HostName = $env:COMPUTERNAME,
        [System.Management.Automation.PSCredential]$Credential,
        [switch]$EnableException
    )

    $computer = [PSFComputer]$HostName

    if ($computer.IsLocalhost) {
        $osDetails = Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Description, Name, OSType, Version
    }
    else {
        $command = [scriptblock]::Create("Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Description, Name, OSType, Version")

        $osDetails = Invoke-PSFCommand -ComputerName $computer -ScriptBlock $command -Credential $Credential
    }

    # Check if the Hyper-V feature is enabled
    if ($osDetails.Caption -like '*Windows 10*') {
        if ($computer.IsLocalhost) {
            $feature = Get-WindowsOptionalFeature -FeatureName 'Microsoft-Hyper-V-All' -Online
        }
        else{
            $command  = [scriptblock]::Create("Get-WindowsOptionalFeature -FeatureName 'Microsoft-Hyper-V-All' -Online")
            $feature = Invoke-PSFCommand -ComputerName $computer -ScriptBlock $command -Credential $Credential
        }

        if($feature.State -ne "Enabled"){
            return $false
        }
        else{
            return $true
        }

    }
    elseif ($osDetails.Caption -like '*Windows Server*') {
        if ($computer.IsLocalhost) {
            $feature = Get-WindowsFeature -Name 'Hyper-V'
        }
        else{
            $command  = [scriptblock]::Create("Get-WindowsFeature -Name 'Hyper-V'")
            $feature = Invoke-PSFCommand -ComputerName $computer -ScriptBlock $command -Credential $Credential
        }

        return $feature.Installed
    }


}
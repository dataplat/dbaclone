function Test-PSDCRemoting {

    <#
    .SYNOPSIS
        Test-PSDCRemoting tests if remoting is enabled and configured

    .DESCRIPTION
        The function will test if the WSMan service is running.
        It will also test if it's able to retrieve a value from the remote host.

        The function will return an object with the results.

        The following information will be returned:
        - HostName              : Which is the host entered at execution
        - IsLocalHost           : If the host is a local host
        - Reachable             : Was the host reachable by a ping request
        - WSManServiceRunning   : Is the WSMan service running = $resultWSManService
        - CommandExecuted       : Was it possible to execute a command remotely
        - Result                : The overall result of the test

    .PARAMETER ComputerName
        Host to connect to

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

        Website: https://psdatabaseclone.org
        Copyright: (C) Sander Stad, sander@sqlstad.nl
        License: MIT https://opensource.org/licenses/MIT

    .LINK
        https://psdatabaseclone.org/

    .EXAMPLE
        Test-PSDCRemoting -HostName SQLDB1

        Test the PS remoting for one host

    .EXAMPLE
        Test-PSDCRemoting -HostName SQLDB1, SQLDB2

        Test the PS remoting for multiple hosts

    .EXAMPLE

    #>

    [CmdLetBinding()]

    param(
        [Parameter(Mandatory = $true)]
        [string[]]$ComputerName,
        [System.Management.Automation.PSCredential]
        $Credential,
        [switch]$EnableException
    )

    begin {

        if (-not $ComputerName) {
            Stop-PSFFunction -Message "Please enter one or more hostnames to test" -Target $ComputerName -Continue
        }

    }

    process {
        # Test if there are any errors
        if (Test-PSFFunctionInterrupt) { return }

        foreach ($comp in $ComputerName) {

            # Get the computer object
            $computer = [PSFComputer]$comp

            # Initialize the variables
            $connectionResult = $false
            $resultWSManService = $false
            $resultCommand = $false

            # Test if the computer is reachable
            [bool]$connectionResult = Test-Connection -ComputerName $comp -BufferSize 16 -Count 1 -ErrorAction 0 -Quiet

            if ($connectionResult) {
                # Test if the WSMan service is running
                try {
                    if ($Credential) {
                        $resultWSManService = [bool](Test-WSMan -ComputerName $comp -Credential $Credential -Authentication Default -ErrorAction SilentlyContinue)
                    }
                    else {
                        $resultWSManService = [bool](Test-WSMan -ComputerName $comp -ErrorAction SilentlyContinue)
                    }
                }
                catch {
                    Stop-PSFFunction -Message "Couldn't test WSMAN.`nVerify that the specified computer name is valid, that the computer is accessible over the network, and that a firewall exception for the WinRM service is enabled and allows access from this computer" -Target $comp -ErrorRecord $_ -Continue
                }

                if ($resultWSManService) {
                    # Reset the result
                    [string]$result = $null

                    # Setup the command
                    $command = [scriptblock]::Create('$env:COMPUTERNAME')

                    # Get the result
                    $result = Invoke-PSFCommand -ComputerName $comp -ScriptBlock $command -Credential $Credential -ErrorAction SilentlyContinue

                    if ($result) {
                        $resultCommand = $true
                    }
                }
            }

            # Return the results
            [PSCustomObject]@{
                ComputerName        = $computer.ComputerName
                IsLocalHost         = $computer.IsLocalhost
                Reachable           = $connectionResult
                WSManServiceRunning = $resultWSManService
                CommandExecuted     = $resultCommand
                Result              = (($connectionResult) -and ($resultWSManService) -and ($resultCommand))
            }
        }

    }

}
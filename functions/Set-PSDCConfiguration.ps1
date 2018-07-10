function Set-PSDCConfiguration {
    <#
    .SYNOPSIS
        Set-PSDCConfiguration sets up the module

    .DESCRIPTION
        For the module to work properly the module needs a couple of settings.
        The most important settings are the ones for the database to store the information
        about the images and the clones.

        The configurations will be saved in the registry of Windows for all users.

        If the database does not yet exist on the server it will try to create the database.
        After that the objects for the database will be created.

    .PARAMETER SqlInstance
        SQL Server name or SMO object representing the SQL Server to connect to

    .PARAMETER SqlCredential
        Allows you to login to servers using SQL Logins as opposed to Windows Auth/Integrated/Trusted. To use:

        $scred = Get-Credential, then pass $scred object to the -SqlCredential parameter.

        Windows Authentication will be used if SqlCredential is not specified. SQL Server does not accept Windows credentials being passed as credentials.
        To connect as a different Windows user, run PowerShell as that user.

    .PARAMETER Database
        Database to use to save all the information in

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
        Set-PSDCConfiguration -SqlInstance SQLDB1 -Database PSDatabaseClone

        Set up the module to use SQLDB1 as the database servers and PSDatabaseClone to save the values in
    #>
    [CmdLetBinding(SupportsShouldProcess = $true)]
    param(
        [object]$SqlInstance,
        [System.Management.Automation.PSCredential]
        $SqlCredential,
        [string]$Database,
        [switch]$EnableException
    )

    begin {
        Write-PSFMessage -Message "Started PSDatabaseClone Setup" -Level Output

        # Try connecting to the instance
        if ($SqlInstance) {
            Write-PSFMessage -Message "Attempting to connect to Sql Server $SqlInstance.." -Level Output
            try {
                $server = Connect-DbaInstance -SqlInstance $SqlInstance -SqlCredential $SqlCredential
            }
            catch {
                Stop-PSFFunction -Message "Could not connect to Sql Server instance $SqlInstance" -ErrorRecord $_ -Target $SqlInstance
                return
            }
        }

        # Setup the database name
        if (-not $Database) {
            $Database = "PSDatabaseClone"
        }

        # Set the flag for the new database
        [bool]$newDatabase = $false

        # Unregister any configurations
        try{
            Unregister-PSFConfig -Scope SystemDefault -Module psdatabaseclone
        }
        catch{
            Stop-PSFFunction -Message "Something went wrong unregistering the configurations" -ErrorRecord $_ -Target $SqlInstance
                return
        }
    }

    process {

        # Test if there are any errors
        if (Test-PSFFunctionInterrupt) { return }

        # Check if the database is already present
        if ($SqlInstance) {
            if (($server.Databases.Name -contains $Database) -or ($server.Databases[$Database].Tables.Count -ge 1)) {
                if ($Force) {
                    try {
                        Remove-DbaDatabase -SqlInstance $SqlInstance -SqlCredential $SqlCredential -Database $Database
                    }
                    catch {
                        Stop-PSFFunction -Message "Couldn't remove database $Database on $SqlInstance" -ErrorRecord $_ -Target $SqlInstance
                        return
                    }
                }
                else {
                    Write-PSFMessage -Message "Database $Database already exists" -Level Verbose
                }
            }

            # Check if the database exists
            if ($server.Databases.Name -notcontains $Database) {

                # Set the flag
                $newDatabase = $true

                try {
                    # Setup the query to create the database
                    $query = "CREATE DATABASE [$Database]"

                    Write-PSFMessage -Message "Creating database $Database on $SqlInstance" -Level Verbose

                    # Executing the query
                    Invoke-DbaSqlQuery -SqlInstance $SqlInstance -SqlCredential $SqlCredential -Database master -Query $query
                }
                catch {
                    Stop-PSFFunction -Message "Couldn't create database $Database on $SqlInstance" -ErrorRecord $_ -Target $SqlInstance
                }
            }
            else {
                # Check if there are any user objects already in the database
                $newDatabase = ($server.Databases[$Database].Tables.Count -eq 0)
            }

            # Setup the path to the sql file
            if ($newDatabase) {
                try {
                    $path = "$($MyInvocation.MyCommand.Module.ModuleBase)\internal\scripts\database.sql"
                    $query = [System.IO.File]::ReadAllText($path)

                    # Create the objects
                    try {
                        Write-PSFMessage -Message "Creating database objects" -Level Verbose

                        # Executing the query
                        Invoke-DbaSqlQuery -SqlInstance $SqlInstance -SqlCredential $SqlCredential -Database $Database -Query $query
                    }
                    catch {
                        Stop-PSFFunction -Message "Couldn't create database objects" -ErrorRecord $_ -Target $SqlInstance
                    }
                }
                catch {
                    Stop-PSFFunction -Message "Couldn't find database script. Make sure you have a valid installation of the module" -ErrorRecord $_ -Target $SqlInstance
                }
            }
            else {
                Write-PSFMessage -Message "Database already contains objects" -Level Verbose
            }

            # Set the database server and database values
            Set-PSFConfig -Module PSDatabaseClone -Name database.server -Value $SqlInstance -Initialize -Validation string
            Set-PSFConfig -Module PSDatabaseClone -Name database.name -Value $Database -Initialize -Validation string
        }

        # Set the credential for the database if needed
        if ($SqlCredential) {
            Set-PSFConfig -Module PSDatabaseClone -Name database.credential -Value $SqlCredential -Initialize
        }

        # Set if Hyper-V is enabled
        Set-PSFConfig -Module PSDatabaseClone -Name hyperv.enabled -Value (Test-PSDCHyperVEnabled) -Validation bool

        # Register the configurations in the system for all users
        Get-PSFConfig -FullName psdatabaseclone.database.server | Register-PSFConfig -Scope SystemDefault
        Get-PSFConfig -FullName psdatabaseclone.database.name | Register-PSFConfig -Scope SystemDefault
        Get-PSFConfig -FullName psdatabaseclone.database.credential | Register-PSFConfig -Scope SystemDefault
        Get-PSFConfig -FullName psdatabaseclone.hyperv.enabled | Register-PSFConfig -Scope SystemDefault
    }

    end {
        # Test if there are any errors
        if (Test-PSFFunctionInterrupt) { return }

        Write-PSFMessage -Message "Finished setting up PSDatabaseClone" -Level Host
    }
}

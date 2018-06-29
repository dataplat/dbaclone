function Set-PdcConfiguration {
<#
.SYNOPSIS
    Set-PdcConfiguration sets up the module

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


.NOTES
    Author: Sander Stad (@sqlstad, sqlstad.nl)

    Website: https://psdatabaseclone.io
    Copyright: (C) Sander Stad, sander@sqlstad.nl
    License: MIT https://opensource.org/licenses/MIT

.LINK
    https://psdatabaseclone.io/

.EXAMPLE
    Set-PdcConfiguration -SqlInstance SQLDB1 -Database PSDatabaseClone

    Set up the module to use SQLDB1 as the database servers and PSDatabaseClone to save the values in
#>
    [CmdLetBinding()]
    param(
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias("ServerInstance", "SqlServerSqlServer")]
        [object]$SqlInstance,

        [System.Management.Automation.PSCredential]
        $SqlCredential,

        [string]$Database
    )

    begin {
        Write-PSFMessage -Message "Started PSDatabaseClone Setup" -Level Output

        # Try connecting to the instance
        Write-PSFMessage -Message "Attempting to connect to Sql Server $SqlInstance.." -Level Output
        try {
            $server = Connect-DbaInstance -SqlInstance $SqlInstance -SqlCredential $SqlCredential
        }
        catch {
            Stop-PSFFunction -Message "Could not connect to Sql Server instance $SqlInstance" -ErrorRecord $_ -Target $SqlInstance
            return
        }

        # Setup the database name
        if (-not $Database) {
            $Database = "PSDatabaseClone"
        }
    }

    process {

        # Test if there are any errors
        if (Test-PSFFunctionInterrupt) { return }

        # Check if the database is already present
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

        # Get the databases from the instance
        $databases = Get-DbaDatabase -SqlInstance $SqlInstance -SqlCredential $SqlCredential

        # Check if the database exists
        if ($databases.Name -notcontains $Database) {
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

        # Setup the path to the sql file
        try {
            $path = "$($MyInvocation.MyCommand.Module.ModuleBase)\internal\scripts\database.sql"
            $query = [System.IO.File]::ReadAllText($path)
        }
        catch {
            Stop-PSFFunction -Message "Couldn't find database script. Make sure you have a valid installation of the module" -ErrorRecord $_ -Target $SqlInstance
        }

        # Create the objects
        try {
            Write-PSFMessage -Message "Creating database objects" -Level Verbose

            # Executing the query
            Invoke-DbaSqlQuery -SqlInstance $SqlInstance -SqlCredential $SqlCredential -Database $Database -Query $query
        }
        catch {
            Stop-PSFFunction -Message "Couldn't create database objects" -ErrorRecord $_ -Target $SqlInstance
        }

        # Writing the setting to the configuration file
        Write-PSFMessage -Message "Registering config values" -Level Verbose
        Set-PSFConfig -Module PSDatabaseClone -Name database.server -Value $SqlInstance -Initialize -Validation string
        Set-PSFConfig -Module PSDatabaseClone -Name database.name -Value $Database -Initialize -Validation string

        Get-PSFConfig -FullName psdatabaseclone.database.server | Register-PSFConfig -Scope SystemDefault
        Get-PSFConfig -FullName psdatabaseclone.database.name | Register-PSFConfig -Scope SystemDefault
    }

    end {
        # Test if there are any errors
        if (Test-PSFFunctionInterrupt) { return }

        Write-PSFMessage -Message "Finished setting up PSDatabaseClone" -Level Host
    }
}
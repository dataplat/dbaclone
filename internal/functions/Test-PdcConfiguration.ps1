function Test-PdcConfiguration {
<#
.SYNOPSIS
    Test the configuration of the module

.DESCRIPTION
    The configuration of the module is vital to let it function.
    This function checks several configurations

.PARAMETER SqlInstance
    The instance that represents the PSDatabaseClone instance that holds the database

.PARAMETER SqlCredential
    Allows you to login to servers using SQL Logins as opposed to Windows Auth/Integrated/Trusted. To use:

    $scred = Get-Credential, then pass $scred object to the -SourceSqlCredential parameter.

    Windows Authentication will be used if SqlCredential is not specified. SQL Server does not accept Windows credentials being passed as credentials.
    To connect as a different Windows user, run PowerShell as that user.

.PARAMETER Database
    The database that holds all the information for the PSDatabaseClone module

.NOTES
    Author: Sander Stad (@sqlstad, sqlstad.nl)

    Website: https://psdatabaseclone.io
    Copyright: (C) Sander Stad, sander@sqlstad.nl
    License: MIT https://opensource.org/licenses/MIT

.LINK
    https://psdatabaseclone.io/

#>
    [CmdLetBinding()]
    param(
        [Alias("ServerInstance", "SqlServerSqlServer")]
        [object]$SqlInstance,

        [System.Management.Automation.PSCredential]
        $SqlCredential,

        [string]$Database
    )

    Write-PSFMessage -Message "SqlInstance: $SqlInstance, Database: $Database" -Level Debug

    # Create the info objects
    $result = [PSCustomObject]@{
        SqlInstance = $null
        Database    = $null
        Check       = $false
        Message     = ""
    }

    $errorOccured = $false

    # Check if the values for the PSDatabaseClone database are set
    if (($SqlInstance -eq $null) -or ($Database -eq $null)) {
        # Get the configurations for the program database
        $Database = Get-PSFConfigValue -FullName psdatabaseclone.database.name -Fallback "NotConfigured"
        $SqlInstance = Get-PSFConfigValue -FullName psdatabaseclone.database.Server -Fallback "NotConfigured"
    }

    # Set the values in the info object
    $result.SqlInstance = $SqlInstance
    $result.Database = $Database

    Write-PSFMessage -Message "Checking configurations" -Level Verbose

    # Check the module database server and database name configurations
    if ($SqlInstance -eq 'NotConfigured') {
        $errorOccured = $true
        $result.Check = $false
        $result.Message = "The PSDatabaseClone database server is not yet configured. Please run Set-PdcConfiguration"

    }

    if ($Database -eq 'NotConfigured') {
        $errorOccured = $true
        $result.Check = $false
        $result.Message = "The PSDatabaseClone database is not yet configured. Please run Set-PdcConfiguration"

    }

    Write-PSFMessage -Message "Attempting to connect to PSDatabaseClone database server $SqlInstance.." -Level Verbose
    if ($result.Check) {
        try {
            $ecServer = Connect-DbaInstance -SqlInstance $SqlInstance -SqlCredential $SqlCredential
        }
        catch {
            $errorOccured = $true
            $result.Check = $false
            $result.Message = "Could not connect to Sql Server instance $SqlInstance"
        }
    }

    # Check if the PSDatabaseClone database is present
    if ($ecServer.Databases.Name -notcontains $Database) {
        $errorOccured = $true
        $result.Check = $false
        $result.Message = "PSDatabaseClone database $Database is not present on $SqlInstance"
    }

    # Check if an error occured
    if (-not $errorOccured) {
        $result.Message = "All OK"
        $result.Check = $true
    }

    Write-PSFMessage -Message "Finished checking configurations" -Level Verbose

    return $result

}
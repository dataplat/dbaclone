function Test-PSDCConfiguration {
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
        Test-PSDCConfiguration

        Test the configuration of the module retrieving the set configurations

    .EXAMPLE
        Test-PSDCConfiguration -SqlInstance SQLDB1 -Database PSDatabaseClone

        Test the configuration with the instance and database set

    #>

    [CmdLetBinding()]

    param(
        [object]$SqlInstance,
        [System.Management.Automation.PSCredential]
        $SqlCredential,
        [string]$Database,
        [switch]$EnableException
    )

    Write-PSFMessage -Message "SqlInstance: $SqlInstance, Database: $Database" -Level Debug

    # Check if the values for the PSDatabaseClone database are set
    if (($null -eq $SqlInstance) -or ($null -eq $Database) -or ($null -eq $SqlCredential)) {
        # Get the configurations for the program database
        $Database = Get-PSFConfigValue -FullName psdatabaseclone.database.name -Fallback "NotConfigured"
        $SqlInstance = Get-PSFConfigValue -FullName psdatabaseclone.database.server -Fallback "NotConfigured"
        $SqlCredential = Get-PSFConfigValue -FullName psdatabaseclone.informationstore.credential -Fallback $null
    }

    Write-PSFMessage -Message "Checking configurations" -Level Verbose

    # Check the module database server and database name configurations
    if ($SqlInstance -eq 'NotConfigured') {
        Stop-PSFFunction -Message "The PSDatabaseClone database server is not yet configured. Please run Set-PSDCConfiguration" -Target $SqlInstance -Continue
    }

    if ($Database -eq 'NotConfigured') {
        Stop-PSFFunction -Message "The PSDatabaseClone database is not yet configured. Please run Set-PSDCConfiguration" -Target $Database -Continue
    }

    Write-PSFMessage -Message "Attempting to connect to PSDatabaseClone database server $SqlInstance.." -Level Verbose
    try {
        $pdcServer = Connect-DbaInstance -SqlInstance $SqlInstance -SqlCredential $SqlCredential -NonPooledConnection
    }
    catch {
        Stop-PSFFunction -Message "Could not connect to Sql Server instance $SqlInstance" -ErrorRecord $_ -Target $pdcServer -Continue
    }

    # Check if the PSDatabaseClone database is present
    if ($pdcServer.Databases.Name -notcontains $Database) {
        Stop-PSFFunction -Message "PSDatabaseClone database $Database is not present on $SqlInstance" -Target $pdcServer -Continue
    }

    Write-PSFMessage -Message "Finished checking configurations" -Level Verbose

}

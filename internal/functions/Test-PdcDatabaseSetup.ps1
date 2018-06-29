function Test-PdcDatabaseSetup {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [Alias("ServerInstance", "SqlServerSqlServer")]
        [object]$SqlInstance,

        [System.Management.Automation.PSCredential]
        $SqlCredential,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Database
    )

    Write-PSFMessage -Message "SqlInstance: $SqlInstance, Database: $Database" -Level Debug

    # Check if the values for the EasyClone database are set
    if (($SqlInstance -eq 'NotConfigured') -or ($Database -eq 'NotConfigured')) {
        Stop-PSFFunction -Message "The module is not yet configured. Please run Set-PdcConfiguration to make the neccesary changes" -Target $SqlInstance
        return
    }

    Write-PSFMessage -Message "Attempting to connect to PSDatabaseClone database server $SqlInstance.." -Level Verbose
    try {
        $ecServer = Connect-DbaInstance -SqlInstance $SqlInstance -SqlCredential $SqlCredential
    }
    catch {
        Stop-PSFFunction -Message "Could not connect to Sql Server instance $SqlInstance" -ErrorRecord $_ -Target $SqlInstance
    }

    # Check if the easyclone database is present
    if ($ecServer.Databases.Name -notcontains $Database) {
        Stop-PSFFunction -Message "PSDatabaseClone database $Database is not present on $SqlInstance" -ErrorRecord $_ -Target $SqlInstance
    }
}
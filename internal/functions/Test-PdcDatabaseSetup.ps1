function Test-PdcDatabaseSetup {

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
        Check       = $true
        Message     = ""
    }

    $errorOccured = $false

    # Check if the values for the EasyClone database are set
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

    # Check if the easyclone database is present
    if ($ecServer.Databases.Name -notcontains $Database) {
        $errorOccured = $true
        $result.Check = $false
        $result.Message = "PSDatabaseClone database $Database is not present on $SqlInstance"
    }

    # Check if an error occured
    if (-not $errorOccured) {
        $result.Message = "All OK"
    }

    Write-PSFMessage -Message "Finished checking configurations" -Level Verbose

    return $result

}
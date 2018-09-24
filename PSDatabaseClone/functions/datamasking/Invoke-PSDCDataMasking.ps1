function Invoke-PSDCDataMasking {
    <#
    .SYNOPSIS
        Invoke-PSDCDataMasking generates random data for tables

    .DESCRIPTION
        Invoke-PSDCDataMasking is able to generate random data for tables.
        It will use a configuration file that can be made manually or generated using New-PSDCMaskingConfiguration

    .PARAMETER SqlInstance
        SQL Server name or SMO object representing the SQL Server to connect to.
        This will be where the database is currently located

    .PARAMETER SqlCredential
        Allows you to login to servers using SQL Logins as opposed to Windows Auth/Integrated/Trusted. To use:

        $scred = Get-Credential, then pass $scred object to the -SqlCredential parameter.

        Windows Authentication will be used if SqlCredential is not specified. SQL Server does not accept Windows credentials being passed as credentials.
        To connect as a different Windows user, run PowerShell as that user.

    .PARAMETER Credential
        Allows you to login to servers or folders
        To use:
        $scred = Get-Credential, then pass $scred object to the -Credential parameter.

    .PARAMETER Database
        Databases to process through

    .PARAMETER Table
        Tables to process. By default all the tables will be processed

    .PARAMETER Column
        Columns to process. By default all the columns will be processed

    .PARAMETER MaskingConfigFile
        Configuration file that contains the which tables and columns need to be masked

    .PARAMETER Locale
        Set the local to enable certain settings in the masking

    .PARAMETER Force
        Forcefully execute commands when needed

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .NOTES
        Author: Sander Stad (@sqlstad, sqlstad.nl)

        Website: https://psdatabaseclone.org
        Copyright: (C) Sander Stad, sander@sqlstad.nl
        License: MIT https://opensource.org/licenses/MIT

    .LINK
        https://psdatabaseclone.org/

    .EXAMPLE
        Invoke-PSDCDataMasking -SqlInstance SQLDB1 -Database DB1 -MaskingConfigFile C:\Temp\DB1.tables.json

        Apply the data masking configuration from the file "DB1.tables.json" to the database
    #>

    [CmdLetBinding()]
    [OutputType('System.String')]

    param(
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [object]$SqlInstance,
        [System.Management.Automation.PSCredential]
        $SqlCredential,
        [System.Management.Automation.PSCredential]
        $Credential,
        [parameter(Mandatory = $true)]
        [object]$Database,
        [parameter(Mandatory = $true)]
        [string]$MaskingConfigFile,
        [string]$Locale = 'en',
        [switch]$Force,
        [switch]$EnableException
    )

    begin {
        # Try connecting to the instance
        Write-PSFMessage -Message "Attempting to connect to Sql Server $SqlInstance.." -Level Verbose
        try {
            $server = Connect-DbaInstance -SqlInstance $SqlInstance -SqlCredential $SqlCredential
        }
        catch {
            Stop-PSFFunction -Message "Could not connect to Sql Server instance $SqlInstance" -ErrorRecord $_ -Target $SqlInstance
            return
        }

        # Check if the destination is accessible
        if (-not (Test-Path -Path $MaskingConfigFile -Credential $Credential)) {
            Stop-PSFFunction -Message "Could not find masking config file" -ErrorRecord $_ -Target $MaskingConfigFile
            return
        }

        # Get all the items that should be processed
        $tables = Get-Content -Path $MaskingConfigFile -Credential $Credential | ConvertFrom-Json

        # Set defaults
        $charString = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    }

    process {
        if (Test-PSFFunctionInterrupt) { return }

        # Create the faker objects
        $faker = New-Object Bogus.Faker($Locale)

        foreach ($table in $tables.Tables) {
            # Get the data
            $query = "SELECT * FROM [$($table.Schema)].[$($table.Name)]"
            #$data = Invoke-DbaQuery -SqlInstance $SqlInstance -SqlCredential $SqlCredential -Database $Database -Query $query | ConvertTo-DbaDataTable
            $data = $server.Databases[$Database].Query($query) | ConvertTo-DbaDataTable

            # Loop through each of the rows and change them
            foreach ($row in $data) {

                $query = "UPDATE [$($table.Schema)].[$($table.Name)] SET "

                foreach ($column in $table.Columns) {
                    $newValue = $null
                    switch($column.MaskingType.ToLower()){

                        {$_ -in 'name', 'address', 'creditcard'} {
                            $newValue = $faker.$($column.MaskingType).$($column.SubType)()
                        }
                        {$_ -in 'date', 'datetime', 'datetime2', 'smalldatetime'}{
                            $newValue = ($faker.Date.Past()).ToString("yyyyMMdd")
                        }
                        "number"{
                            $newValue = $faker.$($column.MaskingType).$($column.SubType)($column.MaxLength)
                        }
                        "string"{
                            $newValue = $faker.$($column.MaskingType).String2($column.MaxLength, $charString)
                        }

                    } # End switch

                    $query += "$($column.Name) = '" + $newValue.Replace("'", "''") + "',"

                } # End for each column

                # Clean up query
                $query = $query.Substring(0, ($query.Length -1))

                # Add where statement
                $query += " WHERE "

                # Loop hrough columns to setup rest of where statement
                foreach ($column in $table.Columns) {

                    switch($column.MaskingType.ToLower()){
                        {$_ -in 'name', 'address', 'creditcard'} {
                            $query += "$($column.Name) = '" + ($row.$($column.Name)).Replace("'", "''") + "' AND "
                        }
                        {$_ -in 'date', 'datetime', 'datetime2', 'smalldatetime'}{
                            $query += "$($column.Name) = '" + ($row.$($column.Name)).Replace("'", "''") + "',"
                        }
                        "number"{
                            $query += "$($column.Name) = " + $faker.$($column.MaskingType).$($column.SubType)($column.MaxLength) + ","
                        }
                        "string"{
                            $query += "$($column.Name) = '" + ($row.$($column.Name)).Replace("'", "''") + "',"
                        }

                    } # End switch

                }

                # Clean up query
                $query = $query.Substring(0, ($query.Length -5))

                try{
                    #Invoke-DbaQuery -SqlInstance $SqlInstance -SqlCredential $SqlCredential -Database $Database -Query $query
                    $server.Databases[$Database].Query($query)
                }
                catch{
                    Stop-PSFFunction -Message "Could not execute the query" -Target $query -Continue
                }


            } # End for each row

        } # End for each table

    } # End process

    end {

    }

}
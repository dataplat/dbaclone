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
        [array]$tables = Get-Content -Path $MaskingConfigFile -Credential $Credential | ConvertFrom-Json

        # Set defaults
        $charString = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'

        # Create the faker objects
        $faker = New-Object Bogus.Faker($Locale)
    }

    process {
        if (Test-PSFFunctionInterrupt) { return }

        foreach ($table in $tables.Tables) {
            # Check if table is present in database
            if ($table.Name -in $server.Databases[$Database].Tables.Name) {
                # Get the data
                try {
                    $query = "SELECT * FROM [$($table.Schema)].[$($table.Name)]"
                    $data = $server.Databases[$Database].Query($query) | ConvertTo-DbaDataTable
                }
                catch {
                    Stop-PSFFunction -Message "Something went wrong retrieving the data from table $($table.Name)" -Target $Database
                }

                # Loop through each of the rows and change them
                foreach ($row in $data.Rows) {

                    $query = "UPDATE [$($table.Schema)].[$($table.Name)] SET "

                    # Loop thorough the columns
                    foreach ($column in $table.Columns) {
                        $query += "$($column.Name) = "

                        switch ($column.MaskingType.ToLower()) {
                            {$_ -in 'name', 'address', 'finance'} {
                                $newValue = $faker.$($column.MaskingType).$($column.SubType)()
                            }
                            {$_ -in 'date', 'datetime', 'datetime2', 'smalldatetime'} {
                                $newValue = ($faker.Date.Past()).ToString("yyyyMMdd")
                            }
                            "number" {
                                $newValue = $faker.$($column.MaskingType).$($column.SubType)($column.MaxLength)
                            }
                            "shuffle" {
                                $newValue = ($row.($column.Name) -split '' | Sort-Object {Get-Random}) -join ''
                            }
                            "string" {
                                $newValue = $faker.$($column.MaskingType).String2($column.MaxLength, $charString)
                            }
                        } # End switch

                        # Setup the column art of the SET statement
                        if ($newValue.Gettype().Name -eq 'DateTime', 'String') {
                            $query += "'" + $newValue.Replace("'", "''") + "',"
                        }
                        elseif ($newValue.Gettype().Name -in 'Double', 'Int32', 'Int64') {
                            $query += "$newValue,"
                        }

                    } # End for each column

                    # Clean up query
                    $query = $query.Substring(0, ($query.Length - 1))

                    # Add where statement
                    $query += " WHERE "

                    # Loop hrough columns to setup rest of where statement
                    foreach ($column in $table.Columns) {
                        # Get the original  value
                        $oldValue = $row.$($column.Name)

                        # Check the type
                        if ($oldValue.Gettype().Name -eq 'DateTime', 'String') {
                            $query += "$($column.Name) = '" + ($row.$($column.Name)).Replace("'", "''") + "' AND "
                        }
                        elseif ($newValue.Gettype().Name -in 'Double', 'Int32', 'Int64') {
                            $query += "$($column.Name) = $($row.$($column.Name)) AND "
                        }

                    }

                    # Clean up query
                    $query = $query.Substring(0, ($query.Length - 5))

                    # Execute the query
                    try {
                        $server.Databases[$Database].Query($query)
                    }
                    catch {
                        Stop-PSFFunction -Message "Could not execute the query" -Target $query -Continue
                    }

                } # End for each row

            } # End table check
            else {
                Stop-PSFFunction -Message "Table $($table.Name) is not present" -Target $Database -Continue
            }

        } # End for each table

    } # End process

    end {

    }

}
function New-PSDCMaskingConfiguration {
    <#
    .SYNOPSIS
        PSDCMaskingConfiguration creates a new table configuration file

    .DESCRIPTION
        PSDCMaskingConfiguration is able to generate the table configuration file
        This file is important to apply any data masking to the data in a database

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

    .PARAMETER Destination
        Destination where to save the generated JSON files.
        Th naming conventio will be "databasename.tables.json"

    .PARAMETER Locale
        Set the local to enable certain settings in the masking

    .PARAMETER Force
        Forcefully execute commands when needed

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
        New-PSDCMaskingConfiguration -SqlInstance SQLDB1 -Database DB1 -Destination C:\Temp\clone\

        Process all tables and columns for database DB1 on instance SQLDB1

    .EXAMPLE
        New-PSDCMaskingConfiguration -SqlInstance SQLDB1 -Database DB1 -Table Customer -Destination C:\Temp\clone\

        Process only table Customer with all the columns

    .EXAMPLE
        New-PSDCMaskingConfiguration -SqlInstance SQLDB1 -Database DB1 -Table Customer -Column City -Destination C:\Temp\clone\

        Process only table Customer and only the column named "City"

    #>
    [CmdLetBinding(SupportsShouldProcess = $true)]
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
        [object[]]$Database,
        [object[]]$Table,
        [object[]]$Column,
        [parameter(Mandatory = $true)]
        [string]$Destination,
        [string]$Locale = 'en',
        [switch]$Force
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

        # Get all the different column types
        try {
            $columnTypes = Get-Content -Path "$($MyInvocation.MyCommand.Module.ModuleBase)\internal\resources\datamasking\columntypes.json" | ConvertFrom-Json
        }
        catch {
            Stop-PSFFunction -Message "Something went wrong importing the column types" -Continue
        }

        # Check if the destination is accessible
        if (-not (Test-Path -Path $Destination)) {
            try {
                $null = New-Item -Path $Destination -ItemType Directory -Credential $Credential -Force:$Force
            }
            catch {
                Stop-PSFFunction -Message "Could not create destination directory" -ErrorRecord $_ -Target $Destination
                return
            }
        }

        # Get the databases
        $DatabaseCollection = $server.Databases | Where-Object Name -in $Database

    }

    process {
        if (Test-PSFFunctionInterrupt) { return }

        #Create the result array
        $results = @()

        # Loop through the databases
        foreach ($db in $DatabaseCollection) {

            #Create the result array
            $tables = @()

            # Get the tables
            if (-not $Table) {
                $TableCollection = $db.Tables
            }
            else {
                $TableCollection = $db.Tables | Where-Object Name -in $Table
            }

            # Loop through the tables
            foreach ($tbl in $TableCollection) {
                # Create the column array
                $columns = @()

                # Get the columns
                if (-not $Column) {
                    $ColumnCollection = $tbl.Columns
                }
                else {
                    $ColumnCollection = $tbl.Columns | Where-Object Name -in $Column
                }

                # Loop through each of the columns
                foreach ($cln in $ColumnCollection) {
                    # Skip identity columns
                    if ((-not $cln.Identity) -and (-not $cln.IsForeignKey)) {
                        $maskingType = $null

                        # Get the masking type
                        $maskingType = $columnTypes | Where-Object {$cln.Name -in $_.Synonim} | Select-Object TypeName -ExpandProperty TypeName

                        $columnLength = $cln.Properties['Length'].Value
                        $columnType = $cln.DataType.Name

                        # Check the maskingtype
                        switch ($maskingType.ToLower()) {
                            "firstname" {
                                $columns += [PSCustomObject]@{
                                    Name        = $cln.Name
                                    ColumnType  = $columnType.ToLower()
                                    MaxLength   = $columnLength
                                    MaskingType = "Name"
                                    SubType     = "Firstname"
                                }
                            }
                            "lastname" {
                                $columns += [PSCustomObject]@{
                                    Name        = $cln.Name
                                    ColumnType  = $columnType.ToLower()
                                    MaxLength   = $columnLength
                                    MaskingType = "Name"
                                    SubType     = "Lastname"
                                }
                            }
                            "creditcard" {
                                $columns += [PSCustomObject]@{
                                    Name        = $cln.Name
                                    ColumnType  = $columnType.ToLower()
                                    MaxLength   = $columnLength
                                    MaskingType = "Finance"
                                    SubType     = "MasterCard"
                                }
                            }
                            "address" {
                                $columns += [PSCustomObject]@{
                                    Name        = $cln.Name
                                    ColumnType  = $columnType.ToLower()
                                    MaxLength   = $columnLength
                                    MaskingType = "Address"
                                    SubType     = "StreetAddress"
                                }
                            }
                            "city" {
                                $columns += [PSCustomObject]@{
                                    Name        = $cln.Name
                                    ColumnType  = $columnType.ToLower()
                                    MaxLength   = $columnLength
                                    MaskingType = "Address"
                                    SubType     = "City"
                                }
                            }
                            "zipcode" {
                                $columns += [PSCustomObject]@{
                                    Name        = $cln.Name
                                    ColumnType  = $columnType.ToLower()
                                    MaxLength   = $columnLength
                                    MaskingType = "Address"
                                    SubType     = "Zipcode"
                                }
                            }
                            default {
                                $type = "Random"

                                switch ($columnType.ToLower()) {
                                    "bigint" {
                                        $subType = "Number"
                                        $maxLength = 9223372036854775807
                                    }
                                    "int" {
                                        $subType = "Number"
                                        $maxLength = 2147483647
                                    }
                                    "date" {
                                        $subType = "Date"
                                        $maxLength = $null
                                    }
                                    "datetime" {
                                        $subType = "Date"
                                        $maxLength = $null
                                    }
                                    "datetime2" {
                                        $subType = "Date"
                                        $maxLength = $null
                                    }
                                    "float" {
                                        $subType = "Float"
                                        $maxLength = $null
                                    }
                                    "int" {
                                        $subType = "Int"
                                        $maxLength = 2147483647
                                    }
                                    "smallint" {
                                        $subType = "Number"
                                        $maxLength = 32767
                                    }
                                    "smalldatetime" {
                                        $subType = "Date"
                                        $maxLength = $null
                                    }
                                    "tinyint" {
                                        $subType = "Number"
                                        $maxLength = 255
                                    }
                                    {$_ -eq 'varchar', 'char'} {
                                        $subType = "String"
                                        $maxLength = $columnLength
                                    }
                                }

                                $columns += [PSCustomObject]@{
                                    Name        = $cln.Name
                                    ColumnType  = $columnType.ToLower()
                                    MaxLength   = $maxLength
                                    MaskingType = $type
                                    SubType     = $subType
                                }
                            }

                        } # End switch

                    } # End if identity

                } # End for each columns

                # Check if something needs to be generated
                if ($columns.Count -ge 1) {
                    $tables += [PSCustomObject]@{
                        Name    = $tbl.Name
                        Schema  = $tbl.Schema
                        Columns = $columns
                    }
                }
                else {
                    Write-PSFMessage -Message "No columns match for masking in table $($tbl.Name)" -Level Verbose
                }

            } # End for each table

            # Check if something needs to be generated
            if ($tables.Count -ge 1) {
                $results += [PSCustomObject]@{
                    Name   = $db.Name
                    Tables = $tables
                }
            }
            else {
                Write-PSFMessage -Message "No columns match for masking in table $($tbl.Name)" -Level Verbose
            }

        } # End for each database

        # Write the data to the destination
        if ($results.Count -ge 1) {
            try {
                Set-Content -Path "$Destination\$($db.Name).tables.json" -Credential $Credential -Value ($results | ConvertTo-Json -Depth 5)
            }
            catch {
                Stop-PSFFunction -Message "Something went wrong writing the results to the destination" -Target $Destination -Continue
            }
        }
        else {
            Write-PSFMessage -Message "No tables to save for database $($db.Name)" -Level Verbose
        }

    } # End process


}
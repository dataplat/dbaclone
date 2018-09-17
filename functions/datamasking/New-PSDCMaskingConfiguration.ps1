function New-PSDCMaskingConfiguration {
    <#
    .SYNOPSIS
        New-PSDCImage creates a new image

    .DESCRIPTION
        New-PSDCImage will create a new image based on a SQL Server database

        The command will either create a full backup or use the last full backup to create the image.

        Every image is created with the name of the database and a time stamp yyyyMMddHHmmss i.e "DB1_20180622171819.vhdx"

    .PARAMETER SqlInstance
        SQL Server name or SMO object representing the SQL Server to connect to.
        This will be where the database is currently located

    .PARAMETER SqlCredential
        Allows you to login to servers using SQL Logins as opposed to Windows Auth/Integrated/Trusted. To use:

        $scred = Get-Credential, then pass $scred object to the -SqlCredential parameter.

        Windows Authentication will be used if SqlCredential is not specified. SQL Server does not accept Windows credentials being passed as credentials.
        To connect as a different Windows user, run PowerShell as that user.

    .PARAMETER Database
        Databases to process through

    .PARAMETER Table
        Tables to process. By default all the tables will be processed

    .PARAMETER Column
        Columns to process. By default all the columns will be processed

    .PARAMETER Destination
        Destination where to save the generated JSON files.
        Th naming conventio will be "databasename.tables.json"

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
        New-PSDCMaskingConfiguration -SqlInstance SQLDB1 -Database DB1 -Destination C:\Temp\clone\

        Process all tables and columns for database DB1 on instance SQLDB1

    .EXAMPLE
        New-PSDCMaskingConfiguration -SqlInstance SQLDB1 -Database DB1 -Table Customer -Destination C:\Temp\clone\

        Process only table Customer with all the columns

    .EXAMPLE
        New-PSDCMaskingConfiguration -SqlInstance SQLDB1 -Database DB1 -Table Customer -Column City -Destination C:\Temp\clone\

        Process only table Customer and only the column named "City"

    #>
    [CmdLetBinding()]
    [OutputType('System.String')]

    param(
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [object]$SqlInstance,
        [System.Management.Automation.PSCredential]
        $SqlCredential,
        [parameter(Mandatory = $true)]
        [object[]]$Database,
        [object[]]$Table,
        [object[]]$Column,
        [parameter(Mandatory = $true)]
        [string]$Destination,
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
                $null = New-Item -Path $Destination -ItemType Directory -Force:$Force
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

        # Loop through the databases
        foreach ($db in $DatabaseCollection) {
            #Create the result array
            $results = @()

            # Get the tables
            if (-not $Table) {
                $TableCollection = $db.Tables
            }
            else {
                $TableCollection = $db.Tables | Where-Object Name -in $Table
            }

            # Loop through the tables
            foreach ($table in $TableCollection) {
                # Create the column array
                $columns = @()

                # Get the columns
                if (-not $Column) {
                    $ColumnCollection = $table.Columns
                }
                else {
                    $ColumnCollection = $table.Columns | Where-Object Name -in $Column
                }

                # Loop through each of the columns
                foreach ($column in $ColumnCollection) {
                    $maskingType = $null

                    # Get the masking type
                    $maskingType = $columnTypes | Where-Object {$column.Name -in $_.Synonim} | Select-Object TypeName -ExpandProperty TypeName

                    # Check if the type found is not empty and add it to the array
                    if ($null -ne $maskingType) {
                        $columns += [PSCustomObject]@{
                            Name        = $column.Name
                            MaskingType = $maskingType.ToString()
                        }
                    }

                } # End for each columns

                # Check if something needs to be generated
                if ($columns.Count -ge 1) {
                    $results += [PSCustomObject]@{
                        Name    = $table.Name
                        Columns = $columns
                    }
                }

            } # End for each table

            # Write the data to the destination
            try {
                Set-Content -Path "$Destination\$($db.Name).tables.json" -Value ($results | ConvertTo-Json)
            }
            catch {
                Stop-PSFFunction -Message "Something went wrong writing the results to the destination" -Target $Destination -Continue
            }


        } # End for each database

    } # End process

    end {
        if (Test-PSFFunctionInterrupt) { return }
    }

}
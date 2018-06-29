function Invoke-PdcRepairClone {
    <#
.SYNOPSIS
    Invoke-PdcRepairClone repairs the clones

.DESCRIPTION
    Invoke-PdcRepairClone has the ability to repair the clones when they have gotten disconnected from the image.
    In such a case the clone is no longer available for the database server and the database will either not show
    any information or the database will have the status (Recovery Pending).

    By running this command all the clones will be retrieved from the database for a certain host.

.PARAMETER HostName
    Set on or more hostnames to retrieve the configurations for

.PARAMETER SqlCredential
    Allows you to login to servers using SQL Logins as opposed to Windows Auth/Integrated/Trusted. To use:

    $scred = Get-Credential, then pass $scred object to the -SqlCredential parameter.

    Windows Authentication will be used if SqlCredential is not specified. SQL Server does not accept Windows credentials being passed as credentials.
    To connect as a different Windows user, run PowerShell as that user.

.NOTES
    Author: Sander Stad (@sqlstad, sqlstad.nl)

    Website: https://easyclone.io
    Copyright: (C) Sander Stad, sander@sqlstad.nl
    License: MIT https://opensource.org/licenses/MIT

.LINK
    https://easyclone.io/

.EXAMPLE
    Invoke-PdcRepairClone -Hostname Host1

    Repair the clones for Host1

#>
    [CmdLetBinding()]

    param(
        [Parameter(Mandatory = $true)]
        [string[]]$HostName,

        [System.Management.Automation.PSCredential]
        $SqlCredential
    )

    begin {
        # Test the module database setup
        $result = Test-PdcDatabaseSetup -SqlInstance $ecDatabaseServer -SqlCredential $SqlCredential -Database $ecDatabaseName

        if(-not $result.Check){
            Stop-PSFFunction -Message $result.Message -Target $result -Continue
            return
        }

    }

    process {
        # Test if there are any errors
        if (Test-PSFFunctionInterrupt) { return }

        # Loop through each of the hosts
        foreach ($hst in $HostName) {

            $query = "
                SELECT i.ImageLocation,
                        c.CloneLocation,
                        c.SqlInstance,
                        c.DatabaseName,
                        c.IsEnabled
                FROM dbo.Clone AS c
                    INNER JOIN dbo.Image AS i
                        ON i.ImageID = c.ImageID
                    INNER JOIN dbo.Host AS h
                        ON h.HostID = c.HostID
                WHERE h.HostName = '$hst';
            "

            # Get the clones registered for the host
            try {
                Write-PSFMessage -Message "Get the clones for host $hst" -Level Verbose
                $results = Invoke-DbaSqlQuery -SqlInstance $ecDatabaseServer -Database $ecDatabaseName -Query $query
            }
            catch {
                Stop-PSFFunction -Message "Couldn't get the clones for $hst" -Target $ecDatabaseServer -ErrorRecord $_ -Continue
            }

            # Loop through the results
            foreach ($result in $results) {

                $disk = $null

                # Get the databases
                Write-PSFMessage -Message "Retrieve the databases for $($result.SqlInstance)" -Level Verbose
                $databases = Get-DbaDatabase -SqlInstance $result.SqlInstance -SqlCredential $SqlCredential

                # Check if the parent of the clone can be reached
                if (Test-Path -Path $result.ImageLocation) {

                    # Get the disk
                    $disk = Get-VHD -Path $result.CloneLocation

                    # Mount the clone
                    try {
                        Write-PSFMessage -Message "Mounting vhd $($result.CloneLocation)" -Level Verbose

                        Mount-VHD -Path $result.CloneLocation -NoDriveLetter -ErrorAction SilentlyContinue
                    }
                    catch {
                        Stop-PSFFunction -Message "Couldn't mount vhd" -Target $clone -Continue
                    }
                }
                else {
                    Stop-PSFFunction -Message "Vhd $($result.CloneLocation) cannot be mounted because parent path cannot be reached" -Target $clone -Continue
                }

                # Check if the database is already attached
                if ($result.DatabaseName -notin $databases.Name) {

                    # Get all the files of the database
                    $databaseFiles = Get-ChildItem -Path $result.AccessPath -Recurse | Where-Object {-not $_.PSIsContainer}

                    # Setup the database filestructure
                    $dbFileStructure = New-Object System.Collections.Specialized.StringCollection

                    # Loop through each of the database files and add them to the file structure
                    foreach ($dbFile in $databaseFiles) {
                        $dbFileStructure.Add($dbFile.FullName) | Out-Null
                    }

                    Write-PSFMessage -Message "Mounting database from clone" -Level Verbose

                    # Mount the database using the config file
                    $null = Mount-DbaDatabase -SqlInstance $result.SQLInstance -Database $result.DatabaseName -FileStructure $dbFileStructure
                }
                else {
                    Write-PSFMessage -Message "Database $($result.Database) is already attached" -Level Verbose
                }

            }

        }

    }

    end {
        # Test if there are any errors
        if (Test-PSFFunctionInterrupt) { return }

        Write-PSFMessage -Message "Finished repairing clones" -Level Verbose
    }

}
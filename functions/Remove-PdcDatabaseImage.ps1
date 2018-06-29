function Remove-PdcDatabaseImage {
    [CmdLetBinding()]

    param(
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]$ImageLocation,

        [System.Management.Automation.PSCredential]
        $Credential,

        [switch]$Force
    )

    begin {
        Write-PSFMessage -Message "Started removing database images" -Level Verbose

        # Get the configurations for the program database
        $ecDatabaseName = Get-PSFConfigValue -FullName easyclone.database.name
        $ecDatabaseServer = Get-PSFConfigValue -FullName easyclone.database.server

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

        foreach ($image in $ImageLocation) {
            [array]$results = $null

            $query = "
                SELECT c.CloneLocation,
                        c.AccessPath,
                        c.SqlInstance,
                        c.DatabaseName,
                        h.HostName,
                        h.IPAddress,
                        h.FQDN,
                        i.ImageLocation
                FROM dbo.Clone AS c
                    INNER JOIN dbo.Host AS h
                        ON h.HostID = c.HostID
                    INNER JOIN dbo.Image AS i
                        ON i.ImageID = c.ImageID
                WHERE i.ImageLocation = '$image'
                ORDER BY h.HostName;
            "

            # Try to get the neccesary info from the EasyClone database
            try {
                Write-PSFMessage -Message "Retrieving data for image '$image'" -Level Verbose
                $results = Invoke-DbaSqlQuery -SqlInstance $ecDatabaseServer -Database $ecDatabaseName -Query $query
            }
            catch {
                Stop-PSFFunction -Message "Couldn't retrieve clone records for host $hst" -Target $hst -Continue
            }

            # Check the results
            if ($results.Count -ge 1) {

                # Loop through the results
                foreach ($result in $results) {

                    # Remove the clones for the host
                    try {
                        Write-PSFMessage -Message "Removing clones for host $($result.HostName) and database $($result.DatabaseName)" -Level Verbose
                        Remove-PdcDatabaseClone -HostName $result.HostName -Database $result.DatabaseName -Credential $Credential
                    }
                    catch {
                        Stop-PSFFunction -Message "Couldn't remove clones from host $($result.HostName)" -Target $result -Continue
                    }

                }

                # Remove the image from the file system
                try {
                    Write-PSFMessage -Message "Removing image '$image' from file system" -Level Verbose
                    $null = Remove-Item -Path $image -Credential $Credential -Force:$Force
                }
                catch {
                    Stop-PSFFunction -Message "Couldn't remove image '$image' from file system" -Target $result
                }

                # Remove the image from the database
                try {
                    $query = "DELETE FROM dbo.Image WHERE ImageLocation = '$image'"
                    $results = Invoke-DbaSqlQuery -SqlInstance $ecDatabaseServer -Database $ecDatabaseName -Query $query
                }
                catch {
                    Stop-PSFFunction -Message "Couldn't remove image '$image' from database" -Target $result
                }
            }
            else {
                Write-PSFMessage -Message "No clones were found created with image $image" -Level Verbose
            }

        } # End for each image

    } # End process

    end {
        # Test if there are any errors
        if (Test-PSFFunctionInterrupt) { return }

        Write-PSFMessage -Message "Finished removing database image(s)" -Level Verbose
    }

}
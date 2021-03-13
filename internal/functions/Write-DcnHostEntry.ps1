function Write-DcnHostEntry {

    [CmdLetBinding()]

    param(
        [PsfComputer]$Computer,
        [switch]$EnableException
    )

    begin {
        $informationStore = Get-PSFConfigValue -FullName dbaclone.informationstore.mode

        # Get the module configurations
        $pdcSqlInstance = Get-PSFConfigValue -FullName dbaclone.database.Server
        $pdcDatabase = Get-PSFConfigValue -FullName dbaclone.database.name
        if (-not $DcnSqlCredential) {
            $pdcCredential = Get-PSFConfigValue -FullName dbaclone.informationstore.credential -Fallback $null
        }
        else {
            $pdcCredential = $DcnSqlCredential
        }
    }

    process {

        try {
            # Get the data of the host
            if ($computer.IsLocalhost) {
                $computerinfo = [System.Net.Dns]::GetHostByName(($env:computerName))

                $hostname = $computerinfo.HostName
                $ipAddress = $computerinfo.AddressList[0]
                $fqdn = $computerinfo.HostName
            }
            else {
                $command = [scriptblock]::Create('[System.Net.Dns]::GetHostByName(($env:computerName))')
                $computerinfo = Invoke-PSFCommand -ComputerName $computer -ScriptBlock $command -Credential $Credential

                $command = [scriptblock]::Create('$env:COMPUTERNAME')
                $result = Invoke-PSFCommand -ComputerName $computer -ScriptBlock $command -Credential $Credential

                $hostname = $result.ToString()
                $ipAddress = $computerinfo.AddressList[0]
                $fqdn = $computerinfo.HostName
            }

            if ($informationStore -eq 'SQL') {
                # Setup the query to check of the host is already added
                $query = "
                            IF EXISTS (SELECT HostName FROM Host WHERE HostName ='$hostname')
                            BEGIN
                                SELECT CAST(1 AS BIT) AS HostKnown;
                            END;
                            ELSE
                            BEGIN
                                SELECT CAST(0 AS BIT) AS HostKnown;
                            END;
                        "

                # Execute the query
                $hostKnown = (Invoke-DbaQuery -SqlInstance $pdcSqlInstance -SqlCredential $pdcCredential -Database $pdcDatabase -Query $query -EnableException).HostKnown
            }
            elseif ($informationStore -eq 'File') {
                $hosts = Get-ChildItem -Path DCNJSONFolder:\ -Filter *hosts.json | ForEach-Object { Get-Content $_.FullName | ConvertFrom-Json }

                $hostKnown = [bool]($hostname -in $hosts.HostName)
            }
        }
        catch {
            Stop-PSFFunction -Message "Couldnt execute query to see if host was known" -Target $query -ErrorRecord $_ -Continue
        }

        # Add the host if the host is known
        if (-not $hostKnown) {
            if ($PSCmdlet.ShouldProcess($hostname, "Adding hostname to database")) {

                if ($informationStore -eq 'SQL') {

                    Write-PSFMessage -Message "Adding host $hostname to database" -Level Verbose

                    $query = "
                                DECLARE @HostID INT;
                                EXECUTE dbo.Host_New @HostID = @HostID OUTPUT, -- int
                                                    @HostName = '$hostname',   -- varchar(100)
                                                    @IPAddress = '$ipAddress', -- varchar(20)
                                                    @FQDN = '$fqdn'			   -- varchar(255)

                                SELECT @HostID AS HostID
                            "

                    try {
                        $hostID = (Invoke-DbaQuery -SqlInstance $pdcSqlInstance -SqlCredential $pdcCredential -Database $pdcDatabase -Query $query -EnableException).HostID
                    }
                    catch {
                        Stop-PSFFunction -Message "Couldnt execute query for adding host" -Target $query -ErrorRecord $_ -Continue
                    }
                }
                elseif ($informationStore -eq 'File') {
                    [array]$hosts = $null

                    # Get all the images
                    $hosts = Get-ChildItem -Path DCNJSONFolder:\ -Filter *hosts.json | ForEach-Object { Get-Content $_.FullName | ConvertFrom-Json }

                    # Setup the new host id
                    if ($hosts.Count -ge 1) {
                        $hostID = ($hosts[-1].HostID | Sort-Object HostID) + 1
                    }
                    else {
                        $hostID = 1
                    }

                    # Add the new information to the array
                    $hosts += [PSCustomObject]@{
                        HostID    = $hostID
                        HostName  = $hostname
                        IPAddress = $ipAddress.IPAddressToString
                        FQDN      = $fqdn
                    }

                    # Test if the JSON folder can be reached
                    if (-not (Test-Path -Path "DCNJSONFolder:\")) {
                        $command = [scriptblock]::Create("Import-Module dbaclone -Force")

                        try {
                            Invoke-PSFCommand -ComputerName $computer -ScriptBlock $command -Credential $Credential
                        }
                        catch {
                            Stop-PSFFunction -Message "Couldn't import module remotely" -Target $command
                            return
                        }
                    }

                    # Setup the json file
                    $jsonHostFile = "DCNJSONFolder:\hosts.json"

                    # Convert the data back to JSON
                    $hosts | ConvertTo-Json | Set-Content $jsonHostFile
                }
            }
        }
        else {
            if ($informationStore -eq 'SQL') {
                Write-PSFMessage -Message "Selecting host $hostname from database" -Level Verbose
                $query = "SELECT HostID FROM Host WHERE HostName = '$hostname'"

                try {
                    $hostID = (Invoke-DbaQuery -SqlInstance $pdcSqlInstance -SqlCredential $pdcCredential -Database $pdcDatabase -Query $query -EnableException).HostID
                }
                catch {
                    Stop-PSFFunction -Message "Couldnt execute query for retrieving host id" -Target $query -ErrorRecord $_ -Continue
                }
            }
            elseif ($informationStore -eq 'File') {
                $hostID = ($hosts | Where-Object { $_.Hostname -eq $hostname } | Select-Object HostID -Unique).HostID
            }
        }
    }
}
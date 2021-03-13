
function Write-DcnCloneEntry {
    [CmdLetBinding(SupportsShouldProcess)]

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

        $cloneID = $null

        if ($informationStore -eq 'SQL') {
            # Get the image id from the database
            Write-PSFMessage -Message "Selecting image from database" -Level Verbose
            try {
                $query = "SELECT ImageID, ImageName FROM dbo.Image WHERE ImageLocation = '$ParentVhd'"
                $image = Invoke-DbaQuery -SqlInstance $pdcSqlInstance -SqlCredential $pdcCredential -Database $pdcDatabase -Query $query -EnableException
            }
            catch {
                Stop-PSFFunction -Message "Couldnt execute query for retrieving image id" -Target $query -ErrorRecord $_ -Continue
            }

            if ($PSCmdlet.ShouldProcess("$($clonePath)", "Adding clone to database")) {
                if ($null -ne $image.ImageID) {
                    # Setup the query to add the clone to the database
                    Write-PSFMessage -Message "Adding clone $cloneLocation to database" -Level Verbose
                    $query = "
                                DECLARE @CloneID INT;
                                EXECUTE dbo.Clone_New @CloneID = @CloneID OUTPUT,                   -- int
                                                    @ImageID = $($image.ImageID),             -- int
                                                    @HostID = $hostId,			                    -- int
                                                    @CloneLocation = '$cloneLocation',	            -- varchar(255)
                                                    @AccessPath = '$accessPath',                    -- varchar(255)
                                                    @SqlInstance = '$($server.DomainInstanceName)', -- varchar(50)
                                                    @DatabaseName = '$cloneDatabase',               -- varchar(100)
                                                    @IsEnabled = $active                            -- bit

                                SELECT @CloneID AS CloneID
                            "

                    Write-PSFMessage -Message "Query New Clone`n$query" -Level Debug

                    # execute the query
                    try {
                        $result = Invoke-DbaQuery -SqlInstance $pdcSqlInstance -SqlCredential $pdcCredential -Database $pdcDatabase -Query $query -EnableException
                        $cloneID = $result.CloneID
                    }
                    catch {
                        Stop-PSFFunction -Message "Couldnt execute query for adding clone" -Target $query -ErrorRecord $_ -Continue
                    }

                }
                else {
                    Stop-PSFFunction -Message "Image couldn't be found" -Target $imageName -Continue
                }
            }
        }
        elseif ($informationStore -eq 'File') {
            # Get the image
            $image = Get-DcnImage -ImageLocation $ParentVhd

            [array]$clones = $null

            # Get all the images
            $clones = Get-DcnClone

            # Setup the new image id
            if ($clones.Count -ge 1) {
                $cloneID = ($clones[-1].CloneID | Sort-Object CloneID) + 1
            }
            else {
                $cloneID = 1
            }

            # Add the new information to the array
            $clones += [PSCustomObject]@{
                CloneID       = $cloneID
                ImageID       = $image.ImageID
                ImageName     = $image.ImageName
                ImageLocation = $ParentVhd
                HostID        = $hostId
                HostName      = $hostname
                CloneLocation = $cloneLocation
                AccessPath    = $accessPath
                SqlInstance   = $($server.DomainInstanceName)
                DatabaseName  = $cloneDatabase
                IsEnabled     = $active
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

            # Set the clone file
            $jsonCloneFile = "DCNJSONFolder:\clones.json"

            # Convert the data back to JSON
            $clones | ConvertTo-Json | Set-Content $jsonCloneFile
        }

        return $cloneID
    }
}
function Remove-PSDCImage {
    <#
    .SYNOPSIS
        Remove-PSDCImage removes one or more images

    .DESCRIPTION
        The command will remove an image from PSDatabaseClone.
        It will also remove all the clones associated with it on the hosts.

    .PARAMETER ImageID
        Remove images based on the image id

    .PARAMETER ImageName
        Remove images based on the image name

    .PARAMETER ImageLocation
        Location of the image as it's saved in the database or can be seen on the file system.

    .PARAMETER Database
        Remove images based on the database

    .PARAMETER ExcludeDatabase
        Filter the images based on the excluded database

    .PARAMETER PSDCSqlCredential
        Allows you to login to servers using SQL Logins as opposed to Windows Auth/Integrated/Trusted.
        This works similar as SqlCredential but is only meant for authentication to the PSDatabaseClone database server and database.

    .PARAMETER Credential
        Allows you to login to servers using  Windows Auth/Integrated/Trusted. To use:

        $scred = Get-Credential, then pass $scred object to the -Credential parameter.

    .PARAMETER Force
        Forcefully remove the items.

    .PARAMETER InputObject
        The input object that is used for pipeline use

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
        Remove-PSDCImage -ImageLocation "\\server1\images\DB1_20180703193345.vhdx"

        Remove an image

    .EXAMPLE
        Get-PSDCImage -Database DB1 | Remove-PSDCImage

        Remove all images and clones based on database DB1
    #>
    [CmdLetBinding(DefaultParameterSetName = "ImageLocation", SupportsShouldProcess = $true,
        ConfirmImpact = 'High')]

    param(
        [int[]]$ImageID,
        [string[]]$ImageName,
        [parameter(ParameterSetName = "ImageLocation")]
        [string[]]$ImageLocation,
        [string[]]$Database,
        [string[]]$ExcludeDatabase,
        [System.Management.Automation.PSCredential]
        $PSDCSqlCredential,
        [System.Management.Automation.PSCredential]
        $Credential,
        [switch]$Force,
        [parameter(ValueFromPipeline = $true, ParameterSetName = "Image")]
        [object[]]$InputObject,
        [switch]$EnableException
    )

    begin {
        # Check if the console is run in Administrator mode
        if ( -not (Test-PSDCElevated) ) {
            Stop-PSFFunction -Message "Module requires elevation. Please run the console in Administrator mode"
        }

        # Check if the setup has ran
        if (-not (Get-PSFConfigValue -FullName psdatabaseclone.setup.status)) {
            Stop-PSFFunction -Message "The module setup has NOT yet successfully run. Please run 'Set-PSDCConfiguration'"
            return
        }

        # Get the information store
        $informationStore = Get-PSFConfigValue -FullName psdatabaseclone.informationstore.mode

        if ($informationStore -eq 'SQL') {
            # Get the module configurations
            $pdcSqlInstance = Get-PSFConfigValue -FullName psdatabaseclone.database.Server
            $pdcDatabase = Get-PSFConfigValue -FullName psdatabaseclone.database.name
            if (-not $PSDCSqlCredential) {
                $pdcCredential = Get-PSFConfigValue -FullName psdatabaseclone.informationstore.credential -Fallback $null
            }
            else {
                $pdcCredential = $PSDCSqlCredential
            }

            # Test the module database setup
            try {
                Test-PSDCConfiguration -SqlCredential $pdcCredential -EnableException
            }
            catch {
                Stop-PSFFunction -Message "Something is wrong in the module configuration" -ErrorRecord $_ -Continue
            }
        }

        # Get all the items
        $items = Get-PSDCImage

        if ($ImageID) {
            Write-PSFMessage -Message "Filtering image ids" -Level Verbose
            $items = $items | Where-Object {$_.ImageID -in $ImageID}
        }

        if ($ImageName) {
            Write-PSFMessage -Message "Filtering image name" -Level Verbose
            $items = $items | Where-Object {$_.ImageName -in $ImageName}
        }

        if ($ImageLocation) {
            Write-PSFMessage -Message "Filtering image locations" -Level Verbose
            $items = $items | Where-Object {$_.ImageLocation -in $ImageLocation}
        }

        if ($Database) {
            Write-PSFMessage -Message "Filtering databases" -Level Verbose
            $items = $items | Where-Object {$_.DatabaseName -in $Database}
        }

        if ($ExcludeDatabase) {
            Write-PSFMessage -Message "Filtering excluded databases" -Level Verbose
            $items = $items | Where-Object {$_.DatabaseName -notin $Database}
        }

        # Append the items
        $InputObject += $items
    }

    process {
        # Test if there are any errors
        if (Test-PSFFunctionInterrupt) { return }

        Write-PSFMessage -Message "Started removing database images" -Level Verbose

        # Group the objects to make it easier to go through
        $images = $InputObject | Group-Object ImageID

        foreach ($image in $images) {

            # Loop through each of the results
            foreach ($item in $image.Group) {

                # Make up the data from the network path
                try {
                    [uri]$uri = New-Object System.Uri($item.ImageLocation)
                    $uriHost = $uri.Host
                }
                catch {
                    Stop-PSFFunction -Message "The image location $ImageNetworkPath is not valid" -ErrorRecord $_ -Target $ImageNetworkPath
                    return
                }

                # Setup the computer object
                $computer = [PsfComputer]$uriHost

                if (-not $computer.IsLocalhost) {
                    # Get the result for the remote test
                    $resultPSRemote = Test-PSDCRemoting -ComputerName $uriHost -Credential $Credential

                    # Check the result
                    if ($resultPSRemote.Result) {

                        $command = [scriptblock]::Create("Import-Module PSDatabaseClone -Force")

                        try {
                            Invoke-PSFCommand -ComputerName $computer -ScriptBlock $command -Credential $Credential
                        }
                        catch {
                            Stop-PSFFunction -Message "Couldn't import module remotely" -Target $command
                            return
                        }
                    }
                    else {
                        Stop-PSFFunction -Message "Couldn't connect to host remotely.`nVerify that the specified computer name is valid, that the computer is accessible over the network, and that a firewall exception for the WinRM service is enabled and allows access from this computer" -Target $resultPSRemote -Continue
                    }
                }

                # Get the clones associated with the image
                $results = @()
                $results = Get-PSDCClone -ImageID $item.ImageID

                # Check the results
                if ($results.Count -ge 1) {
                    # Loop through the results
                    foreach ($result in $results) {
                        if ($PSCmdlet.ShouldProcess($item.CloneID, "Removing clone $($result.CloneLocation) from $($result.HostName)")) {
                            # Remove the clones for the host
                            try {
                                Write-PSFMessage -Message "Removing clones for host $($result.HostName) and database $($result.DatabaseName)" -Level Verbose
                                Remove-PSDCClone -HostName $result.HostName -Database $result.DatabaseName -PSDCSqlCredential $pdcCredential -Credential $Credential -Confirm:$false
                            }
                            catch {
                                Stop-PSFFunction -Message "Couldn't remove clones from host $($result.HostName)" -ErrorRecord $_ -Target $result -Continue
                            }
                        }
                    }
                }
                else {
                    Write-PSFMessage -Message "No clones were found created with image $($image.Name)" -Level Verbose
                }

                if ($PSCmdlet.ShouldProcess($item.ImageLocation, "Removing image from system")) {
                    # Remove the image from the file system
                    try {
                        if ($computer.IsLocalhost) {
                            if (Test-Path -Path $item.ImageLocation -Credential $Credential) {
                                Write-PSFMessage -Message "Removing image '$($item.ImageLocation)' from file system" -Level Verbose

                                $null = Remove-Item -Path $item.ImageLocation -Credential $Credential -Force:$Force
                            }
                            else {
                                Write-PSFMessage -Message "Couldn't find image $($item.ImageLocation)" -Level Verbose
                            }
                        }
                        else {
                            $command = [scriptblock]::Create("Test-Path -Path '$($item.ImageLocation)'")
                            $result = Invoke-PSFCommand -ComputerName $computer -ScriptBlock $command -Credential $Credential

                            if ($result) {
                                $command = [scriptblock]::Create("Remove-Item -Path '$($item.ImageLocation)' -Force")
                                $result = Invoke-PSFCommand -ComputerName $computer -ScriptBlock $command -Credential $Credential
                            }
                            else {
                                Write-PSFMessage -Message "Couldn't find image '$($item.ImageLocation)'" -Level Verbose
                            }
                        }
                    }
                    catch {
                        Stop-PSFFunction -Message "Couldn't remove image '$($item.ImageLocation)' from file system" -ErrorRecord $_ -Target $result
                    }
                }

                if ($PSCmdlet.ShouldProcess($item.ImageLocation, "Removing image from database")) {
                    if ($informationStore -eq 'SQL') {
                        # Remove the image from the database
                        try {
                            $query = "DELETE FROM dbo.Image WHERE ImageID = $($item.ImageID)"

                            $null = Invoke-DbaQuery -SqlInstance $pdcSqlInstance -SqlCredential $pdcCredential -Database $pdcDatabase -Query $query
                        }
                        catch {
                            Stop-PSFFunction -Message "Couldn't remove image '$($item.ImageLocation)' from database" -ErrorRecord $_ -Target $query
                        }
                    }
                    elseif ($informationStore -eq 'File') {
                        $imageData = Get-PSDCImage
                        [array]$newImageData = $null

                        $imageData = $imageData | Where-Object {$_.ImageID -ne $item.ImageID}

                        # Set the image file
                        $jsonImageFile = "PSDCJSONFolder:\images.json"

                        # Convert the data back to JSON
                        if ($newImageData.Count -ge 1) {
                            $imageData | ConvertTo-Json | Set-Content $jsonImageFile
                        }
                        else {
                            Clear-Content -Path $jsonImageFile
                        }

                    }
                }

            } # End for each item in group

        } # End for each image

    } # End process

    end {
        # Test if there are any errors
        if (Test-PSFFunctionInterrupt) { return }

        Write-PSFMessage -Message "Finished removing database image(s)" -Level Verbose
    }

}

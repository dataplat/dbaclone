function Invoke-PSDCCleanup {

    param(
        [object[]]$Item,
        [System.Management.Automation.PSCredential]
        $SqlCredential,
        [System.Management.Automation.PSCredential]
        $Credential
    )

    begin {
        # Reverse the order of the items to run backwards
        $cleanupItems = $Item | Sort-Object Number -Descending
    }

    process {
        # Loop through each of the items
        foreach ($item in $cleanupItems) {
            switch ($item.TypeName) {
                "FileInfo" {
                    try {
                        if (Test-Path -Path $item.Object.FullName) {
                            Remove-Item -Path $item.Object.FullName
                        }
                        else {
                            Write-PSFMessage -Message "Object $($item.TypeName) cdoesn't exist" -Level Verbose
                        }
                    }
                    catch {

                    }
                }

                "DirectoryInfo" {
                    try {
                        if (Test-Path -Path $item.Object.FullName) {
                            Remove-Item -Path $item.Object.FullName
                        }
                        else {
                            Write-PSFMessage -Message "Object $($item.TypeName) cdoesn't exist" -Level Verbose
                        }
                    }
                    catch {

                    }
                }

                "Database"{
                    $database = $item.Object
                    try{
                        Remove-DbaDatabase -SqlInstance $database.SqlInstance -Database $database.DatabaseName -SqlCredential $SqlCredential
                    }
                    catch{

                    }
                }

                "VirtualHardDisk" {
                    $item.Object
                    $vhd = $item.Object

                    # Dismount the VHD if it's attched
                    if ($vhd.Attached) {
                        try {
                            Dismount-VHD -Path $vhd.Path
                        }
                        catch {

                        }
                    }

                    # Remove the vhd
                    try {
                        if (Test-Path -Path $i.Object.FullName) {
                            Remove-Item -Path $vhd.Path
                        }
                        else {
                            Write-PSFMessage -Message "Object $($i.TypeName) cdoesn't exist" -Level Verbose
                        }

                    }
                    catch {

                    }

                }

            } # End switch

        } # For each cleanup item

    } # End process

    end {

    }
}
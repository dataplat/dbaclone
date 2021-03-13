function Mount-DcnVhd {

    param(
        [PsfComputer]$Computer,
        [string]$Path,
        [switch]$EnableException
    )

    # Check if computer is local
    if ($computer.IsLocalhost) {
        # Mount the disk
        $null = Mount-DiskImage -ImagePath "$($Path)"

        # Get the disk based on the name of the vhd
        $diskImage = Get-DiskImage -ImagePath $Path
        $disk = Get-Disk | Where-Object Number -eq $diskImage.Number
    }
    else {
        # Mount the disk
        $command = [ScriptBlock]::Create("Mount-DiskImage -ImagePath `"$($Path)`"")
        $null = Invoke-PSFCommand -ComputerName $computer -ScriptBlock $command -Credential $Credential

        # Get the disk based on the name of the vhd
        $command = [ScriptBlock]::Create("
                                `$diskImage = Get-DiskImage -ImagePath $($Path)
                                Get-Disk | Where-Object Number -eq $($diskImage.Number)
                            ")
        $disk = Invoke-PSFCommand -ComputerName $computer -ScriptBlock $command -Credential $Credential
    }

    return $disk

}
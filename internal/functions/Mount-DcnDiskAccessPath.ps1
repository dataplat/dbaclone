function Mount-DcnDiskAccessPath {

    param(
        [PsfComputer]$Computer,
        [object]$Disk,
        [string]$Path,
        [switch]$EnableException
    )

    # Check if computer is local
    if ($computer.IsLocalhost) {
        # Get the partition based on the disk
        $partition = Get-Partition -Disk $Disk | Where-Object { $_.Type -ne "Reserved" } | Select-Object -First 1

        # Create an access path for the disk
        $null = Add-PartitionAccessPath -DiskNumber $Disk.Number -PartitionNumber $partition.PartitionNumber -AccessPath $Path -ErrorAction SilentlyContinue
    }
    else {
        $command = [ScriptBlock]::Create("Get-Partition -DiskNumber $($Disk.Number)")
        $partition = Invoke-PSFCommand -ComputerName $computer -ScriptBlock $command -Credential $Credential | Where-Object { $_.Type -ne "Reserved" } | Select-Object -First 1

        $command = [ScriptBlock]::Create("Add-PartitionAccessPath -DiskNumber $($Disk.Number) -PartitionNumber $($partition.PartitionNumber) -AccessPath '$Path' -ErrorAction Ignore")

        $null = Invoke-PSFCommand -ComputerName $computer -ScriptBlock $command -Credential $Credential
    }

}
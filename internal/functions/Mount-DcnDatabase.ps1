function Mount-DcnDatabase {

    [CmdLetBinding(SupportsShouldProcess)]

    param(
        [PsfComputer]$Computer,
        [string]$Path,
        [DbaInstanceParameter]$SqlInstance,
        [pscredential]$SqlCredential,
        [string]$Database,
        [switch]$EnableException
    )

    # Get all the files of the database
    if ($computer.IsLocalhost) {
        $databaseFiles = Get-ChildItem -Path $Path -Filter *.*df -Recurse
    }
    else {
        $commandText = "Get-ChildItem -Path '$Path' -Filter *.*df -Recurse"
        $command = [ScriptBlock]::Create($commandText)
        $databaseFiles = Invoke-PSFCommand -ComputerName $computer -ScriptBlock $command -Credential $Credential
    }

    # Setup the database filestructure
    $dbFileStructure = New-Object System.Collections.Specialized.StringCollection

    # Loop through each of the database files and add them to the file structure
    foreach ($dbFile in $databaseFiles) {
        $null = $dbFileStructure.Add($dbFile.FullName)
    }

    # Mount the database
    if ($PSCmdlet.ShouldProcess($Database, "Mounting database $Database")) {
        try {
            Write-PSFMessage -Message "Mounting database from clone" -Level Verbose
            $null = Mount-DbaDatabase -SqlInstance $SqlInstance -SqlCredential $SqlCredential -Database $Database -FileStructure $dbFileStructure
        }
        catch {
            Stop-PSFFunction -Message "Couldn't mount database $Database" -ErrorRecord $_ -Target $SqlInstance -Continue
        }
    }

}
function Test-DcnPath {

    param(
        [PsfComputer]$Computer,
        [string]$Path,
        [pscredential]$Credential
    )

    if ($computer.IsLocalhost) {
        if (Test-Path -Path $Path -Credential $Credential) {
            return $true
        }
    }
    else {
        $command = [ScriptBlock]::Create("Test-Path -Path `"$($Path)`"")
        $result = Invoke-PSFCommand -ComputerName $computer -ScriptBlock $command -Credential $Credential
        if ($result) {
            return $true
        }
    }

    return $false
}
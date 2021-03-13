function New-DcnChildVhd {
    param(
        [PsfComputer]$Computer,
        [string]$Path,
        [string]$Vhd,
        [pscredential]$Credential
    )

    begin {
        # Set the location where to save the diskpart command
        $diskpartScriptFile = Get-PSFConfigValue -FullName dbaclone.diskpart.scriptfile -Fallback "$env:APPDATA\dbaclone\diskpartcommand.txt"

        if (-not (Test-Path -Path $diskpartScriptFile)) {
            try {
                $null = New-Item -Path $diskpartScriptFile -ItemType File
            }
            catch {
                Stop-PSFFunction -Message "Could not create diskpart script file" -ErrorRecord $_ -Continue
            }
        }
    }

    process {
        $command = "create vdisk file='$($Path)' parent='$ParentVhd'"

        # Check if computer is local
        if ($computer.IsLocalhost) {
            # Set the content of the diskpart script file
            Set-Content -Path $diskpartScriptFile -Value $command -Force

            $script = [ScriptBlock]::Create("diskpart /s $diskpartScriptFile")
            $null = Invoke-PSFCommand -ScriptBlock $script
        }
        else {
            $command = [ScriptBlock]::Create("New-VHD -ParentPath $ParentVhd -Path `"$($Path)`" -Differencing")
            $vhd = Invoke-PSFCommand -ComputerName $computer -ScriptBlock $command -Credential $Credential

            if (-not $vhd) {
                return
            }
        }
    }
}
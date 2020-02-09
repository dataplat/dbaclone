if (-not (Test-PSDCDatabaseClone -WindowsVersion)) {
    Stop-PSFFunction -Message "Unsupported version of Windows" -FunctionName 'Pre Import'
}

if (-not (Test-Path -Path "$env:APPDATA\psdatabaseclone")) {
    try {
        $null = New-Item -Path "$env:APPDATA\psdatabaseclone" -ItemType Directory -Force:$Force
    }
    catch {
        Stop-PSFFunction -Message "Something went wrong creating the working directory" -Target "$env:APPDATA\psdatabaseclone" -ErrorRecord $_ -FunctionName 'Pre Import'
    }
}



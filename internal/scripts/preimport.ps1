# Add all things you want to run before importing the main code

# Load the strings used in messages
. Import-ModuleFile -Path "$($script:ModuleRoot)\internal\scripts\strings.ps1"

if (-not (Test-Path -Path "$env:APPDATA\dbaclone")) {
    try {
        $null = New-Item -Path "$env:APPDATA\dbaclone" -ItemType Directory -Force:$Force
    }
    catch {
        Stop-PSFFunction -Message "Something went wrong creating the working directory" -Target "$env:APPDATA\dbaclone" -ErrorRecord $_ -FunctionName 'Pre Import'
    }
}

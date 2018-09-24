# constants
if (Test-Path C:\temp\constants.ps1) {
    Write-Verbose "C:\temp\constants.ps1 found."
    . C:\temp\constants.ps1
}
elseif (Test-Path "$PSScriptRoot\constants.local.ps1") {
    Write-Verbose "tests\constants.local.ps1 found."
    . "$PSScriptRoot\constants.local.ps1"
}
else {
    $script:workingfolder = "C:\projects"
    $script:jsonfolder = "C:\projects\config"
    $script:imagefolder = "C:\projects\images"
    $script:clonefolder = "C:\projects\clones"
}

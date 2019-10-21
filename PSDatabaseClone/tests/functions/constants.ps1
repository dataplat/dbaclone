# constants
if (Test-Path C:\temp\constants_pstsqlttestgenerator.ps1) {
    Write-Verbose "C:\temp\constants_psdatabaseclone.ps1 found."
    . C:\temp\constants_psdatabaseclone.ps1
}
else {
    $script:computer = "localhost"
    $script:sqlinstance = "localhost\SQL2017"
    $script:database = "UnitTesting_Tests"
    $script:workingfolder = "C:\projects\"
    $script:clonefolder = (Join-Path -Path $script:workingfolder -ChildPath "clone")
}

if ($env:appveyor) {
    $PSDefaultParameterValues['*:WarningAction'] = 'SilentlyContinue'
}
# constants
if (Test-Path C:\temp\constants_pstsqlttestgenerator.ps1) {
    Write-Verbose "C:\temp\constants_psdatabaseclone.ps1 found."
    . C:\temp\constants_psdatabaseclone.ps1
}
else {
    $script:computer = "localhost"
    $script:sourcesqlinstance = "localhost\SQL2017"
    $script:destinationsqlinstance = "localhost\SQL2017"
    $script:database = "PSDatabaseClone_Tests"
    $script:workingfolder = "C:\projects\psdc"
    $script:psdcshare = "psdc"
    $script:images = "images"
    $script:imagefolder = (Join-Path -Path $script:workingfolder -ChildPath "images")
    $script:clones = "clones"
    $script:clonefolder = (Join-Path -Path $script:workingfolder -ChildPath "clones")
}

if ($env:appveyor) {
    $PSDefaultParameterValues['*:WarningAction'] = 'SilentlyContinue'
}
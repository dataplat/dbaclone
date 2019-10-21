<#
This script publishes the module to the gallery.
It expects as input an ApiKey authorized to publish the module.

Insert any build steps you may need to take before publishing it here.
#>
param (
    $ApiKey,

    $WorkingDirectory,

    $Repository = 'PSGallery',

    [switch]
    $LocalRepo,

    [switch]
    $SkipPublish,

    [switch]
    $AutoVersion
)

# region ApiKey defaults
if (-not $ApiKey) {
    $ApiKey = $($env:psgallery_apiKey)
}

#region Handle Working Directory Defaults
if (-not $WorkingDirectory) {
    if ($env:RELEASE_PRIMARYARTIFACTSOURCEALIAS) {
        $WorkingDirectory = Join-Path -Path $env:SYSTEM_DEFAULTWORKINGDIRECTORY -ChildPath $env:RELEASE_PRIMARYARTIFACTSOURCEALIAS
    }
    else { $WorkingDirectory = $env:workingdirectory }
}
#endregion Handle Working Directory Defaults

# Prepare publish folder
try {
    Write-PSFMessage -Level Important -Message "Creating and populating publishing directory"
    $publishDir = New-Item -Path $WorkingDirectory -Name publish -ItemType Directory
    Copy-Item -Path "$($WorkingDirectory)\PStSQLtTestGenerator" -Destination $publishDir.FullName -Recurse -Force
}
catch {
    Stop-PSFFunction -Message "Something went wrong creating and populating publishing directory" -Target $publishDir -ErrorRecord $_
    return
}

# region remove unneccesary directories
try {
    Remove-Item -Path "$($publishDir.FullName)\PStSQLtTestGenerator\appveyor.yml" -Force -Recurse
    Remove-Item -Path "$($publishDir.FullName)\PStSQLtTestGenerator\build" -Force -Recurse
    Remove-Item -Path "$($publishDir.FullName)\PStSQLtTestGenerator\resources" -Force -Recurse
    Remove-Item -Path "$($publishDir.FullName)\PStSQLtTestGenerator\tests" -Force -Recurse
}
catch {
    Stop-PSFFunction -Message "Could not remove directories" -Target $publishDir.FullName -ErrorRecord $_
    return
}
# end region

#region Gather text data to compile
$text = @()
$processed = @()

# Gather Stuff to run before
foreach ($line in (Get-Content "$($PSScriptRoot)\filesBefore.txt" | Where-Object { $_ -notlike "#*" })) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }

    $basePath = Join-Path -Path "$($publishDir.FullName)\PStSQLtTestGenerator" -ChildPath $line
    foreach ($entry in (Resolve-PSFPath -Path $basePath)) {
        $item = Get-Item $entry
        if ($item.PSIsContainer) { continue }
        if ($item.FullName -in $processed) { continue }
        $text += [System.IO.File]::ReadAllText($item.FullName)
        $processed += $item.FullName
    }
}

# Gather commands
Get-ChildItem -Path "$($publishDir.FullName)\PStSQLtTestGenerator\internal\functions\" -Recurse -File -Filter "*.ps1" | ForEach-Object {
    $text += [System.IO.File]::ReadAllText($_.FullName)
}
Get-ChildItem -Path "$($publishDir.FullName)\PStSQLtTestGenerator\functions\" -Recurse -File -Filter "*.ps1" | ForEach-Object {
    $text += [System.IO.File]::ReadAllText($_.FullName)
}

# Gather stuff to run afterwards
foreach ($line in (Get-Content "$($PSScriptRoot)\filesAfter.txt" | Where-Object { $_ -notlike "#*" })) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }

    $basePath = Join-Path "$($publishDir.FullName)\PStSQLtTestGenerator" $line
    foreach ($entry in (Resolve-PSFPath -Path $basePath)) {
        $item = Get-Item $entry
        if ($item.PSIsContainer) { continue }
        if ($item.FullName -in $processed) { continue }
        $text += [System.IO.File]::ReadAllText($item.FullName)
        $processed += $item.FullName
    }
}
#endregion Gather text data to compile

#region Update the psm1 file
$fileData = Get-Content -Path "$($publishDir.FullName)\PStSQLtTestGenerator\PStSQLtTestGenerator.psm1" -Raw
$fileData = $fileData.Replace('"<was not compiled>"', '"<was compiled>"')
$fileData = $fileData.Replace('"<compile code into here>"', ($text -join "`n`n"))
[System.IO.File]::WriteAllText("$($publishDir.FullName)\PStSQLtTestGenerator\PStSQLtTestGenerator.psm1", $fileData, [System.Text.Encoding]::UTF8)
#endregion Update the psm1 file

#region Updating the Module Version
Write-PSFMessage -Level Important -Message "Branch: $($env:APPVEYOR_REPO_BRANCH)"
#if ($env:APPVEYOR_REPO_BRANCH -eq 'master') {
if ($SkipPublish) { return }
if ($AutoVersion) {
    Write-PSFMessage -Level Important -Message "Updating module version numbers."
    try { [version]$remoteVersion = (Find-Module 'PStSQLtTestGenerator' -Repository $Repository -ErrorAction Stop).Version }
    catch {
        Stop-PSFFunction -Message "Failed to access $($Repository)" -EnableException $true -ErrorRecord $_
    }
    if (-not $remoteVersion) {
        Stop-PSFFunction -Message "Couldn't find PStSQLtTestGenerator on repository $($Repository)" -EnableException $true
    }
    $newBuildNumber = $remoteVersion.Build + 1
    [version]$localVersion = (Import-PowerShellDataFile -Path "$($publishDir.FullName)\PStSQLtTestGenerator\PStSQLtTestGenerator.psd1").ModuleVersion
    Update-ModuleManifest -Path "$($publishDir.FullName)\PStSQLtTestGenerator\PStSQLtTestGenerator.psd1" -ModuleVersion "$($localVersion.Major).$($localVersion.Minor).$($newBuildNumber)"
}

#region Publish
if ($LocalRepo) {
    # Dependencies must go first
    Write-PSFMessage -Level Important -Message "Creating Nuget Package for module: PSFramework"
    New-PSMDModuleNugetPackage -ModulePath (Get-Module -Name PSFramework).ModuleBase -PackagePath .
    Write-PSFMessage -Level Important -Message "Creating Nuget Package for module: PStSQLtTestGenerator"
    New-PSMDModuleNugetPackage -ModulePath "$($publishDir.FullName)\PStSQLtTestGenerator" -PackagePath .
}
else {
    # Publish to Gallery
    Write-PSFMessage -Level Important -Message "Publishing the PStSQLtTestGenerator module to $($Repository)"
    Publish-Module -Path "$($publishDir.FullName)\PStSQLtTestGenerator" -NuGetApiKey $ApiKey -Force -Repository $Repository
}
#endregion Updating the Module Version


#endregion Publish
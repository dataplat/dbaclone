# constants
#$publishDir = "C:\Projects"
$publishDir = $env:workingfolder
Write-Host "Working folder: $publishDir"
$workingfolder = "$($publishDir)\psdc"
$jsonfolder = "$workingfolder\config"
$imagefolder = "$workingfolder\images"
$clonefolder = "$workingfolder\clones"

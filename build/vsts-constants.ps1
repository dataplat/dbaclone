# constants
$publishDir = New-Item -Path $env:SYSTEM_DEFAULTWORKINGDIRECTORY -Name publish -ItemType Directory
$rootPath = "$($publishDir.FullName)\psdc"
$workingfolder = "$rootPath"
$jsonfolder = "$rootPath\config"
$imagefolder = "$rootPath\images"
$clonefolder = "$rootPath\clones"

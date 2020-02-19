
[array]$availableImages = Get-DcnImage

$imageIds = [scriptblock]::Create($availableImages.ImageID -join ",")
$imageNames = [scriptblock]::Create("'$($availableImages.ImageName -join "','")'")
$imageDbNames = [scriptblock]::Create("'$($availableImages.DatabaseName -join "','")'")
$imageLocations = [scriptblock]::Create("'$($availableImages.ImageLocation -join "','")'")

Register-PSFTeppScriptblock -Name "dbaclone.images.id" -ScriptBlock $imageIds
Register-PSFTeppScriptblock -Name "dbaclone.images.name" -ScriptBlock $imageNames
Register-PSFTeppScriptblock -Name "dbaclone.images.database" -ScriptBlock $imageDbNames
Register-PSFTeppScriptblock -Name "dbaclone.images.location" -ScriptBlock $imageLocations

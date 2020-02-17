
[array]$availableClones = Get-DcnClone

$cloneIds = [scriptblock]::Create($availableClones.CloneID -join ",")
$cloneDbNames = [scriptblock]::Create("'$($availableClones.DatabaseName -join "','")'")
$cloneHostnames = [scriptblock]::Create("'$($availableClones.HostName -join "','")'")
$cloneImageIds = [scriptblock]::Create($availableClones.ImageID -join ",")
$cloneImageNames = [scriptblock]::Create("'$($availableClones.ImageName -join "','")'")

Register-PSFTeppScriptblock -Name "dbaclone.clones.id" -ScriptBlock $cloneIds
Register-PSFTeppScriptblock -Name "dbaclone.clones.databasename" -ScriptBlock $cloneDbNames
Register-PSFTeppScriptblock -Name "dbaclone.clones.hostname" -ScriptBlock $cloneHostnames
Register-PSFTeppScriptblock -Name "dbaclone.clones.imageid" -ScriptBlock $cloneImageIds
Register-PSFTeppScriptblock -Name "dbaclone.clones.imagename" -ScriptBlock $cloneImageNames

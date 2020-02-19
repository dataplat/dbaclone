<#
# Example:
Register-PSFTeppArgumentCompleter -Command Get-Alcohol -Parameter Type -Name dbaclone.alcohol
#>

# Image commands
Register-PSFTeppArgumentCompleter -Command Get-DcnImage -Parameter ImageID -Name 'dbaclone.images.id'
Register-PSFTeppArgumentCompleter -Command Get-DcnImage -Parameter ImageName -Name 'dbaclone.images.name'

Register-PSFTeppArgumentCompleter -Command Remove-DcnImage -Parameter Database -Name 'dbaclone.images.database'
Register-PSFTeppArgumentCompleter -Command Remove-DcnImage -Parameter ImageID -Name 'dbaclone.images.id'
Register-PSFTeppArgumentCompleter -Command Remove-DcnImage -Parameter ImageName -Name 'dbaclone.images.name'
Register-PSFTeppArgumentCompleter -Command Remove-DcnImage -Parameter ImageLocation -Name 'dbaclone.images.location'

# Clone commands
Register-PSFTeppArgumentCompleter -Command Get-DcnClone -Parameter Database -Name 'dbaclone.clones.databasename'
Register-PSFTeppArgumentCompleter -Command Get-DcnClone -Parameter HostName -Name 'dbaclone.clones.hostname'
Register-PSFTeppArgumentCompleter -Command Get-DcnClone -Parameter ImageID -Name 'dbaclone.clones.imageid'
Register-PSFTeppArgumentCompleter -Command Get-DcnClone -Parameter ImageName -Name 'dbaclone.clones.imagename'

Register-PSFTeppArgumentCompleter -Command Invoke-DcnRepairClone -Parameter HostName -Name 'dbaclone.clones.hostname'

Register-PSFTeppArgumentCompleter -Command New-DcnClone -Parameter Database -Name 'dbaclone.images.database'

Register-PSFTeppArgumentCompleter -Command Remove-DcnClone -Parameter Database -Name 'dbaclone.clones.databasename'
Register-PSFTeppArgumentCompleter -Command Remove-DcnClone -Parameter HostName -Name 'dbaclone.clones.hostname'




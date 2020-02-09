function Test-PSDCDatabaseClone {

    param(
        [switch]$SetupStatus
    )

    begin {

    }

    process {
        if ($SetupStatus) {
            if (-not (Get-PSFConfigValue -FullName psdatabaseclone.setup.status)) {
                return $false
            }
            else {
                return $true
            }
        }
    }

}
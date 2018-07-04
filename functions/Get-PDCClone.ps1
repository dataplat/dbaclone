function Get-PDCClone {
<#
.SYNOPSIS
    Get-PDCClone get on or more clones

.DESCRIPTION
    Get-PDCClone will retrieve the clones and apply filters if needed.
    By default all the clones are returned

.PARAMETER HostName
    Filter based on the hostname

.PARAMETER Database
    Filter based on the database

.PARAMETER ImageID
    Filter based on the image id

.PARAMETER ImageName
    Filter based on the image name

.PARAMETER ImageLocation
    Filter based on the image location

.NOTES
    Author: Sander Stad (@sqlstad, sqlstad.nl)

    Website: https://psdatabaseclone.io
    Copyright: (C) Sander Stad, sander@sqlstad.nl
    License: MIT https://opensource.org/licenses/MIT

.LINK
    https://psdatabaseclone.io/

.EXAMPLE
    Get-PDCClone -HostName host1, host2

    Retrieve the clones for host1 and host2

.EXAMPLE
    Get-PDCClone -Database DB1

    Get all the clones that have the name DB1

.EXAMPLE
    Get-PDCClone -ImageName DB1_20180703085917

    Get all the clones that were made with image "DB1_20180703085917"
#>

    [CmdLetBinding()]

    param(
        [string[]]$HostName,
        [string[]]$Database,
        [int[]]$ImageID,
        [string[]]$ImageName,
        [string[]]$ImageLocation
    )

    begin {

        # Test the module database setup
        try {
            Test-PDCConfiguration -EnableException
        }
        catch {
            Stop-PSFFunction -Message "Something is wrong in the module configuration" -ErrorRecord $_ -Continue
        }

        $pdcSqlInstance = Get-PSFConfigValue -FullName psdatabaseclone.database.server
        $pdcDatabase = Get-PSFConfigValue -FullName psdatabaseclone.database.name

    }

    process {

        # Test if there are any errors
        if (Test-PSFFunctionInterrupt) { return }

        $query = "
            SELECT c.CloneID,
                c.CloneLocation,
                c.AccessPath,
                c.SqlInstance,
                c.DatabaseName,
                c.IsEnabled,
                i.ImageID,
                i.ImageName,
                i.ImageLocation,
                h.HostName
            FROM dbo.Clone AS c
                INNER JOIN dbo.Host AS h
                    ON h.HostID = c.HostID
                INNER JOIN dbo.Image AS i
                    ON i.ImageID = c.ImageID;
            "

        try {
            $results = Invoke-DbaSqlQuery -SqlInstance $pdcSqlInstance -Database $pdcDatabase -Query $query -As PSObject
        }
        catch {
            Stop-PSFFunction -Message "Could not execute query" -ErrorRecord $_ -Target $query
        }

        # Filter host name
        if($HostName){
            $results = $results | Where-Object {$_.HostName -in $HostName}
        }

        # Filter image id
        if($Database){
            $results = $results | Where-Object {$_.DatabaseName -in $Database}
        }

        # Filter image id
        if($ImageID){
            $results = $results | Where-Object {$_.ImageID -in $ImageID}
        }

        # Filter image name
        if($ImageName){
            $results = $results | Where-Object {$_.ImageName -in $ImageName}
        }

        # Filter image location
        if($ImageLocation){
            $results = $results | Where-Object {$_.ImageLocation -in $ImageLocation}
        }

        return $results
    }

    end {

        # Test if there are any errors
        if (Test-PSFFunctionInterrupt) { return }

        Write-PSFMessage -Message "Finished retrieving clone(s)" -Level Verbose

    }

}
function New-PSDCRandomName {
    <#
    .SYNOPSIS
        Generates a list of random names

    .DESCRIPTION
        The command can generate a list of random names.
        The choices are first names, last names or both.
        Another choice is to have either male, female or both type names. The default is both female and male.

    .PARAMETER Amount
        Amount of names to be generated

    .PARAMETER NameType
        Type of name to be generated.
        This can either be first names, last names or full names

    .NOTES
        Author: Sander Stad (@sqlstad, sqlstad.nl)

        Website: https://psdatabaseclone.org
        Copyright: (C) Sander Stad, sander@sqlstad.nl
        License: MIT https://opensource.org/licenses/MIT

    .LINK
        https://psdatabaseclone.org/

    .EXAMPLE
        New-RandomName -Amount 10 -NameType Firstname

        Generates 10 randomfirst names

    .EXAMPLE
        New-RandomName -Amount 5

        Generates 5 random names and return th first name, last name and full name

    #>

    [OutputType('System.Array')]
    [OutputType('System.Object')]

    param(
        [parameter(Mandatory = $true)]
        [int]$Amount,
        [ValidateSet('Firstname', 'Lastname', 'Fullname', 'All')]
        [string[]]$NameType,
        [switch]$Male,
        [switch]$Female
    )

    begin {
        # Setup the path
        $resourcePath = "$($MyInvocation.MyCommand.Module.ModuleBase)\internal\resources\datamasking"

        # Check amount
        if ($Amount -lt 1) {
            Stop-PSFFunction -Message "Please enter a number greater than 0"
        }

        # Check name type
        if (-not $NameType) {
            Write-PSFMessage -Message "Setting name type to 'All'" -Level Verbose
            $NameType = 'All'
        }

        # Check the genders
        if($Female -and $Male){
            Stop-PSFFunction -Message "Please enter either -Female or -Male. The default is both female and male."
        }

        # Declare arrays
        $firstNames = @()
        $lastNames = @()
        $fullNames = @()

        # Loop through each of the name types
        foreach($type in $NameType){
            if($type -in ('Firstname', 'Fullname', 'All')){
                if($Female){
                    $filePath = "$resourcePath\firstnames_female.txt"
                }
                elseif($Male){
                    $filePath = "$resourcePath\firstnames_male.txt"
                }
                else{
                    $filePath = "$resourcePath\firstnames_all.txt"
                }

                $firstNames = Get-Content -Path $filePath
            }

            if($type -in ('Lastname', 'Fullname', 'All')){
                $lastNames = Get-Content -Path "$resourcePath\lastnames_all.txt"
            }
        }

        # Check the amount does not exceed the maximum possible
        if($firstNames.Count -eq 0) { $maxFirstNames = 1 } else { $maxFirstNames = $firstNames.Count }
        if($lastNames.Count -eq 0) { $maxLastNames = 1 } else { $maxLastNames = $lastNames.Count }
        $maxAmount = $maxFirstNames * $maxLastNames

        if($Amount -gt $maxAmount){
            Stop-PSFFunction -Message "The amount of names to generate can not be more than $maxAmount"
        }

    }

    process {
        # Generate the amount of names
        for ($i = 0; $i -lt $Amount; $i++) {
            $firstname = $null
            $lastName = $null

            # Get the names from the arrays
            if(($NameType -contains 'Firstname') -or ($NameType -contains 'All') -or ($NameType -contains 'Fullname')){
                $random = Get-Random -Minimum 0 -Maximum $firstNames.Count

                $firstName = $firstNames[$random]
            }

            if(($NameType -contains 'Lastname') -or ($NameType -contains 'All') -or ($NameType -contains 'Fullname')){
                $random = Get-Random -Minimum 0 -Maximum $lastNames.Count

                $lastname = $lastNames[$random]
            }

            # Setup the full names when neccesary
            if(($NameType -contains 'Fullname') -or ($NameType -contains 'All')){
                $fullName = "$($firstName) $($lastName)"
            }

            [PSCustomObject]@{
                FirstName   = $firstName
                LastName   = $lastName
                FullName    = $fullName
            }

        } # end for amount

    } # end process
}
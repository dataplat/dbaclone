function New-PSDCRandomItem {
    <#
    .SYNOPSIS
        Generates a list of random items

    .DESCRIPTION
        The command can generate a list of random iems.
        This can be credit cards, IBAN numbers etc

    .PARAMETER Amount
        Amount of names to be generated

    .PARAMETER Type
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


    .EXAMPLE


    #>

    [OutputType('System.Array')]
    [OutputType('System.Object')]

    param(
        [parameter(Mandatory = $true)]
        [int]$Amount,
        [ValidateSet('CreditCard', 'IBAN')]
        [string[]]$NameType,
        [switch]$Male,
        [switch]$Female
    )


}
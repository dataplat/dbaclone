function New-PSDCRandomCreditCard {
    <#
    .SYNOPSIS
        Generates a list of random credit card numbers

    .DESCRIPTION
        The command can generate a list of random credit card numbers.
        This can be either MasterCard, AmericanExpress, DinersClub, Discover. By default it's MasterCard.

    .PARAMETER Amount
        Amount of credit card numbers to be generated

    .PARAMETER Type
        Type of credit card to be generated.

    .NOTES
        Author: Sander Stad (@sqlstad, sqlstad.nl)

        Website: https://psdatabaseclone.org
        Copyright: (C) Sander Stad, sander@sqlstad.nl
        License: MIT https://opensource.org/licenses/MIT

    .LINK
        https://psdatabaseclone.org/

    .EXAMPLE
        New-RandomCreditCard -Amount 5 -Type MasterCard

        Generate 5 random MasterCard creditcard numbers


    #>

    [OutputType('System.Array')]
    [OutputType('System.Object')]

    param(
        [parameter(Mandatory = $true)]
        [int]$Amount,
        [ValidateSet('MasterCard', 'AmericanExpress', 'DinersClub', 'Discover')]
        [string[]]$Type
    )

    begin {
        [string]$MasterCard = "^(?:5[1-5][0-9]{2}|222[1-9]|22[3-9][0-9]|2[3-6][0-9]{2}|27[01][0-9]|2720)[0-9]{12}$"
        [string]$AmericanExpress = "^3[47][0-9]{13}$"
        [string]$DinersClub = "^3(?:0[0-5]|[68][0-9])[0-9]{11}$"
        [string]$Discover = "^6(?:011|5[0-9]{2})[0-9]{12}$"

        if(-not $Type){
            $type = 'MasterCard'
        }

        switch($Type){
            'MasterCard' {
                $creditCard = New-Object Fare.Xeger($MasterCard)
            }
            'AmericanExpress' {
                $creditCard = New-Object Fare.Xeger($AmericanExpress)
            }
            'DinersClub' {
                $creditCard = New-Object Fare.Xeger($DinersClub)
            }
            'Discover' {
                $creditCard = New-Object Fare.Xeger($Discover)
            }
        }
    }

    process{
        $result = @()

        for($i = 0; $i -lt $Amount; $i++){
            $result += $creditCard.Generate()
        }

        return $result

    }

}
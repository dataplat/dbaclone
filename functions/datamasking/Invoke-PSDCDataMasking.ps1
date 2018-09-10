function Invoke-PSDCDataMasking {

    function GenerateRandomName {

    }

    [string]$IBAN = "^[A-Z]{2}(?:[ ]?[0-9]){18,20}$"
    [string]$BBAN = "^([A-Z]{2}[ \\-]?[0-9]{2})(?=(?:[ \\-]?[A-Z0-9]){9,30}$)((?:[ \\-]?[A-Z0-9]{3,5}){2,7})([ \\-]?[A-Z0-9]{1,3})?$";


    [string]$MasterCard = "^(?:5[1-5][0-9]{2}|222[1-9]|22[3-9][0-9]|2[3-6][0-9]{2}|27[01][0-9]|2720)[0-9]{12}$"
    [string]$AmericanExpress = "^3[47][0-9]{13}$"
    [string]$DinersClub = "^3(?:0[0-5]|[68][0-9])[0-9]{11}$"
    [string]$Discover = "^6(?:011|5[0-9]{2})[0-9]{12}$"


    $creditCardNumber = New-Object Fare.Xeger($MasterCard)

    $creditCardNumber.Generate()
    $creditCardNumber.Generate()
    $creditCardNumber.Generate()
    $creditCardNumber.Generate()
    $creditCardNumber.Generate()
}
$firstNames = Get-Content "C:\Users\sande\OneDrive\_Development\PowerShell\sanderstad\PSDatabaseClone\internal\resources\datamasking\firstnames_all.txt"

$firstNames.Count

$lastNames = Get-Content "C:\Users\sande\OneDrive\_Development\PowerShell\sanderstad\PSDatabaseClone\internal\resources\datamasking\lastnames_all.txt"

$lastNames.Count

$numbers = @()

for($i = 0; $i -lt 1000; $i++){
    $random = Get-Random -Minimum 0 -Maximum ($firstNames.Count * $lastNames.Count)
    $numbers += $random
    Start-Sleep -Milliseconds 2
}

$numbers.Count

$numbers.Count | Select-Object -Unique

$numbers = $numbers | Sort-Object

$numbers[0]

$numbers[-1]
function Invoke-PSDCCleanup{

    param(
        [object[]]$Item
    )

    begin{
        # Reverse the order of the items to run backwards
        $cleanupItems = $Item | Sort-Object Number -Descending
    }

    process{

        foreach($i in $cleanupItems){
            switch($i.TypeName){
                "FileInfo" {
                    try{
                        Remove-Item -Path $i.Object.FullName
                    }
                    catch{

                    }
                }

                "DirectoryInfo" {
                    try{
                        Remove-Item -Path $i.Object.FullName
                    }
                    catch{

                    }
                }

                "VirtualHardDisk" {
                    $i.Object
                    $vhd = $i.Object

                    # Dismount the VHD if it's attched
                    if($vhd.Attached){
                        try{
                            Dismount-VHD -Path $vhd.Path
                        }
                        catch{

                        }
                    }

                    # Remove the vhd
                    try{
                        Remove-Item -Path $vhd.Path
                    }
                    catch{

                    }

                }
            }
        }

    }

    end{

    }
}

$list = @()

$secpasswd = ConvertTo-SecureString "75RknS0w" -AsPlainText -Force
$mycreds = New-Object System.Management.Automation.PSCredential ("FUZZYLION\Sander", $secpasswd)

$item = New-Item -Path "C:\Temp\clean\file1.txt" -Force
$list += [PSCustomObject]@{
    Number = ($list.Count + 1)
    TypeName = $item.GetType().Name
    TypeBase = $item.GetType().BaseType
    Object = $item
}

$command = [scriptblock]::Create("Get-VHD -Path `"D:\PSDatabaseClone\images\QA_20180710220741.vhdx`"")
$item = Invoke-PSFCommand -ComputerName SQLDB1 -ScriptBlock $command -Credential $mycreds

$list += [PSCustomObject]@{
    Number = ($list.Count + 1)
    TypeName = "VirtualHardDisk"
    TypeBase = "Microsoft.HyperV.PowerShell.VirtualizationObject"
    Object = $item
}

<# $list += [PSCustomObject]@{
    Number = ($list.Count + 1)
    TypeName = $item.GetType().Name
    TypeBase = $item.GetType().BaseType
    Object = $item
} #>

$item = New-Item -Path "C:\Temp\clean\folder1" -ItemType Directory -Force
$list += [PSCustomObject]@{
    Number = ($list.Count + 1)
    TypeName = $item.GetType().Name
    TypeBase = $item.GetType().BaseType
    Object = $item
}

Start-Sleep -Seconds 5

Invoke-PSDCCleanup -Item $list
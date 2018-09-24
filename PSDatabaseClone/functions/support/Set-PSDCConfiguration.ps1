function Set-PSDCConfiguration {
    <#
    .SYNOPSIS
        Set-PSDCConfiguration sets up the module

    .DESCRIPTION
        For the module to work properly the module needs a couple of settings.
        The most important settings are the ones for the database to store the information
        about the images and the clones.

        The configurations will be saved in the registry of Windows for all users.

        If the database does not yet exist on the server it will try to create the database.
        After that the objects for the database will be created.

    .PARAMETER InformationStore
        Where is the information going to be stored.
        This can be either a SQL Server database or files formatted as JSON.

        SQL Server has the advantage of being more reliable and have all the information available
        JSON files have a small footprint, are fast and don't require a database server

        The best way to save the JSON files is in a network share to make is possible for other
        clients to get the information.

        The default is to save the data in JSON files.

    .PARAMETER SqlInstance
        SQL Server name or SMO object representing the SQL Server to connect to

    .PARAMETER SqlCredential
        Allows you to login to servers using SQL Logins as opposed to Windows Auth/Integrated/Trusted. To use:

        $scred = Get-Credential, then pass $scred object to the -SqlCredential parameter.

        Windows Authentication will be used if SqlCredential is not specified. SQL Server does not accept Windows credentials being passed as credentials.
        To connect as a different Windows user, run PowerShell as that user.

    .PARAMETER Credential
        Allows you to login to servers or use authentication to access files and folder/shares

        $scred = Get-Credential, then pass $scred object to the -Credential parameter.

    .PARAMETER Database
        Database to use to save all the information in

    .PARAMETER Path
        Path where the JSON files will be created

    .PARAMETER InputPrompt
        Use this parameter to get a question to put in values using user input

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .PARAMETER WhatIf
        If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.

    .PARAMETER Confirm
        If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.

    .PARAMETER Force
        Forcefully create items when needed

    .NOTES
        Author: Sander Stad (@sqlstad, sqlstad.nl)

        Website: https://psdatabaseclone.org
        Copyright: (C) Sander Stad, sander@sqlstad.nl
        License: MIT https://opensource.org/licenses/MIT

    .LINK
        https://psdatabaseclone.org/

    .EXAMPLE
        Set-PSDCConfiguration -SqlInstance SQLDB1 -Database PSDatabaseClone

        Set up the module to use SQLDB1 as the database servers and PSDatabaseClone to save the values in

    .EXAMPLE
        Set-PSDCConfiguration

        The user will be prompted to enter the information to configure the module
    #>
    [CmdLetBinding(SupportsShouldProcess = $true, DefaultParameterSetName = "Prompt")]

    param(
        [parameter(ParameterSetName = "File")]
        [parameter(ParameterSetName = "SQL")]
        [ValidateSet('SQL', 'File')]
        [string]$InformationStore = 'File',
        [parameter(ParameterSetName = "SQL", Mandatory = $true)]
        [object]$SqlInstance,
        [parameter(ParameterSetName = "SQL")]
        [System.Management.Automation.PSCredential]
        $SqlCredential,
        [parameter(ParameterSetName = "SQL")]
        [string]$Database,
        [parameter(ParameterSetName = "File", Mandatory = $true)]
        [string]$Path,
        [parameter(ParameterSetName = "File")]
        [System.Management.Automation.PSCredential]
        $Credential,
        [switch]$EnableException,
        [parameter(ParameterSetName = "Prompt")]
        [switch]$InputPrompt,
        [switch]$Force
    )

    begin {
        Write-PSFMessage -Message "Started PSDatabaseClone Setup" -Level Output

        # Check if the user needs to be asked for user input
        if ($InputPrompt -or ($InformationStore -notin 'SQL', 'File') -or (-not $SqlInstance -and -not $SqlInstance -and -not $Credential -and -not $Database)) {
            # Setup the choices for the user
            $choiceDatabase = New-Object System.Management.Automation.Host.ChoiceDescription '&Database', 'Save the information in a database'
            $choiceDatabase.HelpMessage = "Choose to have the information saved in a database. This is reliable and is the default choice"
            $choiceJSON = New-Object System.Management.Automation.Host.ChoiceDescription '&JSON', 'Save the information in JSON files'
            $choiceJSON.HelpMessage = "If you don't want to rely on a database you can choose JSON to save your information. "

            # Create the options
            $options = [System.Management.Automation.Host.ChoiceDescription[]]($choiceDatabase, $choiceJSON)

            # Set extra information for the prompt
            $title = 'Choose your system'
            $message = 'Where do you want your data to be saved?'

            # Present the user with the choices
            $resultSystem = $host.ui.PromptForChoice($title, $message, $options, 0)

            if ($resultSystem -eq 0) {
                # Database
                $SqlInstance = Read-Host ' - Please enter the SQL Server instance'
                $Database = Read-Host ' - Database Name [PSDatabaseClone]'
                $databaseUser = Read-Host ' - Database Login'
                $databasePass = Read-Host ' - Password' -AsSecureString

                # If the credentials are entered create the credential object
                if (($DatabaseUser -ne '') -and (($databasePass -ne '') -or ($null -ne $databasePass))) {
                    $SqlCredential = New-Object System.Management.Automation.PSCredential ($databaseUser, $databasePass)
                }

                # Set the flag for the new database
                [bool]$newDatabase = $false

                # Set the variable for the information store
                $InformationStore = 'SQL'
            }
            elseif ($resultSystem -eq 1) {
                # Make sure other variables are not set
                $SqlInstance = $null
                $Database = $null
                $SqlCredential = $null

                # Database
                $filePath = Read-Host ' - Please enter the path to save the files to'
                $fileUser = Read-Host ' - Login (Optional)'
                $filePass = Read-Host ' - Password (Optional)' -AsSecureString

                # If the credentials are entered create the credential object
                if (($fileUser -ne '') -and (($filePass -ne '') -or ($null -ne $filePass))) {
                    $Credential = New-Object System.Management.Automation.PSCredential ($fileUser, $filePass)
                }

                # Clean up the file path
                if ($filePath.EndsWith("\")) {
                    $filePath = $filePath.Substring(0, $filePath.Length - 1)
                }

                # Check the file path
                if ($filePath.StartsWith("\\")) {
                    # Make up the data from the network path
                    try {
                        # Convert to uri
                        [uri]$uri = New-Object System.Uri($filePath)
                        $uriHost = $uri.Host

                        # Setup the computer object
                        $computer = [PsfComputer]$uriHost

                        # Check if the path is reachable
                        $command = [scriptblock]::Create("Test-Path -Path $filePath")

                        $resultTestFilePath = Invoke-PSFCommand -ComputerName $computer -ScriptBlock $command -Credential $Credential
                    }
                    catch {
                        Stop-PSFFunction -Message "The file path $filePath is not valid" -ErrorRecord $_ -Target $filePath
                        return
                    }
                }
                else {
                    $resultTestFilePath = Test-Path -Path $filePath
                }

                # Check the result
                if (-not $resultTestFilePath) {
                    Stop-PSFFunction -Message "Could not access the path $filePath" -Target $filePath
                    return
                }

                # Set the variable for the information store
                $InformationStore = 'File'
            }

        }

        # Unregister any configurations
        try {
            Unregister-PSFConfig -Scope SystemDefault -Module psdatabaseclone
        }
        catch {
            Stop-PSFFunction -Message "Something went wrong unregistering the configurations" -ErrorRecord $_ -Target $SqlInstance
            return
        }
    }

    process {

        # Test if there are any errors
        if (Test-PSFFunctionInterrupt) { return }


        if ($InformationStore -eq 'SQL') {
            # Setup the database name
            if (-not $Database -or $Database -eq '') {
                $Database = "PSDatabaseClone"
            }

            # Try connecting to the instance
            if ($SqlInstance) {
                Write-PSFMessage -Message "Attempting to connect to Sql Server $SqlInstance.." -Level Verbose
                try {
                    $server = Connect-DbaInstance -SqlInstance $SqlInstance -SqlCredential $SqlCredential
                }
                catch {
                    Stop-PSFFunction -Message "Could not connect to Sql Server instance $SqlInstance" -ErrorRecord $_ -Target $SqlInstance
                    return
                }
            }

            # Check if the database is already present
            if (($server.Databases.Name -contains $Database) -or ($server.Databases[$Database].Tables.Count -ge 1)) {
                if ($Force) {
                    try {
                        Remove-DbaDatabase -SqlInstance $SqlInstance -SqlCredential $SqlCredential -Database $Database
                    }
                    catch {
                        Stop-PSFFunction -Message "Couldn't remove database $Database on $SqlInstance" -ErrorRecord $_ -Target $SqlInstance
                        return
                    }
                }
                else {
                    Write-PSFMessage -Message "Database $Database already exists" -Level Verbose
                }
            }

            # Check if the database exists
            if ($server.Databases.Name -notcontains $Database) {

                # Set the flag
                $newDatabase = $true

                try {
                    # Setup the query to create the database
                    $query = "CREATE DATABASE [$Database]"

                    Write-PSFMessage -Message "Creating database $Database on $SqlInstance" -Level Verbose

                    # Executing the query
                    Invoke-DbaQuery -SqlInstance $SqlInstance -SqlCredential $SqlCredential -Database master -Query $query
                }
                catch {
                    Stop-PSFFunction -Message "Couldn't create database $Database on $SqlInstance" -ErrorRecord $_ -Target $SqlInstance
                }
            }
            else {
                # Check if there are any user objects already in the database
                $newDatabase = ($server.Databases[$Database].Tables.Count -eq 0)
            }

            # Setup the path to the sql file
            if ($newDatabase) {
                try {
                    $path = "$($MyInvocation.MyCommand.Module.ModuleBase)\internal\resources\database\database.sql"
                    $query = [System.IO.File]::ReadAllText($path)

                    # Create the objects
                    try {
                        Write-PSFMessage -Message "Creating database objects" -Level Verbose

                        # Executing the query
                        Invoke-DbaQuery -SqlInstance $SqlInstance -SqlCredential $SqlCredential -Database $Database -Query $query
                    }
                    catch {
                        Stop-PSFFunction -Message "Couldn't create database objects" -ErrorRecord $_ -Target $SqlInstance
                    }
                }
                catch {
                    Stop-PSFFunction -Message "Couldn't find database script. Make sure you have a valid installation of the module" -ErrorRecord $_ -Target $SqlInstance
                }
            }
            else {
                Write-PSFMessage -Message "Database already contains objects" -Level Verbose
            }

            # Set the database server and database values
            Set-PSFConfig -Module PSDatabaseClone -Name database.server -Value $SqlInstance -Validation string
            Set-PSFConfig -Module PSDatabaseClone -Name database.name -Value $Database -Validation string
        }
        else {
            # Create the JSON files

            if ($null -eq $filePath) {
                $filePath = $Path
            }

            # Create the PSDrive to be able to use credentials
            try {
                $null = New-PSDrive -Name PSDatabaseClone -PSProvider FileSystem -Root $filePath -Credential $Credential
            }
            catch {
                Stop-PSFFunction -Message "Couldn not create PS-Drive to JSON files" -Target $filePath
            }

            # Create the files
            try {
                # Get the files
                $files = Get-ChildItem -Path PSDatabaseClone:\

                # Check if we have any files
                if ($files.Count -eq 0) {
                    $null = New-Item -Path PSDatabaseClone:\hosts.json -Force:$Force
                    $null = New-Item -Path PSDatabaseClone:\images.json -Force:$Force
                    $null = New-Item -Path PSDatabaseClone:\clones.json -Force:$Force
                }
                else {
                    if (-not $Force -and ("$filePath\hosts.json" -in $files.FullName)) {
                        Stop-PSFFunction -Message "File 'hosts.json' already exists" -Target $filePath
                    }
                    else {
                        $null = New-Item -Path PSDatabaseClone:\hosts.json -Force:$Force
                    }

                    if (-not $Force -and ("$filePath\images.json" -in $files.FullName)) {
                        Stop-PSFFunction -Message "File 'images.json' already exists" -Target $filePath
                    }
                    else {
                        $null = New-Item -Path PSDatabaseClone:\images.json -Force:$Force
                    }

                    if (-not $Force -and ("$filePath\clones.json" -in $files.FullName)) {
                        Stop-PSFFunction -Message "File 'clones.json' already exists" -Target $filePath
                    }
                    else {
                        $null = New-Item -Path PSDatabaseClone:\clones.json -Force:$Force
                    }
                }

                # Set the path in case it's set for file store mode
                Set-PSFConfig -Module PSDatabaseClone -Name informationstore.path -Value "$filePath" -Validation string
            }
            catch {
                Stop-PSFFunction -Message "Could not create the JSON files in path $filePath" -Target $filePath -ErrorRecord $_
                return
            }
        }

        # Set the credential for the database if needed
        if ($SqlCredential) {
            Set-PSFConfig -Module PSDatabaseClone -Name informationstore.credential -Value $SqlCredential
        }

        # Set the credential for files and folders if needed
        if ($Credential) {
            Set-PSFConfig -Module PSDatabaseClone -Name informationstore.credential -Value $Credential
        }

        # Set the information store mode
        Set-PSFConfig -Module PSDatabaseClone -Name informationstore.mode -Value $InformationStore

        # Register the configurations in the system for all users
        Get-PSFConfig -FullName psdatabaseclone.informationstore.mode | Register-PSFConfig -Scope SystemDefault
        Get-PSFConfig -FullName psdatabaseclone.informationstore.credential | Register-PSFConfig -Scope SystemDefault
        Get-PSFConfig -FullName psdatabaseclone.informationstore.path | Register-PSFConfig -Scope SystemDefault

        Get-PSFConfig -FullName psdatabaseclone.database.server | Register-PSFConfig -Scope SystemDefault
        Get-PSFConfig -FullName psdatabaseclone.database.name | Register-PSFConfig -Scope SystemDefault

        # Set the path to the diskpart script file
        Set-PSFConfig -Module PSDatabaseClone -Name diskpart.scriptfile -Value "$env:APPDATA\psdatabaseclone\diskpartcommand.txt" -Validation string
        New-Item -Path "$env:APPDATA\psdatabaseclone" -ItemType Directory
        Get-PSFConfig -FullName psdatabaseclone.diskpart.scriptfile | Register-PSFConfig -Scope SystemDefault

        # Check if all the settings have been made
        if ($InformationStore -eq 'SQL') {
            $dbServer = Get-PSFConfigValue -FullName psdatabaseclone.database.server
            $dbName = Get-PSFConfigValue -FullName psdatabaseclone.database.name

            if (($false -ne $dbServer) -and ($false -ne $dbName)) {
                Write-PSFMessage -Message "All mandatory configurations have been made" -Level Host
                Set-PSFConfig -Module PSDatabaseClone -Name setup.status -Value $true -Validation bool
            }
            else {
                Write-PSFMessage -Message "The mandatory configurations have NOT been made. Please check your settings." -Level Warning
                Set-PSFConfig -Module PSDatabaseClone -Name setup.status -Value $false -Validation bool
            }
        }
        else {
            $path = Get-PSFConfigValue -FullName psdatabaseclone.informationstore.path

            if (($null -ne $path) -or ('' -ne $path)) {
                Write-PSFMessage -Message "All mandatory configurations have been made" -Level Host
                Set-PSFConfig -Module PSDatabaseClone -Name setup.status -Value $true -Validation bool
            }
            else {
                Write-PSFMessage -Message "The mandatory configurations have NOT been made. Please check your settings." -Level Warning
                Set-PSFConfig -Module PSDatabaseClone -Name setup.status -Value $false -Validation bool
            }
        }

        # Set the overall status in the configurations
        Get-PSFConfig -FullName psdatabaseclone.setup.status | Register-PSFConfig -Scope SystemDefault


    }

    end {
        # Test if there are any errors
        if (Test-PSFFunctionInterrupt) { return }

        Write-PSFMessage -Message "Finished setting up PSDatabaseClone" -Level Host
    }
}

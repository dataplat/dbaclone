@{
    # Script module or binary module file associated with this manifest
    ModuleToProcess   = 'PSDatabaseClone.psm1'

    # Version number of this module.
    ModuleVersion     = '0.3.1'

    # ID used to uniquely identify this module
    GUID              = 'db92ed6d-9955-4357-b577-897ef1a535e2'

    # Author of this module
    Author            = 'Sander Stad'

    # Company or vendor of this module
    CompanyName       = ''

    # Copyright statement for this module
    Copyright         = 'Copyright (c) 2018 Sander Stad'

    # Description of the functionality provided by this module
    Description       = 'Module for cloning SQL Server databases'

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '5.0'

    # Modules that must be imported into the global environment prior to importing
    # this module
    RequiredModules   = @(
        @{ ModuleName = 'PSFramework'; ModuleVersion = '0.10.27.128' },
        @{ ModuleName = 'dbatools'; ModuleVersion = '0.9.337' }
    )

    # Assemblies that must be loaded prior to importing this module
    RequiredAssemblies = @("bin\PSDatabaseClone.dll", "bin\Bogus.dll")

    # Type files (.ps1xml) to be loaded when importing this module
    # TypesToProcess = @('xml\PSDatabaseClone.Types.ps1xml')

    # Format files (.ps1xml) to be loaded when importing this module
    # FormatsToProcess = @('xml\PSDatabaseClone.Format.ps1xml')

    # Functions to export from this module
    FunctionsToExport = 'Convert-PSDCLocalUncPathToLocalPath',
		'Get-PSDCClone',
		'Get-PSDCImage',
		'Initialize-PSDCVhdDisk',
		'Invoke-PSDCDataMasking',
		'Invoke-PSDCRepairClone',
		'New-PSDCClone',
		'New-PSDCImage',
		'New-PSDCMaskingConfiguration',
		'New-PSDCVhdDisk',
		'Remove-PSDCClone',
		'Remove-PSDCImage',
		'Set-PSDCConfiguration',
		'Test-PSDCRemoting'

    # Cmdlets to export from this module
    CmdletsToExport   = ''

    # Variables to export from this module
    VariablesToExport = ''

    # Aliases to export from this module
    AliasesToExport   = ''

    # List of all modules packaged with this module
    ModuleList        = @()

    # List of all files packaged with this module
    FileList          = @()

    # Private data to pass to the module specified in ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData       = @{

        #Support for PowerShellGet galleries.
        PSData = @{

            # Tags applied to this module. These help with module discovery in online galleries.
            # Tags = @()

            # A URL to the license for this module.
            # LicenseUri = ''

            # A URL to the main website for this project.
            # ProjectUri = ''

            # A URL to an icon representing this module.
            # IconUri = ''

            # ReleaseNotes of this module
            # ReleaseNotes = ''

        } # End of PSData hashtable

    } # End of PrivateData hashtable
}
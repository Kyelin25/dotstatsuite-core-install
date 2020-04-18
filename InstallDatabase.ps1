Function Install-StructureDatabase{
    Param(
        [Parameter(Mandatory=$true)]
        [string]
        $MaapiInstallationPackageDirectory,

        [Parameter(Mandatory=$true)]
        [string]
        $DbUpInstallationPackageDirectory,

        [Parameter(Mandatory=$true)]
        [string]
        $DataspaceId,

        [Parameter(Mandatory=$true)]
        [string]
        $DatabaseServer,

        [Parameter(Mandatory=$true)]
        [string]
        $SysAdminUserName,

        [Parameter(Mandatory=$true)]
        [string]
        $SysAdminPassword,

        [Parameter(Mandatory=$true)]
        [string]
        $DatabaseUserToCreate,

        [Parameter(Mandatory=$true)]
        [string]
        $DatabaseUserToCreatePassword
    )

    if( -not ( Test-Path $MaapiInstallationPackageDirectory -PathType Container ) )
    {
        throw [System.IO.DirectoryNotFoundException]"Could not find maapi installation package directory: $MaapiInstallationPackageDirectory"
    }

    if( -not ( Test-Path $DbUpInstallationPackageDirectory -PathType Container ) )
    {
        throw [System.IO.DirectoryNotFoundException]"Could not find DbUp installation package directory: $DbUpInstallationPackageDirectory"
    }

    # Work out the connection string we need to use. This means working out the database name too
    $DatabaseName="${DataspaceId}StructDb"
    $DatabaseConnectionString="Server=${DatabaseServer};Database=${DatabaseName};User=${SysAdminUserName};Password=${SysAdminPassword};"

    Push-Location
    Set-Location $MaapiInstallationPackageDirectory

    # Calculate the path of the configuration file
    $ToolConfigurationFile=Join-Path $MaapiInstallationPackageDirectory Estat.Sri.Mapping.Tool.dll.config

    # Retrieve the configuration file content
    [xml]$ConfigFileContent=Get-Content -Path $ToolConfigurationFile

    # Update the sqlserver connection string to the one we want
    $ConfigFileContent.SelectSingleNode("/configuration/connectionStrings/add[@name='sqlserver']").connectionString=$DatabaseConnectionString

    # Write it back
    $ConfigFileContent.Save($ToolConfigurationFile)

    # Now that we've set up maapi, let's use DbUp to create the database
    Set-Location $DbUpInstallationPackageDirectory

    & .\DotStat.DbUp.exe upgrade --connectionString "$DatabaseConnectionString" --mappingStoreDb --loginName $DatabaseUserToCreate --loginPwd $DatabaseUserToCreatePassword --force

    # The database now exists. Time to turn it into a mapping store db
    Set-Location $MaapiInstallationPackageDirectory

    & .\Estat.Sri.Mapping.Tool.exe init -m sqlserver -f

    Pop-Location
}

Function Install-DataDatabase{
    Param(
        [Parameter(Mandatory=$true)]
        [string]
        $DbUpInstallationPackageDirectory,

        [Parameter(Mandatory=$true)]
        [string]
        $DataspaceId,

        [Parameter(Mandatory=$true)]
        [string]
        $DatabaseServer,

        [Parameter(Mandatory=$true)]
        [string]
        $SysAdminUserName,

        [Parameter(Mandatory=$true)]
        [string]
        $SysAdminPassword,

        [Parameter(Mandatory=$true)]
        [string]
        $DatabaseUserToCreate,

        [Parameter(Mandatory=$true)]
        [string]
        $DatabaseUserToCreatePassword
    )

    if( -not ( Test-Path $DbUpInstallationPackageDirectory -PathType Container ) )
    {
        throw [System.IO.DirectoryNotFoundException]"Could not find DbUp installation package directory: $DbUpInstallationPackageDirectory"
    }

    # Work out the connection string we need to use. This means working out the database name too
    $DatabaseName="${DataspaceId}DataDb"
    $DatabaseConnectionString="Server=${DatabaseServer};Database=${DatabaseName};User=${SysAdminUserName};Password=${SysAdminPassword};"

    Push-Location
    Set-Location $DbUpInstallationPackageDirectory

    # Create and initialise the database
    & .\DotStat.DbUp.exe upgrade --connectionString "$DatabaseConnectionString" --dataDb --loginName $DatabaseUserToCreate --loginPwd $DatabaseUserToCreatePassword --force

    Pop-Location
}

Function Install-CommonDatabase{
    Param(
        [Parameter(Mandatory=$true)]
        [string]
        $DbUpInstallationPackageDirectory,

        [Parameter(Mandatory=$true)]
        [string]
        $DataspaceId,

        [Parameter(Mandatory=$true)]
        [string]
        $DatabaseServer,

        [Parameter(Mandatory=$true)]
        [string]
        $SysAdminUserName,

        [Parameter(Mandatory=$true)]
        [string]
        $SysAdminPassword,

        [Parameter(Mandatory=$true)]
        [string]
        $DatabaseUserToCreate,

        [Parameter(Mandatory=$true)]
        [string]
        $DatabaseUserToCreatePassword
    )

    if( -not ( Test-Path $DbUpInstallationPackageDirectory -PathType Container ) )
    {
        throw [System.IO.DirectoryNotFoundException]"Could not find DbUp installation package directory: $DbUpInstallationPackageDirectory"
    }

    # Work out the connection string we need to use. This means working out the database name too
    $DatabaseName="${DataspaceId}CommonDb"
    $DatabaseConnectionString="Server=${DatabaseServer};Database=${DatabaseName};User=${SysAdminUserName};Password=${SysAdminPassword};"

    Push-Location
    Set-Location $DbUpInstallationPackageDirectory

    # Create and initialise the database
    & .\DotStat.DbUp.exe upgrade --connectionString "$DatabaseConnectionString" --commonDb --loginName $DatabaseUserToCreate --loginPwd $DatabaseUserToCreatePassword --force

    Pop-Location
}

Function Install-DataspaceDatabases{
    Param(
        [Parameter(Mandatory=$true)]
        [string]
        $MaapiInstallationPackageDirectory,

        [Parameter(Mandatory=$true)]
        [string]
        $DbUpInstallationPackageDirectory,

        [Parameter(Mandatory=$true)]
        [string]
        $DataspaceId,

        [Parameter(Mandatory=$true)]
        [string]
        $DatabaseServer,

        [Parameter(Mandatory=$true)]
        [string]
        $SysAdminUserName,

        [Parameter(Mandatory=$true)]
        [string]
        $SysAdminPassword,

        [Parameter(Mandatory=$true)]
        [string]
        $CommonApplicationUserPassword,

        [Parameter(Mandatory=$true)]
        [string]
        $DataApplicationUserPassword,

        [Parameter(Mandatory=$true)]
        [string]
        $StructureApplicationUserPassword
    )

    # Set up the logins that will be created for using the databases
    $StructureApplicationLogin="${DataspaceId}StructureLogin"
    $CommonApplicationLogin="${DataspaceId}CommonLogin"
    $DataApplicationLogin="${DataspaceId}DataLogin"

    Install-StructureDatabase -MaapiInstallationPackageDirectory $MaapiInstallationPackageDirectory -DbUpInstallationPackageDirectory $DbUpInstallationPackageDirectory -DataspaceId $DataspaceId -DatabaseServer $DatabaseServer -SysAdminUserName $SysAdminUserName -SysAdminPassword $SysAdminPassword -DatabaseUserToCreate $StructureApplicationLogin -DatabaseUserToCreatePassword $StructureApplicationUserPassword

    Install-CommonDatabase -DbUpInstallationPackageDirectory $DbUpInstallationPackageDirectory -DataspaceId $DataspaceId -DatabaseServer $DatabaseServer -SysAdminUserName $SysAdminUserName -SysAdminPassword $SysAdminPassword -DatabaseUserToCreate $CommonApplicationLogin -DatabaseUserToCreatePassword $CommonApplicationUserPassword

    Install-DataDatabase -DbUpInstallationPackageDirectory $DbUpInstallationPackageDirectory -DataspaceId $DataspaceId -DatabaseServer $DatabaseServer -SysAdminUserName $SysAdminUserName -SysAdminPassword $SysAdminPassword -DatabaseUserToCreate $DataApplicationLogin -DatabaseUserToCreatePassword $DataApplicationUserPassword
}
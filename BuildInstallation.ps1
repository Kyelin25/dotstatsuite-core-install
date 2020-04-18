Function Clone-CoreRepositories{
    Param(
        [Parameter(Mandatory=$true)]
        [string]
        $BaseRepositoryDirectory,

        [Parameter(Mandatory=$true)]
        [string]
        $EurostatUserName,

        [Parameter(Mandatory=$true)]
        [string]
        $EurostatPassword,

        [Parameter(Mandatory=$true)]
        [string]
        $DataAccessRepoBranch,

        [Parameter(Mandatory=$true)]
        [string]
        $MaapiRepoBranch,

        [Parameter(Mandatory=$true)]
        [string]
        $AuthDbRepoBranch,

        [Parameter(Mandatory=$true)]
        [string]
        $NSIEurostatRepoBranch,

        [Parameter(Mandatory=$true)]
        [string]
        $NSIPluginRepoBranch,

        [Parameter(Mandatory=$true)]
        [string]
        $TransferRepoBranch,

        [Parameter(Mandatory=$true)]
        [string]
        $AuthManagementRepoBranch
    )

    if( -not (Test-Path $BaseRepositoryDirectory -PathType Container ) )
    {
        throw [System.IO.DirectoryNotFoundException]"Could not find base repository directory: $BaseRepositoryDirectory"
    }

    $env:GIT_REDIRECT_STDERR = '2>&1' # Redirect git's stderr to stdout because it keeps pushing stuff there that has no business being there and makes it look like errors are occurring.

    Push-Location

    Set-Location $BaseRepositoryDirectory

    # Clone the db-up repository
    & git clone -b $DataAccessRepoBranch --single-branch https://gitlab.com/sis-cc/.stat-suite/dotstatsuite-core-data-access.git dotstatsuite-core-dbup

    # Clone the maapi.net tool repo
    & git clone -b $MaapiRepoBranch --single-branch --recurse-submodules https://${EurostatUserName}:$EurostatPassword@webgate.ec.europa.eu/CITnet/stash/scm/sdmxri/maapi.net.git

    # Ensure that the authdb.sql.git submodule is cloned
    & git clone -b $AuthDbRepoBranch --single-branch --recurse-submodules https://${EurostatUserName}:$EurostatPassword@webgate.ec.europa.eu/CITnet/stash/scm/sdmxri/authdb.sql.git maapi.net/src/Estat.Sri.Security/resources

    # Clone the NSI web service repo
    & git clone -b $NSIEurostatRepoBranch --single-branch https://${EurostatUserName}:$EurostatPassword@webgate.ec.europa.eu/CITnet/stash/scm/sdmxri/nsiws.net.git

    # Clone the NSI web service plugin repo
    & git clone -b $NSIPluginRepoBranch --single-branch https://gitlab.com/sis-cc/.stat-suite/dotstatsuite-core-sdmxri-nsi-plugin.git

    # Clone the Transfer service repo
    & git clone -b $TransferRepoBranch --single-branch https://gitlab.com/sis-cc/.stat-suite/dotstatsuite-core-transfer.git

    # Clone the AuthorizationManagement service repo
    & git clone -b $AuthManagementRepoBranch --single-branch https://gitlab.com/sis-cc/.stat-suite/dotstatsuite-core-auth-management.git

    Pop-Location
}

Function Publish-DbUp{
    Param(
        [Parameter(Mandatory=$true)]
        [string]
        $RepositoryDirectory,

        [Parameter(Mandatory=$true)]
        [string]
        $PackageOutputDirectory,

        [string]
        $Version="Release"
    )

    if( -not (Test-Path $RepositoryDirectory -PathType Container ) ){
        throw [System.IO.DirectoryNotFoundException]"Could not find repository directory: $RepositoryDirectory"
    }

    Push-Location
    Set-Location $RepositoryDirectory

    # Build the dotstatsuite-core-dbup tool
    & dotnet publish ./DotStat.DbUp -c Release -o $PackageOutputDirectory -r win-x64

    Pop-Location
}

Function Publish-MaapiDbTool{
    Param(
        [Parameter(Mandatory=$true)]
        [string]
        $RepositoryDirectory,

        [Parameter(Mandatory=$true)]
        [string]
        $PackageOutputDirectory,

        [string]
        $Version="Release"
    )

    if( -not (Test-Path $RepositoryDirectory -PathType Container ) ){
        throw [System.IO.DirectoryNotFoundException]"Could not find repository directory: $RepositoryDirectory"
    }

    Push-Location
    Set-Location $RepositoryDirectory

    # Build the maapi.net tool
    & dotnet publish ./src/Estat.Sri.Mapping.Tool/Estat.Sri.Mapping.Tool.csproj -c $Version -o $PackageOutputDirectory -r win-x64

    Pop-Location
}

Function Publish-NsiService{
    Param(
        [Parameter(Mandatory=$true)]
        [string]
        $NsiRepositoryDirectory,

        [Parameter(Mandatory=$true)]
        [string]
        $NsiPluginRepositoryDirectory,

        [Parameter(Mandatory=$true)]
        [string]
        $PackageOutputDirectory,

        [string]
        $Version="Release"
    )

    if( -not (Test-Path $NsiRepositoryDirectory -PathType Container ) ){
        throw [System.IO.DirectoryNotFoundException]"Could not find NSI repository directory: $NsiRepositoryDirectory"
    }

    if( -not (Test-Path $NsiPluginRepositoryDirectory -PathType Container ) ){
        throw [System.IO.DirectoryNotFoundException]"Could not find NSI plugin repository directory: $NsiPluginRepositoryDirectory"
    }

    # Create the output folder if it doesn't exist. We have to do this in this function because we're manually copying rather using dotnet publish
    if( -not (Test-Path $PackageOutputDirectory -PathType Container ) )
    {
        New-Item $PackageOutputDirectory -ItemType Directory
    }

    Push-Location
    Set-Location $NsiRepositoryDirectory

    # Build the NSI web service
    & dotnet restore ./NSIWebServices.sln
    & dotnet build ./NSIWebServices.sln --no-restore -c $Version
    & dotnet publish ./src/NSIWebServiceCore/NSIWebServiceCore.csproj --no-build -c $Version -o ./out

    Copy-Item ./out/* $PackageOutputDirectory -Recurse -Force

    # Remove the built in app.config file as well as the sample files in the config folder
    Remove-Item $PackageOutputDirectory/config/app.config
    Remove-Item $PackageOutputDirectory/config/*.sample

    Set-Location $NsiPluginRepositoryDirectory

    # Build the NSI plugin
    & dotnet publish -c Release -o ./out

    # Copy the dlls we need from the plugin
    $PluginsDirectory=Join-Path $PackageOutputDirectory Plugins

    Copy-Item ./out/DotStat.Common.dll $PluginsDirectory
    Copy-Item ./out/DotStat.DB.dll $PluginsDirectory
    Copy-Item ./out/DotStat.Domain.dll $PluginsDirectory
    Copy-Item ./out/DotStat.MappingStore.dll $PluginsDirectory
    Copy-Item ./out/DotStat.NSI.DataRetriever.dll $PluginsDirectory
    Copy-Item ./out/DotStat.NSI.RetrieverFactory.deps.json $PluginsDirectory
    Copy-Item ./out/DotStat.NSI.RetrieverFactory.dll $PluginsDirectory

    Pop-Location
}

Function Publish-TransferService{
    Param(
        [Parameter(Mandatory=$true)]
        [string]
        $RepositoryDirectory,

        [Parameter(Mandatory=$true)]
        [string]
        $PackageOutputDirectory,

        [string]
        $Version="Release"
    )

    if( -not (Test-Path $RepositoryDirectory -PathType Container ) ){
        throw [System.IO.DirectoryNotFoundException]"Could not find repository directory: $RepositoryDirectory"
    }

    Push-Location
    Set-Location $RepositoryDirectory

    # Build the Transfer service
    & dotnet publish -c $Version -o $PackageOutputDirectory

    Pop-Location
}

Function Publish-AuthManagementService{
    Param(
        [Parameter(Mandatory=$true)]
        [string]
        $RepositoryDirectory,

        [Parameter(Mandatory=$true)]
        [string]
        $PackageOutputDirectory,

        [string]
        $Version="Release"
    )

    if( -not (Test-Path $RepositoryDirectory -PathType Container ) ){
        throw [System.IO.DirectoryNotFoundException]"Could not find repository directory: $RepositoryDirectory"
    }

    Push-Location
    Set-Location $RepositoryDirectory

    # Build the Authorization Management service
    & dotnet publish -c $Version -o $PackageOutputDirectory

    Pop-Location
}

# Eurostat Credentials
$EurostatUserName=""
$EurostatPassword=""

$BaseBuildDirectory="C:\Development\OpenSource"

if( -not (Test-Path $BaseBuildDirectory -PathType Container ) )
{
    throw [System.IO.DirectoryNotFoundException]"Could not find base build directory: $BaseBuildDirectory"
}

$RepositorySubfolder = "Repos"
$BuiltPackagesSubfolder="Packages"

$BaseRepositoryDirectory=Join-Path $BaseBuildDirectory $RepositorySubfolder
$BasePackagesDirectory=Join-Path $BaseBuildDirectory $BuiltPackagesSubfolder

# Git branches
$DataAccessRepoBranch = "6.2.1"
$MaapiRepoBranch="1.25.1"
$AuthDbRepoBranch="1.0.1"
$NSIEurostatRepoBranch="7.11.1"
$NSIPluginRepoBranch="7.11.1"
$TransferRepoBranch="release3.0.0"
$AuthManagementRepoBranch="release3.0.0"

New-Item $BaseRepositoryDirectory -ItemType Directory

# Pull all the required repositories
Clone-CoreRepositories -BaseRepositoryDirectory $BaseRepositoryDirectory -EurostatUserName $EurostatUserName -EurostatPassword $EurostatPassword -DataAccessRepoBranch $DataAccessRepoBranch -MaapiRepoBranch $MaapiRepoBranch -AuthDbRepoBranch $AuthDbRepoBranch -NSIEurostatRepoBranch $NSIEurostatRepoBranch -NSIPluginRepoBranch $NSIPluginRepoBranch -TransferRepoBranch $TransferRepoBranch -AuthManagementRepoBranch $AuthManagementRepoBranch 

# Define all the repository folders
$NsiRepositoryDirectory=Join-Path $BaseRepositoryDirectory nsiws.net
$NsiPluginRepositoryDirectory=Join-Path $BaseRepositoryDirectory dotstatsuite-core-sdmxri-nsi-plugin
$MaapiRepositoryDirectory=Join-Path $BaseRepositoryDirectory maapi.net
$DbUpRepositoryDirectory=Join-Path $BaseRepositoryDirectory dotstatsuite-core-dbup
$TransferRepositoryDirectory=Join-Path $BaseRepositoryDirectory dotstatsuite-core-transfer
$AuthManagementRepositoryDirectory=Join-Path $BaseRepositoryDirectory dotstatsuite-core-auth-management

New-Item $BasePackagesDirectory -ItemType Directory

# Define all the output package folders
$NsiPackageFolder=Join-Path $BasePackagesDirectory nsi
$DbUpPackageFolder=Join-Path $BasePackagesDirectory dbup
$MaapiPackageFolder=Join-Path $BasePackagesDirectory maapi
$TransferPackageFolder=Join-Path $BasePackagesDirectory transfer
$AuthManagementPackageFolder=Join-Path $BasePackagesDirectory authmanagement

New-Item $NsiPackageFolder -ItemType Directory
New-Item $DbUpPackageFolder -ItemType Directory
New-Item $MaapiPackageFolder -ItemType Directory
New-Item $TransferPackageFolder -ItemType Directory
New-Item $AuthManagementPackageFolder -ItemType Directory

Publish-NsiService -NsiRepositoryDirectory $NsiRepositoryDirectory -NsiPluginRepositoryDirectory $NsiPluginRepositoryDirectory -PackageOutputDirectory $NsiPackageFolder
Publish-MaapiDbTool -RepositoryDirectory $MaapiRepositoryDirectory -PackageOutputDirectory $MaapiPackageFolder
Publish-DbUp -RepositoryDirectory $DbUpRepositoryDirectory -PackageOutputDirectory $DbUpPackageFolder
Publish-TransferService -RepositoryDirectory $TransferRepositoryDirectory -PackageOutputDirectory $TransferPackageFolder
Publish-AuthManagementService -RepositoryDirectory $AuthManagementRepositoryDirectory -PackageOutputDirectory $AuthManagementPackageFolder

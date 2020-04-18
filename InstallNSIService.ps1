Function Install-NSIWebService{
    Param(
        [Parameter(Mandatory=$true)]
        [string]
        $NsiInstallationPackageDirectory,

        [Parameter(Mandatory=$true)]
        [string]
        $BaseWebsiteName,

        [Parameter(Mandatory=$true)]
        [string]
        $InstallationFolder, # Folder to install to

        [string]
        $ApplicationRelativeUrl="",

        [Parameter(Mandatory=$true)]
        [string]
        $DataspaceId
    )

    Import-Module WebAdministration

    # If we weren't provided with a relative url, build it from the data space id
    if( $ApplicationRelativeUrl -eq "" )
    {
        $ApplicationRelativeUrl = "${DataspaceId}NSIUnauthenticated"
    }

    # Calculate the application name
    $ApplicationName = "${DataspaceId}NSIUnauthenticated"

    if( -not ( Test-Path $NsiInstallationPackageDirectory -PathType Container ) )
    {
        throw [System.IO.DirectoryNotFoundException]"Could not find NSI installation package directory: $NsiInstallationPackageDirectory"
    }

    $WebsiteTestPath="IIS:\Sites\${BaseWebsiteName}"

    if( -not ( Test-Path $WebsiteTestPath ) )
    {
        throw [System.ArgumentException]"Could not find base website: $BaseWebsiteName"
    }

    # Create the application folder if it doesn't exist
    if( -not ( Test-Path $InstallationFolder -PathType Container ) )
    {
        New-Item $InstallationFolder -ItemType Directory
    }else
    {
        # If it does exist, we're going to empty it out
        Get-ChildItem -Path $InstallationFolder | Remove-Item -Recurse -Force
    }

    # Copy the solution into the application folder
    Copy-Item -Path $NsiInstallationPackageDirectory/* -Destination $InstallationFolder -Recurse -Force

    # Create the application pool if it doesn't already exist
    if( -not ( Test-Path IIS:\AppPools\$ApplicationName ) )
    {
        New-WebAppPool -Name $ApplicationName
    }

    # Create the web application
    New-WebApplication -Site $BaseWebsiteName -Name $ApplicationName -PhysicalPath $InstallationFolder -ApplicationPool $ApplicationName

}
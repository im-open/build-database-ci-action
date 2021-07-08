$PSModuleAutoLoadingPreference = 'None'
$ErrorActionPreference = 'Stop'

if( $PSVersionTable.PSVersion -lt "5.0" ) {
    Write-Error "Requires PowerShell 5.0 or greater"
    exit 1
}
# set TLS version to 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Import-Module Microsoft.PowerShell.Management 
Import-Module Microsoft.PowerShell.Utility 
Import-Module PackageManagement

# This will install the latest version of PowerShellGet, which will in-turn install a compatible version of PackageManagement and the NuGet package provider.
PackageManagement\Install-Package -Name PowerShellGet -Force -AllowClobber -Source PSGallery -MaximumVersion 2.2.2
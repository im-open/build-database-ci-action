param(
    [switch]$incremental, #The database will be dropped before the build is run when switch is not set, or will apply the scripts to the current database if set
    [switch]$runTests, #Dictates whether or not the tests are run
    [string]$dbName,
    [switch]$installMockDbObjects,
    [switch]$dropDbAfterBuild,
    [string]$mockDbObjectNugetFeedUrl,
    [string]$nugetUser,
    [securestring]$nugetPassword,
    [string]$dbServerName = "localhost",
    [string]$dbServerPort = "1433",
    [switch]$validateMigrations = $false,
    [switch]$seedData = $false,
    [string]$dbUsername,
    [string]$dbPassword
)

# $oldverbose = $VerbosePreference
# $VerbosePreference = "continue"

flyway -v

$PSModuleAutoLoadingPreference = 'None'
$ErrorActionPreference = 'Stop'

if ( $PSVersionTable.PSVersion -lt "5.0" ) {
    Write-Error "Requires PowerShell 5.0 or greater"
    exit 1
}

Import-Module Microsoft.PowerShell.Management -Verbose:$false
Import-Module Microsoft.PowerShell.Utility -Verbose:$false
echo "Loading or Installing Required PowerShell Modules..."
# Ensure we have compatible versions of the required modules available
Import-Module -Name PackageManagement -MinimumVersion 1.1.7.2 -Force -Verbose:$false
Import-Module PowerShellGet -MinimumVersion 1.6 -Force -Verbose:$false
Import-Module Microsoft.Powershell.Security

# set TLS version to 1.2
Write-Verbose "Setting TLS version to 1.2"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# If a minimum version of the SQL Server Powershell module is installed, import it. If not, install it from the PowerShell gallery ( https://www.powershellgallery.com/api/v2/).
if (get-module SqlServer -ListAvailable | Where-Object { $_.Version -ge [Version]"21.0" }) {
    Write-Verbose "Importing SqlServer module"
    Import-Module SqlServer -MinimumVersion 21.0
}
else {
    # install the SqlServer module
    $repo = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
    if (!$repo) {
        Write-Verbose "Registering PSGallery as as PSRepository"
        Register-PSRepository -Name "PSGallery" -SourceLocation "https://www.powershellgallery.com/api/v2/" -InstallationPolicy Trusted
    }
    PowerShellGet\Install-Module SqlServer -Repository PSGallery -Force -AllowClobber
    Import-Module SqlServer -MinimumVersion 21.0
}

Write-Output "Installing database build tools..."
Invoke-Expression "$PSScriptRoot\install-db-tools.ps1"

Write-Host "Building database..."

# Dot source the DMFlyway file so its functions can be used
. $PSScriptRoot\database-management\DMFlyway.ps1

Invoke-DatabaseBuild -incremental:$incremental `
    -runTests:$runTests `
    -runAllMigrations `
    -hostName $dbServerName `
    -port $dbServerPort `
    -installMockDbObjects:$installMockDbObjects `
    -mockDbObjectNugetFeedUrl $mockDbObjectNugetFeedUrl `
    -seedData:$seedData `
    -dropDbAfterBuild:$dropDbAfterBuild `
    -nugetUser $nugetUser `
    -nugetPassword $nugetPassword `
    -validateMigrations:$validateMigrations `
    -dbUsername $dbUsername `
    -dbPassword $dbPassword

# $VerbosePreference = $oldverbose

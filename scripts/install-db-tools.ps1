[CmdletBinding()]

$localSqlServer = Get-InstalledModule -Name SqlServer -AllVersions -ErrorAction SilentlyContinue

Write-Host "install-db-tools starting..."

# If update needed
if(!$localSqlServer){
    $psRepo = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
    if(!$psRepo){
        Write-Verbose "Registering PSGallery as a PSRepository"
        Register-PSRepository -Name "PSGallery" -SourceLocation "https://www.powershellgallery.com/api/v2/" -PublishLocation "https://www.powershellgallery.com/api/v2/package/" -InstallationPolicy Trusted
        $psRepo = Get-PSRepository -Name PSGallery
    }
    $policy = $psRepo.InstallationPolicy
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    PowerShellGet\Install-Module -Name SqlServer -Scope CurrentUser -Repository PSGallery -AllowClobber
    Set-PSRepository -Name PSGallery -InstallationPolicy $policy
}

Write-Host "Import SqlServer"
Import-Module -Name SqlServer

$server = New-Object -TypeName "Microsoft.SqlServer.Management.Smo.Server"
Write-Host $server.GetType().Assembly.FullName

Get-TypeData -TypeName Microsoft.SqlServer.Management.Smo.Server

Write-Host "install-db-tools complete!"
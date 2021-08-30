. $PSScriptRoot\DMConfig.ps1

<#
.SYNOPSIS
Imports database view dependencies from specified dependencies file

.DESCRIPTION
This will import database view dependencies from specified dependencies file. Dependency file needs to be a delimited text file (like csv) and must have the following header row.
PackageName:Version (delimiter is your choice)

.PARAMETER projectRoot
Root of the calling project. (Optional)

.PARAMETER nugetFeedUrl
Indicates the source of the nuget feed.

.PARAMETER dependenciesFile
Full path to the dependencies csv file.

.PARAMETER delimiter
Indicates your chosen delimiter for the dependenciesFile (Optional: defaults to ":")

.PARAMETER outputFolder
Indicates the location to install the packages to.

.EXAMPLE

Install-DbOjbectDependencies -dependenciesFile .\dbObject.dependencies -delimiter , -outputFolder .\dbObjectDependencies

.LINK
https://github.com/im-practices/database-migrator
http://kb.extendhealth.com/display/PD/Database+Migrator+Tool

#>
function Install-DbObjectDependencies {
    [CmdletBinding()]
    param(
        [string]$projectRoot = (Get-ProjectRoot),
        [string]$nugetFeedUrl,
        [string]$nugetUser,
        [securestring]$nugetPassword,
        [string]$dependenciesFile,
        [char]$delimiter = ':',
        [string]$outputFolder
    )
    Write-Host "Installing database objects:"

    if (![System.IO.Directory]::Exists($outputFolder)) {
        New-Item -ItemType Directory -Path $outputFolder
    }

    Import-Csv -Path $dependenciesFile -Delimiter $delimiter | Foreach-Object {
        #Download Package
        $packageName = $_.packageName
        $version = $_.version
        $schema = $packageName.Split('.')[0]
        $url = "$nugetFeedUrl/Database/$schema/$packageName.$version.nupkg"
        $nugetOutput = "$outputFolder\$packageName.nupkg"
        Write-Host "$packageName.$version"
        Remove-Item $nugetOutput -Force -Recurse -ErrorAction Ignore
        
        try {
            $nugetCredential = New-CredentialObject -username $nugetUser -password $nugetPassword
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest $url -OutFile $nugetOutput -Credential $nugetCredential
        }
        catch [System.MissingFieldException] {
            Write-Error $_;
        }
        catch {
            Write-Error $_;
        }
        
        #Extract Package
        $extractionLocation = "$outputFolder\$packageName"
        Remove-Item $extractionLocation -Force -Recurse -ErrorAction Ignore
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($nugetOutput, $extractionLocation)
    }
}

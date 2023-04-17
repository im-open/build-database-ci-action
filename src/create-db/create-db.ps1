param (
    [string]$dbServer,
    [string]$dbServerPort,
    [string]$dbName,
    [string]$pathToCreateDbFile,
    [string]$mockDependencyObjectList,
    [switch]$incremental = $false,
    [switch]$useIntegratedSecurity = $false,
    [switch]$trustServerCertificate = $false,
    [switch]$installMockDbObjects = $false,
    [string]$username,
    [securestring]$password
)

$ErrorActionPreference = "Stop";

if (-Not $incremental) {
    & $PSScriptRoot/../run-sql-command-for-file.ps1 `
        -dbServer "$dbServer,$dbServerPort" `
        -dbName "master" `
        -pathToFile $pathToCreateDbFile `
        -sqlCmdVariables "DatabaseName=$dbName" `
        -useIntegratedSecurity:$useIntegratedSecurity `
        -trustServerCertificate:$trustServerCertificate `
        -username $username `
        -password $password
}


if (-Not $installMockDbObjects) {
    return
}

Write-Output "Installing dependencies"

$parsedDependencies = ConvertFrom-Json $mockDependencyObjectList
& $PSScriptRoot/download-db-dependencies.ps1 -dependencies $parsedDependencies

& $PSScriptRoot/run-db-dependencies.ps1 `
    -dbServer "$dbServer,$dbServerPort" `
    -dbName $dbName `
    -useIntegratedSecurity:$useIntegratedSecurity `
    -trustServerCertificate:$trustServerCertificate `
    -username $username `
    -password $password
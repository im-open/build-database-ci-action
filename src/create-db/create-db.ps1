param (
    [string]$dbServer,
    [string]$dbServerPort,
    [string]$dbName,
    [string]$pathToCreateDbFile,
    [string]$mockDependencyObjectList,
    [switch]$useIntegratedSecurity = $false,
    [switch]$installMockDbObjects = $false,
    [string]$username,
    [securestring]$password
)

$ErrorActionPreference = "Stop";

& $PSScriptRoot/../run-sql-command-for-file.ps1 `
    -dbServer "$dbServer,$dbServerPort" `
    -dbName "master" `
    -pathToFile $pathToCreateDbFile `
    -sqlCmdVariables "DatabaseName = $dbName" `
    -useIntegratedSecurity:$useIntegratedSecurity `
    -username $username `
    -password $password


if (-Not $installMockDbObjects) {
    return
}

Write-Output "Installing dependencies"

$parsedDependencies = ConvertFrom-Json $mockDependencyObjectList
$ $PSScriptRoot/../dependency-scripts\download-db-dependencies.ps1 -dependencies $parsedDependencies

& $PSScriptRoot/../dependency-scripts\run-db-dependencies.ps1 `
    -dbServer "$dbServer,$dbServerPort" `
    -dbName $dbName `
    -useIntegratedSecurity:$useIntegratedSecurity `
    -username $username `
    -password $password
param (
    [string]$dbServer,
    [string]$dbServerPort,
    [string]$dbName,
    [string]$pathToTests,
    [string]$managedSchemas,
    [string]$queryTimeout,
    [switch]$useIntegratedSecurity = $false,
    [string]$username,
    [SecureString]$password
)

$ErrorActionPreference = "Stop"

Write-Output "Setting up tests"

& $PSScriptRoot/../run-flyway/run-flyway-migrate.ps1 `
    -dbServer $dbServer `
    -dbServerPort $dbServerPort `
    -dbName $dbName `
    -pathToMigrationFiles $pathToTests `
    -migrationHistoryTable TestingHistory `
    -managedSchemas $managedSchemas `
    -useIntegratedSecurity:$useIntegratedSecurity `
    -username $username `
    -password $password
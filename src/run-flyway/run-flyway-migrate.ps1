param (
    [string]$dbServer,
    [string]$dbServerPort,
    [string]$dbName,
    [string]$pathToMigrationFiles,
    [string]$extraParameters,
    [string]$migrationHistoryTable,
    [string]$baselineVersion = 0,
    [string]$managedSchemas,
    [switch]$enableOutOfOrder = $false,
    [switch]$useIntegratedSecurity = $false,
    [switch]$trustServerCertificate = $false,
    [switch]$validateMigrations = $false,
    [string]$username,
    [SecureString]$password
)
$ErrorActionPreference = "Stop";
. $PSScriptRoot/../exception-details.ps1

Write-Information -InformationAction Continue -MessageData "Running migrate..."   

$resolvedPaths = New-Object -TypeName "System.Collections.ArrayList"
$pathToMigrationFiles.Split(",") | ForEach-Object {
    if ([System.Environment]::OSVersion.Platform -eq "Unix") {
        $resolvedPaths.Add("filesystem:$(Resolve-Path $_)")
    } else {
        $resolvedPaths.Add("filesystem:`"$(Resolve-Path $_)`"")
    }
}

$flywayLocations = $resolvedPaths -Join ','

Write-Output "List of migration directories: = $flywayLocations"

try {
    $jdbcUrl = "jdbc:sqlserver://${dbServer}:$dbServerPort;databaseName=$dbName;"

    if ($useIntegratedSecurity) {
        $jdbcUrl += "integratedSecurity=true;"
    }

    if ($trustServerCertificate) {
        $jdbcUrl += "trustServerCertificate=true;"
    }

    $outOfOrderValue = $enableOutOfOrder.ToString().ToLower()
    $validateMigrationsValue = $validateMigrations.ToString().ToLower()
    $flywayParamArray = @(
        "-url=`"$jdbcUrl`""
        "-locations=$flywayLocations"
        "-installedBy=`"$username`""
        "-table=`"$migrationHistoryTable`""
        "-baselineOnMigrate=true"
        "-baselineVersion=`"$baselineVersion`""
        "-schemas=`"$managedSchemas`""
        "-outOfOrder=$outOfOrderValue"
        "-validateOnMigrate=$validateMigrationsValue"
    )

    $printableFlywayParamArray = $flywayParamArray.psobject.copy()

    if ($null -ne $password) {
        $cred = New-Object System.Management.Automation.PSCredential -ArgumentList $username, $password
        $plainPassword = $cred.GetNetworkCredential().Password

        $flywayParamArray += "-user=`"$userName`""
        $flywayParamArray += "-password=`"$plainPassword`""
        $printableFlywayParamArray += "-user=`"$userName`""
        $printableFlywayParamArray += "-password=`"$password`""
    }

    $flywayParams = [string]::Join(" ", $flywayParamArray)
    $flywayParams = $flywayParams + " $extraParameters"
    $printableFlywayParams = [string]::Join(" ", $printableFlywayParamArray) + " $extraParameters"

    Write-Output "Running the flyway command:"
    Write-Output "flyway $printableFlywayParams migrate"
    Invoke-Expression -Command "& flyway $flywayParams migrate" -ErrorAction Stop

    if ($LASTEXITCODE -ne 0) {
        throw "Running flyway exited with a non-successful exit code: $LASTEXITCODE"
    }

    if ($? -ne $true) {
        throw "Running flyway failed! See the logs above for more information."
    }
}
catch {
    Write-Host $_.Exception
    Write-ExceptionDetails $_.Exception
    throw
}

Write-Host "`nThe flyway command, migrate, completed successfully!"
param (
    [string]$dbServer,
    [string]$dbServerPort,
    [string]$dbName,
    [string]$pathToTests,
    [string]$managedSchemas,
    [string]$testTimeout,
    [switch]$useIntegratedSecurity = $false,
    [switch]$trustServerCertificate = $false,
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
    -trustServerCertificate:$trustServerCertificate `
    -username $username `
    -password $password


Write-Output "Toggling off schema binding for tests"

$fakeTablePattern = "tSQLt.FakeTable\s+(@TableName\s*=\s*)?N?'([^']+)'"
$objectNames = (
    Get-ChildItem $pathToTests/*.sql -File -Recurse |
    Where-Object { $_.Name.StartsWith("R__") } |
    ForEach-Object {
        Get-Content -Raw $_.FullName |
        Select-String -Pattern $fakeTablePattern -AllMatches |
        ForEach-Object { $_.Matches } |
        ForEach-Object { $_.Groups[2].Value }
    } |
    Sort-Object |
    Get-Unique
)
$objectNames = $objectNames -join ','
Write-Output $objectNames

$toggleQueryTimeout = 120
$removeSchemaBindingSql = $null
$restoreSchemaBindingSql = $null
$authSqlCmdParams = ''
$plainPassword = ''

if (-Not $useIntegratedSecurity) {
    $cred = New-Object System.Management.Automation.PSCredential -ArgumentList $username, $password
    $plainPassword = $cred.GetNetworkCredential().Password

    $authSqlCmdParams = "-Username `"$username`" -Password `"$plainPassword`""
}

if (-Not [string]::IsNullOrEmpty($objectNames)) {
    $setStatements = "
    SET NOEXEC OFF;
    SET ANSI_NULL_DFLT_ON ON;
    SET ANSI_NULLS ON;
    SET ANSI_PADDING ON;
    SET ANSI_WARNINGS ON;
    SET ARITHABORT ON;
    SET CONCAT_NULL_YIELDS_NULL ON;
    SET QUOTED_IDENTIFIER ON;
    SET XACT_ABORT ON;"

    $getToggleQuery = "
    $setStatements
    DECLARE @unbindSql VARCHAR(MAX);
    DECLARE @rebindSql VARCHAR(MAX);

    BEGIN TRY
        EXEC DBA.usp_ToggleSchemaBindingBatch @objectList = N'$objectNames', @mode = 'VARIABLE', @isSchemaBoundOnly = 1, @unbindSql = @unbindSql OUTPUT, @rebindSql = @rebindSql OUTPUT;
        SELECT @unbindSql as unbindSql, @rebindSql as rebindSql;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH;"

    Write-Output "Getting schemabinding toggle queries"
    $sqlCmdParams = @(
        "-ServerInstance `"$dbServer, $dbServerPort`""
        "-Database `"$dbName`""
        "-Query `"$getToggleQuery`""
        "-QueryTimeout $toggleQueryTimeout"
        "-MaxCharLength 150000"
    )
    if (-Not $useIntegratedSecurity) {
        $sqlCmdParams += $authSqlCmdParams
    }
    if ($trustServerCertificate) {
        $sqlCmdParams += "-TrustServerCertificate"
    }
    
    $paramsAsAString = [string]::Join(" ", $sqlCmdParams)
    
    $toggleschemabinding = Invoke-Expression -Command "Invoke-Sqlcmd $sqlCmdParams"
    Write-Output "Setting removeSchemaBindingSql"
    $removeSchemaBindingSql = "
        $setStatements
        BEGIN TRY
            BEGIN TRANSACTION;
            " + $toggleschemabinding.unbindSql + "
            COMMIT TRANSACTION;
        END TRY
        BEGIN CATCH
            IF (@@TRANCOUNT > 0)
            BEGIN
            ROLLBACK TRANSACTION;
            END;

            THROW;
            RETURN;
        END CATCH;"

    Write-Output "Setting restoreSchemaBindingSql"
    $restoreSchemaBindingSql = "
        $setStatements
        BEGIN TRY
            BEGIN TRANSACTION;
            " + $toggleschemabinding.rebindSql + "
            COMMIT TRANSACTION;
        END TRY
        BEGIN CATCH
            IF (@@TRANCOUNT > 0)
            BEGIN
            ROLLBACK TRANSACTION;
            END;

            THROW;
            RETURN;
        END CATCH;"
}

if (-Not [string]::IsNullOrEmpty($removeSchemaBindingSql)) {
    $sqlCmdParams = @(
        "-ServerInstance `"$dbServer, $dbServerPort`""
        "-Database `"$dbName`""
        "-QueryTimeout $toggleQueryTimeout"
        "-Query `"$removeSchemaBindingSql`""
    )
    if (-Not $useIntegratedSecurity) {
        $sqlCmdParams += $authSqlCmdParams
    }
    if ($trustServerCertificate) {
        $sqlCmdParams += "-TrustServerCertificate"
    }
    
    $paramsAsAString = [string]::Join(" ", $sqlCmdParams)
    $paramsAsAString = $paramsAsAString.Replace('"', '')
    Write-Output "SQL Command to run: $paramsAsAString"
    Invoke-Expression -Command "Invoke-Sqlcmd $paramsAsAString"
}

Write-Output "Running tSQLt tests"

& $PSScriptRoot/run-tsqlt.ps1 `
    -dbServer $dbServer `
    -dbServerPort $dbServerPort `
    -dbName $dbName `
    -queryTimeout $testTimeout `
    -useIntegratedSecurity:$useIntegratedSecurity `
    -trustServerCertificate:$trustServerCertificate `
    -username $username `
    -password $password

& $PSScriptRoot/print-results.ps1

Write-Output "Toggling on schema binding"

if (-Not [string]::IsNullOrEmpty($restoreSchemaBindingSql)) {
    $sqlCmdParams = @(
        "-ServerInstance `"$dbServer, $dbServerPort`""
        "-Database `"$dbName`""
        "-QueryTimeout $toggleQueryTimeout"
        "-Query `"$restoreSchemaBindingSql`""
    )
    if (-Not $useIntegratedSecurity) {
        $sqlCmdParams += $authSqlCmdParams
    }
    if ($trustServerCertificate) {
        $sqlCmdParams += "-TrustServerCertificate"
    }
    
    $paramsAsAString = [string]::Join(" ", $sqlCmdParams)
    $paramsAsAString = $paramsAsAString.Replace('"', '')
    Write-Output "SQL Command to run: $paramsAsAString"
    Invoke-Expression -Command "Invoke-Sqlcmd $paramsAsAString"
}
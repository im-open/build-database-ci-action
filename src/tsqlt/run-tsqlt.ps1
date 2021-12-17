param (
    [string]$dbServer,
    [string]$dbServerPort,
    [string]$dbName,
    [string]$queryTimeout,
    [switch]$useIntegratedSecurity = $false,
    [string]$username,
    [SecureString]$password
)

$ErrorActionPreference = "Stop"

$resultsfolder = Join-Path $PSScriptRoot "../test-results"
$resultsFile = Join-Path $resultsfolder "test-results.xml"

if (!(Test-Path $resultsfolder)) {
    New-Item $resultsfolder -ItemType Directory
}

if (!(Test-Path $resultsFile)) {
    New-Item -ItemType File -Force -Path $resultsFile
}

$runTestsSql = "
    IF EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[tSQLt].[RunAll]')
        AND TYPE IN (N'P',N'PC'))
    BEGIN
        EXECUTE [tSQLt].[RunAll];
    END;
    "

$getTestResultsSql = "
    :XML ON
    EXEC [tSQLt].[XmlResultFormatter];
    "

$queryTimeoutParam = if ($queryTimeout) { "-t $queryTimeout" } else { "" }
$authParams = ""

if ($useIntegratedSecurity) {
    $authParams = "-E"
}
else {
    $cred = New-Object System.Management.Automation.PSCredential -ArgumentList $username, $password
    $plainPassword = $cred.GetNetworkCredential().Password

    $authParams = "-U `"$username`" -P `"$plainPassword`""
}

try {
    Write-Output "Executing tSQLt tests"
    Invoke-Expression "& sqlcmd $authParams -S `"$dbServer,$dbServerPort`" -d `"$dbName`" -Q `"$runTestsSql`" $queryTimeoutParam"
    $results = Invoke-Expression "& sqlcmd $authParams -b -S `"$dbServer,$dbServerPort`" -d `"$dbName`" -h-1 -I -Q `"$getTestResultsSql`" $queryTimeoutParam"

    # Catch when an error happens in the test run (e.g. query timeout)
    if ($results -notlike "*testsuites*") {
        throw $results
    }
}
catch {
    Write-Output $_.Exception
    throw
}
finally {
    $regex = [regex]::Match($results, '<testsuites>[\s\S]+<\/testsuites>')
    if ($regex.Success) {
        $regex.captures.groups[0].value > $resultsFile
    }
}
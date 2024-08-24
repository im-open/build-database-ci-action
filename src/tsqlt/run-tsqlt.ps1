param (
    [string]$dbServer,
    [string]$dbServerPort,
    [string]$dbName,
    [string]$queryTimeout,
    [switch]$useIntegratedSecurity = $false,
    [switch]$trustServerCertificate = $false,
    [string]$username,
    [SecureString]$password,
    [string]$resultsFile
)

$ErrorActionPreference = "Stop"


$runTestsSql = "
    IF EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[tSQLt].[RunAll]')
        AND TYPE IN (N'P',N'PC'))
    BEGIN
        EXECUTE [tSQLt].[RunAll];
    END;
    "

$getTestResultsSql = "
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

if ($trustServerCertificate) {
    $authParams += " -C"
}

try {
    Write-Output "Executing tSQLt tests"
    Invoke-Expression "& sqlcmd $authParams -S `"$dbServer,$dbServerPort`" -d `"$dbName`" -Q `"$runTestsSql`" $queryTimeoutParam"
    $results = Invoke-Expression "& sqlcmd $authParams -b -S `"$dbServer,$dbServerPort`" -d `"$dbName`" -h-1 -I -Q `"$getTestResultsSql`" $queryTimeoutParam" | ConvertTo-Xml -As String

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
    else{
        Write-Output $results
        throw "Unable to parse testsuites from XML"
    }
}
param (
    [string]$dbServer,
    [string]$dbServerPort,
    [string]$dbName,
    [int]$queryTimeout = 0,
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

$getResultSummarySql = "
    SELECT
        TestCaseSummary.Msg,
        TestCaseSummary.Cnt,
        TestCaseSummary.SuccessCnt,
        TestCaseSummary.SkippedCnt,
        TestCaseSummary.FailCnt,
        TestCaseSummary.ErrorCnt
    FROM tSQLt.TestCaseSummary();
    "
$getErrorDetailSql = "
    SELECT
        TestResult.Name,
        TestResult.Result,
        TestResult.Msg
    FROM tSQLt.TestResult
    WHERE TestResult.Result IN ('Failure', 'Error')
    "

$queryTimeoutParam = if ($queryTimeout) { "-t $queryTimeout" } else { "" }
$authParams_sqlcmd = ""
$authParams_PS = ""

if ($useIntegratedSecurity) {
    $authParams_sqlcmd = "-E"
}
else {
    $cred = New-Object System.Management.Automation.PSCredential -ArgumentList $username, $password
    $plainPassword = $cred.GetNetworkCredential().Password

    $authParams_sqlcmd = "-U `"$username`" -P `"$plainPassword`""
    $authParams_PS = "-Credential `"$cred`""
}

if ($trustServerCertificate) {
    $authParams_sqlcmd += " -C"
    $authParams_PS += " -TrustServerCertificate"
}

try {
    Write-Output "Executing tSQLt tests"
    Invoke-Expression "& sqlcmd $authParams_sqlcmd -S `"$dbServer,$dbServerPort`" -d `"$dbName`" -Q `"$runTestsSql`" $queryTimeoutParam"
    
    $resultSummary = Invoke-Expression "& Invoke-Sqlcmd -ServerInstance `"$dbServer,$dbServerPort`" -Database `"$dbName`" $authParams_PS -Query `"$getResultSummarySql`" -QueryTimeout $queryTimeout"

}
catch {
    Write-Output $_.Exception
    throw
}
finally {
    # Catch when an error happens in the test run (e.g. query timeout)
    if ($resultSummary.Count -eq 0) {
        throw "A fatal error occurred that prevented the reporting of results"
    }
    else {
        $errorDetail = Invoke-Expression "& Invoke-Sqlcmd -ServerInstance `"$dbServer,$dbServerPort`" -Database `"$dbName`" $authParams_PS -Query `"$getErrorDetailSql`" -QueryTimeout $queryTimeout"
 
        if ($errorDetail.Count -gt 0){
            foreach ($testResult in $errorDetail) {
                Write-Output "$($testResult.Name) $($testResult.Result.ToUpper())!`nMessage: $($testResult.Msg)`n"
            }
            throw "Some tests failed or had errors."
        }
    }
}
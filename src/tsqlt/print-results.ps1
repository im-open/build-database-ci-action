$numErrored = 0
$numFailed = 0
$totalTests = 0
$resultXmlPath = Join-Path $PSScriptRoot "../test-results/test-results.xml"

[xml]$resultXml = Get-Content $resultXmlPath
if ($null -ne $resultXml) {
    foreach ($testsuite in $resultXml.testsuites.testsuite) {
        $numErrored += $testsuite.errors
        $numFailed += $testsuite.failures 
    }
    foreach ($testcase in $resultXml.testsuites.testsuite.testcase) {
        $totalTests++
        $testname = "[$($testcase.classname)].[$($testcase.name)]"
        if ($null -ne $($testcase.error)) {
            Write-Output "$testname ERRORED!`nError Message: $($testcase.error.message)`n"
        } 
        elseif ($null -ne $($testcase.failure)) {
            Write-Output "$testname FAILED!`nFailure Message: $($testcase.failure.message)`n"
        }
    }
}

Write-Output "Number of tests: $totalTests"
Write-Output "Number of failures: $numFailed"
Write-Output "Number of errors: $numErrored"

echo "::set-output name=number_of_tests::$totalTests"
echo "::set-output name=number_of_failures::$numFailed"
echo "::set-output name=number_of_errors::$numErrored"
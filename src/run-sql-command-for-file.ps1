param (
    [string]$dbServer,
    [string]$dbName,
    [string]$pathToFile,
    [string]$sqlCmdVariables,
    [switch]$useIntegratedSecurity = $false,
    [string]$username,
    [securestring]$password
)

$ErrorActionPreference = "Stop";
Import-Module SqlServer

$sqlCmdParams = @(
    "-InputFile $pathToFile"
    "-ServerInstance `"$dbServer`""
    "-Database `"master`""
    "-AbortOnError"
    "-SeverityLevel 0"
    "-ErrorLevel 0"
    "-Verbose"
    "-Variable @(`"$sqlCmdVariables`")"
)

if (!$useIntegratedSecurity) {
    $cred = New-Object System.Management.Automation.PSCredential -ArgumentList $username, $password
    $plainPassword = $cred.GetNetworkCredential().Password

    $sqlCmdParams += "-Username $username"
    $sqlCmdParams += "-Password $plainPassword"
}

$paramsAsAString = [string]::Join(" ", $sqlCmdParams)

Invoke-Expression -Command "Invoke-Sqlcmd $paramsAsAString"
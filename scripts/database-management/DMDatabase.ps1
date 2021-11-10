function Invoke-SqlByFileName {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$scriptPath,
        [string]$hostName,
        [string]$port,        
        [string]$targetDatabase,
        [string]$connectionDatabase,
        [string]$username,
        [SecureString]$password
    )
    
    $parameters = @(
        "-InputFile `"$scriptPath`""
        "-ServerInstance `"$hostName`""
        "-Database `"$connectionDatabase`""
        "-AbortOnError"
        "-SeverityLevel 0"
        "-ErrorLevel 0"
        "-Verbose"
        "-Variable @(`"DatabaseName = $targetDatabase`")"
    )

    if ($username) {
        $plainPassword = Get-PlainTextPassword $password

        $parameters += "-Username $username"
        $parameters += "-Password '$plainPassword'"
    }

    $parametersString = [string]::Join(" ", $parameters)
    $expression = "Invoke-Sqlcmd $parametersString"
    Invoke-Expression $expression
}

function Remove-Db {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$instanceName,
        [Parameter(Mandatory)]
        [string]$dbName
    )

    Write-Verbose "Dropping Database $dbName on $instanceName"
    $serverInstance = New-Object -TypeName "Microsoft.SqlServer.Management.Smo.Server" -ArgumentList $instanceName
    if ($serverInstance.Databases[$dbName]) {
        $serverInstance.KillDatabase($dbName)
    }
    
    Write-Verbose "Task complete (either the database was dropped or it did not exist)"
}

function Get-DbConnectionUrl () {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [string]$hostName,
        [string]$port,
        [string]$database,
        [switch]$useIntegratedSecurity
    )

    $jdbcUrl = "jdbc:sqlserver://${hostName}:$port;databaseName=$database;"

    if ($useIntegratedSecurity) {
        $jdbcUrl += "integratedSecurity=true;"
    }

    return $jdbcUrl
}
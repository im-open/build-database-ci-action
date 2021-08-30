function Write-Host-Error([string]$message) {
    Write-Error $message -ForegroundColor Red
}

function Assert-DbNameValid {
    param(
        [string]$name,
        [string[]]$forbiddenDbNames
    )

    if ($forbiddenDbNames.Contains(($name.ToLower()))) {
        $errorMessage = "$name is not available for a database name because it conflicts with a linked server in the ExtendHealth database"
        Write-Status $errorMessage
        throw $errorMessage
    }
}

function Show-ExternalError() {
    Show-ErrorBase (Get-LastExitCode $true)
}

function Show-Error() {
    Show-ErrorBase (Get-LastExitCode $false)
}

function Show-ErrorBase($exitCode) {
    if ($exitCode -ne 0) {
        Write-Status "Error occurred $exitCode"
        throw $exitCode
    }
}

function Get-LastExitCode([bool] $isExternalCommand = $false) {
    if ($isExternalCommand) {
        if ($LASTEXITCODE -ne 0) {
            return $LASTEXITCODE
        }
    }

    if ($? -ne $true) {
        return -1
    }

    return 0
}

function Get-ElapsedTime {
    [OutputType([String])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [datetime]$start,
        [Parameter(Mandatory)]
        [datetime]$end
    )
    $elapsed = $end - $start
    $elapsedString = ""
    if ($elapsed.TotalSeconds -eq 0) {
        $elapsedString = "$($elapsed.TotalMilliseconds)ms"
        return $elapsedString
    }
    
    if ($elapsed.Hours -gt 0) {
        $elapsedString += $elapsed.ToString("hh") + ":"
    }
    $elapsedString += $elapsed.ToString("mm\:ss")
    return $elapsedString
}

function Write-SectionBreak () {
    Write-Status ("-" * (get-host).UI.RawUI.MaxWindowSize.Width)
}

function Invoke-Log {
    param(
        [string]$logData
    )
    Write-Verbose $logData
} 		 

function Invoke-Git {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string[]]$argumentList,
        [switch]$returnOutput,
        [switch]$showOutput
    )            
    $gitPath = & "C:\Windows\System32\where.exe" git
    $gitErrorPath = Join-Path $PSScriptRoot "stderr.txt"
    $gitOutputPath = Join-Path $PSScriptRoot "stdout.txt"

    if ($gitPath.Count -gt 1) {
        $gitPath = $gitPath[0]
    }

    if ($showOutput) {
        Write-Status "> git $([System.String]::Join(" ", $argumentList))"
    }

    $process = Start-Process $gitPath -ArgumentList $argumentList -NoNewWindow -PassThru -Wait -RedirectStandardError $gitErrorPath -RedirectStandardOutput $gitOutputPath

    $outputText = (Get-Content $gitOutputPath)
    if ($showOutput) {
        $outputText | ForEach-Object { Write-Status $_ }
    }
    
    if ($process.ExitCode -ne 0) {
        $errorText = (Get-Content $gitErrorPath)

        if ($showOutput) {
            $errorText | ForEach-Object { Write-Host-Error $_ }
        }
        
        if ($null -ne $errorText) {                
            throw "$errorText `r`n $(Get-PSCallStack)"
        }
    }
    if ($returnOutput) {
        if ([string]::IsNullOrEmpty($outputText)) {
            throw "git command did not return anything. `r`n $(Get-PSCallStack)"
        }
        return $outputText
    }
}

function Get-SchemaBoundObject {        
    param (
        [string] $path
    )
    $fakeTablePattern = "tSQLt.FakeTable\s+(@TableName\s*=\s*)?N?'([^']+)'"
    $objectNames = (
        Get-ChildItem $path\*.sql -File -Recurse |
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
    return $objectNames
}

function Write-Status {
    param (
        [string] $message
    )
    Write-Information -InformationAction Continue -MessageData $message
}

function Get-ExceptionDetails {
    [CmdletBinding()]
    param (
        [Exception]$exception
    )
    $ex = $exception

    $items = [System.Collections.Generic.List[hashtable]]::new()
    while ($ex -ne $null) {
        $item = @{}

        $typeName = $ex.GetType().Name
        $item.Add("Message", $ex.Message)
        $item.Add("StackTrace", $ex.StackTrace)
        
        if ($typeName -eq "SqlException") {
            $item.Add("Source", $ex.Source)
            $item.Add("Class", $ex.Class)
            $item.Add("LineNumber", $ex.LineNumber)
            $item.Add("Procedure", $ex.Procedure)
            $item.Add("Server", $ex.Server)
            $item.Add("ClientConnectionId", $ex.ClientConnectionId)                                    
            $count = 1
            foreach ($error in $ex.Errors) {              
                $item.Add("Error$count", $error)
                $count++
            }
        }   

        if ($typeName -eq "SqlPowerShellSqlExecutionException") {
            $item.Add("SqlError", $ex.SqlError)
        }

        $items.Add($item)
        $ex = $ex.InnerException
    }    

    $details = $items | ConvertTo-Json -Compress

    return $details
}

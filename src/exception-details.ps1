function Write-ExceptionDetails {
    [CmdletBinding()]
    param (
        [Exception]$exception
    )
    $ex = $exception

    Write-Host "Flyway Command Failed"

    $items = [System.Collections.Generic.List[hashtable]]::new()
    while ($null -ne $ex) {
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

    Write-Error $details
}
. $PSScriptRoot\DMDatabase.ps1
. $PSScriptRoot\DMConfig.ps1
. $PSScriptRoot\DMHelper.ps1
. $PSScriptRoot\DMDependencies.ps1

<#
.SYNOPSIS
Creates a new database or runs migrations not yet applied to database.

.DESCRIPTION
This is what will create or migrate a database and run unit tests that have been created with tSQLt. 

.PARAMETER projectRoot
The root of the project that indicates where migrations, snapshot, tests and other folders stem from. (Default to local project root by git file)

.PARAMETER dbName
Name of Database. Expected to be a new database name and not an existing one. (Optional)

.PARAMETER hostName
Name of the server. (Optional)

.PARAMETER port
Port to determine instance on the server. (Optional)

.PARAMETER incremental
When set the database be updated with migrations scripts that have not been applied. (Default to rebuild database)

.PARAMETER dropDbAfterBuild
The database will be dropped after the build is run when switch is set. (Default to not drop database)

.PARAMETER runTests
Indicates you want to run tests when set. (Default to not run tests)

.PARAMETER seedData
Indicates you want to load data to your database for testing or using with an application. (Default to not Load Data)

.PARAMETER runAllMigrations
Indicates that you want to include all baseline migrations in the run

.PARAMETER installMockDbObjects
Indicates you want to install db objects a bounded context is dependent on. Requires .dmconfig to have paths { dependencies = "", dependenciesOutputFolder = ""}; sqlDependencies.csv in format PackageName:Version (Default to not install)

.EXAMPLE
Invoke-DatabaseBuild
Invoke-DatabaseBuild -dbName "TestDatabase" -hostName "localhost" -port 1433
Invoke-DatabaseBuild -dbName "TestDatabase" -hostName "localhost" -port 1433 -seedData
Invoke-DatabaseBuild -dbName "TestDatabase" -hostName "localhost" -port 1433 -incremental

.NOTES
By default with no parameters this will create a new database named 'LocalExtendHealth' on 'localhost,1433' and not run tests. It will drop
the database if one is named the same and will not update flyway. You can wrap this module in you own custom script if a command to just migration or
test without putting in the same parameters. Also customize the .dmconfig.json if you want to set a different database name and instance.

.LINK
https://github.com/im-practices/database-migrator
http://kb.extendhealth.com/display/PD/Database+Migrator+Tool

#>
function Invoke-DatabaseBuild {
    [CmdletBinding()]
    param(
        [string]$projectRoot = (Get-ProjectRoot),
        [string]$dbName, 
        [string]$hostName,
        [string]$port,
        [switch]$incremental,
        [switch]$dropDbAfterBuild,
        [switch]$runTests = $false,
        [switch]$seedData = $false,
        [switch]$runAllMigrations,
        [switch]$installMockDbObjects,
        [string]$queryTimeout
    )
    Clear-DmConfigCache
    if (!$dbName) {
        $dbName = (Get-DMConfig -projectRoot $projectRoot).db.name
    }
    if (!$hostName) {
        $hostName = (Get-DMConfig -projectRoot $projectRoot).db.hostName
    }
    if (!$port) {
        $port = (Get-DMConfig -projectRoot $projectRoot).db.port
    }
    if (!$queryTimeout){
        $queryTimeout = (Get-DMConfig -projectRoot $projectRoot).db.queryTimeout
    }

    $baselineScriptName = Join-Path $projectRoot (Get-DMConfig -projectRoot $projectRoot).DbScripts.databaseInitialization -Resolve
    $sqlFolder = Join-Path $projectRoot (Get-DMConfig -projectRoot $projectRoot).paths.migrations -Resolve

    $start = [DateTime]::Now
    $ErrorActionPreference = "Stop";
    $exitCode = 0;

    Assert-DbNameValid $dbName (Get-DMConfig -projectRoot $projectRoot).db.forbiddenDbNames

    if ($incremental -eq $false)
    {
        Remove-Db "$hostName,$port" $dbName
        Write-Verbose "Executing Create Database Expression:"
        Write-Verbose "The command is [Invoke-SqlByFileName -scriptPath $baselineScriptName -hostName $hostName -port $port -targetDatabase $dbName -connectionDatabase master]"
        Invoke-SqlByFileName -scriptPath $baselineScriptName -hostName $hostName -port $port -targetDatabase $dbName -connectionDatabase "master"
        Show-Error
        Write-Status "Database $dbName created successfully"
    }

    if ($installMockDbObjects) {
        $dependenciesOutputFolder = Join-Path $projectRoot (Get-DMCOnfig -projectRoot $projectRoot).paths.dependenciesOutputFolder
        $dependenciesFile = Join-Path $projectRoot (Get-DMCOnfig -projectRoot $projectRoot).paths.dependencies -Resolve
        Install-DbObjectDependencies -dependenciesFile $dependenciesFile -outputFolder $dependenciesOutputFolder
        Get-ChildItem -Path $dependenciesOutputFolder -Recurse -Depth 1 -Filter *.sql | ForEach-Object {
            Invoke-SqlByFileName -scriptPath $_.FullName -hostName $hostName -port $port -targetDatabase $dbName -connectionDatabase $dbName
        }
    }

    try
    {   
        $baselineVersion = 0
        
        if($incremental -eq $true) {
            $baselineVersion = 0.1 # this will allow us to ignore missing migrations when running flyway
            $runAllMigrations = $true # if running incremental we do not want to run baseline snapshot as this could break a deployment. We never want to run baseline snapshot when deploying migrations
        }
        $baselineSnapshotFolder = (Get-DMConfig -projectRoot $projectRoot).paths.baselineSnapshot
        if ($runAllMigrations -eq $false -and $baselineSnapshotFolder) {
            $versions = Get-Version -sqlFolder $baselineSnapshotFolder
            $baselineVersion = ($versions | Measure-Object -Maximum).Maximum
            Invoke-FlywayBaseline -hostName $hostName -port $port -dbName $dbName -MigrationHistoryTable "MigrationHistory" -projectRoot $projectRoot -baselineVersion $baselineVersion
            Invoke-Flyway -hostName $hostName -port $port -dbName $dbName -scriptFolder $baselineSnapshotFolder -MigrationHistoryTable "MigrationHistory" -projectRoot $projectRoot -baselineVersion $baselineVersion
        }
        Write-Status "Executing Flyway build and migrations";
        Write-Verbose "The command is: [Invoke-Flyway -hostName $hostName -port $port -dbName $dbName -scriptFolder $sqlFolder -MigrationHistoryTable ""MigrationHistory""]"
        Invoke-Flyway -hostName $hostName -port $port -dbName $dbName -scriptFolder $sqlFolder -MigrationHistoryTable "MigrationHistory" -projectRoot $projectRoot -baselineVersion $baselineVersion
        Show-ExternalError
        if ($runTests) {
            [int]$errorCount = 0
            [int]$failCount = 0
            [string]$testErrorMessage = ""
            Test-Migration -hostName $hostName -port $port -database $dbName -projectRoot $projectRoot -queryTimeout $queryTimeout ([ref]$errorCount) ([ref]$failCount)
            Write-Verbose "Tests Errored = $errorCount"
            Write-Verbose "Tests Failed = $failCount"
            if ($errorCount -gt 0) {
                $testErrorMessage += "$errorCount test(s) errored"
            }
            if ($failCount -gt 0) {
                $testErrorMessage += "`n$failCount test(s) failed"
            }
            if ($testErrorMessage.Length -gt 0) {
                throw $testErrorMessage
            }
        }

        if ($seedData) {
            Invoke-LoadSeedData -hostName $hostName -port $port -database $dbName -projectRoot $projectRoot
        }
    }
    catch
    {
        $exitCode = 1
        $errorMessage = "DMFlyway.ps1 exception: `r`n $(Get-PSCallStack)"
        Write-Status "$errorMessage `r`n $(Get-ExceptionDetails $_.Exception)"
        throw $errorMessage
    }
    finally
    {
        try
        {
            if ($dropDbAfterBuild)
            {
                Remove-Db "$hostName,$port" $dbName
            }
        }
        catch
        {
            Write-Status "Unable to drop database `r`n $(Get-ExceptionDetails $_.Exception)"
            throw
        }

        $end = [DateTime]::Now
        $elapsed = Get-ElapsedTime $start $end
        $errorMessage = "successfully"
        if ($exitCode -ne 0)
        {
            $errorMessage = "with errors"
        }

        Write-Status "Execution of Invoke-DatabaseBuild completed $errorMessage in: $elapsed"
        Write-Status "Invoke-DatabaseBuild Exiting with code: $exitCode"
        Write-SectionBreak
    }
}

function Test-Migration {
    param (
        [string]$database,
        [string]$hostName,
        [string]$port,
        [string]$projectRoot = (Get-ProjectRoot),
        [string]$queryTimeout,
        [ref][int]$numTestsErrored,
        [ref][int]$numTestsFailed
    )

    $unitTestingFolder = Join-Path $projectRoot (Get-DMConfig -projectRoot $projectRoot).paths.unitTests -Resolve
    $resultXmlPath = Join-Path $projectRoot "bin\test-results.xml"
    $numErrored = 0
    $numFailed = 0

    Invoke-Flyway -dbName "$database" -HostName "$hostName" -port $port -scriptFolder $unitTestingFolder -MigrationHistoryTable "TestingHistory" -projectRoot $projectRoot
    Show-ExternalError
    $testStart = [DateTime]::Now
    Write-Status "Running Unit Tests"
    Invoke-TSQLTTestRunner -hostName "$hostName" -port $port -DbName "$database" -projectRoot $projectRoot -queryTimeout $queryTimeout
    # determine if any tests have failed
    [xml]$resultXml = Get-Content $resultXmlPath
    if ($null -ne $resultXml) {
        foreach ($testsuite in $resultXml.testsuites.testsuite){
            $numErrored += $testsuite.errors
            $numFailed += $testsuite.failures 
        }
        foreach ($testcase in $resultXml.testsuites.testsuite.testcase){
            $testname = "[$($testcase.classname)].[$($testcase.name)]"
            if ($null -ne $($testcase.error)){
                Write-Status "$testname ERRORED!`nError Message: $($testcase.error.message)`n"
            } 
            elseif ($null -ne $($testcase.failure)){
                Write-Status "$testname FAILED!`nFailure Message: $($testcase.failure.message)`n"
            }
        }
    }
    $numTestsErrored.Value = $numErrored
    $numTestsFailed.Value = $numFailed

    Show-ExternalError
    $testEnd = [DateTime]::Now
    $testRunTime = Get-ElapsedTime $testStart $testEnd
    Write-Status "Unit test run completed in $testRunTime"
    Write-SectionBreak
}

function Invoke-LoadSeedData {
    param (
        [string]$database,
        [string]$hostName,
        [string]$port,
        [string]$projectRoot = (Get-ProjectRoot)
    )

    $seedDataFolder = Join-Path $projectRoot (Get-DMConfig -projectRoot $projectRoot).paths.databaseSeedData -Resolve
    
    Write-Status "Executing Flyway for test data";
    Invoke-Flyway -dbName "$database" -HostName "$hostName" -port $port -scriptFolder $seedDataFolder -MigrationHistoryTable "SeedDataHistory" -projectRoot $projectRoot
    Show-ExternalError
}

function Invoke-TSQLTTestRunner {
    [CmdletBinding()]
    param
    (
        [string]$hostName,
        [string]$port,
        [string]$dbName,
        [string]$projectRoot, 
        [string]$queryTimeout
    )
    $ErrorActionPreference = "Stop"

    $folder = Join-Path $projectRoot "bin"
    $resultsFile = Join-Path $folder "test-results.xml"
    $unitTestingFolder = Join-Path $projectRoot (Get-DMConfig -projectRoot $projectRoot).paths.unitTests -Resolve 
    $removeSchemaBindingSql = $null
    $restoreSchemaBindingSql = $null
    
    if (!(Test-Path $folder)) {
        New-Item $folder -ItemType Directory
    }
    
    if (!(Test-Path $resultsFile)) {
        New-Item -ItemType File -Force -Path $resultsFile
    }

    # Parse all test scripts to retrieve objects for which dependent objects will need schemabinding removed; format as comma-delimited string
    $objectNames = (Get-SchemaBoundObject -path $unitTestingFolder) -join ','

    # Get scripts to unbind and rebind for toggling schemabinding on all downstream dependencies for $objectNames
    if (-Not [string]::IsNullOrEmpty($objectNames)) {
        Write-Verbose "objectNames = '$objectNames'"
        Get-Schemabinding-Toggle-Queries -hostname $hostName -dbName $dbName -objectNames $objectNames ([ref]$removeSchemaBindingSql) ([ref]$restoreSchemaBindingSql)
        Write-Verbose "removeSchemaBindingSql = '$removeSchemaBindingSql'"
        Write-Verbose "restoreSchemaBindingSql = '$restoreSchemaBindingSql'"
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
    try {
        # Toggle schemabinding off if there are objects that need it
        if (-Not [string]::IsNullOrEmpty($removeSchemaBindingSql)) { 
            Write-Verbose "Executing toggle schemabinding off"
            Invoke-Sqlcmd -ServerInstance "$hostname" -Database "$dbName" -Query "$removeSchemaBindingSql" -QueryTimeout $queryTimeout
        }

        Write-Verbose "Executing tSQLt tests"
        sqlcmd -E -S "$hostName,$port" -d "$dbName" -Q "$runTestsSql" -t $queryTimeout
        $results = sqlcmd -E -b -S "$hostName,$port" -d "$dbName" -h-1 -I -Q "$getTestResultsSql" -t $queryTimeout

        # Catch when an error happens in the test run (e.g. query timeout). This may not be the correct error from SSMS but will fail the build
        if ($results -notlike "*testsuites*"){
            throw $results
        }
       
        # Toggle schemabinding on if there are objects that need it
        if (-Not [string]::IsNullOrEmpty($restoreSchemaBindingSql)) {
            Write-Verbose "Executing toggle schemabinding on"
            Invoke-Sqlcmd -ServerInstance "$hostname" -Database "$dbName" -Query "$restoreSchemaBindingSql" -QueryTimeout $queryTimeout
        }
    }
    catch{
        Write-Status $(Get-ExceptionDetails $_.Exception)
        throw
     }
    finally {
        $regex = [regex]::Match($results, '<testsuites>[\s\S]+<\/testsuites>')
        if($regex.Success){
            $regex.captures.groups[0].value > $resultsFile
        }
    }
    Write-SectionBreak
}

function Get-Schemabinding-Toggle-Queries {
    param
    (
        [string] $hostname,
        [string] $dbName,
        [string] $objectNames,
        [ref][string] $removeSchemaBindingSql,
        [ref][string] $restoreSchemaBindingSql
    )

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

    $toggleQueryTimeout = 120

    Write-Verbose "Getting schemabinding toggle queries"
    $toggleschemabinding = Invoke-Sqlcmd -ServerInstance "$hostname" -Database "$dbName" -Query "$getToggleQuery" -QueryTimeout $toggleQueryTimeout -MaxCharLength 150000
    $removeSchemaBindingSql.Value = "
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
    $restoreSchemaBindingSql.Value = "
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

function Invoke-Flyway {
    [OutputType([System.Int32])]
    [CmdletBinding()]
    param (
        [string]$dbName, #(Optional) generated based off build number if not specified
        [string]$port, # the port (always required)
        [string]$hostName, # the name of the SQL Server instance (always required)
        [string]$scriptFolder, #= locations of migrations,
        [string]$MigrationHistoryTable, #= "TestingHistory" #"Flyway.Testing"
        [string]$baselineVersion = 0, # Starting Version Number for Migration
        [string]$projectRoot,
        [switch]$enableOutOfOrder = $false
    )
    $ErrorActionPreference = "Stop";

    $flywayLocations =  "filesystem:`"" + (Resolve-Path $scriptFolder) + "`"" 

    Write-Status "Run flyway..."
    try
    {
        $outOfOrderValue = $enableOutOfOrder.ToString().ToLower()
        $managedSchemas = (Get-DMConfig -projectRoot $projectRoot).Flyway.managedSchema
        $jdbcUrl = Get-DbConnectionUrl -hostName $hostName -port $port -database $dbName
        $flywayParamArray = @(
            '-n'
            "-url=$jdbcUrl"
            "-placeholders.DatabaseName=$dbName"
            "-locations=$flywayLocations"
            "-installedBy=$currentUserName"
            "-table=$MigrationHistoryTable"
            "-baselineOnMigrate=true"
            "-baselineVersion=$baselineVersion"
            "-schemas=`"$managedSchemas`""
            "-outOfOrder=$outOfOrderValue"
        )
        $flywayParams = [string]::Join(" ", $flywayParamArray)
        if ($baselineVersion -gt 0) {
            $flywayParams = $flywayParams + " -ignoreMissingMigrations=true"
        }
        Write-Verbose "Running migrations: [flyway $flywayParams migrate]"
        Invoke-Log ( cmd /c "flyway $flywayParams migrate" )
        Show-ExternalError
    }
    catch
    {
        Write-Status $(Get-ExceptionDetails $_.Exception)
        throw
    }
    Write-Status "Flyway ran successfully!"
}

function Invoke-FlywayBaseline {
    [OutputType([System.Int32])]
    [CmdletBinding()]
    param (
        [string]$dbName, #(Optional) generated based off build number if not specified
        [string]$port, # the port (always required)
        [string]$hostName, # the name of the SQL Server instance (always required)
        [string]$MigrationHistoryTable, #= "TestingHistory" #"Flyway.Testing"
        [string]$baselineVersion = 0, # Starting Version Number for Migration
        [string]$projectRoot
    )
    $ErrorActionPreference = "Stop";

    Write-Status "Run Flyway baseline..."
    try
    {
        $jdbcUrl = Get-DbConnectionUrl -hostName $hostName -port $port -database $dbName
        $managedSchemas = (Get-DMConfig -projectRoot $projectRoot).Flyway.managedSchema
        $flywayParamArray = @(
            '-n'
            "-url=$jdbcUrl"
            "-placeholders.DatabaseName=$dbName"
            "-table=$MigrationHistoryTable"
            "-baselineVersion=$baselineVersion"
            "-schemas=`"$managedSchemas`""
        )
        $flywayParams = [string]::Join(" ", $flywayParamArray)

        Write-Verbose "Running migrations: [flyway $flywayParams baseline]"
        Invoke-Log ( cmd /c "flyway $flywayParams baseline" )
        Show-ExternalError
    }
    catch
    {
        Write-Error $_.Exception
        throw
    }
    Write-Status "Flyway baseline ran successfully!"
}

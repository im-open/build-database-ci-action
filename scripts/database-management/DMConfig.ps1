Write-Debug("********DMConfig.ps1 INIT********")
$dmConfig = $null

function Get-ProjectRoot {
    [CmdletBinding()]
    param ()

    # USES FOR Get-ProjectRoot
    # ---------------------------------------------------------------------------------
    # Creating a new dmconfig - WHERE TO PUT THE FILE
    # Pass to Get-DMConfig 
    # To get the full path to the Init Script "src\Init\Initialization.sql"
    # To get the full path to the Migrations folder "src\Migrations"
    # To get the full path to the UnitTests folder "src\Testing"
    # To get the full path to the DatabaseSeedData folder "src\SeedData"
    # To get the full path to the Snapshot folder "src\snapshot"
    # To get the full path to the Bin folder "src\bin"
    # Invoke-Flyway with -projectRoot
    # Test-Migration with -projectRoot
    # Invoke-LoadSeedData with -projectRoot
    # Invoke-TSQLTTestRunner with -projectRoot
    # Invoke-DatabaseBuild with -projectRoot


    try {
        $gitResult = Invoke-Git -argumentList @("rev-parse", "--show-toplevel") -returnOutput
        return $gitResult
    }
    catch {
        return [Environment]::CurrentDirectory
    }
    
}

function Get-GitRemoteUrl {
    [CmdletBinding()]
    param ()
    return Invoke-Git -argumentList @("config", "--get", "remote.origin.url") -returnOutput
}

function Get-DMConfig {
    [CmdletBinding()]
    param(
        # [Parameter(Mandatory=$true)]
        $projectRoot
    )

    Write-Debug("Checking if dmConfig is null")
    Write-Debug("Value for dmConfig is $script:dmConfig")
    
    if (!$script:dmConfig) {
        Write-Debug("dmConfig was null, calling Find-DMConfig")
        $script:dmConfig = Find-DMConfig -path $projectRoot
    }
    else {
        Write-Debug("dmConfig not null, using cached version")
    }

    Write-Debug("Checking if we found dmConfig")
    
    if ($null -eq $script:dmConfig) {
        $errorMessage = "No .dmconfig.psd1 file found at: $projectRoot. `r`n $(Get-PSCallStack)"
        Write-Status $errorMessage
        throw $errorMessage
    }    
    Write-Debug("After finding dmConfig, dmConfig = $script:dmConfig")

    Write-Debug("We found dmConfig, returning it")
    return $script:dmConfig
}

function Find-DMConfig {
    param (
        [string]$path,
        [string]$name = '.dmconfig.psd1'
    )

    Write-Debug("Executing Find-DMConfig with path = $path")

    if ($path) {
        Write-Debug("path was specified, creating fullPath")
        $fullPath = (Join-Path $path $name)
        Write-Debug("fullPath = $fullPath")
    }
    else {
        Write-Debug("path was null, setting fullPath to null")
        $fullPath = $null
    }

    $dmConfig = $null
    if (($fullPath -ne $null) -And (Test-Path $fullPath)) {
        Write-Debug("fullPath was valid, reading dmConfig file")
        $dmConfig = Import-LocalizedData -BaseDirectory $path -FileName $name
    }
    else {
        Write-Debug("dmConfig not found - throwing")
        Throw "Error - dmconfig file was not found in specified location"
    }
    return $dmConfig
}

<#
.SYNOPSIS
Clears out the cached dmconfig. 

.DESCRIPTION 
The dmconfig is cached per powershell session. To help avoid problems if changes are made, this function will be 
called by the main functions that are used for the tooling. 
#>
function Clear-DmConfigCache {
    $script:dmConfig = $null
}

function Get-ConfigTemplate {
    param(
        [string]$Path
    )
    $json = Get-Content -Path $Path | Out-String
    return $json
}

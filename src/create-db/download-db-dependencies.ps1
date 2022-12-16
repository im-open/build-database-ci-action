param(
    [PSCustomObject[]]$dependencies
)

if ($null -eq $dependencies -or !$dependencies.PSobject.Properties.name.Contains("Count" ) -or $dependencies.Count -eq 0) {
    return
}

Write-Host "Downloading database objects"

$dependencyOutputFolder = "$PSScriptRoot/.dependencies"

if (-Not (Test-Path $dependencyOutputFolder)) {
    New-Item -ItemType Directory -Path $dependencyOutputFolder
}

foreach ($dependency in $dependencies) {
    #Download Package
    $packageName = $dependency.packageName
    $version = $dependency.version
    $url = $dependency.nugetUrl
    $nugetOutput = "$dependencyOutputFolder/$packageName.nupkg"

    $headers = If ($dependency.authToken) { @{ "Authorization" = "Bearer $($dependency.authToken)" } } Else { @{} };
    Write-Host "Downloading $packageName.$version"
    Remove-Item $nugetOutput -Force -Recurse -ErrorAction Ignore

    try {
        Invoke-WebRequest $url -OutFile $nugetOutput -Headers $headers
    }
    catch {
        Write-Error $_;
    }

    #Extract Package
    $extractionLocation = "$dependencyOutputFolder/$packageName"
    Remove-Item $extractionLocation -Force -Recurse -ErrorAction Ignore
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($nugetOutput, $extractionLocation)
}

Write-Host "Finished downloading database objects"
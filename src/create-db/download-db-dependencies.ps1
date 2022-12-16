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
    New-Item -ItemType Directory -Path $extractionLocation
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    # [System.IO.Compression.ZipFile]::ExtractToDirectory($nugetOutput, $extractionLocation)

    $zip = [System.IO.Compression.ZipFile]::OpenRead($nugetOutput)

    foreach ($item in $zip.Entries) {
        $itemDirectory = Join-Path -Path $extractionLocation -ChildPath (Split-Path -parent $item.FullName)
        
        try {
            if ($itemDirectory -and -not (Test-Path $itemDirectory)) {
                New-Item -ItemType Directory -Path $itemDirectory
            }
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($item, (Join-Path -Path $extractionLocation -ChildPath $item.FullName), $false)
        }
        catch {
            # Write out any errors that happen but continue on
            Write-Host "An Error Occurred. Writing out the information and moving on."
            Write-Host $_
        }
    }
}

Write-Host "Finished downloading database objects"
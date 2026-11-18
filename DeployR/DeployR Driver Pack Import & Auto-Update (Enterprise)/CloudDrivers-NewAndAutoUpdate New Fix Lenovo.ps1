# Cloud Driver Pack Import and Auto-Update (public configuration)
# Requires PowerShell 7, DeployR PowerShell module and the extraction tools used below.
# Configure these values before running. Import/update logic is unchanged.
$DeviceList = "$PSScriptRoot\Models.csv"
$dest = "C:\DeployRDriverPacks\Downloads"
$TemoraryFolder = "C:\DeployRDriverPacks\Temp"
$ExtractMSI = "$PSScriptRoot\TwoPint.DeployR.ExtractMSI.dll"
$StateFile = "C:\DeployRDriverPacks\Downloads\DriverPackVersions.json"
$DeployRModulePath = 'C:\Program Files\2Pint Software\DeployR\Client\PSModules\DeployR.Utility'
$DeployRToken = 'YOUR_2PINT_API_TOKEN_HERE'
$DeployRPasscode = 'YOUR_DEPLOYR_PASSCODE_HERE'
$api = "https://api.service.2pintsoftware.com"

# Initialization (unchanged)
$Devices = Import-Csv -Path $DeviceList
if ([string]::IsNullOrWhiteSpace($DeployRToken)) { throw "Set DEPLOYR_TOKEN before running." }
$url = "$api/driverpacks/search"
$Global:Exist = @()
$Global:Imported = @()

# Auto-update state. Never overwrite an existing item without a known baseline.
$State = @{}
if (Test-Path $StateFile) {
    $State = Get-Content $StateFile -Raw | ConvertFrom-Json -AsHashtable
    if ($null -eq $State) { $State = @{} }
}
$Global:Updated = @()
$Global:UnchangedCount = 0
$Global:Unverified = @()
function Save-DriverState {
    $temp = "$StateFile.tmp"
    $State | ConvertTo-Json -Depth 8 | Set-Content -Path $temp -Encoding utf8
    Move-Item -Path $temp -Destination $StateFile -Force
}
function Update-ExistingDriverPack {
    param([string]$MakeAlias,[string]$ModelAlias,[string]$InputSourceFolder)
    $item = Get-DeployRContentItem | Where-Object { $_.Name -eq "Driver Pack - $MakeAlias - $ModelAlias" } | Select-Object -First 1
    if (-not $item) { throw "Existing content item disappeared." }
    $versions = @(Get-DeployRContentItemVersion -ContentItemId $item.id)
    $active = @($versions | Where-Object { $_.status -eq 'Active' })
    if ($active.Count -ne 1) { throw "Expected exactly one active version; found $($active.Count)." }
    if (-not (Test-Path $InputSourceFolder)) { throw "Extracted folder missing: $InputSourceFolder" }
    if (-not (Get-ChildItem -Path $InputSourceFolder -Recurse -File | Select-Object -First 1)) { throw "Extracted folder is empty." }
    Update-DeployRContentItemContent -ContentId $item.id -ContentVersion $active[0].versionNo -SourceFolder $InputSourceFolder -ErrorAction Stop | Out-Null
}


function CheckExist {
    param (
    [parameter(Mandatory=$true)]
    [string]$MakeAlias,
    [parameter(Mandatory=$true)]
    [string]$ModelAlias,
    [string]$DeployRModulePath = $script:DeployRModulePath
    )
    
    Import-Module $DeployRModulePath
    Connect-DeployR -Passcode $DeployRPasscode

    if (Get-DeployRContentItem | Where-Object {$_.Name -eq "Driver Pack - $MakeAlias - $ModelAlias"}){
        Write-Host "  Driver Pack Content Item already exists for: $MakeAlias - $ModelAlias" -ForegroundColor Yellow
        $Global:Exist += "Driver Pack Content Item already exists for: $MakeAlias - $ModelAlias"
        return $true
    } else {
        return $false
    }

    
}

function Import-DriverPack {
    param (
    [parameter(Mandatory=$true)]
    [string]$MakeAlias,
    [parameter(Mandatory=$true)]
    [string]$ModelAlias,
    [parameter(Mandatory=$true)]
    [string]$InputSourceFolder, #Downloaded Extracted Driver Pack Source Folder
    [string]$DeployRModulePath = $script:DeployRModulePath
    )
    
    if (-not $InputSourceFolder) {
        Write-Error "InputSourceFolder is a required parameter. Exiting."
        Write-Host "Please provide a local InputSourceFolder path where the driver pack is already extracted." -ForegroundColor Yellow
        return
    }
    
    #Ensure Source Folder exists
    if (-not (Test-Path $InputSourceFolder)) {
        Write-Error "Source Folder $InputSourceFolder does not exist. Exiting."
        return
    }
    Import-Module $DeployRModulePath


    Write-Host "  Source Path: $InputSourceFolder"
    if (Get-DeployRContentItem | Where-Object {$_.Name -eq "Driver Pack - $MakeAlias - $ModelAlias"}){
        Write-Host "  Driver Pack Content Item already exists for: $MakeAlias - $ModelAlias" -ForegroundColor Yellow
        throw "Content item already exists during new import: $MakeAlias - $ModelAlias"
    }
    else {
        Write-Host "  Driver Pack Content Item does not exist for $MakeAlias - $ModelAlias. Creating new one."
        #Download the Driver Pack
        if ($InputSourceFolder -and (Test-Path $InputSourceFolder)) {
            Write-Host "  Using provided Input Source Folder: $InputSourceFolder"
        }
        
        #Create DeployR Content Item for the Driver Pack        
        $NewCI = New-DeployRContentItem -Name "Driver Pack - $MakeAlias - $ModelAlias" -Type Folder -Purpose DriverPack -Description "Generated for $MakeAlias - $ModelAlias"
        $ContentId = $NewCI.id
        $NewVersion = New-DeployRContentItemVersion -ContentItemId $ContentId -Description "Source: $InputSourceFolder" -DriverManufacturer $MakeAlias -DriverModel $ModelAlias -SourceFolder "$InputSourceFolder" -Status Active
        $ContentVersion = $NewVersion.versionNo
        #Upload the extracted driver pack to the DeployR Content Item
        write-Host "  Uploading extracted Driver Pack to DeployR Content Item"
        try {
            $ciVersion = update-DeployRContentItemContent -ContentId $ContentId -ContentVersion $ContentVersion -SourceFolder "$InputSourceFolder" -ErrorAction Stop
            write-Host "  Successfully uploaded Driver Pack content to DeployR!  Content Item Info:" -ForegroundColor Green
            write-Host "    CI driverManufacturer:   $($ciVersion.driverManufacturer)" -ForegroundColor DarkGray
            write-Host "    CI driverModel:          $($ciVersion.driverModel)" -ForegroundColor DarkGray
            write-Host "    CI ID:                   $($ciVersion.contentItemId), Version: $($ciVersion.versionNo)" -ForegroundColor DarkGray
            write-Host "    CI path:                 $($ciVersion.relativePath)" -ForegroundColor DarkGray
            write-Host "    CI Status:               $($ciVersion.status)" -ForegroundColor DarkGray
            write-Host "    CI Size:                 $([math]::round($ciVersion.contentSize / 1MB, 2)) MB" -ForegroundColor DarkGray
            $Global:Imported += "Successfully Imported: $MakeAlias - $ModelAlias"
        }
        catch {
            throw "Failed to upload Driver Pack content for $MakeAlias - $ModelAlias. Error: $_"
        }
    }
}

$NoDriver = @()
foreach ($Device in $Devices) {
    try {
    $ErrorActionPreference = "Stop"
    $systemAlias = $Device.SystemAlias
    $manufacturer = $Device.Manufacturer
    $model = $Device.Model
    $os= $Device.OS
    $osArch = $Device.osArch
    $osBuild = $Device.OSBuild
    $Version = $Device.OSReleaseId

    #Create Folder
    If (!(Test-Path $TemoraryFolder)) {New-Item -Path $TemoraryFolder -ItemType Directory}
    If (!(Test-Path "$dest\$manufacturer")) {New-Item -Path "$dest\$manufacturer" -ItemType Directory}
    
    #Kolla om den finns
    Write-Verbose -Verbose "Check if driver pack already exists for $manufacturer $model"
    $Check = CheckExist -MakeAlias $manufacturer -ModelAlias $model
    $StateKey = "$manufacturer|$model|$os|$osArch|$osBuild|$Version"
    # First run: no reliable historic package version is stored in DeployR.
    # Refresh existing content ONCE to establish a known baseline, never claim it was older.
    $BaselineRequired = $Check -and -not $State.ContainsKey($StateKey)
    if ($BaselineRequired) {
        Write-Host "  BASELINE: Existing pack has no tracked version. Will refresh once from catalog if hash metadata is available." -ForegroundColor Yellow
    }

    # Get applicable driver packs
    $query = "?systemAlias=$systemAlias&manufacturer=$manufacturer&model=$model&os=$os&osArchitecture=$osArch&osBuild=$osBuild&osReleaseId=$Version"
    $url = "$api/driverpacks/search"
    $url += $query
    $Headers = @{ Authorization = "Bearer $($DeployRToken)" }
    Write-Host "URL: $url"
    $response = Invoke-RestMethod -Uri $url -Method GET -Headers $Headers -ContentType "application/json" -UseBasicParsing -ErrorAction Stop -Verbose
    $driverPacks = $response.results

    # Lenovo catalog naming fallback. Keep the original model for DeployR content and state.
    # Only retry this known naming difference if the original result is empty or lacks required metadata.
    $CatalogModel = $model
    if ($manufacturer -eq 'Lenovo' -and $model -eq 'ThinkPad X1 Yoga Gen 7') {
        $OriginalPacks = @($driverPacks | Where-Object { $null -ne $_ })
        $OriginalIncomplete = $OriginalPacks.Count -eq 0 -or @($OriginalPacks | Where-Object {
            (-not $_.packageID -and -not $_.id) -or (-not $_.driverPackHash -and -not $_.hashSHA256)
        }).Count -gt 0
        if ($OriginalIncomplete) {
            $AlternateModel = 'ThinkPad X1 Yoga 7th Gen'
            Write-Host "  CATALOG FALLBACK: Trying Lenovo name '$AlternateModel' (DeployR model remains '$model')." -ForegroundColor Cyan
            $EncodedModel = [uri]::EscapeDataString($AlternateModel)
            $FallbackQuery = "?systemAlias=$systemAlias&manufacturer=$manufacturer&model=$EncodedModel&os=$os&osArchitecture=$osArch&osBuild=$osBuild&osReleaseId=$Version"
            try {
                $FallbackResponse = Invoke-RestMethod -Uri "$api/driverpacks/search$FallbackQuery" -Method GET -Headers $Headers -ContentType "application/json" -UseBasicParsing -ErrorAction Stop
                $FallbackPacks = @($FallbackResponse.results | Where-Object { $null -ne $_ })
                $FallbackComplete = $FallbackPacks.Count -gt 0 -and @($FallbackPacks | Where-Object {
                    (-not $_.packageID -and -not $_.id) -or (-not $_.driverPackHash -and -not $_.hashSHA256)
                }).Count -eq 0
                if ($FallbackComplete) {
                    $driverPacks = $FallbackPacks
                    $CatalogModel = $AlternateModel
                    Write-Host "  CATALOG FALLBACK: Valid package metadata found using '$CatalogModel'." -ForegroundColor Green
                } else {
                    Write-Warning "Catalog fallback did not return complete package metadata. Original result retained."
                }
            } catch {
                Write-Warning "Catalog fallback request failed: $($_.Exception.Message). Original result retained."
            }
        }
    }
    Write-Host "Driver packs found: $($driverPacks.Count)"
    if ($driverPacks.Count -eq 0) {
        $NoDriver += "Modell Not Found: $model"
    }

    # Compare stable, content-specific hashes supplied by the 2Pint catalog.
    # catalogVersion is the catalog snapshot date, NOT the driver package version.
    if (-not $driverPacks -or @($driverPacks).Count -eq 0) { continue }
    $current = @($driverPacks | ForEach-Object {
        $hash = [string]$_.driverPackHash
        if (-not $hash) { $hash = [string]$_.hashSHA256 }
        $packageIdentifier = [string]$_.packageID
        # Lenovo catalog entries can have packageID = null while still providing a stable catalog id,
        # download URL and hashes. Use catalog id only for Lenovo state/signature tracking.
        if ($manufacturer -eq 'Lenovo' -and -not $packageIdentifier) {
            $packageIdentifier = [string]$_.id
        }
        [pscustomobject]@{
            PackageID = $packageIdentifier
            Hash = $hash
            Version = [string]$_.version
            ReleaseDate = [string]$_.releaseDate
            FileName = [string]$_.fileName
        }
    } | Sort-Object PackageID)
    if (@($current | Where-Object { -not $_.Hash -or -not $_.PackageID }).Count -gt 0) {
        $Global:Unverified += "$manufacturer - $model (missing packageID or content hash)"
        continue
    }
    $current | ForEach-Object { Write-Host "  Catalog: $($_.PackageID) | $($_.Version) | $($_.ReleaseDate) | hash $($_.Hash)" }
    if ($Check -and -not $BaselineRequired) {
        $previous = @($State[$StateKey].Packages)
        $previousSignature = (@($previous | ForEach-Object { "$($_.PackageID)|$($_.Hash)" } | Sort-Object) -join ';')
        $currentSignature = (@($current | ForEach-Object { "$($_.PackageID)|$($_.Hash)" } | Sort-Object) -join ';')
        if ($previousSignature -eq $currentSignature) {
            Write-Host "  SKIPPED: package IDs and hashes unchanged." -ForegroundColor Green
            $Global:UnchangedCount++
            continue
        }
        Write-Host "  CHANGED: catalog package ID/hash differs; updating content." -ForegroundColor Cyan
    }

    # Each model has its own clean staging folder. Upload exactly once per model.
    $StagingFolder = "$TemoraryFolder\Staging"
    if (Test-Path $TemoraryFolder) { Remove-Item "$TemoraryFolder\*" -Recurse -Force -ErrorAction Stop }
    New-Item -Path $StagingFolder -ItemType Directory -Force | Out-Null
    # Download and expand the drivers
    $urlList = New-Object System.Collections.ArrayList
    $driverCount = 0
    foreach ($driverPack in $driverPacks) {
        #pause
        # Check for a duplicate URL, no need to download the same thing multiple times
        if ($urlList.Contains($driverPack.url)) {
            Write-Host "Skipping driver pack because it has already been downloaded: $($driverPack.Name)"
            continue
        }
        [void]$urlList.Add($driverPack.url)

        # Download
        $destPath = $null
        $driverCount++
  
        $FileName = $driverPack.fileName
        $OutFile = "$TemoraryFolder\$FileName"
        $CompleteFolder = "$dest\" + $manufacturer + "\" + $model
        If (!(Test-Path "$CompleteFolder")) {New-Item -Path "$CompleteFolder" -ItemType Directory}

        Write-Host "Downloading: $($driverPack.url)"
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest $driverPack.url -OutFile $OutFile -UseBasicParsing
        $destFileInfo = Get-Item $OutFile

        # Expand
        Write-Verbose -Message "DriverPack: $($destFileInfo.FullName)"


        # CAB files are easy, extract them with expand.exe
        if ($destFileInfo.Extension -eq '.cab') {
            $destPath = Join-Path $TemoraryFolder $destFileInfo.BaseName
            
            if (-NOT (Test-Path "$destPath")) {
                New-Item $destPath -ItemType Directory -Force -ErrorAction Ignore | Out-Null
        
                Write-Verbose -Verbose "Expanding CAB file to $destPath"
                Expand -R "$($destFileInfo.FullName)" -F:* "$destPath" | Out-Null
            }
            
        }

        # Zip files are also easy, extract them with Expand-Archive
        if ($destFileInfo.Extension -eq '.zip') {
            $destPath = Join-Path $TemoraryFolder $destFileInfo.BaseName
        
            if (-NOT (Test-Path "$destPath")) {
                Write-Verbose -Verbose "Expanding zip file to $destPath"
                Expand-Archive -Path $destFileInfo.FullName -DestinationPath $destPath -Force
            }
            
        }

        # Executables are a little more work.  Dell can be self-extracted while HP needs 7za and Lenovo requires an Inno extractor.
        if ($destFileInfo.Extension -eq '.exe') {

            if ($destFileInfo.VersionInfo.FileDescription -match 'Dell') {
        
                $destPath = Join-Path $TemoraryFolder $destFileInfo.BaseName    
                if (-NOT (Test-Path "$destPath")) {
                    Write-Verbose -Verbose "Expanding Dell driver exe to $destPath"
                    $null = New-Item -Path $destPath -ItemType Directory -Force -ErrorAction Ignore | Out-Null
                    Start-Process -FilePath $destFileInfo.FullName -ArgumentList "/s /e=`"$destPath`"" -Wait
                }
                

            }
            if (($destFileInfo.VersionInfo.InternalName -match 'hpsoftpaqwrapper') -or ($destFileInfo.VersionInfo.OriginalFilename -match 'hpsoftpaqwrapper.exe') -or ($destFileInfo.VersionInfo.FileDescription -like "HP *")) {
                            
                $destPath = Join-Path $TemoraryFolder $destFileInfo.BaseName
                if (-NOT (Test-Path "$destPath")) {
                    Write-Verbose -Verbose "Expanding HP driver exe with 7za to $destPath"
                    & "$PSScriptRoot\Tools\x64\7za.exe" -y x "$($destFileInfo.FullName)" -o"$destPath" | Out-Host
                }
                
            }
            if (($destFileInfo.VersionInfo.FileDescription -match 'Lenovo') -or ($destFileInfo.Name -match 'tc_') -or ($destFileInfo.Name -match 'tp_') -or ($destFileInfo.Name -match 'ts_') -or ($destFileInfo.Name -match '500w') -or ($destFileInfo.Name -match 'sccm_') -or ($destFileInfo.Name -match 'm710e') -or ($destFileInfo.Name -match 'tp10') -or ($destFileInfo.Name -match 'tp8') -or ($destFileInfo.Name -match 'yoga')) {
        
                $destPath = Join-Path $TemoraryFolder $destFileInfo.BaseName
                if (-NOT (Test-Path "$destPath")) {
                    Write-Verbose -Verbose "Expanding Lenovo driver exe with innoextract to $destPath"
                    & "$PSScriptRoot\Tools\x64\innoextract.exe" -e -d "$destPath" "$($destFileInfo.FullName)" | Out-Host
                }
                
            }
            if ($destFileInfo.VersionInfo.FileDescription -match 'VMware') {
                # It's a wrapped MSI, need to get the MSI out of it.  It will be written to %TEMP%
                & "$($destFileInfo.FullName)" /x | Out-Host
                # Get the file info
                $destFileInfo = Get-Item "$($env:TEMP)\"
                $matchingFiles = Get-ChildItem "$($env:TEMP)\*~setup\VMware Tools.msi" -Recurse
                $destFileInfo = Get-Item $matchingFiles[0]
                # No continue here as we'll let the MSI logic below extract the contents
            }

        }

        # MSIs need our custom extractor
        if ($destFileInfo.Extension -eq '.msi') {

            $destPath = Join-Path $TemoraryFolder $destFileInfo.BaseName    
            if (-NOT (Test-Path "$destPath")) {
                Write-Verbose -Verbose "Extracting MSI file to $destPath"
                & dotnet.exe "$ExtractMSI" "$($destFileInfo.FullName)" "$destPath" | Out-Host
            }
            
        }


        #Compress the extracted driver pack to a zip file for easier handling
        #Write-Verbose -Verbose "Compress drivers to $CompleteFolder"
        #Compress-Archive -Path $destPath -DestinationPath "$CompleteFolder\$($destFileInfo.BaseName).zip" -Force
        #& "$PSScriptRoot\Tools\x64\7za.exe" a -tzip "$CompleteFolder\$($destFileInfo.BaseName).zip" $destPath

        if (-not $destPath -or -not (Test-Path $destPath)) { throw "Extraction failed: $FileName" }
        $extractedFiles = @(Get-ChildItem -Path $destPath -Recurse -File -ErrorAction Stop)
        if ($extractedFiles.Count -eq 0) { throw "No files extracted from $FileName" }
        $PackFolder = $StagingFolder
        if (@($driverPacks).Count -gt 1) {
            $PackFolder = "$StagingFolder\Package-$driverCount"
            New-Item -Path $PackFolder -ItemType Directory -Force | Out-Null
        }
        Copy-Item -Path "$destPath\*" -Destination $PackFolder -Recurse -Force -ErrorAction Stop
    }
    if ($driverCount -eq 0) { throw "No downloadable packages" }
    if (-not (Get-ChildItem $StagingFolder -Recurse -File | Select-Object -First 1)) { throw "Staging is empty" }
    Write-Verbose -Verbose "Upload complete driver pack to DeployR"
    if ($Check) {
            Update-ExistingDriverPack -MakeAlias $manufacturer -ModelAlias $model -InputSourceFolder $StagingFolder
            $Global:Updated += "$manufacturer - $model"
        } else {
            Import-DriverPack -MakeAlias $manufacturer -ModelAlias $model -InputSourceFolder $StagingFolder
        }
    $State[$StateKey] = @{ Packages = @($current); LastSuccessUtc = (Get-Date).ToUniversalTime().ToString('o') }
    Save-DriverState
    Write-Host "  SUCCESS: model published and state saved." -ForegroundColor Green
    } catch {
        $Global:Unverified += "$($Device.Manufacturer) - $($Device.Model): $($_.Exception.Message)"
        Write-Warning "FAILED: $($Device.Manufacturer) - $($Device.Model): $($_.Exception.Message)"
    } finally {
        if (Test-Path $TemoraryFolder) {
            Remove-Item "$TemoraryFolder\*" -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
write-host ""
write-host ""
$Global:Imported | ForEach-Object {
    Write-Host $_ -ForegroundColor Green
}
write-host ""
$Global:Exist | ForEach-Object {
    Write-Host $_ -ForegroundColor DarkYellow
}
write-host ""
$NoDriver | ForEach-Object {
    Write-Host $_ -ForegroundColor Red
}
Write-Host "Updated: $($Global:Updated.Count); Needs review: $($Global:Unverified.Count)"
$Global:Unverified | ForEach-Object { Write-Warning $_ }

# Console summary (no changes to driver import/update workflow)
$ProcessedCount = @($Devices).Count
$ImportedCount = @($Global:Imported).Count
$UpdatedCount = @($Global:Updated).Count
$FailedCount = @($Global:Unverified).Count + @($NoDriver).Count

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "       DeployR Driver Pack Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ("Models processed : {0}" -f $ProcessedCount)
Write-Host ("Imported         : {0}" -f $ImportedCount) -ForegroundColor Green
Write-Host ("Updated          : {0}" -f $UpdatedCount) -ForegroundColor Green
Write-Host ("Unchanged        : {0}" -f $Global:UnchangedCount) -ForegroundColor Yellow
Write-Host ("Failed           : {0}" -f $FailedCount) -ForegroundColor $(if ($FailedCount -gt 0) { 'Red' } else { 'Green' })
Write-Host "========================================" -ForegroundColor Cyan
pause

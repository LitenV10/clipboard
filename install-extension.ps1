# Clipboard AI - one-command unpacked installer for Windows Chrome
# Downloads the published CRX, extracts its extension files to a stable folder,
# then opens Chrome's Extensions page and File Explorer at that folder.
# The user must enable Developer mode (if needed) and click Load unpacked.

$ErrorActionPreference = "Stop"

$CrxUrl = "https://LitenV10.github.io/clipboard/clipboard-ai-extension.crx"
$InstallDir = Join-Path $env:LOCALAPPDATA "ClipboardAI\Extension"
$TempRoot = Join-Path $env:TEMP ("clipboard-ai-" + [guid]::NewGuid().ToString("N"))
$CrxPath = Join-Path $TempRoot "clipboard-ai-extension.crx"
$ZipPath = Join-Path $TempRoot "extension.zip"
$ExtractDir = Join-Path $TempRoot "extracted"

try {
    New-Item -ItemType Directory -Path $TempRoot -Force | Out-Null

    Write-Host "Downloading Clipboard AI..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $CrxUrl -OutFile $CrxPath -UseBasicParsing

    $bytes = [System.IO.File]::ReadAllBytes($CrxPath)
    if ($bytes.Length -lt 16 -or [System.Text.Encoding]::ASCII.GetString($bytes, 0, 4) -ne "Cr24") {
        throw "The download is not a valid CRX package. Check that the GitHub Pages CRX URL is correct."
    }

    $crxVersion = [BitConverter]::ToUInt32($bytes, 4)
    switch ($crxVersion) {
        3 {
            if ($bytes.Length -lt 12) { throw "The CRX3 header is incomplete." }
            $headerLength = [BitConverter]::ToUInt32($bytes, 8)
            $zipOffset = 12L + [int64]$headerLength
        }
        2 {
            $publicKeyLength = [BitConverter]::ToUInt32($bytes, 8)
            $signatureLength = [BitConverter]::ToUInt32($bytes, 12)
            $zipOffset = 16L + [int64]$publicKeyLength + [int64]$signatureLength
        }
        default {
            throw "Unsupported CRX format version: $crxVersion"
        }
    }

    if ($zipOffset -lt 16 -or $zipOffset -gt ($bytes.Length - 4)) {
        throw "The CRX package contains an invalid ZIP payload offset."
    }
    if ([System.Text.Encoding]::ASCII.GetString($bytes, [int]$zipOffset, 2) -ne "PK") {
        throw "The CRX package does not contain a ZIP payload."
    }

    $zipBytes = New-Object byte[] ($bytes.Length - [int]$zipOffset)
    [Array]::Copy($bytes, [int]$zipOffset, $zipBytes, 0, $zipBytes.Length)
    [System.IO.File]::WriteAllBytes($ZipPath, $zipBytes)

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    New-Item -ItemType Directory -Path $ExtractDir -Force | Out-Null
    [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipPath, $ExtractDir)

    $ManifestPath = Join-Path $ExtractDir "manifest.json"
    if (-not (Test-Path $ManifestPath)) {
        throw "manifest.json was not found at the package root. The CRX may have an unexpected folder structure."
    }

    $manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
    if ($manifest.manifest_version -ne 3) {
        throw "Expected a Manifest V3 extension, but the downloaded package reports Manifest Version $($manifest.manifest_version)."
    }

    # Replace only the dedicated ClipboardAI install directory.
    if (Test-Path $InstallDir) {
        Remove-Item -LiteralPath $InstallDir -Recurse -Force
    }
    $installParent = Split-Path -Parent $InstallDir
    New-Item -ItemType Directory -Path $installParent -Force | Out-Null
    Move-Item -LiteralPath $ExtractDir -Destination $InstallDir

    Write-Host ""
    Write-Host "Clipboard AI files are ready." -ForegroundColor Green
    Write-Host "Folder: $InstallDir" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Chrome and File Explorer will open."
    Write-Host "In Chrome: enable Developer mode if needed, click Load unpacked,"
    Write-Host "then select the ClipboardAI\Extension folder."
    Write-Host ""

    $chromeCandidates = @(
        (Join-Path $env:ProgramFiles "Google\Chrome\Application\chrome.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "Google\Chrome\Application\chrome.exe"),
        (Join-Path $env:LOCALAPPDATA "Google\Chrome\Application\chrome.exe")
    )
    $chromeExe = $chromeCandidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1

    if ($chromeExe) {
        Start-Process -FilePath $chromeExe -ArgumentList "chrome://extensions"
    }
    else {
        Start-Process "https://www.google.com/chrome/"
        Write-Warning "Chrome was not found in its usual install locations. Open Chrome and visit chrome://extensions."
    }

    Start-Process -FilePath "explorer.exe" -ArgumentList "`"$InstallDir`""
}
catch {
    Write-Host ""
    Write-Host "Clipboard AI setup failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    if (Test-Path $TempRoot) {
        Remove-Item -LiteralPath $TempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

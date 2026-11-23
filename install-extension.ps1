# Clipboard AI Extension installer
# Downloads the published CRX, extracts its ZIP payload, and opens Chrome's
# Extensions page. The user must enable Developer mode and click "Load unpacked".

$ErrorActionPreference = "Stop"

$CrxUrl = "https://LitenV10.github.io/clipboard/clipboard-ai-extension.crx"
$InstallDir = Join-Path $env:LOCALAPPDATA "ClipboardAI\Extension"
$TempRoot = Join-Path $env:TEMP ("clipboard-ai-" + [guid]::NewGuid().ToString("N"))
$CrxPath = Join-Path $TempRoot "clipboard-ai-extension.crx"
$ZipPath = Join-Path $TempRoot "extension.zip"

try {
    New-Item -ItemType Directory -Path $TempRoot -Force | Out-Null

    Write-Host "Downloading Clipboard AI..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $CrxUrl -OutFile $CrxPath -UseBasicParsing

    $bytes = [System.IO.File]::ReadAllBytes($CrxPath)
    if ($bytes.Length -lt 16 -or [System.Text.Encoding]::ASCII.GetString($bytes, 0, 4) -ne "Cr24") {
        throw "The downloaded file is not a valid Chrome extension package (CRX)."
    }

    $crxVersion = [BitConverter]::ToUInt32($bytes, 4)

    switch ($crxVersion) {
        3 {
            if ($bytes.Length -lt 12) { throw "The CRX3 header is incomplete." }
            $headerLength = [BitConverter]::ToUInt32($bytes, 8)
            $zipOffset = 12 + [int64]$headerLength
        }
        2 {
            $publicKeyLength = [BitConverter]::ToUInt32($bytes, 8)
            $signatureLength = [BitConverter]::ToUInt32($bytes, 12)
            $zipOffset = 16 + [int64]$publicKeyLength + [int64]$signatureLength
        }
        default {
            throw "Unsupported CRX format version: $crxVersion"
        }
    }

    if ($zipOffset -ge $bytes.Length -or $zipOffset -lt 16) {
        throw "The CRX package has an invalid ZIP payload offset."
    }

    if ([System.Text.Encoding]::ASCII.GetString($bytes, [int]$zipOffset, 2) -ne "PK") {
        throw "The CRX package does not contain a valid ZIP payload."
    }

    $zipBytes = New-Object byte[] ($bytes.Length - [int]$zipOffset)
    [Array]::Copy($bytes, [int]$zipOffset, $zipBytes, 0, $zipBytes.Length)
    [System.IO.File]::WriteAllBytes($ZipPath, $zipBytes)

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $ExtractDir = Join-Path $TempRoot "extracted"
    New-Item -ItemType Directory -Path $ExtractDir -Force | Out-Null
    [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipPath, $ExtractDir)

    if (-not (Test-Path (Join-Path $ExtractDir "manifest.json"))) {
        throw "manifest.json was not found at the extension root. Check the CRX build."
    }

    if (Test-Path $InstallDir) {
        Remove-Item -LiteralPath $InstallDir -Recurse -Force
    }

    $parent = Split-Path -Parent $InstallDir
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    Move-Item -LiteralPath $ExtractDir -Destination $InstallDir

    Write-Host ""
    Write-Host "Extension files installed at:" -ForegroundColor Green
    Write-Host $InstallDir -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Chrome will now open. Enable Developer mode, click Load unpacked,"
    Write-Host "and select the ClipboardAI\Extension folder shown above."
    Write-Host ""

    $chromeCandidates = @(
        (Join-Path $env:ProgramFiles "Google\Chrome\Application\chrome.exe"),
        (Join-Path ([Environment]::GetEnvironmentVariable("ProgramFiles(x86)")) "Google\Chrome\Application\chrome.exe"),
        (Join-Path $env:LOCALAPPDATA "Google\Chrome\Application\chrome.exe")
    )

    $chromeExe = $chromeCandidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1

    if ($chromeExe) {
        Start-Process -FilePath $chromeExe -ArgumentList "chrome://extensions"
    }
    else {
        Write-Warning "Chrome was not found in its usual install locations. Open Chrome and visit chrome://extensions."
    }
}
catch {
    Write-Host ""
    Write-Host "Installation preparation failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    if (Test-Path $TempRoot) {
        Remove-Item -LiteralPath $TempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

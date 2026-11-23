# Clipboard AI - self-hosted Chrome installer (Windows)
# Uses Chrome's ExtensionSettings policy with normal_installed.
# This is a Chrome enterprise policy configuration. It is reversible.
# Run in the current Windows user account; no admin rights are intended.

$ErrorActionPreference = "Stop"

$ExtensionId = "ohcmdegnceogacjmanfgciinijhkogoc"
$UpdateUrl = "https://LitenV10.github.io/clipboard/update.xml"
$CrxUrl = "https://LitenV10.github.io/clipboard/clipboard-ai-extension.crx"
$PolicyPath = "HKCU:\Software\Policies\Google\Chrome"
$PolicyName = "ExtensionSettings"

Write-Host "Checking Clipboard AI release files..." -ForegroundColor Cyan

# Verify the hosted update manifest and CRX are reachable before changing policy.
$xmlResponse = Invoke-WebRequest -Uri $UpdateUrl -UseBasicParsing
[xml]$updateXml = $xmlResponse.Content

$ns = New-Object System.Xml.XmlNamespaceManager($updateXml.NameTable)
$ns.AddNamespace("g", "http://www.google.com/update2/response")
$appNode = $updateXml.SelectSingleNode("//g:app", $ns)
$checkNode = $updateXml.SelectSingleNode("//g:updatecheck", $ns)

if (-not $appNode -or $appNode.GetAttribute("appid") -ne $ExtensionId) {
    throw "update.xml does not contain the expected extension ID ($ExtensionId)."
}
if (-not $checkNode -or $checkNode.GetAttribute("codebase") -ne $CrxUrl) {
    throw "update.xml does not point to the expected CRX URL ($CrxUrl)."
}
if (-not $checkNode.GetAttribute("version")) {
    throw "update.xml is missing the CRX version."
}

$crxResponse = Invoke-WebRequest -Uri $CrxUrl -Method Head -UseBasicParsing
if ($crxResponse.StatusCode -lt 200 -or $crxResponse.StatusCode -ge 400) {
    throw "The CRX URL did not return a successful response."
}

if (-not (Test-Path $PolicyPath)) {
    New-Item -Path $PolicyPath -Force | Out-Null
}

# Preserve other ExtensionSettings entries if this user already has any.
$existing = Get-ItemProperty -Path $PolicyPath -Name $PolicyName -ErrorAction SilentlyContinue
$settings = @{}

if ($existing -and $existing.$PolicyName) {
    try {
        $parsed = $existing.$PolicyName | ConvertFrom-Json -ErrorAction Stop
        if ($parsed -is [System.Collections.IDictionary]) {
            foreach ($key in $parsed.Keys) { $settings[$key] = $parsed[$key] }
        }
        else {
            foreach ($property in $parsed.PSObject.Properties) {
                $settings[$property.Name] = $property.Value
            }
        }
    }
    catch {
        throw "Existing Chrome ExtensionSettings policy is not valid JSON. No changes were made."
    }
}

$settings[$ExtensionId] = @{
    installation_mode = "normal_installed"
    update_url = $UpdateUrl
}

$json = $settings | ConvertTo-Json -Depth 20 -Compress
New-ItemProperty -Path $PolicyPath -Name $PolicyName -Value $json -PropertyType String -Force | Out-Null

# Remove only the old legacy entry created by the previous installer, if present.
$legacyPath = Join-Path $PolicyPath "ExtensionInstallForcelist"
if (Test-Path $legacyPath) {
    $legacy = Get-ItemProperty -Path $legacyPath -ErrorAction SilentlyContinue
    foreach ($property in $legacy.PSObject.Properties) {
        if ($property.Name -match '^\d+$' -and "$($property.Value)" -like "$ExtensionId;*") {
            Remove-ItemProperty -Path $legacyPath -Name $property.Name -ErrorAction SilentlyContinue
        }
    }
}

Write-Host ""
Write-Host "Clipboard AI installation policy has been configured." -ForegroundColor Green
Write-Host "Extension ID: $ExtensionId"
Write-Host "Update manifest: $UpdateUrl"
Write-Host ""
Write-Host "Fully exit Chrome (all windows), then reopen it." -ForegroundColor Yellow
Write-Host "Check chrome://policy and click Reload policies."
Write-Host "Then check chrome://extensions for Clipboard AI."
Write-Host ""
Write-Host "Chrome may show that it is managed by your organization because this uses a Chrome policy."

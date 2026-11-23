# Clipboard AI policy remover
$ErrorActionPreference = "Stop"
$ExtensionId = "ohcmdegnceogacjmanfgciinijhkogoc"
$PolicyPath = "HKCU:\Software\Policies\Google\Chrome"
$PolicyName = "ExtensionSettings"

if (-not (Test-Path $PolicyPath)) {
    Write-Host "No per-user Chrome policy found."
    exit 0
}

$current = Get-ItemProperty -Path $PolicyPath -Name $PolicyName -ErrorAction SilentlyContinue
if (-not $current -or -not $current.$PolicyName) {
    Write-Host "No ExtensionSettings policy found."
    exit 0
}

try {
    $parsed = $current.$PolicyName | ConvertFrom-Json -ErrorAction Stop
    $settings = @{}
    foreach ($property in $parsed.PSObject.Properties) {
        if ($property.Name -ne $ExtensionId) {
            $settings[$property.Name] = $property.Value
        }
    }

    if ($settings.Count -eq 0) {
        Remove-ItemProperty -Path $PolicyPath -Name $PolicyName -ErrorAction SilentlyContinue
    }
    else {
        $json = $settings | ConvertTo-Json -Depth 20 -Compress
        Set-ItemProperty -Path $PolicyPath -Name $PolicyName -Value $json
    }

    Write-Host "Clipboard AI installation policy removed. Fully restart Chrome." -ForegroundColor Green
}
catch {
    throw "Could not safely parse the existing policy. No changes were made."
}

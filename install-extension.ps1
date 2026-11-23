# install-extension.ps1
$ExtensionId = "ohcmdegnceogacjmanfgciinijhkogoc"
$UpdateUrl   = "https://LitenV10.github.io/clipboard/update.xml"
$PolicyPath  = "HKCU:\Software\Policies\Google\Chrome\ExtensionInstallForcelist"

if (-not (Test-Path $PolicyPath)) {
    New-Item -Path $PolicyPath -Force | Out-Null
}

New-ItemProperty -Path $PolicyPath -Name "1" -Value "$ExtensionId;$UpdateUrl" -PropertyType String -Force | Out-Null

Write-Host "Done. Fully close Chrome, reopen it, and check chrome://policy." -ForegroundColor Green

# Sign QuietTrack exe after building.
# Usage: .\scripts\sign.ps1
#
# Prerequisites: run once to create the cert:
#   New-SelfSignedCertificate -Type CodeSigningCert -Subject "CN=QuietTrack, O=QuietTrack" `
#     -CertStoreLocation "Cert:\CurrentUser\My" -FriendlyName "QuietTrack Code Signing" `
#     -NotAfter (Get-Date).AddYears(5)
#   # Then trust it:
#   $cert = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert | Where-Object { $_.Subject -eq "CN=QuietTrack, O=QuietTrack" }
#   Export-Certificate -Cert $cert -FilePath "$env:TEMP\quiettrack.cer" -Type CERT
#   Import-Certificate -FilePath "$env:TEMP\quiettrack.cer" -CertStoreLocation "Cert:\CurrentUser\Root"

$ErrorActionPreference = "Stop"

$exePath = "build\windows\x64\runner\Release\quiettrack.exe"
if (-not (Test-Path $exePath)) {
    Write-Host "ERROR: $exePath not found. Run 'flutter build windows' first." -ForegroundColor Red
    exit 1
}

$cert = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert |
    Where-Object { $_.Subject -eq "CN=QuietTrack, O=QuietTrack" } |
    Select-Object -First 1

if (-not $cert) {
    Write-Host "ERROR: Code signing certificate not found. See comments at top of this script." -ForegroundColor Red
    exit 1
}

Write-Host "Signing $exePath ..." -ForegroundColor Cyan
$result = Set-AuthenticodeSignature -FilePath $exePath -Certificate $cert -TimestampServer "http://timestamp.digicert.com"

if ($result.Status -eq "Valid") {
    Write-Host "Signed successfully. Thumbprint: $($cert.Thumbprint)" -ForegroundColor Green
} else {
    Write-Host "Signing failed: $($result.Status) - $($result.StatusMessage)" -ForegroundColor Red
    exit 1
}

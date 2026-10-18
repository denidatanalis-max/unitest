# konek-vps.ps1 - kirim binary Linux ke VPS.
# Portable: jalan di PC mana pun dan huruf drive apa pun (T:, E:, ...).
# Pakai:
#   ./konek-vps.ps1                             -> kirim ke ~/
#   ./konek-vps.ps1 -Tujuan "~/apps/myunitest/" -> kirim ke folder lain

param(
    [string]$Tujuan = "~/"
)

$ErrorActionPreference = "Stop"

$Server = "depth_claude@103.152.242.78"
$Binary = "target\x86_64-unknown-linux-musl\release\myunitest"
$Sumber = ".secrets\id_depthculture"
$Kunci  = "$env:LOCALAPPDATA\depth-ssh\id_depthculture"

# Pindah ke folder tempat script ini berada, supaya path relatif selalu benar.
Push-Location $PSScriptRoot
try {
    if (-not (Test-Path $Sumber)) { throw "Kunci tidak ada: $Sumber" }
    if (-not (Test-Path $Binary)) {
        throw "Binary belum ada. Build dulu: cargo build --release --target x86_64-unknown-linux-musl"
    }

    # Salin kunci ke folder lokal PC ini, lalu kunci izinnya (sama seperti ssh-vps.cmd).
    New-Item -ItemType Directory -Force (Split-Path $Kunci) | Out-Null
    if (Test-Path $Kunci) { Remove-Item $Kunci -Force }
    Copy-Item $Sumber $Kunci
    icacls $Kunci /inheritance:r /grant:r "$($env:USERDOMAIN)\$($env:USERNAME):F" | Out-Null

    scp -i $Kunci -o StrictHostKeyChecking=accept-new -o ConnectTimeout=12 $Binary "${Server}:$Tujuan"
    if ($LASTEXITCODE -ne 0) { throw "scp gagal (kode $LASTEXITCODE)" }

    Write-Host "Berhasil: $Binary -> ${Server}:$Tujuan" -ForegroundColor Green
}
finally {
    Pop-Location   # kembali ke folder semula
}

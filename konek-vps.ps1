# konek-vps.ps1 - build, kirim, dan restart program di VPS. Satu perintah.
# Portable: jalan di PC mana pun dan huruf drive apa pun (T:, E:, ...).
# Pakai:
#   ./konek-vps.ps1

$ErrorActionPreference = "Stop"

$App    = "myunitest"                        # nama program = nama folder = nama service
$Port   = 9200                               # port program (untuk tes akhir)
$Server = "depth_claude@103.152.242.78"
$Target = "x86_64-unknown-linux-musl"
$Binary = "target\$Target\release\$App"
$Folder = "~/$App"                           # folder program di VPS
$Sumber = ".secrets\id_depthculture"
$Kunci  = "$env:LOCALAPPDATA\depth-ssh\id_depthculture"

# Pindah ke folder tempat script ini berada, supaya path relatif selalu benar.
Push-Location $PSScriptRoot
try {
    # 1. Build versi Linux. Kalau gagal, berhenti di sini (VPS tidak disentuh).
    Write-Host "[1/3] Build..." -ForegroundColor Cyan
    cargo build --release --target $Target
    if ($LASTEXITCODE -ne 0) { throw "Build gagal. Perbaiki error di atas dulu." }

    # Siapkan kunci SSH di PC ini (sama seperti ssh-vps.cmd).
    if (-not (Test-Path $Sumber)) { throw "Kunci tidak ada: $Sumber" }
    New-Item -ItemType Directory -Force (Split-Path $Kunci) | Out-Null
    if (Test-Path $Kunci) { Remove-Item $Kunci -Force }
    Copy-Item $Sumber $Kunci
    icacls $Kunci /inheritance:r /grant:r "$($env:USERDOMAIN)\$($env:USERNAME):F" | Out-Null
    $Opsi = @("-i", $Kunci, "-o", "StrictHostKeyChecking=accept-new", "-o", "ConnectTimeout=12")

    # 2. Kirim dengan nama sementara (.new). Program lama tetap jalan selama upload.
    Write-Host "[2/3] Kirim..." -ForegroundColor Cyan
    scp @Opsi $Binary "${Server}:$Folder/$App.new"
    if ($LASTEXITCODE -ne 0) { throw "Kirim gagal (kode $LASTEXITCODE). Program lama tetap jalan." }

    # 3. Tukar file lama dengan yang baru, restart service, lalu tes apakah web menjawab.
    Write-Host "[3/3] Tukar, restart, tes..." -ForegroundColor Cyan
    $Perintah = "chmod +x $Folder/$App.new && mv -f $Folder/$App.new $Folder/$App && sudo systemctl restart $App && sleep 1 && curl -fsS http://127.0.0.1:$Port/"
    ssh -t @Opsi $Server $Perintah
    if ($LASTEXITCODE -ne 0) { throw "Restart/tes gagal. Cek di VPS: journalctl -u $App -n 20 --no-pager" }

    Write-Host ""
    Write-Host "Deploy berhasil!" -ForegroundColor Green
}
finally {
    Pop-Location   # kembali ke folder semula
}

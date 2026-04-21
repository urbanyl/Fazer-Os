param(
  [string]$BuildDir = "build",
  [int]$Stage2Sectors = 32,
  [int]$ImageSizeMiB = 64
)

$ErrorActionPreference = "Stop"

function Require-Command([string]$Name) {
  $cmd = Get-Command $Name -ErrorAction SilentlyContinue
  if (-not $cmd) {
    throw "Commande manquante: $Name"
  }
}

Require-Command python
Require-Command nasm

New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null

Write-Host "[1/4] Assemble MBR" -ForegroundColor Cyan
nasm -f bin -DSTAGE2_SECTORS=$Stage2Sectors src/boot/mbr.asm -o "$BuildDir/mbr.bin"

Write-Host "[2/4] Assemble Stage2" -ForegroundColor Cyan
nasm -f bin -DSTAGE2_SECTORS=$Stage2Sectors src/boot/stage2.asm -o "$BuildDir/stage2.bin"

Write-Host "[3/4] Assemble Kernel (raw bin)" -ForegroundColor Cyan
nasm -f bin src/kernel/kernel.asm -o "$BuildDir/kernel.bin"

Write-Host "[4/4] Build disk image" -ForegroundColor Cyan
python tools/mkimage.py `
  --mbr "$BuildDir/mbr.bin" `
  --stage2 "$BuildDir/stage2.bin" `
  --kernel "$BuildDir/kernel.bin" `
  --out "$BuildDir/fazer.img" `
  --stage2-sectors $Stage2Sectors `
  --size-mib $ImageSizeMiB

Write-Host "OK -> $BuildDir/fazer.img" -ForegroundColor Green


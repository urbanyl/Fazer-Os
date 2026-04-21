param(
  [string]$Image = "build/fazer.img",
  [int]$MemoryMiB = 256
)

$ErrorActionPreference = "Stop"

$qemu = Get-Command qemu-system-x86_64 -ErrorAction SilentlyContinue
if (-not $qemu) {
  throw "qemu-system-x86_64 introuvable dans PATH"
}

if (-not (Test-Path $Image)) {
  throw "Image introuvable: $Image (lance d'abord tools/build.ps1 ou make image)"
}

& $qemu.Source `
  -m "$MemoryMiB" `
  -drive "format=raw,file=$Image,if=ide,index=0,media=disk" `
  -serial stdio


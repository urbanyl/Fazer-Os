param(
  [Parameter(Mandatory = $true)]
  [string]$RawImage,

  [string]$OutDisk = "build\\fazer.vdi",

  [ValidateSet("VDI", "VMDK")]
  [string]$Format = "VDI"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $RawImage)) {
  throw "Image brute introuvable: $RawImage"
}

$vbm = Get-Command VBoxManage -ErrorAction SilentlyContinue
if (-not $vbm) {
  throw "VBoxManage introuvable. Installe VirtualBox (ou ajoute VBoxManage au PATH)."
}

$outDir = Split-Path -Parent $OutDisk
if ($outDir -and -not (Test-Path $outDir)) {
  New-Item -ItemType Directory -Force -Path $outDir | Out-Null
}

Write-Host "Conversion: $RawImage -> $OutDisk ($Format)" -ForegroundColor Cyan
& $vbm.Source convertfromraw $RawImage $OutDisk --format $Format
Write-Host "OK -> $OutDisk" -ForegroundColor Green


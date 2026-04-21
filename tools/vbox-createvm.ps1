param(
  [string]$Name = "FazerOS",
  [string]$BaseFolder = "$env:USERPROFILE\\VirtualBox VMs",
  [int]$MemoryMiB = 256,
  [string]$DiskPath = "build\\fazer.vdi"
)

$ErrorActionPreference = "Stop"

$vbm = Get-Command VBoxManage -ErrorAction SilentlyContinue
if (-not $vbm) {
  throw "VBoxManage introuvable. Installe VirtualBox (ou ajoute VBoxManage au PATH)."
}

if (-not (Test-Path $DiskPath)) {
  throw "Disque introuvable: $DiskPath (génère-le avec tools/vbox-make-disk.ps1 ou utilise un .vmdk)"
}

Write-Host "Création VM: $Name" -ForegroundColor Cyan
& $vbm.Source createvm --name $Name --ostype Other_64 --register --basefolder $BaseFolder

& $vbm.Source modifyvm $Name --firmware bios --memory $MemoryMiB --vram 16 --boot1 disk --boot2 none --boot3 none --boot4 none

& $vbm.Source storagectl $Name --name "IDE" --add ide --controller PIIX4
& $vbm.Source storageattach $Name --storagectl "IDE" --port 0 --device 0 --type hdd --medium $DiskPath

Write-Host "OK -> VM prête. Lance-la depuis VirtualBox." -ForegroundColor Green


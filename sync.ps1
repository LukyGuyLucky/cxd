# sync.ps1 - copy freshly built cx.exe + std/ into e:\cxd
# Does NOT build. Run `dub build --compiler=ldc2 --build=release` first.
# Run from anywhere: powershell -File sync.ps1

$ErrorActionPreference = "Stop"

$ProjectDir = $PSScriptRoot
$CxExe      = Join-Path $ProjectDir "cx.exe"
$CxStdSrc   = Join-Path $ProjectDir "std"
$DestRoot   = "e:\cxd"
$DestExe    = Join-Path $DestRoot "cx.exe"
$DestStd    = Join-Path $DestRoot "std"

if (-not (Test-Path $CxExe))    { throw "cx.exe not found in $ProjectDir - build first" }
if (-not (Test-Path $CxStdSrc)) { throw "std/ not found in $ProjectDir" }
if (-not (Test-Path $DestRoot)) { throw "$DestRoot not found" }

Copy-Item -Path $CxExe -Destination $DestExe -Force
Write-Host "[ok] cx.exe  -> $DestExe"

if (Test-Path $DestStd) { Remove-Item -Recurse -Force $DestStd }
Copy-Item -Recurse -Path $CxStdSrc -Destination $DestStd
Write-Host "[ok] std/    -> $DestStd"

Write-Host "[ok] sync done."
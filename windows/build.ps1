# Windows release build — mirrors linux/build.sh.
# Builds the app, packages the MSIX, then compiles the Inno Setup installer.
# Outputs:
#   windows\bluebubbles.msix
#   windows\bluebubbles-windows.exe
$ErrorActionPreference = 'Stop'

$flutter = if ($env:FLUTTER_CMD) { $env:FLUTTER_CMD } else { 'flutter' }
$iscc = if ($env:ISCC_PATH) { $env:ISCC_PATH } else { "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe" }
if (-not (Test-Path $iscc)) { throw "Inno Setup compiler not found at '$iscc'. Install Inno Setup 6 or set ISCC_PATH." }

Set-Location (Join-Path $PSScriptRoot '..')

# Clean the Release output first: the installer ships Release\*.dll wholesale,
# so leftovers from removed plugins would get packaged into the installer.
$releaseDir = 'build\windows\x64\runner\Release'
if (Test-Path $releaseDir) { Remove-Item $releaseDir -Recurse -Force }

& $flutter pub get
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# Runs `flutter build windows --release` and packages the result as an MSIX
& dart run msix:create
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# Compile the Inno Setup installer
& $iscc 'windows\bluebubbles_installer_script.iss'
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Get-FileHash 'windows\bluebubbles.msix', 'windows\bluebubbles-windows.exe' -Algorithm SHA256 | Format-List Path, Hash

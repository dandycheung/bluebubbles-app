# Windows release build script. Run from the root of the repository. Requires Inno Setup 6 to be installed.
# Builds the app, packages the MSIX, then compiles the Inno Setup installer.
# Outputs:
#   windows\bluebubbles.msix (MS Store submission only — not attached to releases)
#   windows\bluebubbles-signed.msix (directly-distributed, unsigned; SignPath signs it in CI — only when SIGNED_MSIX_PUBLISHER is set)
#   windows\bluebubbles_installer.exe
$ErrorActionPreference = 'Stop'

# Flutter version to build with; override with the FLUTTER_VERSION env var.
$flutterVersion = if ($env:FLUTTER_VERSION) { $env:FLUTTER_VERSION } else { '3.44.2' }

$iscc = if ($env:ISCC_PATH) { $env:ISCC_PATH } else { "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe" }
if (-not (Test-Path $iscc)) { throw "Inno Setup compiler not found at '$iscc'. Install Inno Setup 6 or set ISCC_PATH." }

Set-Location (Join-Path $PSScriptRoot '..')

# Runs a command and aborts the build if it fails.
function Invoke-Checked {
    param([Parameter(Mandatory)][string[]]$Command, [Parameter(ValueFromRemainingArguments)][string[]]$Rest)
    & $Command[0] @($Command | Select-Object -Skip 1) @Rest
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

# Switch the project to the pinned Flutter version via fvm.
# Set FLUTTER_CMD to bypass fvm and use a preinstalled Flutter instead.
if ($env:FLUTTER_CMD) {
    $flutterCmd = $env:FLUTTER_CMD -split ' '
    $dartCmd = @('dart')
} else {
    Invoke-Checked @('fvm') use $flutterVersion --force
    $flutterCmd = 'fvm', 'flutter'
    $dartCmd = 'fvm', 'dart'
}

# Clean the Release output first: the installer ships Release\*.dll wholesale,
# so leftovers from removed plugins would get packaged into the installer.
$releaseDir = 'build\windows\x64\runner\Release'
if (Test-Path $releaseDir) { Remove-Item $releaseDir -Recurse -Force }

Invoke-Checked $flutterCmd pub get --enforce-lockfile

# Runs `flutter build windows --release` and packages the result as the MS Store
# MSIX (windows\bluebubbles.msix). Microsoft signs this one, so pass --store
# explicitly (store mode is no longer set in pubspec.yaml).
Invoke-Checked $dartCmd run msix:create --store

# Build the directly-distributed MSIX, left unsigned for SignPath to sign in CI.
# Reuses the Release output from the store build above. SIGNED_MSIX_PUBLISHER must
# equal the SignPath certificate's subject DN, or Windows will reject the signature.
# Skipped when unset (e.g. local builds without signing configured).
if ($env:SIGNED_MSIX_PUBLISHER) {
    $signedArgs = @(
        '--build-windows', 'false',
        '--sign-msix', 'false',
        '--publisher', $env:SIGNED_MSIX_PUBLISHER,
        '--output-name', 'bluebubbles-signed'
    )
    if ($env:SIGNED_MSIX_IDENTITY) { $signedArgs += @('--identity-name', $env:SIGNED_MSIX_IDENTITY) }
    Invoke-Checked $dartCmd run msix:create @signedArgs
}

# Compile the Inno Setup installer
Invoke-Checked @($iscc) 'windows\bluebubbles_installer_script.iss'

$hashTargets = @('windows\bluebubbles.msix', 'windows\bluebubbles_installer.exe')
if (Test-Path 'windows\bluebubbles-signed.msix') { $hashTargets += 'windows\bluebubbles-signed.msix' }
Get-FileHash $hashTargets -Algorithm SHA256 | Format-List Path, Hash

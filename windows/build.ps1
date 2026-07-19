# Windows release build script. Run from the root of the repository. Requires Inno Setup 6 to be installed.
#
# Phases (so CI can sign the app payload between building and packaging):
#   -Phase Build    build the app + store MSIX, then stop, leaving build\windows\x64\runner\Release
#                   ready for SignPath to sign the inner binaries.
#   -Phase Package  package the sideload MSIX + Inno installer from the (now-signed) Release\ dir.
#   -Phase All      both, back-to-back (default — local builds with no signing round-trip).
#
# Outputs:
#   windows\bluebubbles-store.msix      (Build/All) MS Store submission only — not attached to releases
#   windows\bluebubbles.msix            (Package/All) directly-distributed, unsigned; SignPath signs it in CI
#                                       (only when SIGNED_MSIX_PUBLISHER is set)
#   windows\bluebubbles_installer.exe   (Package/All)
param(
    [ValidateSet('All', 'Build', 'Package')]
    [string]$Phase = 'All',
    [ValidateSet('x64', 'arm64')]
    [string]$Arch = $(if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'x64' })
)

$ErrorActionPreference = 'Stop'

# Flutter version to build with; override with the FLUTTER_VERSION env var.
$flutterVersion = if ($env:FLUTTER_VERSION) { $env:FLUTTER_VERSION } else { '3.44.6' }

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

$releaseDir = "build\windows\$Arch\runner\Release"

if ($Phase -ne 'Package') {
    # --- Build phase: produce the Release\ output and the store MSIX ---

    # Clean the Release output first: the installer ships Release\*.dll wholesale,
    # so leftovers from removed plugins would get packaged into the installer.
    if (Test-Path $releaseDir) { Remove-Item $releaseDir -Recurse -Force }

    Invoke-Checked $flutterCmd pub get --enforce-lockfile

    # Build the app ourselves before packaging. msix aborts on arm64 if
    # build\windows\arm64 doesn't already exist (configuration.dart:434), and it
    # runs that check before it would build — so let flutter produce the
    # arch-specific Release folder first, then have msix only package it
    # (--build-windows false). --no-pub reuses the lockfile-enforced resolution above.
    Invoke-Checked $flutterCmd build windows --no-pub

    # Packages the MS Store MSIX (windows\bluebubbles-store.msix). Microsoft signs
    # this one, so pass --store explicitly (store mode is no longer set in
    # pubspec.yaml). Built from the unsigned Release output — Microsoft re-signs the
    # package at ingestion.
    Invoke-Checked $dartCmd run msix:create --store --architecture $Arch --build-windows false --output-name bluebubbles-store

    Get-FileHash 'windows\bluebubbles-store.msix' -Algorithm SHA256 | Format-List Path, Hash
}

if ($Phase -ne 'Build') {
    # --- Package phase: wrap the Release\ binaries (signed by CI in between) ---

    $iscc = if ($env:ISCC_PATH) { $env:ISCC_PATH } else { "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe" }
    if (-not (Test-Path $iscc)) { throw "Inno Setup compiler not found at '$iscc'. Install Inno Setup 6 or set ISCC_PATH." }

    if (-not (Test-Path $releaseDir)) { throw "Release output '$releaseDir' not found — run the Build phase first." }

    # Build the directly-distributed MSIX, left unsigned for SignPath to sign in CI.
    # Reuses the Release output from the store build above. SIGNED_MSIX_PUBLISHER must
    # equal the SignPath certificate's subject DN, or Windows will reject the signature.
    # Only built when PACKAGE_MSIX=true (CI sets this when the payload was signed): an
    # unsigned msix can't be installed, so packaging one for the signing fallback — or
    # for a local build without signing — is pointless. Skipped when either is unset.
    if ($env:PACKAGE_MSIX -eq 'true' -and $env:SIGNED_MSIX_PUBLISHER) {
        # MakeAppx needs a valid X.500 DN here; a plain display name yields a cryptic
        # 0x80080204 "manifest is not valid". Fail with a clear message instead.
        if ($env:SIGNED_MSIX_PUBLISHER -notmatch '(^|,)\s*CN=') {
            throw "SIGNED_MSIX_PUBLISHER must be an X.500 DN starting with 'CN=' (got: '$env:SIGNED_MSIX_PUBLISHER')."
        }
        $msixArgs = @(
            '--build-windows', 'false',
            '--sign-msix', 'false',
            '--architecture', $Arch,
            '--publisher', $env:SIGNED_MSIX_PUBLISHER,
            '--output-name', 'bluebubbles'
        )
        if ($env:SIGNED_MSIX_IDENTITY) { $msixArgs += @('--identity-name', $env:SIGNED_MSIX_IDENTITY) }
        Invoke-Checked $dartCmd run msix:create @msixArgs
    }

    # Compile the Inno Setup installer
    Invoke-Checked @($iscc) "/DArch=$Arch" 'windows\bluebubbles_installer_script.iss'

    $hashTargets = @('windows\bluebubbles_installer.exe')
    if (Test-Path 'windows\bluebubbles.msix') { $hashTargets += 'windows\bluebubbles.msix' }
    Get-FileHash $hashTargets -Algorithm SHA256 | Format-List Path, Hash
}

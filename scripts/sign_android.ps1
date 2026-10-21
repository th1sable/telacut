param(
    [Parameter(Mandatory=$true)][string]$InputApk,
    [Parameter(Mandatory=$true)][string]$OutputApk,
    [Parameter(Mandatory=$true)][string]$JavaDirectory,
    [Parameter(Mandatory=$true)][string]$BuildToolsDirectory
)
$ErrorActionPreference = 'Stop'
$projectDirectory = Split-Path -Parent $PSScriptRoot
$privateDirectory = Join-Path $projectDirectory '.signing'
$keyFile = Join-Path $privateDirectory 'telacut-release.p12'
$passwordFile = Join-Path $privateDirectory 'password.dpapi'
$java = Join-Path $JavaDirectory 'bin\java.exe'
$keytool = Join-Path $JavaDirectory 'bin\keytool.exe'
$signer = Join-Path $BuildToolsDirectory 'lib\apksigner.jar'
$align = Join-Path $BuildToolsDirectory 'zipalign.exe'
foreach ($required in @($InputApk, $java, $keytool, $signer, $align)) {
    if (!(Test-Path -LiteralPath $required -PathType Leaf)) { throw "Missing required file: $required" }
}
if (Test-Path -LiteralPath $OutputApk) { throw 'Refusing to overwrite an existing signed APK.' }
if ((Test-Path -LiteralPath $keyFile) -and !(Test-Path -LiteralPath $passwordFile)) {
    throw 'Signing key exists without its password record. Restore the original record; do not generate another key.'
}
New-Item -ItemType Directory -Path $privateDirectory -Force | Out-Null
if (!(Test-Path -LiteralPath $passwordFile)) {
    $secret = [Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(48))
    $secure = ConvertTo-SecureString $secret -AsPlainText -Force
    $protected = ConvertFrom-SecureString $secure
    [IO.File]::WriteAllText($passwordFile, $protected, [Text.Encoding]::UTF8)
    $secret = $null
} else {
    $secure = ConvertTo-SecureString ([IO.File]::ReadAllText($passwordFile))
}
$pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
$previousPassword = $env:TELACUT_SIGNING_PASSWORD
try {
    $env:TELACUT_SIGNING_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
    if (!(Test-Path -LiteralPath $keyFile)) {
        & $keytool -genkeypair -keystore $keyFile -storetype PKCS12 -storepass:env TELACUT_SIGNING_PASSWORD -keypass:env TELACUT_SIGNING_PASSWORD -alias telacut-release -keyalg RSA -keysize 3072 -validity 10000 -dname 'CN=TelaCut' -noprompt
        if ($LASTEXITCODE -ne 0) { throw 'Signing key generation failed.' }
    }
    & $align -c -P 16 4 $InputApk
    if ($LASTEXITCODE -ne 0) { throw 'APK alignment verification failed.' }
    $destinationDirectory = Split-Path -Parent ([IO.Path]::GetFullPath($OutputApk))
    New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
    & $java -jar $signer sign --ks $keyFile --ks-key-alias telacut-release --ks-pass env:TELACUT_SIGNING_PASSWORD --key-pass env:TELACUT_SIGNING_PASSWORD --v4-signing-enabled false --out $OutputApk $InputApk
    if ($LASTEXITCODE -ne 0) { throw 'APK signing failed.' }
    & $java -jar $signer verify --verbose --print-certs $OutputApk
    if ($LASTEXITCODE -ne 0) { throw 'Signed APK verification failed.' }
    Get-FileHash -LiteralPath $OutputApk -Algorithm SHA256
} finally {
    $env:TELACUT_SIGNING_PASSWORD = $previousPassword
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
    $secure.Dispose()
}

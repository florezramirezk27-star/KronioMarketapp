<#
.SYNOPSIS
    Genera el keystore de release para Android y su archivo key.properties.

.DESCRIPTION
    La llave de debug que genera Flutter sirve para `flutter run`, pero una app
    firmada con ella NO se puede publicar en Play Store: Google rechaza el APK
    en la subida y el build pasa limpio, asi que el error aparece tarde y sin
    relacion aparente con la causa.

    Este script crea la llave de produccion una sola vez. Sin ella no se pueden
    publicar actualizaciones, porque Android no permite cambiar la llave de
    firma de una app ya publicada.

    Corre en Windows PowerShell 5.1 y en PowerShell 7+. No necesita que
    `keytool` este en el PATH: busca el JDK de JAVA_HOME o el de Android Studio.

    Ni el keystore ni key.properties se versionan: ambos estan en .gitignore.

.EXAMPLE
    .\scripts\generar_keystore.ps1
#>
[CmdletBinding()]
param(
    # Sobrescribe un keystore existente. Por defecto el script cancela, para no
    # perder la llave de una app ya publicada por accidente.
    [switch]$Force,

    # Ruta del keystore. Por defecto android/app/kronio-release.jks.
    [string]$KeystorePath
)

$ErrorActionPreference = 'Stop'

$androidDir = Split-Path -Parent $PSScriptRoot
if (-not $KeystorePath) {
    $KeystorePath = Join-Path $androidDir 'app/kronio-release.jks'
}
$keyPropsPath = Join-Path $androidDir 'key.properties'

# ---------------------------------------------------------------------------
# keytool
# ---------------------------------------------------------------------------
# `keytool` viene con el JDK, pero no siempre esta en el PATH: en una maquina
# con JAVA_HOME configurado y Android Studio instalado sigue sin estar, y el
# error que da es "keytool no se reconoce como nombre de un cmdlet".

function Find-Keytool {
    $onPath = Get-Command keytool -ErrorAction SilentlyContinue
    if ($onPath) { return $onPath.Source }

    $candidates = @()
    if ($env:JAVA_HOME) { $candidates += (Join-Path $env:JAVA_HOME 'bin/keytool.exe') }

    # Android Studio trae su propio JDK (jbr = JetBrains Runtime).
    $studioRoots = @(
        "$env:ProgramFiles/Android/Android Studio",
        "$env:LOCALAPPDATA/Programs/Android Studio"
    )
    foreach ($root in $studioRoots) {
        $candidates += (Join-Path $root 'jbr/bin/keytool.exe')
    }

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path $candidate)) { return $candidate }
    }
    return $null
}

$keytool = Find-Keytool
if (-not $keytool) {
    Write-Host "No se encontro keytool." -ForegroundColor Red
    Write-Host ""
    Write-Host "Buscalo en el JDK que ya tenes instalado y agregalo al PATH, o"
    Write-Host "define JAVA_HOME. Rutas habituales:"
    Write-Host "  $env:ProgramFiles\Android\Android Studio\jbr\bin"
    Write-Host "  C:\Program Files\Java\jdk-<version>\bin"
    exit 1
}

# ---------------------------------------------------------------------------
# Helpers de entrada
# ---------------------------------------------------------------------------

# Lee un valor obligatorio sin eco en pantalla.
function Read-Secret {
    param([string]$Prompt, [switch]$AllowEmpty)

    do {
        $secure = Read-Host $Prompt -AsSecureString
        $plain = [System.Net.NetworkCredential]::new('', $secure).Password
        if ($AllowEmpty) {
            if ([string]::IsNullOrWhiteSpace($plain)) {
                Write-Host "  (vacio = se genera una aleatoria)" -ForegroundColor DarkGray
            }
        } elseif ([string]::IsNullOrWhiteSpace($plain)) {
            Write-Host "  No puede quedar vacio." -ForegroundColor DarkGray
        }
    } while ([string]::IsNullOrWhiteSpace($plain) -and -not $AllowEmpty)

    return $plain
}

# Lee un valor obligatorio, con un default que se aplica al apretar Enter.
function Read-WithDefault {
    param([string]$Prompt, [string]$Default)

    $value = Read-Host "$Prompt [$Default]"
    if ([string]::IsNullOrWhiteSpace($value)) { return $Default }
    return $value.Trim()
}

function Generate-Password {
    # Sin simbolos que rompan el parseo de key.properties ni la linea de
    # comandos de keytool: solo alfanumericos, 28 caracteres.
    $chars = 'abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789'
    $bytes = New-Object byte[] 28

    # `RandomNumberGenerator.Fill` es .NET Core 2.1+ y NO existe en .NET
    # Framework, que es lo que usa Windows PowerShell 5.1 (el PowerShell por
    # defecto en Windows). Se usa la API clasica `GetBytes`, que anda en ambos.
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $rng.GetBytes($bytes)
    } finally {
        $rng.Dispose()
    }

    return -join ($bytes | ForEach-Object { $chars[$_ % $chars.Length] })
}

# ---------------------------------------------------------------------------
# Banner
# ---------------------------------------------------------------------------

Write-Host ''
Write-Host '=== Keystore de release para Android ===' -ForegroundColor Cyan
Write-Host "keytool: $keytool"
Write-Host ''
Write-Host 'La llave se genera UNA sola vez. Si la perdes, no podras publicar'
Write-Host 'actualizaciones de la app: Google no permite cambiarla.'
Write-Host ''

if (Test-Path $KeystorePath) {
    if (-not $Force) {
        Write-Host "Ya existe $KeystorePath" -ForegroundColor Yellow
        Write-Host ''
        Write-Host 'Si NO es la llave de una app ya publicada, podes regenerarla:'
        Write-Host '  .\scripts\generar_keystore.ps1 -Force'
        exit 0
    }
    Write-Host "Se va a SOBRESCRIBIR $KeystorePath" -ForegroundColor Red
    Write-Host ''
    $confirm = Read-Host 'Confirmar? (si/no)'
    if ($confirm -ne 'si') {
        Write-Host 'Cancelado.' -ForegroundColor Yellow
        exit 0
    }
}

# ---------------------------------------------------------------------------
# Datos
# ---------------------------------------------------------------------------

$storePassword = Read-Secret 'Password del keystore (storePassword):' -AllowEmpty
if ([string]::IsNullOrWhiteSpace($storePassword)) {
    $storePassword = Generate-Password
    Write-Host '  -> generado automaticamente' -ForegroundColor DarkGray
}

$keyPassword = Read-Secret 'Password de la llave (keyPassword):' -AllowEmpty
if ([string]::IsNullOrWhiteSpace($keyPassword)) {
    $keyPassword = Generate-Password
    Write-Host '  -> generado automaticamente' -ForegroundColor DarkGray
}

$alias = Read-WithDefault 'Alias de la llave (keyAlias)' 'kronio'

$dn = Read-WithDefault 'Distinguished Name' 'CN=Kronio Market, OU=Dev, O=Kronio, L=Bogota, ST=Cundinamarca, C=CO'

$validity = Read-WithDefault 'Valida en dias' '10000'
$validityNumber = 0
if (-not [int]::TryParse($validity, [ref]$validityNumber) -or $validityNumber -le 0) {
    Write-Host "La validez debe ser un numero entero positivo: '$validity'" -ForegroundColor Red
    exit 1
}

# ---------------------------------------------------------------------------
# Generar
# ---------------------------------------------------------------------------

Write-Host ''
Write-Host 'Generando keystore...' -ForegroundColor Cyan

& $keytool -genkeypair `
    -alias $alias `
    -keyalg RSA `
    -keysize 2048 `
    -validity $validityNumber `
    -keystore $KeystorePath `
    -storepass $storePassword `
    -keypass $keyPassword `
    -dname $dn

if ($LASTEXITCODE -ne 0) {
    Write-Host 'Fallo keytool.' -ForegroundColor Red
    exit 1
}

# ---------------------------------------------------------------------------
# key.properties
# ---------------------------------------------------------------------------
# Dos detalles que rompen el build si se ignoran:
#
# 1. En key.properties las barras invertidas son caracter de escape de
#    `java.util.Properties`, asi que hay que escaparlas o Gradle lee
#    `C:Userskevinkronio-release.jks` y falla al abrir el keystore.
#
# 2. El archivo se escribe SIN BOM a proposito. `Properties.load(InputStream)`
#    decodifica como ISO-8859-1 segun el spec, asi que un BOM UTF-8 se pega al
#    nombre de la primera clave: la clave pasa a llamarse
#    "<BOM>storePassword" y la busqueda de "storePassword" devuelve null, lo que
#    revienta con un NullPointerException en vez de un mensaje util.
#    `Set-Content -Encoding UTF8` en Windows PowerShell 5.1 mete BOM; de ahi el
#    WriteAllText explicito.

$storeFileEscaped = $KeystorePath -replace '\\', '\\' -replace ':', '\:'
$keyProps = @"
storePassword=$storePassword
keyPassword=$keyPassword
keyAlias=$alias
storeFile=$storeFileEscaped
"@

[System.IO.File]::WriteAllText(
    $keyPropsPath,
    $keyProps,
    [System.Text.UTF8Encoding]::new($false)   # $false = sin BOM
)

# ---------------------------------------------------------------------------
# Verificacion
# ---------------------------------------------------------------------------
# Se relee el archivo con un parser de Properties real. Si algo quedo mal
# escapado o con BOM, se detecta aqui y no tres minutos adentro de Gradle.

Write-Host ''
Write-Host 'Verificando key.properties...' -ForegroundColor Cyan

$verifyProps = New-Object System.Collections.Specialized.OrderedDictionary
$verify = @'
import java.util.Properties;
import java.io.FileInputStream;
public class Verify {
  public static void main(String[] a) throws Exception {
    Properties p = new Properties();
    try (FileInputStream in = new FileInputStream(a[0])) { p.load(in); }
    for (String k : p.stringPropertyNames()) {
      if (k.contains("storePassword")) System.out.println("CLAVE CORRUPTA: " + k);
    }
    for (String k : new String[]{"storePassword","keyPassword","keyAlias","storeFile"}) {
      String v = p.getProperty(k);
      if (v == null || v.isEmpty()) { System.out.println("FALTA: " + k); System.exit(1); }
    }
    System.out.println("OK: " + p.getProperty("storeFile"));
    if (!new java.io.File(p.getProperty("storeFile")).isFile()) {
      System.out.println("ERROR: storeFile no apunta a un archivo existente");
      System.exit(1);
    }
  }
}
'@

$tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ("kronio-verify-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
try {
    $javaExe = Join-Path (Split-Path -Parent $keytool) 'java.exe'
    $verifyJava = Join-Path $tmpDir 'Verify.java'
    Set-Content -Path $verifyJava -Value $verify -Encoding UTF8

    & $javaExe $verifyJava $keyPropsPath 2>&1 | ForEach-Object { Write-Host "  $_" }
    if ($LASTEXITCODE -ne 0) {
        Write-Host 'key.properties no es valido. No se continua.' -ForegroundColor Red
        exit 1
    }
} finally {
    Remove-Item -Recurse -Force $tmpDir -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host 'Listo.' -ForegroundColor Green
Write-Host "  keystore:       $KeystorePath"
Write-Host "  key.properties: $keyPropsPath"
Write-Host ''
Write-Host 'Ambos estan en .gitignore. No los subas al repositorio.' -ForegroundColor Yellow
Write-Host ''
Write-Host 'Anotalas en tu gestor de contrasenas. Sin la llave no se puede'
Write-Host 'publicar ninguna actualizacion de esta app.'
Write-Host ''
Write-Host 'Para compilar:'
Write-Host '  flutter build appbundle --release'
Write-Host ''

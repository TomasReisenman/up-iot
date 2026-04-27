<#
    install-docker.ps1
    Instala Docker Desktop en Windows usando winget (preferido) o choco.
    Si no hay ninguno, descarga el instalador oficial.

    Requiere PowerShell con privilegios de administrador.
    Uso:
        powershell -ExecutionPolicy Bypass -File scripts\install-docker.ps1
#>

$ErrorActionPreference = 'Stop'

function Write-Ok    ($m) { Write-Host "[OK] $m" -ForegroundColor Green }
function Write-Fail  ($m) { Write-Host "[X]  $m" -ForegroundColor Red }
function Write-Warn  ($m) { Write-Host $m -ForegroundColor Yellow }
function Write-Dim   ($m) { Write-Host $m -ForegroundColor DarkGray }

function Test-IsAdmin {
    $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object System.Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdmin)) {
    Write-Fail "Este script necesita PowerShell como Administrador."
    Write-Dim  "Hacé click derecho en PowerShell -> 'Ejecutar como administrador' y volvé a correrlo."
    exit 1
}

Write-Host "==> Instalando Docker Desktop para Windows"

if (-not [Environment]::Is64BitOperatingSystem) {
    Write-Fail "Docker Desktop requiere Windows 64-bit."
    exit 1
}

$winVer = [System.Environment]::OSVersion.Version
if ($winVer.Major -lt 10) {
    Write-Fail "Docker Desktop requiere Windows 10/11."
    exit 1
}

$winget = Get-Command winget -ErrorAction SilentlyContinue
$choco  = Get-Command choco  -ErrorAction SilentlyContinue

if ($winget) {
    Write-Warn "Usando winget..."
    winget install -e --id Docker.DockerDesktop --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) { Write-Fail "winget falló."; exit 1 }
}
elseif ($choco) {
    Write-Warn "Usando Chocolatey..."
    choco install docker-desktop -y
    if ($LASTEXITCODE -ne 0) { Write-Fail "choco falló."; exit 1 }
}
else {
    Write-Warn "No se encontró winget ni choco. Descargando instalador oficial..."
    $url = 'https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe'
    $out = Join-Path $env:TEMP 'DockerDesktopInstaller.exe'
    Invoke-WebRequest -Uri $url -OutFile $out
    Write-Warn "Ejecutando $out (acepta el UAC)..."
    Start-Process -FilePath $out -ArgumentList 'install','--quiet','--accept-license' -Wait
    Remove-Item $out -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Ok "Instalación lanzada."
Write-Dim "Pasos siguientes:"
Write-Dim "  1) Reiniciá la sesión / la PC si Docker Desktop lo pide."
Write-Dim "  2) Abrí 'Docker Desktop' desde el menú Inicio y esperá a 'Engine running'."
Write-Dim "  3) Verificá con:  powershell -ExecutionPolicy Bypass -File scripts\check-docker.ps1"

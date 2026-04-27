<#
    check-docker.ps1
    Verifica si Docker está instalado y operativo en Windows.

    Uso:
        powershell -ExecutionPolicy Bypass -File scripts\check-docker.ps1
        powershell -ExecutionPolicy Bypass -File scripts\check-docker.ps1 -Install

    Códigos de salida:
        0  Docker OK
        1  Daemon no responde (Docker Desktop no está corriendo)
        2  Docker no instalado
        3  Falta el plugin 'docker compose'
#>

param(
    [switch]$Install
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Write-Ok    ($m) { Write-Host "[OK] $m" -ForegroundColor Green }
function Write-Fail  ($m) { Write-Host "[X]  $m" -ForegroundColor Red }
function Write-Warn  ($m) { Write-Host $m -ForegroundColor Yellow }
function Write-Dim   ($m) { Write-Host $m -ForegroundColor DarkGray }

Write-Host "==> Plataforma: Windows ($([System.Environment]::OSVersion.Version))"

$dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
if (-not $dockerCmd) {
    Write-Fail "Docker no está instalado (no se encontró 'docker' en PATH)."
    if ($Install) {
        Write-Warn "Lanzando instalador..."
        & "$ScriptDir\install-docker.ps1"
        exit $LASTEXITCODE
    } else {
        Write-Dim "Sugerencia: ejecutá  '.\scripts\check-docker.ps1 -Install'"
        Write-Dim "             o corré directamente  '.\scripts\install-docker.ps1'."
    }
    exit 2
}

try {
    $ver = & docker --version 2>$null
    Write-Ok "Docker CLI encontrado: $ver"
} catch {
    Write-Fail "No pude ejecutar 'docker --version'."
    exit 2
}

try {
    $cv = & docker compose version 2>$null
    if ($LASTEXITCODE -ne 0) { throw "compose v2 no disponible" }
    Write-Ok ($cv | Select-Object -First 1)
} catch {
    Write-Fail "No se encuentra el plugin 'docker compose' (v2)."
    Write-Dim "    Actualizá Docker Desktop a una versión reciente."
    exit 3
}

& docker info *>$null
if ($LASTEXITCODE -ne 0) {
    Write-Fail "El daemon de Docker no responde."
    Write-Dim "    Iniciá 'Docker Desktop' desde el menú Inicio y esperá a que diga 'Engine running'."
    Write-Dim "    Si usás WSL2, verificá que el backend WSL esté habilitado en Settings -> General."
    exit 1
}

Write-Ok "Daemon respondiendo."
Write-Host ""
Write-Dim "Listo: podés correr  .\stack.sh start  (o el equivalente en PowerShell) desde node-red\"
exit 0

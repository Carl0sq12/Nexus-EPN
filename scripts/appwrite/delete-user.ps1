<#
.SYNOPSIS
  Borra un usuario de Appwrite Auth por email (y su perfil si existe).

.DESCRIPTION
  Borrar solo el documento en Databases NO elimina la cuenta de Auth.
  Este script busca el usuario en Auth → Users y lo elimina.

.EXAMPLE
  .\delete-user.ps1 -Email "usuario@epn.edu.ec"
#>

param(
  [Parameter(Mandatory = $true)]
  [string]$Email
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$EnvFile = Join-Path $ScriptDir '.env'

function Read-DotEnv {
  param([string]$Path)
  if (-not (Test-Path $Path)) {
    throw "Falta $Path - copia .env.example a .env y completa APPWRITE_*"
  }
  Get-Content $Path | ForEach-Object {
    $line = $_.Trim()
    if (-not $line -or $line.StartsWith('#')) { return }
    $i = $line.IndexOf('=')
    if ($i -lt 1) { return }
    $key = $line.Substring(0, $i).Trim()
    $val = $line.Substring($i + 1).Trim()
    Set-Item -Path "Env:$key" -Value $val
  }
}

Read-DotEnv $EnvFile

$Endpoint = $env:APPWRITE_ENDPOINT.TrimEnd('/')
$ProjectId = $env:APPWRITE_PROJECT_ID
$ApiKey = $env:APPWRITE_API_KEY
$DatabaseId = if ($env:APPWRITE_DATABASE_ID) { $env:APPWRITE_DATABASE_ID } else { 'nexus_campus' }
$NormalizedEmail = $Email.Trim().ToLowerInvariant()

if (-not $ProjectId -or -not $ApiKey) {
  throw 'APPWRITE_PROJECT_ID y APPWRITE_API_KEY son obligatorios en .env'
}

$headers = @{
  'X-Appwrite-Project' = $ProjectId
  'X-Appwrite-Key'     = $ApiKey
  'Content-Type'       = 'application/json'
}

Write-Host "Buscando usuario: $NormalizedEmail"

$encoded = [uri]::EscapeDataString($NormalizedEmail)
$listUrl = "$Endpoint/users?queries[]=" + [uri]::EscapeDataString("equal(`"email`",`"$NormalizedEmail`")")
try {
  $list = Invoke-RestMethod -Method Get -Uri $listUrl -Headers $headers
} catch {
  # Fallback: listar y filtrar en cliente (por si queries no estan disponibles)
  $list = Invoke-RestMethod -Method Get -Uri "$Endpoint/users?limit=100" -Headers $headers
}

$users = @()
if ($list.users) { $users = @($list.users) }

$match = $users | Where-Object { $_.email -and $_.email.ToLowerInvariant() -eq $NormalizedEmail }

if (-not $match) {
  Write-Host "No hay usuario Auth con ese email. Ya puedes registrarte de nuevo."
  exit 0
}

foreach ($user in @($match)) {
  $userId = $user.'$id'
  Write-Host "Eliminando Auth user id=$userId email=$($user.email)"

  try {
    Invoke-RestMethod -Method Delete -Uri "$Endpoint/users/$userId" -Headers $headers | Out-Null
    Write-Host "  Auth: eliminado"
  } catch {
    Write-Host "  Auth: ERROR $($_.Exception.Message)"
    if ($_.ErrorDetails.Message) { Write-Host "  $($_.ErrorDetails.Message)" }
    throw
  }

  try {
    Invoke-RestMethod -Method Delete -Uri "$Endpoint/databases/$DatabaseId/collections/profiles/documents/$userId" -Headers $headers | Out-Null
    Write-Host "  Perfil profiles/$userId: eliminado"
  } catch {
    Write-Host "  Perfil: no existia o ya estaba borrado (ok)"
  }
}

Write-Host ""
Write-Host "Listo. Vuelve a registrar ese correo en la app."

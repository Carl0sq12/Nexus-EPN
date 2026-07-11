<#
.SYNOPSIS
  Nexus Campus - Setup completo de Appwrite (PowerShell, sin Node).
#>

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

if (-not $Endpoint -or -not $ProjectId -or -not $ApiKey) {
  throw 'APPWRITE_ENDPOINT, APPWRITE_PROJECT_ID y APPWRITE_API_KEY son obligatorios'
}

$Headers = @{
  'X-Appwrite-Project' = $ProjectId
  'X-Appwrite-Key'     = $ApiKey
  'Content-Type'       = 'application/json'
}

function Invoke-Appwrite {
  param(
    [string]$Method,
    [string]$Path,
    [object]$Body = $null
  )
  $uri = "$Endpoint$Path"
  $params = @{
    Method      = $Method
    Uri         = $uri
    Headers     = $Headers
    ErrorAction = 'Stop'
  }
  if ($null -ne $Body) {
    $params.Body = ($Body | ConvertTo-Json -Depth 20 -Compress)
  }
  try {
    return Invoke-RestMethod @params
  } catch {
    $status = $null
    $msg = $_.Exception.Message
    if ($_.Exception.Response) {
      $status = [int]$_.Exception.Response.StatusCode
      try {
        $stream = $_.Exception.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($stream)
        $bodyText = $reader.ReadToEnd()
        if ($bodyText) { $msg = $bodyText }
      } catch {}
    }
    if ($_.ErrorDetails.Message) { $msg = $_.ErrorDetails.Message }
    $err = New-Object PSObject -Property @{
      Status  = $status
      Message = $msg
    }
    throw $err
  }
}

function Test-AlreadyExists {
  param($ErrorObject)
  $status = $ErrorObject.Status
  $msg = [string]$ErrorObject.Message
  return ($status -eq 409) -or ($msg -match 'already exists') -or ($msg -match 'already_exists')
}

function Get-ErrorStatus {
  param($Caught)
  if ($null -ne $Caught.Status) { return [int]$Caught.Status }
  if ($null -ne $Caught.TargetObject -and $null -ne $Caught.TargetObject.Status) {
    return [int]$Caught.TargetObject.Status
  }
  $msg = [string]$Caught
  if ($Caught.Exception) { $msg = [string]$Caught.Exception.Message }
  if ($Caught.TargetObject.Message) { $msg = [string]$Caught.TargetObject.Message }
  if ($msg -match '"code"\s*:\s*(\d+)') { return [int]$Matches[1] }
  if ($msg -match '404') { return 404 }
  if ($msg -match '409') { return 409 }
  return $null
}

function Get-ErrorMessage {
  param($Caught)
  if ($Caught.TargetObject.Message) { return [string]$Caught.TargetObject.Message }
  if ($Caught.Message) { return [string]$Caught.Message }
  if ($Caught.Exception) { return [string]$Caught.Exception.Message }
  return [string]$Caught
}

function Ensure-Database {
  try {
    Invoke-Appwrite -Method GET -Path "/databases/$DatabaseId" | Out-Null
    Write-Host "[OK] Database ya existe: $DatabaseId"
  } catch {
    $status = Get-ErrorStatus $_
    if ($status -eq 404) {
      Invoke-Appwrite -Method POST -Path '/databases' -Body @{
        databaseId = $DatabaseId
        name       = 'Nexus Campus'
      } | Out-Null
      Write-Host "[OK] Database creada: $DatabaseId"
    } else {
      throw $_
    }
  }
}

function Ensure-Collection {
  param([string]$Id, [string]$Name)
  try {
    Invoke-Appwrite -Method GET -Path "/databases/$DatabaseId/collections/$Id" | Out-Null
    Write-Host "[OK] Collection ya existe: $Id"
  } catch {
    $status = Get-ErrorStatus $_
    if ($status -eq 404) {
      try {
        Invoke-Appwrite -Method POST -Path "/databases/$DatabaseId/collections" -Body @{
          collectionId     = $Id
          name             = $Name
          documentSecurity = $true
          permissions      = @(
            'read("any")',
            'create("users")',
            'update("users")',
            'delete("users")'
          )
        } | Out-Null
        Write-Host "[OK] Collection creada: $Id"
      } catch {
        $createStatus = Get-ErrorStatus $_
        $createMsg = Get-ErrorMessage $_
        if ($createStatus -eq 409 -or $createMsg -match 'already exists') {
          Write-Host "[OK] Collection ya existe: $Id"
        } else {
          throw $_
        }
      }
    } elseif ($status -eq 409) {
      Write-Host "[OK] Collection ya existe: $Id"
    } else {
      throw $_
    }
  }
}

function Ensure-Attribute {
  param(
    [string]$CollectionId,
    [hashtable]$Def
  )
  $key = $Def.key
  $type = $Def.type
  $pathMap = @{
    string   = 'string'
    integer  = 'integer'
    float    = 'float'
    boolean  = 'boolean'
    datetime = 'datetime'
    email    = 'email'
    enum     = 'enum'
  }
  $sub = $pathMap[$type]
  $body = @{
    key      = $key
    required = [bool]$Def.required
  }
  if ($Def.ContainsKey('defaultValue') -and $null -ne $Def.defaultValue) {
    $body['default'] = $Def.defaultValue
  }
  if ($Def.ContainsKey('array')) { $body['array'] = [bool]$Def.array }

  switch ($type) {
    'string' {
      $body['size'] = if ($Def.size) { $Def.size } else { 255 }
    }
    'integer' {
      if ($Def.ContainsKey('min')) { $body['min'] = $Def.min }
      if ($Def.ContainsKey('max')) { $body['max'] = $Def.max }
    }
    'float' {
      if ($Def.ContainsKey('min')) { $body['min'] = $Def.min }
      if ($Def.ContainsKey('max')) { $body['max'] = $Def.max }
    }
    'enum' {
      $body['elements'] = $Def.elements
    }
  }

  try {
    Invoke-Appwrite -Method POST -Path "/databases/$DatabaseId/collections/$CollectionId/attributes/$sub" -Body $body | Out-Null
    Write-Host "  + attribute $CollectionId.$key ($type)"
  } catch {
    $status = Get-ErrorStatus $_
    $msg = Get-ErrorMessage $_
    if ($status -eq 409 -or $msg -match 'already exists' -or $msg -match 'already_exists') {
      Write-Host "  . attribute $CollectionId.$key ya existe"
    } else {
      Write-Warning "  ! attribute $CollectionId.$key : $msg"
    }
  }
}

function Wait-Attributes {
  param([string]$CollectionId, [string[]]$Keys)
  $attempts = 40
  for ($i = 1; $i -le $attempts; $i++) {
    $attrs = Invoke-Appwrite -Method GET -Path "/databases/$DatabaseId/collections/$CollectionId/attributes"
    $map = @{}
    foreach ($a in $attrs.attributes) { $map[$a.key] = $a }
    $pending = @()
    foreach ($k in $Keys) {
      if (-not $map.ContainsKey($k) -or $map[$k].status -ne 'available') {
        $pending += $k
      }
    }
    if ($pending.Count -eq 0) {
      Write-Host "  [OK] attributes ready: $CollectionId"
      return
    }
    Write-Host "   ... esperando attrs $CollectionId ($i/$attempts): $($pending -join ', ')"
    Start-Sleep -Seconds 2
  }
  throw "Timeout esperando attributes en $CollectionId"
}

function Ensure-Index {
  param(
    [string]$CollectionId,
    [string]$Key,
    [string]$Type,
    [string[]]$Attributes,
    [string[]]$Orders = $null
  )
  $body = @{
    key        = $Key
    type       = $Type
    attributes = $Attributes
  }
  if ($Orders) { $body['orders'] = $Orders }
  try {
    Invoke-Appwrite -Method POST -Path "/databases/$DatabaseId/collections/$CollectionId/indexes" -Body $body | Out-Null
    Write-Host "  + index $CollectionId.$Key"
  } catch {
    $status = Get-ErrorStatus $_
    $msg = Get-ErrorMessage $_
    if ($status -eq 409 -or $msg -match 'already exists' -or $msg -match 'already_exists') {
      Write-Host "  . index $CollectionId.$Key ya existe"
    } else {
      Write-Warning "  ! index $CollectionId.$Key omitido: $msg"
    }
  }
}

function Ensure-Bucket {
  param([string]$Id, [string]$Name)
  try {
    Invoke-Appwrite -Method GET -Path "/storage/buckets/$Id" | Out-Null
    Write-Host "[OK] Bucket ya existe: $Id"
  } catch {
    $status = Get-ErrorStatus $_
    if ($status -eq 404) {
      try {
        Invoke-Appwrite -Method POST -Path '/storage/buckets' -Body @{
          bucketId              = $Id
          name                  = $Name
          permissions           = @(
            'read("any")',
            'create("users")',
            'update("users")',
            'delete("users")'
          )
          fileSecurity          = $true
          enabled               = $true
          maximumFileSize       = 10485760
          allowedFileExtensions = @('jpg', 'jpeg', 'png', 'webp', 'heic')
          compression           = 'gzip'
          encryption            = $false
          antivirus             = $true
        } | Out-Null
        Write-Host "[OK] Bucket creado: $Id"
      } catch {
        $createStatus = Get-ErrorStatus $_
        $createMsg = Get-ErrorMessage $_
        if ($createStatus -eq 403 -or $createMsg -match 'maximum number of buckets') {
          Write-Warning "Bucket '$Id' no creado: limite del plan. Usa el bucket 'avatars' con prefijo '$Id/'."
        } elseif ($createStatus -eq 409 -or $createMsg -match 'already exists') {
          Write-Host "[OK] Bucket ya existe: $Id"
        } else {
          throw $_
        }
      }
    } elseif ($status -eq 409) {
      Write-Host "[OK] Bucket ya existe: $Id"
    } else {
      throw $_
    }
  }
}

$Collections = @(
  @{
    id = 'profiles'; name = 'Profiles'
    attributes = @(
      @{ key = 'email'; type = 'email'; required = $false }
      @{ key = 'full_name'; type = 'string'; size = 200; required = $false }
      @{ key = 'role'; type = 'enum'; elements = @('passenger', 'driver'); required = $false; defaultValue = 'passenger' }
      @{ key = 'avatar_url'; type = 'string'; size = 2048; required = $false }
      @{ key = 'phone'; type = 'string'; size = 40; required = $false }
      @{ key = 'cedula'; type = 'string'; size = 10; required = $false }
    )
    indexes = @(
      @{ key = 'idx_email'; type = 'key'; attributes = @('email') }
      @{ key = 'idx_role'; type = 'key'; attributes = @('role') }
      @{ key = 'idx_phone'; type = 'key'; attributes = @('phone') }
    )
  }
  @{
    id = 'trips'; name = 'Trips'
    attributes = @(
      @{ key = 'driver_id'; type = 'string'; size = 64; required = $true }
      @{ key = 'origin'; type = 'string'; size = 500; required = $true }
      @{ key = 'destination'; type = 'string'; size = 500; required = $true }
      @{ key = 'departure_time'; type = 'datetime'; required = $true }
      @{ key = 'total_seats'; type = 'integer'; required = $true; min = 1; max = 20 }
      @{ key = 'available_seats'; type = 'integer'; required = $true; min = 0; max = 20 }
      @{ key = 'price_per_seat'; type = 'float'; required = $true; min = 0 }
      @{ key = 'status'; type = 'enum'; elements = @('active', 'cancelled', 'full', 'in_progress', 'completed'); required = $false; defaultValue = 'active' }
      @{ key = 'origin_latitude'; type = 'float'; required = $false }
      @{ key = 'origin_longitude'; type = 'float'; required = $false }
      @{ key = 'destination_latitude'; type = 'float'; required = $false }
      @{ key = 'destination_longitude'; type = 'float'; required = $false }
      @{ key = 'route_distance_meters'; type = 'float'; required = $false }
      @{ key = 'route_duration_seconds'; type = 'float'; required = $false }
      @{ key = 'route_points'; type = 'string'; size = 20000; required = $false }
    )
    indexes = @(
      @{ key = 'idx_driver'; type = 'key'; attributes = @('driver_id') }
      @{ key = 'idx_status'; type = 'key'; attributes = @('status') }
      @{ key = 'idx_departure'; type = 'key'; attributes = @('departure_time') }
      @{ key = 'idx_status_departure'; type = 'key'; attributes = @('status', 'departure_time'); orders = @('ASC', 'ASC') }
    )
  }
  @{
    id = 'trip_requests'; name = 'Trip Requests'
    attributes = @(
      @{ key = 'trip_id'; type = 'string'; size = 64; required = $true }
      @{ key = 'passenger_id'; type = 'string'; size = 64; required = $true }
      @{ key = 'status'; type = 'enum'; elements = @('pending', 'price_proposed', 'accepted', 'rejected', 'cancelled'); required = $false; defaultValue = 'pending' }
      @{ key = 'passenger_count'; type = 'integer'; required = $false; min = 1; max = 20; defaultValue = 1 }
      @{ key = 'pickup_note'; type = 'string'; size = 1000; required = $false }
      @{ key = 'dropoff_note'; type = 'string'; size = 1000; required = $false }
      @{ key = 'pickup_latitude'; type = 'float'; required = $false }
      @{ key = 'pickup_longitude'; type = 'float'; required = $false }
      @{ key = 'dropoff_latitude'; type = 'float'; required = $false }
      @{ key = 'dropoff_longitude'; type = 'float'; required = $false }
      @{ key = 'request_stops'; type = 'string'; size = 2000; required = $false }
      @{ key = 'proposed_price'; type = 'float'; required = $false; min = 0 }
      @{ key = 'price_note'; type = 'string'; size = 1000; required = $false }
    )
    indexes = @(
      @{ key = 'idx_trip'; type = 'key'; attributes = @('trip_id') }
      @{ key = 'idx_passenger'; type = 'key'; attributes = @('passenger_id') }
      @{ key = 'idx_status'; type = 'key'; attributes = @('status') }
      @{ key = 'idx_trip_passenger'; type = 'key'; attributes = @('trip_id', 'passenger_id') }
    )
  }
  @{
    id = 'vehicles'; name = 'Vehicles'
    attributes = @(
      @{ key = 'driver_id'; type = 'string'; size = 64; required = $true }
      @{ key = 'brand'; type = 'string'; size = 100; required = $true }
      @{ key = 'model'; type = 'string'; size = 100; required = $true }
      @{ key = 'color'; type = 'string'; size = 50; required = $true }
      @{ key = 'plate'; type = 'string'; size = 30; required = $true }
      @{ key = 'photo_url'; type = 'string'; size = 2048; required = $false }
      @{ key = 'license_photo_url'; type = 'string'; size = 2048; required = $false }
      @{ key = 'approval_status'; type = 'enum'; elements = @('pending', 'approved', 'rejected'); required = $false; defaultValue = 'pending' }
    )
    indexes = @(
      @{ key = 'idx_driver'; type = 'key'; attributes = @('driver_id') }
      @{ key = 'idx_plate'; type = 'unique'; attributes = @('plate') }
      @{ key = 'idx_approval'; type = 'key'; attributes = @('approval_status') }
    )
  }
  @{
    id = 'messages'; name = 'Messages'
    attributes = @(
      @{ key = 'trip_id'; type = 'string'; size = 64; required = $true }
      @{ key = 'sender_id'; type = 'string'; size = 64; required = $true }
      @{ key = 'content'; type = 'string'; size = 4000; required = $true }
      @{ key = 'is_system'; type = 'boolean'; required = $false; defaultValue = $false }
    )
    indexes = @(
      @{ key = 'idx_trip'; type = 'key'; attributes = @('trip_id') }
    )
  }
  @{
    id = 'notifications'; name = 'Notifications'
    attributes = @(
      @{ key = 'user_id'; type = 'string'; size = 64; required = $true }
      @{ key = 'title'; type = 'string'; size = 200; required = $true }
      @{ key = 'body'; type = 'string'; size = 2000; required = $true }
      @{ key = 'type'; type = 'string'; size = 50; required = $true }
      @{ key = 'read'; type = 'boolean'; required = $false; defaultValue = $false }
      @{ key = 'related_id'; type = 'string'; size = 64; required = $false }
    )
    indexes = @(
      @{ key = 'idx_user'; type = 'key'; attributes = @('user_id') }
    )
  }
  @{
    id = 'ratings'; name = 'Ratings'
    attributes = @(
      @{ key = 'trip_id'; type = 'string'; size = 64; required = $true }
      @{ key = 'rater_id'; type = 'string'; size = 64; required = $true }
      @{ key = 'rated_user_id'; type = 'string'; size = 64; required = $true }
      @{ key = 'score'; type = 'integer'; required = $true; min = 1; max = 5 }
      @{ key = 'comment'; type = 'string'; size = 2000; required = $false }
    )
    indexes = @(
      @{ key = 'idx_trip'; type = 'key'; attributes = @('trip_id') }
      @{ key = 'idx_rater'; type = 'key'; attributes = @('rater_id') }
      @{ key = 'idx_rated'; type = 'key'; attributes = @('rated_user_id') }
      @{ key = 'uniq_trip_rater_rated'; type = 'unique'; attributes = @('trip_id', 'rater_id', 'rated_user_id') }
    )
  }
  @{
    id = 'sos_alerts'; name = 'SOS Alerts'
    attributes = @(
      @{ key = 'user_id'; type = 'string'; size = 64; required = $true }
      @{ key = 'latitude'; type = 'float'; required = $true }
      @{ key = 'longitude'; type = 'float'; required = $true }
      @{ key = 'type'; type = 'enum'; elements = @('personal_emergency', 'mechanical_problem'); required = $false; defaultValue = 'personal_emergency' }
      @{ key = 'message'; type = 'string'; size = 2000; required = $false }
    )
    indexes = @(
      @{ key = 'idx_user'; type = 'key'; attributes = @('user_id') }
    )
  }
  @{
    id = 'emergency_contacts'; name = 'Emergency Contacts'
    attributes = @(
      @{ key = 'user_id'; type = 'string'; size = 64; required = $true }
      @{ key = 'name'; type = 'string'; size = 200; required = $true }
      @{ key = 'phone'; type = 'string'; size = 40; required = $true }
      @{ key = 'relationship'; type = 'string'; size = 100; required = $false }
    )
    indexes = @(
      @{ key = 'idx_user'; type = 'key'; attributes = @('user_id') }
    )
  }
)

Write-Host "Nexus Campus -> Appwrite setup (PowerShell)"
Write-Host "Endpoint: $Endpoint"
Write-Host "Project:  $ProjectId"
Write-Host "Database: $DatabaseId"

Ensure-Database

foreach ($col in $Collections) {
  Write-Host ""
  Write-Host "-> $($col.id)"
  Ensure-Collection -Id $col.id -Name $col.name
  foreach ($attr in $col.attributes) {
    Ensure-Attribute -CollectionId $col.id -Def $attr
  }
  $keys = @($col.attributes | ForEach-Object { $_.key })
  Wait-Attributes -CollectionId $col.id -Keys $keys
  foreach ($idx in $col.indexes) {
    Ensure-Index -CollectionId $col.id -Key $idx.key -Type $idx.type -Attributes $idx.attributes -Orders $idx.orders
  }
}

Write-Host ""
Write-Host "-> buckets"
Ensure-Bucket -Id 'avatars' -Name 'Avatars'
Ensure-Bucket -Id 'vehicles' -Name 'Vehicles'

Write-Host ""
Write-Host "=================================================="
Write-Host " AUTH - Verificacion de cuenta y recuperar password"
Write-Host "=================================================="
Write-Host ""
Write-Host "En Appwrite Console -> Auth -> Settings:"
Write-Host "1) Email verification: ENABLED"
Write-Host "2) Redirect URLs:"
Write-Host "   - https://nexus-five-chi.vercel.app/auth-callback.html"
Write-Host "   - https://nexus-five-chi.vercel.app/reset-password.html"
Write-Host "3) Templates: Verification + Recovery"
Write-Host "4) SMTP recomendado en produccion"
Write-Host ""
Write-Host "Project ID: $ProjectId"
Write-Host "Endpoint:   $Endpoint"
Write-Host "Database:   $DatabaseId"
Write-Host ""
Write-Host "[DONE] Setup terminado."
Write-Host ""
Write-Host "Pon en el .env de la app Flutter:"
Write-Host "APPWRITE_ENDPOINT=$Endpoint"
Write-Host "APPWRITE_PROJECT_ID=$ProjectId"
Write-Host "APPWRITE_DATABASE_ID=$DatabaseId"

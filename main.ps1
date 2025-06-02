# main.ps1 - Script principal para crear vhosts y certificados SSL
# Uso: Ejecutar como administrador

. "$PSScriptRoot\inc\ssl-tools.ps1"

# Verificar privilegios de administrador y auto-elevación
if (-not (Test-Admin)) {
    Write-Host "Elevando privilegios de administrador..."
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'powershell.exe'
    $psi.Arguments = "-ExecutionPolicy Bypass -File `"$PSCommandPath`""
    $psi.Verb = 'runas'
    [System.Diagnostics.Process]::Start($psi) | Out-Null
    exit
}

# Menú interactivo inicial
Write-Host "==============================="
Write-Host " XAMPP VirtualHost SSL Helper "
Write-Host "==============================="
Write-Host "[1] Crear nuevo VirtualHost"
Write-Host "[2] Reparar/regenerar SSL de un dominio"
Write-Host "[3] Salir"
$op = Read-Host 'Selecciona una opción (1, 2, 3)'
if ($op -eq '3') { exit }

if ($op -eq '2') {
    $vhostDir = "C:/xampp/apache/conf/vhost/apache/"
    $sslBase = "C:/xampp/apache/conf/vhost/ssl/"
    $vhosts = Get-ChildItem $vhostDir -Filter *.conf | Select-Object -ExpandProperty Name
    if ($vhosts.Count -eq 0) {
        Write-Warning "No se encontraron VirtualHosts para reparar."
        exit
    }
    # Filtrar nombres sospechosos
    $dominios = @()
    foreach ($v in $vhosts) {
        $dom = $v -replace '\.conf$',''
        if ($dom.Length -lt 3) {
            Write-Warning "Archivo de vhost con nombre sospechoso: $v (ignorado)"
        } else {
            $dominios += $dom
        }
    }
    if ($dominios.Count -eq 0) {
        Write-Error "No se encontraron dominios válidos para reparar."
        exit
    }
    Write-Host "\nDominios disponibles para reparar SSL:"
    for ($i=0; $i -lt $dominios.Count; $i++) {
        Write-Host ("[" + ($i+1) + "] " + $dominios[$i])
    }
    $sel = Read-Host 'Selecciona el número de dominio a reparar'
    if ($sel -match '^[0-9]+$' -and $sel -ge 1 -and $sel -le $dominios.Count) {
        $Domain = $dominios[$sel-1]
    } else {
        Write-Error "Selección inválida."; exit 1
    }
    # Limpiar SSL viejo
    $sslDir = "$sslBase$Domain"
    if (Test-Path $sslDir) {
        Remove-Item "$sslDir\*" -Force -Recurse
        Write-Host "Certificados SSL viejos eliminados para $Domain."
    }
    # Verificar que el vhost existe
    $vhostFile = "$vhostDir$Domain.conf"
    if (!(Test-Path $vhostFile)) {
        Write-Warning "El archivo de VirtualHost para $Domain no existe. Solo se regenerará el SSL."
    }
    New-SSLCert -Domain $Domain
    Write-Host "\nCertificado SSL regenerado para $Domain. Reinicia Apache si es necesario."
    Restart-Apache
    Write-Host "\nLimpiando caché DNS..."
    Start-Process -FilePath "ipconfig" -ArgumentList "/flushdns" -NoNewWindow -Wait
    Write-Host "Caché DNS limpiada."
    exit
}

# 1. Solicitar datos
$Domain = Read-Host 'Dominio principal (ej: myapp.local)'
$tpls = Get-ChildItem "$PSScriptRoot\templates" -Filter *.txt | Select-Object -ExpandProperty Name
# Mostrar plantillas con índice numérico
Write-Host "\nPlantillas disponibles:" 
for ($i=0; $i -lt $tpls.Count; $i++) {
    $nombre = $tpls[$i].Split('.')[0]
    Write-Host ("[" + ($i+1) + "] " + $nombre.PadRight(12) + " => " + $tpls[$i])
}
$tplIndex = Read-Host 'Selecciona el número de plantilla (ej: 1, 2, 3...)'
if ($tplIndex -match '^[0-9]+$' -and $tplIndex -ge 1 -and $tplIndex -le $tpls.Count) {
    $Template = $tpls[$tplIndex-1].Split('.')[0]
} else {
    Write-Error "Selección inválida."; exit 1
}
$TplFile = "$PSScriptRoot\templates\$Template.txt"
if (!(Test-Path $TplFile)) { Write-Error "No se encontró la plantilla $TplFile"; exit 1 }
$DocRoot = Read-Host "DocumentRoot (default: C:/xampp/htdocs/$Domain)"
if (-not $DocRoot) { $DocRoot = "C:/xampp/htdocs/$Domain" }
if (!(Test-Path $DocRoot)) { New-Item -ItemType Directory -Path $DocRoot | Out-Null }

# Verificar y preparar soporte para vhosts personalizados
$httpdVhosts = "C:/xampp/apache/conf/extra/httpd-vhosts.conf"
$vhostIncLine = 'IncludeOptional conf/vhost/apache/*.conf'
$vhostApacheDir = "C:/xampp/apache/conf/vhost/apache/"
$vhostSslDir = "C:/xampp/apache/conf/vhost/ssl/"
$vhostCaDir = "C:/xampp/apache/conf/vhost/ca/"
$vhostLogsDir = "C:/xampp/apache/conf/vhost/logs/"

# Crear directorios si no existen
foreach ($dir in @($vhostApacheDir, $vhostSslDir, $vhostCaDir, $vhostLogsDir)) {
    if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
}

# Añadir IncludeOptional si no existe
if (Test-Path $httpdVhosts) {
    $vhostsContent = Get-Content $httpdVhosts -Raw
    if ($vhostsContent -notmatch [regex]::Escape($vhostIncLine)) {
        Add-Content -Path $httpdVhosts -Value "`n$vhostIncLine"
        Write-Host "Línea IncludeOptional añadida a httpd-vhosts.conf."
    }
}

# 2. Generar SSL y CA
New-SSLCert -Domain $Domain

# 3. Leer plantilla y reemplazar placeholders
$sslDir = "C:/xampp/apache/conf/vhost/ssl/$Domain"
$logsDir = "C:/xampp/apache/conf/vhost/logs/"
$sslKey = "$sslDir/server.key"
$sslCrt = "$sslDir/server.crt"
$tpl = Get-Content $TplFile -Raw
$tpl = $tpl -replace '\{\{DOMAIN\}\}', $Domain
$tpl = $tpl -replace '\{\{DOCROOT\}\}', $DocRoot
$tpl = $tpl -replace '\{\{LOGS_DIR\}\}', $logsDir
$tpl = $tpl -replace '\{\{SSL_KEY\}\}', $sslKey
$tpl = $tpl -replace '\{\{SSL_CERT\}\}', $sslCrt

# 4. Escribir archivo de vhost
$vhostFile = "C:/xampp/apache/conf/vhost/apache/$Domain.conf"
Set-Content -Path $vhostFile -Value $tpl -Encoding UTF8
Write-Host "\nArchivo de VirtualHost generado: $vhostFile"

# 5. Agregar a hosts de Windows
$hostsPath = "$env:windir\System32\drivers\etc\hosts"
$hostsEntry = "127.0.0.1`t$Domain" + [Environment]::NewLine + "127.0.0.1`twww.$Domain"
if (-not (Select-String -Path $hostsPath -Pattern "\b$Domain\b" -Quiet)) {
    Add-Content -Path $hostsPath -Value $hostsEntry
    Write-Host "\nAgregado $Domain a hosts de Windows."
} else {
    Write-Host "\n$Domain ya existe en hosts de Windows."
}

Write-Host "\n¡Listo! Reinicia Apache y accede a https://$Domain"

# 6. Reiniciar Apache automáticamente
Restart-Apache

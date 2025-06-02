# Funciones auxiliares para CA y certificados SSL
# (mover aquí la lógica de mkcert-local.ps1 para ser usada como módulo)

function New-SSLCert {
    param(
        [string]$Domain,
        [string]$CAName = "LocalDev-Root-CA",
        [string]$Country = "US",
        [string]$Org = "DevOrg",
        [string]$OrgUnit = "DevUnit",
        [string]$XamppRoot = "C:/xampp"
    )
    $sslDir = "$XamppRoot/apache/conf/vhost/ssl/$Domain"
    $caDir = "$XamppRoot/apache/conf/vhost/ca"
    if (!(Test-Path $sslDir)) { New-Item -ItemType Directory -Path $sslDir | Out-Null }
    if (!(Test-Path $caDir)) { New-Item -ItemType Directory -Path $caDir | Out-Null }
    $caKey = "$caDir/RootCA.key"
    $caPem = "$caDir/RootCA.pem"
    $caCrt = "$caDir/RootCA.crt"
    $caSrl = "$caDir/RootCA.srl"
    $domainKey = "$sslDir/server.key"
    $domainCsr = "$sslDir/server.csr"
    $domainCrt = "$sslDir/server.crt"
    $domainExt = "$sslDir/domains.ext"
    if (!(Test-Path $caKey -PathType Leaf)) {
        Write-Host "Generating Root CA..."
        & openssl req -x509 -nodes -new -sha256 -days 3650 -newkey rsa:2048 -config NUL `
            -keyout $caKey -out $caPem -subj "/C=$Country/CN=$CAName/O=$Org/OU=$OrgUnit"
        & openssl x509 -outform pem -in $caPem -out $caCrt
    }
    Write-Host "Generating key and CSR for $Domain..."
    & openssl req -new -nodes -newkey rsa:2048 -config NUL -keyout $domainKey -out $domainCsr `
        -subj "/C=$Country/O=$Org/OU=$OrgUnit/CN=$Domain"
    @"
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = $Domain
DNS.2 = www.$Domain
DNS.3 = localhost
DNS.4 = 127.0.0.1
IP.1 = 127.0.0.1
"@ | Set-Content $domainExt
    Write-Host "Signing certificate with CA..."
    & openssl x509 -req -sha256 -days 825 -in $domainCsr `
        -CA $caPem -CAkey $caKey -CAcreateserial -extfile $domainExt -out $domainCrt
    Write-Host "Importing CA to Windows Root store..."
    Import-Certificate -FilePath $caCrt -CertStoreLocation Cert:\LocalMachine\Root | Out-Null
    Write-Host "SSL listo para $Domain"
}

function Restart-Apache {
    $httpdExe = "C:\xampp\apache\bin\httpd.exe"
    Write-Host "\nReiniciando Apache directamente (sin .bat)..."
    # Intentar matar procesos httpd.exe
    $null = Start-Process -FilePath "taskkill" -ArgumentList "/F /IM httpd.exe" -NoNewWindow -Wait -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    # Iniciar Apache en background
    if (Test-Path $httpdExe) {
        Start-Process -FilePath $httpdExe -WindowStyle Hidden
        Write-Host "Apache reiniciado."
    } else {
        Write-Warning "No se encontró httpd.exe. Reinicia Apache manualmente."
    }
}

function Write-Section {
    param([string]$Text)
    Write-Host ("\n==== $Text ====\n")
}

function Test-Admin {
    # Devuelve $true si el script corre como administrador
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal $currentIdentity
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Backup-File {
    param(
        [string]$FilePath
    )
    if (Test-Path $FilePath) {
        $backup = "$FilePath.bak-$(Get-Date -Format 'yyyyMMddHHmmss')"
        Copy-Item $FilePath $backup
        Write-Host "Backup creado: $backup"
    }
}

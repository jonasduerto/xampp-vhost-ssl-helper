@echo off
setlocal enabledelayedexpansion
set OPENSSL_BIN=C:\xampp\apache\bin\openssl.exe
set OPENSSL_CONF=C:\xampp\apache\conf\openssl.cnf
set CA_DIR=C:\xampp\apache\conf\vhost\ca
set SSL_DIR=C:\xampp\apache\conf\vhost\ssl\%1
set DOMAIN=%1

REM Exportar variable de entorno para OpenSSL
set OPENSSL_CONF=%OPENSSL_CONF%
set "OPENSSL_CONF=%OPENSSL_CONF%"

REM 1. Crear directorio SSL si no existe
if not exist "%SSL_DIR%" mkdir "%SSL_DIR%"

REM 1b. Crear directorio CA si no existe
if not exist "%CA_DIR%" mkdir "%CA_DIR%"

REM 2. Crear CA Root si no existe
if not exist "%CA_DIR%\RootCA.key" (
    echo [INFO] Generando RootCA...
    set "OPENSSL_CONF=%OPENSSL_CONF%"
    "%OPENSSL_BIN%" req -x509 -nodes -new -sha256 -days 3650 -newkey rsa:2048 ^
        -keyout "%CA_DIR%\RootCA.key" -out "%CA_DIR%\RootCA.pem" ^
        -subj "/C=US/CN=LocalDev-Root-CA" -config "%OPENSSL_CONF%"
    "%OPENSSL_BIN%" x509 -outform pem -in "%CA_DIR%\RootCA.pem" -out "%CA_DIR%\RootCA.crt"
    echo [INFO] Instalando RootCA en Windows...
    powershell -Command "Start-Process powershell -ArgumentList 'Import-Certificate -FilePath ''%CA_DIR%\RootCA.crt'' -CertStoreLocation Cert:\LocalMachine\Root' -Wait -WindowStyle Hidden" -Verb RunAs
)

REM 3. Crear archivo SAN (domains.ext) - ¡AGREGAR localhost y 127.0.0.1!
(
    echo authorityKeyIdentifier=keyid,issuer
    echo basicConstraints=CA:FALSE
    echo keyUsage = digitalSignature, nonRepudiation, keyEncipherment
    echo subjectAltName = @alt_names
    echo [alt_names]
    echo DNS.1 = %DOMAIN%
    echo DNS.2 = www.%DOMAIN%
    echo DNS.3 = localhost
    echo DNS.4 = 127.0.0.1
    echo IP.1 = 127.0.0.1
) > "%SSL_DIR%\domains.ext"

REM 4. Generar clave y CSR
set "OPENSSL_CONF=%OPENSSL_CONF%"
"%OPENSSL_BIN%" req -new -nodes -newkey rsa:2048 ^
    -keyout "%SSL_DIR%\server.key" -out "%SSL_DIR%\server.csr" ^
    -subj "/C=US/CN=%DOMAIN%" -config "%OPENSSL_CONF%"

REM 5. Firmar con la CA (¡IMPORTANTE! Usar CA, no autofirmar)
set "OPENSSL_CONF=%OPENSSL_CONF%"
"%OPENSSL_BIN%" x509 -req -sha256 -days 825 ^
    -in "%SSL_DIR%\server.csr" ^
    -CA "%CA_DIR%\RootCA.pem" -CAkey "%CA_DIR%\RootCA.key" -CAcreateserial ^
    -extfile "%SSL_DIR%\domains.ext" ^
    -out "%SSL_DIR%\server.crt"

del "%SSL_DIR%\server.csr" "%SSL_DIR%\domains.ext"
echo [OK] Certificado generado para %DOMAIN% con SANs
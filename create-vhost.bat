@echo off
setlocal enabledelayedexpansion

REM ===== Configuración inicial =====
set XAMPP_PATH=C:\xampp
set APACHE_CONF=%XAMPP_PATH%\apache\conf
set VHOST_APACHE=%APACHE_CONF%\vhost\apache
set VHOST_LOGS=%APACHE_CONF%\vhost\logs
set VHOST_SSL=%APACHE_CONF%\vhost\ssl
set OPENSSL_CONF=%APACHE_CONF%\openssl.cnf
set HTDOCS=%XAMPP_PATH%\htdocs

REM ===== Plantilla VirtualHost =====
REM Ahora se lee desde archivo externo vhost-template.txt

REM ===== Verificar privilegios de administrador =====
whoami /groups | find "S-1-5-32-544" >nul
if errorlevel 1 (
    echo.
    echo [ERROR] Debes ejecutar este script como Administrador.
    echo Intenta hacer clic derecho y seleccionar "Ejecutar como administrador".
    pause
    exit /b
)

REM ===== Interfaz de usuario principal =====
:MENU
cls
@echo off
setlocal enabledelayedexpansion

echo -----------------------------------------------
echo VIRTUAL HOST CREATOR FOR XAMPP (ADVANCED)
echo -----------------------------------------------
echo 1. Crear nuevo VirtualHost (con o sin SSL, subdominios, abrir en navegador)
echo 2. Instalar SSL en un dominio o subdominio
echo 3. Reparar/Reinstalar SSL
echo 8. Salir
echo.
set /p MENUOPT="Selecciona una opcion [1-3,8]: "
if "%MENUOPT%"=="8" exit /b
if "%MENUOPT%"=="1" goto START
if "%MENUOPT%"=="2" goto INSTALL_SSL
if "%MENUOPT%"=="3" goto REPAIR_SSL
goto MENU

REM ===== Solicitar dominio y subdominio =====
:START
set "SUBDOMINIO="
echo.
set /p DOMAIN="Dominio principal (ej: myapp.local): "
if "%DOMAIN%"=="" goto START
set /p SUBDOMINIO="Subdominio (opcional, ej: dev): "
if not "%SUBDOMINIO%"=="" (
    set DOMAIN=%SUBDOMINIO%.%DOMAIN%
)

REM ===== Validar si ya existe =====
findstr /i /c:"%DOMAIN%" "%windir%\System32\drivers\etc\hosts" >nul 2>&1
if not errorlevel 1 (
    echo.
    echo [ERROR] El dominio %DOMAIN% ya existe en el archivo hosts.
    pause
    goto MENU
)
if exist "%VHOST_APACHE%\%DOMAIN%.conf" (
    echo.
    echo [ERROR] Ya existe un archivo de configuracion para %DOMAIN%.
    pause
    goto MENU
)

REM ===== Directorio del proyecto =====
set DEFAULT_DIR=%HTDOCS%\%DOMAIN%
echo.
echo Project directory [Default: %DEFAULT_DIR%]
set /p PROJECT_DIR="Enter new path or press Enter to use default: "
if "%PROJECT_DIR%"=="" set "PROJECT_DIR=%DEFAULT_DIR%"

REM ===== Opción SSL =====
echo.
echo 1. Crear con SSL (https)
echo 2. Crear sin SSL (solo http)
set /p SSL_OPT="Selecciona [1-2, default 1]: "
if "%SSL_OPT%"=="2" (
    set GEN_SSL=N
) else (
    set GEN_SSL=Y
)

REM Instalar certificado?
if /i "%GEN_SSL%"=="Y" (
    echo.
    choice /c YN /n /m "Install certificate in Windows trust store? [Y/N] (Default Y): "
    if errorlevel 2 (set INSTALL_CERT=N) else (set INSTALL_CERT=Y)
)

REM Agregar a hosts?
echo.
choice /c YN /n /m "Add to Windows hosts file? [Y/N] (Default Y): "
if errorlevel 2 (set ADD_HOSTS=N) else (set ADD_HOSTS=Y)

REM Mostrar resumen
echo.
echo ===== CONFIGURATION SUMMARY =====
echo Domain:          %DOMAIN%
echo Project dir:     %PROJECT_DIR%
echo Generate SSL:    %GEN_SSL%
if "%GEN_SSL%"=="Y" echo Install cert:    %INSTALL_CERT%
echo Add to hosts:    %ADD_HOSTS%
echo.
choice /c YN /n /m "Proceed with this configuration? [Y/N] (Default Y): "
if errorlevel 2 goto MENU

REM ===== Crear estructura de carpetas =====
echo.
echo Creating directories...
if not exist "%VHOST_APACHE%" mkdir "%VHOST_APACHE%"
if not exist "%VHOST_LOGS%" mkdir "%VHOST_LOGS%"
if not exist "%VHOST_SSL%\%DOMAIN%" mkdir "%VHOST_SSL%\%DOMAIN%"
if not exist "%PROJECT_DIR%" (
    mkdir "%PROJECT_DIR%"
    REM Copiar index-template.html y reemplazar {{DOMAIN}}
    set INDEX_FILE=%PROJECT_DIR%\index.html
    setlocal enabledelayedexpansion
    set "INDEX_CONTENT="
    for /f "usebackq delims=" %%A in ("c:\www\xampp\index-template.html") do (
        set "LINE=%%A"
        set "LINE=!LINE:{{DOMAIN}}=%DOMAIN%!"
        set "INDEX_CONTENT=!INDEX_CONTENT!!LINE!^\n!"
    )
    (echo !INDEX_CONTENT!) > "!INDEX_FILE!"
    endlocal
)

REM ===== Limpiar certificados antiguos antes de generar nuevos SSL =====
if /i "%GEN_SSL%"=="Y" (
    echo.
    echo Limpiando certificados antiguos de localhost y CA local...
    call c:\www\xampp\vhost-clean-old-certs.bat
)
REM ===== Generar certificados SSL con CA propia =====
if /i "%GEN_SSL%"=="Y" (
    echo.
    echo Generating SSL certificate with local CA...
    call c:\www\xampp\vhost-makecert.bat %DOMAIN%
    set SSL_KEY=%VHOST_SSL%\%DOMAIN%\server.key
    set SSL_CERT=%VHOST_SSL%\%DOMAIN%\server.crt
) else (
    set SSL_KEY=%APACHE_CONF%\ssl.key\server.key
    set SSL_CERT=%APACHE_CONF%\ssl.crt\server.crt
)

REM ===== Selección de plantilla =====
echo.
echo Selecciona plantilla de VirtualHost:
echo 1. Default (genérico)
echo 2. Laravel
echo 3. WordPress
set /p TEMPLATE_OPT="Selecciona [1-3, default 1]: "
if "%TEMPLATE_OPT%"=="2" (
    set VHOST_TEMPLATE_FILE=c:\www\xampp\vhost-template-laravel.txt
) else if "%TEMPLATE_OPT%"=="3" (
    set VHOST_TEMPLATE_FILE=c:\www\xampp\vhost-template-wordpress.txt
) else (
    set VHOST_TEMPLATE_FILE=c:\www\xampp\vhost-template.txt
)

REM ===== Normalizar rutas a formato con slash =====
set "PROJECT_DIR_SLASH=%PROJECT_DIR:\=/%"
set "SSL_KEY_SLASH=%SSL_KEY:\=/%"
set "SSL_CERT_SLASH=%SSL_CERT:\=/%"
set "VHOST_LOGS_SLASH=%VHOST_LOGS:\=/%"

REM ===== Crear archivo de VirtualHost =====
echo.
echo Creating virtual host configuration...
set VHOST_FILE=%VHOST_APACHE%\%DOMAIN%.conf
setlocal enabledelayedexpansion
del "%VHOST_FILE%" >nul 2>&1
for /f "usebackq delims=" %%A in ("!VHOST_TEMPLATE_FILE!") do (
    set "LINE=%%A"
    set "LINE=!LINE:{{DOMAIN}}=%DOMAIN%!"
    set "LINE=!LINE:{{DOCROOT}}=%PROJECT_DIR_SLASH%!"
    set "LINE=!LINE:{{LOGS_DIR}}=%VHOST_LOGS_SLASH%!"
    set "LINE=!LINE:{{SSL_KEY}}=%SSL_KEY_SLASH%!"
    set "LINE=!LINE:{{SSL_CERT}}=%SSL_CERT_SLASH%!"
    if /i "%GEN_SSL%"=="N" (
        echo !LINE! | findstr /i /c:"<VirtualHost *:443>" >nul && set "LINE="
        echo !LINE! | findstr /i /c:"SSLEngine on" >nul && set "LINE="
        echo !LINE! | findstr /i /c:"SSLCertificateFile" >nul && set "LINE="
        echo !LINE! | findstr /i /c:"SSLCertificateKeyFile" >nul && set "LINE="
        echo !LINE! | findstr /i /c:"SSLCipherSuite" >nul && set "LINE="
        echo !LINE! | findstr /i /c:"SSLProtocol" >nul && set "LINE="
        echo !LINE! | findstr /i /c:"SSLHonorCipherOrder" >nul && set "LINE="
    )
    if defined LINE (
        echo !LINE!>>"%VHOST_FILE%"
    ) else (
        echo.>>"%VHOST_FILE%"
    )
)
endlocal
echo Virtual host created at:
echo %VHOST_FILE%

REM ===== Agregar a hosts file =====
if /i "%ADD_HOSTS%"=="Y" (
    echo.
    echo Adding to hosts file...
    echo 127.0.0.1    %DOMAIN% >> %windir%\System32\drivers\etc\hosts
    echo 127.0.0.1    www.%DOMAIN% >> %windir%\System32\drivers\etc\hosts
    echo Hosts file updated!
)

REM ===== Finalización =====
echo.
echo ===== SETUP COMPLETE =====
echo Domain:       http://%DOMAIN%
if "%GEN_SSL%"=="Y" echo HTTPS:       https://%DOMAIN%
echo Project dir:  %PROJECT_DIR%
echo Config file:  %VHOST_FILE%

echo.
choice /c YN /n /m "Abrir en navegador ahora? [Y/N] (Default Y): "
if errorlevel 2 goto MENU
start http://%DOMAIN%
if "%GEN_SSL%"=="Y" start https://%DOMAIN%

echo.
echo Press any key to return to menu...
pause >nul
goto MENU

:INSTALL_SSL
cls
echo === INSTALAR SSL EN UN DOMINIO O SUBDOMINIO ===
echo.
REM === Verificar y crear RootCA si no existe ===
set CA_DIR=%XAMPP_PATH%\apache\conf\vhost\ca
if not exist "%CA_DIR%\RootCA.key" (
    echo [INFO] RootCA no encontrada. Creando CA...
    call c:\www\xampp\vhost-makecert.bat dummy-domain.local
)
set /p DOMAIN="Dominio (ej: myapp.local): "
if "%DOMAIN%"=="" goto MENU
set SSL_KEY=%VHOST_SSL%\%DOMAIN%\server.key
set SSL_CERT=%VHOST_SSL%\%DOMAIN%\server.crt
if not exist "%VHOST_SSL%\%DOMAIN%" mkdir "%VHOST_SSL%\%DOMAIN%"
"%XAMPP_PATH%\apache\bin\openssl.exe" genrsa -out "%SSL_KEY%" 2048
"%XAMPP_PATH%\apache\bin\openssl.exe" req -new -key "%SSL_KEY%" -out "%VHOST_SSL%\%DOMAIN%\server.csr" -subj "/CN=%DOMAIN%/O=Local Development/C=US"
"%XAMPP_PATH%\apache\bin\openssl.exe" x509 -req -days 3650 -in "%VHOST_SSL%\%DOMAIN%\server.csr" -signkey "%SSL_KEY%" -out "%SSL_CERT%"
echo SSL certificate created at:
echo %SSL_CERT%
echo.
choice /c YN /n /m "¿Instalar certificado en Windows trust store? [Y/N] (Default Y): "
if errorlevel 2 goto MENU
powershell -Command "Start-Process powershell -ArgumentList 'Import-Certificate -FilePath ''%SSL_CERT%'' -CertStoreLocation Cert:\LocalMachine\Root' -Wait -WindowStyle Hidden" -Verb RunAs
echo Certificate installed successfully!
echo.
echo Press any key to return to menu...
pause >nul
goto MENU

:REPAIR_SSL
cls
echo === REPARAR/REINSTALAR SSL EN UN DOMINIO O SUBDOMINIO ===
echo.
REM === Verificar y crear RootCA si no existe ===
set CA_DIR=%XAMPP_PATH%\apache\conf\vhost\ca
if not exist "%CA_DIR%\RootCA.key" (
    echo [INFO] RootCA no encontrada. Creando CA...
    call c:\www\xampp\vhost-makecert.bat dummy-domain.local
)
set /p DOMAIN="Dominio (ej: myapp.local): "
if "%DOMAIN%"=="" goto MENU
set SSL_KEY=%VHOST_SSL%\%DOMAIN%\server.key
set SSL_CERT=%VHOST_SSL%\%DOMAIN%\server.crt
set VHOST_FILE=%VHOST_APACHE%\%DOMAIN%.conf
if exist "%VHOST_FILE%" (
    ren "%VHOST_FILE%" "%DOMAIN%.conf.bk"
    echo Archivo de vhost anterior renombrado a %DOMAIN%.conf.bk
)
if not exist "%VHOST_SSL%\%DOMAIN%" mkdir "%VHOST_SSL%\%DOMAIN%"
"%XAMPP_PATH%\apache\bin\openssl.exe" genrsa -out "%SSL_KEY%" 2048
"%XAMPP_PATH%\apache\bin\openssl.exe" req -new -key "%SSL_KEY%" -out "%VHOST_SSL%\%DOMAIN%\server.csr" -subj "/CN=%DOMAIN%/O=Local Development/C=US"
"%XAMPP_PATH%\apache\bin\openssl.exe" x509 -req -days 3650 -in "%VHOST_SSL%\%DOMAIN%\server.csr" -signkey "%SSL_KEY%" -out "%SSL_CERT%"
echo SSL certificate created at:
echo %SSL_CERT%
REM ===== Normalizar rutas a formato con slash =====
set "HTDOCS_SLASH=%HTDOCS:\=/%"
set "SSL_KEY_SLASH=%SSL_KEY:\=/%"
set "SSL_CERT_SLASH=%SSL_CERT:\=/%"
set "VHOST_LOGS_SLASH=%VHOST_LOGS:\=/%"

REM Generar nuevo archivo de vhost apuntando al nuevo certificado
set VHOST_TEMPLATE_FILE=c:\www\xampp\vhost-template.txt
del "%VHOST_FILE%" >nul 2>&1
setlocal enableddelayedexpansion
for /f "usebackq delims=" %%A in ("!VHOST_TEMPLATE_FILE!") do (
    set "LINE=%%A"
    set "LINE=!LINE:{{DOMAIN}}=%DOMAIN%!"
    set "LINE=!LINE:{{DOCROOT}}=%HTDOCS_SLASH%/%DOMAIN%!"
    set "LINE=!LINE:{{LOGS_DIR}}=%VHOST_LOGS_SLASH%!"
    set "LINE=!LINE:{{SSL_KEY}}=%SSL_KEY_SLASH%!"
    set "LINE=!LINE:{{SSL_CERT}}=%SSL_CERT_SLASH%!"
    if defined LINE (
        echo !LINE!>>"%VHOST_FILE%"
    ) else (
        echo.>>"%VHOST_FILE%"
    )
)
endlocal
echo Nuevo archivo de vhost generado: %VHOST_FILE%
choice /c YN /n /m "¿Instalar certificado en Windows trust store? [Y/N] (Default Y): "
if errorlevel 2 goto MENU
powershell -Command "Start-Process powershell -ArgumentList 'Import-Certificate -FilePath ''%SSL_CERT%'' -CertStoreLocation Cert:\LocalMachine\Root' -Wait -WindowStyle Hidden" -Verb RunAs
echo Certificate installed successfully!
echo.
echo Press any key to return a menu...
pause >nul
goto MENU

:CANCEL
echo Operation cancelled by user!
pause
goto MENU
@echo off
REM vhost-clean-old-certs.bat - Elimina certificados antiguos de localhost y dominios locales del almacén de Windows
REM Uso: Ejecutar como administrador

REM Eliminar certificados de localhost expirados o viejos
powershell -Command "Get-ChildItem -Path Cert:\LocalMachine\Root | Where-Object { ($_.Subject -like '*CN=localhost*' -or $_.Subject -like '*CN=127.0.0.1*' -or $_.Subject -like '*CN=*.local*') -and $_.NotAfter -lt (Get-Date).AddDays(1) } | Remove-Item -Force"

REM Eliminar certificados de RootCA antiguos generados por scripts previos (opcional, si el Subject contiene 'LocalDev-Root-CA')
powershell -Command "Get-ChildItem -Path Cert:\LocalMachine\Root | Where-Object { $_.Subject -like '*LocalDev-Root-CA*' -and $_.NotAfter -lt (Get-Date).AddYears(1) } | Remove-Item -Force"

echo.
echo Certificados antiguos de localhost y CA local eliminados del almacén de Windows (si existían).
echo.
pause

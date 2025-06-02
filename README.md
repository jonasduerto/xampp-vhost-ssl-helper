# XAMPP VirtualHost SSL Helper

Automatización 100% PowerShell para crear VirtualHosts en XAMPP con SSL local y plantillas.

## Flujo actualizado (2025)
- Ejecuta `main.ps1` como Administrador.
- Elige dominio, plantilla y DocumentRoot.
- El script genera la CA local, certificados, instala la CA en Windows, crea el vhost y actualiza el archivo hosts.
- Plantillas en `/templates` (generic, laravel, wordpress, miniphp).
- Helpers en `/inc` (ej: ssl-tools.ps1).
- **No uses los scripts batch ni los `.ps1` legacy.**

## Estructura
- `/main.ps1`: Script principal (PowerShell)
- `/inc/ssl-tools.ps1`: Funciones SSL/CA
- `/templates/*.txt`: Plantillas vhost

## Uso rápido
```powershell
cd C:\www\xampp
powershell -ExecutionPolicy Bypass -File .\main.ps1
```

## Requisitos
- XAMPP para Windows
- OpenSSL incluido en XAMPP
- Ejecutar como Administrador

## Notas
- Los certificados generados son válidos para el dominio, www, localhost y 127.0.0.1.
- El flujo es 100% PowerShell, sin batch.

## Licencia
MIT


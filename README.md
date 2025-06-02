# XAMPP VirtualHost SSL Helper

Automatiza la creación de VirtualHosts en XAMPP para Windows, incluyendo generación de certificados SSL con una CA local y su instalación en el almacén de confianza de Windows. Ideal para entornos de desarrollo local con HTTPS realista y soporte para subdominios, Laravel, WordPress y más.

## Características
- Crea VirtualHosts personalizados en XAMPP con o sin SSL.
- Genera certificados SSL válidos para dominios locales usando una CA propia.
- Instala la CA y los certificados en el almacén de confianza de Windows.
- Soporte para plantillas de VirtualHost (genérico, Laravel, WordPress).
- Limpieza automática de certificados antiguos.
- Interfaz interactiva por consola.

## Archivos principales
- `create-vhost.bat`: Script principal para crear y gestionar VirtualHosts.
- `vhost-makecert.bat`: Genera la CA local y los certificados SSL.
- `vhost-clean-old-certs.bat`: Limpia certificados antiguos del almacén de Windows.
- `vhost-template.txt`, `vhost-template-laravel.txt`, `vhost-template-wordpress.txt`: Plantillas de configuración para Apache.

## Requisitos
- XAMPP para Windows (probado en C:\xampp)
- OpenSSL incluido en XAMPP
- Ejecutar scripts como Administrador

## Instalación
1. Copia todos los archivos de este repositorio en una carpeta, por ejemplo `C:\www\xampp`.
2. Asegúrate de que la ruta de XAMPP en los scripts coincide con tu instalación (por defecto `C:\xampp`).
3. Ejecuta `create-vhost.bat` como Administrador.

## Uso rápido
1. **Crear un nuevo VirtualHost**
   - Ejecuta `create-vhost.bat` como Administrador.
   - Sigue las instrucciones para ingresar el dominio, subdominio, ruta del proyecto y opciones de SSL.
   - El script generará los certificados, configurará el VirtualHost y actualizará el archivo hosts.

2. **Instalar o reparar SSL en un dominio existente**
   - Opción 2 o 3 en el menú de `create-vhost.bat`.
   - El script verificará y creará la CA si es necesario.

3. **Limpiar certificados antiguos**
   - Ejecuta `vhost-clean-old-certs.bat` como Administrador.

## Ejemplo de uso
```sh
cd C:\www\xampp
create-vhost.bat
```

## Notas
- Siempre ejecuta los scripts como Administrador para poder modificar el almacén de certificados y el archivo hosts.
- Los certificados generados son válidos para el dominio, www, localhost y 127.0.0.1.
- Puedes personalizar las plantillas de VirtualHost según tus necesidades.

## Licencia
MIT


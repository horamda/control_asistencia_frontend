# Publicacion web en Railway

La publicacion usa una compilacion local de Flutter y un servicio Nginx separado
del backend. No se suben claves de Android ni archivos del proyecto completo.

Desde la raiz del proyecto, compilar:

```powershell
flutter build web --release --dart-define=API_BASE_URL=https://control-asistencia.up.railway.app --dart-define=APP_FLAVOR=PROD --dart-define=APP_PROD=true
```

Preparar una carpeta que contenga solamente:

- `Dockerfile`: copiar `deploy/web/Dockerfile`.
- `nginx.conf.template`: copiar el archivo de la raiz.
- `railway.toml`: copiar el archivo de la raiz.
- `web/`: copiar el contenido de `build/web/`.

Publicar esa carpeta con `railway up <carpeta> --path-as-root --no-gitignore
--project <id-proyecto> --service <id-servicio-web> --environment production`.
Los identificadores deben verificarse en Railway antes de publicar.

Generar el dominio del servicio web con puerto 8080. Verificar el login y las
respuestas CORS de la API desde ese dominio. Si el backend limita origenes,
agregar el dominio web a `CORS_ALLOWED_ORIGINS` conservando los existentes.

Verificar camara y ubicacion en Safari/iPhone y Chrome/Android con HTTPS.
La web no usa el bloqueo de actualizaciones de APK; sus archivos de codigo y
version se revalidan mediante `Cache-Control: no-cache`.

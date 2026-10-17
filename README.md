# FicharQR

Frontend Flutter separado para empleados (fichar entrada/salida, ver perfil y asistencias).

## Alcance

- Solo app de empleado.
- Backend objetivo: `../backend`.
- Contrato congelado: `../backend/docs/mobile_v1_openapi.yaml`.

## Android: tamaño y distribución

Versión actual: **1.24.0+32**. La versión de la app es independiente de la del contrato API.

Desde PowerShell, con la firma release configurada:

Los APK por arquitectura conservan `versionCode=32`, igual que el APK universal y el
AAB, para mantener una secuencia de actualizaciones coherente entre formatos.

```powershell
# APK separados para ARM64, ARM32 y x86_64:
.\scripts\build_android.ps1 -ApiBaseUrl https://tu-backend.com
# Google Play (entrega las bibliotecas adecuadas para cada dispositivo):
.\scripts\build_android.ps1 -ApiBaseUrl https://tu-backend.com -Format Bundle
# Un solo APK compatible con las tres arquitecturas, de mayor tamaño:
.\scripts\build_android.ps1 -ApiBaseUrl https://tu-backend.com -Format Universal
```

- Para instalación directa, elegir el APK de la arquitectura del dispositivo; ARM64 suele
  corresponder a los celulares recientes. ARM32 mantiene soporte para equipos anteriores.
  No subir un APK ARM64 como descarga universal para todos los empleados.
- El script compila en PROD, conserva R8 y reducción de recursos, elimina iconos no usados
  y separa símbolos Dart. Los paquetes, símbolos y `manifest.json` con SHA-256 quedan en
  `artifacts/android/<version>/<formato>/`, fuera de Git y del directorio borrado por
  `flutter clean`. Respaldar ese directorio junto con la versión distribuida.
- Flutter ya activa R8 en release: no comparar un APK debug con release como si toda
  la diferencia proviniera de cambios al código. El APK debug incluye depuración y varias ABI.
- El lector ML Kit permanece incluido para escanear sin descargar un modelo en el primer uso.
  `android/app/src/main/res/raw/keep.xml` conserva el icono referenciado desde Dart.
- El login usa `fichaya-login.png` (512 px, 312 KB) en lugar de empaquetar el original
  `logo_dp.png` (1,79 MB). El original se conserva para diseño, sin incluirlo en el bundle.
- Antes de distribuir, probar en un teléfono la actualización sobre la versión instalada,
  fichada con QR/GPS/foto, modo sin conexión y recordatorios. Compilar no publica ni cambia
  la versión mínima exigida por el backend.

Fuentes: [distribución Android de Flutter](https://docs.flutter.dev/deployment/android)
 y [análisis de tamaño](https://docs.flutter.dev/perf/app-size).

## Push, comunicados y reuniones (contratos 1.45/1.46)

- **Inicio → Comunicados** o **menú → Comunicados** abre la bandeja del empleado.
  Los mensajes se consultan en el servidor y siguen disponibles aunque se borre
  la notificación de Android, mientras RR. HH. no los elimine. Requiere conexión.
- El listado tiene contador de no leídos, páginas de 20 y acción «Marcar todos como
  leídos». Abrir el detalle registra la lectura y muestra el texto completo y la
  imagen autenticada sin recortar. No se envía el JWT a URLs de imágenes externas.
- En **Comunicados → Notificaciones → Activar notificaciones** se puede solicitar
  permiso y volver a registrar el dispositivo. **Permisos de Android** abre Ajustes.
  Tras iniciar sesión y registrar el token, Android muestra los push con la app
  cerrada; no hace falta mantener una pantalla o servicio permanente abierto.
  «Forzar detención» en Ajustes bloquea la recepción hasta volver a abrir la app.
- La bandeja almacena comunicados de RR. HH.; no es un historial universal de todos
  los push de reuniones o trámites. La recepción real requiere validación en celular.

- Android y web registran su token FCM al iniciar sesión, al regresar a la app y al
  renovarse. El cierre de sesión elimina el registro y revoca el token del dispositivo.
- `/push/config` controla la activación. Con push activo se cancelan los recordatorios
  locales de 30 minutos; con push desactivado se conserva el mecanismo local nativo.
- En web, entrar en **Mis reuniones → Activar notificaciones**: el permiso requiere
  interacción del usuario. La configuración de la página y VAPID provienen del backend.
  `web/firebase-messaging-sw.js` contiene solamente configuración pública del proyecto;
  actualizarla junto con el backend si se cambia de proyecto Firebase.
- Las notificaciones abren el detalle tras iniciar sesión/desbloquear. Las rutas
  `/reuniones/{id}` y `/comunicados/{id}` requieren el fallback a `index.html` ya incluido en Nginx.
- El resumen usa lunes a domingo (`semana=actual`); los recordatorios locales consultan
  por separado próximos siete días. Se muestran horas asistidas y superposiciones.
- Validación real de entrega pendiente de un dispositivo y una sesión de prueba:
  verificar foreground, background, app cerrada, permiso denegado, cambio de empleado
  y cierre de sesión. No enviar pruebas a empleados reales sin autorización.
- La integración no incorpora un editor de comunicados generales en el panel.

Referencia: [recepción FCM en Flutter](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages).

## Apariencia y tarjetas

- **M?s opciones ? Apariencia** permite elegir **Claro**, **Oscuro** o **Seg?n el sistema**.
  También se accede desde el bot?n de paleta en el inicio de sesi?n. La preferencia se
  guarda en el dispositivo y se conserva entre sesiones; por defecto sigue al sistema.
- Paleta tomada de `../backend/static/css/panel.css` y `panel-theme.css`: azul `#0866FF`,
  fondo claro `#F0F2F5`, fondo oscuro `#18191A`, tarjetas oscuras `#242526` y acento
  oscuro `#4599FF`. Los estados y las series de gr?ficos conservan su significado.
- `buildAppTheme`, `AppPalette` y `AppColors` centralizan superficies, texto y contraste.
  `AppCard` centra el texto heredado; las tarjetas de indicadores usan alineaci?n centrada
  expl?cita y altura adaptable. Los códigos QR mantienen su contraste para lectura.
- Pruebas: `theme_preferences_test.dart`, `appearance_cards_test.dart`,
  `project_responsive_test.dart` y `reuniones_responsive_test.dart`. Incluyen ambos temas,
  persistencia, seguimiento del sistema, celulares/tablets y texto ampliado hasta 200 %.

## Reuniones (contrato 1.40.1)

- Acceso desde el inicio y desde **Más opciones → Mis reuniones**. Incluye próximas fechas,
  definiciones, detalle, historial paginado con filtros y estadísticas por período.
- El escáner distingue `fichaya://reunion?` antes de ejecutar los controles de fichada.
  Envía el QR completo a `/reuniones/registrar`, sin exigir GPS ni foto y sin usar la cola offline.
  El resto de los QR conserva el circuito de fichadas con GPS, foto y cola offline.
- Sede, horarios, cancelaciones y reprogramaciones se muestran según el servidor; las horas
  visibles corresponden a Argentina. No se calcula un calendario de feriados en el cliente.
- En Android/iOS, **Activar recordatorios 30 min antes** solicita permiso de notificaciones.
  Se actualizan al iniciar, volver a primer plano, refrescar y registrar asistencia.
  Android usa alarmas inexactas compatibles con ahorro de batería; iOS programa hasta las
  próximas 60 notificaciones. Con push activo, el servidor envia los recordatorios y se evita duplicarlos localmente.
- Los avisos se identifican por empleado, reunión y fecha. Cambiar de cuenta o cerrar sesión
  elimina los de la cuenta anterior; una consulta fallida al backend no borra los avisos vigentes.
- Agenda destacada e indicadores de participación, con tarjetas de altura natural en una
  columna para celulares y dos para tablets. Filtros desplazables, ancho máximo de 1120 px
  y botón de escaneo compacto en horizontal o con texto ampliado. La matriz de pruebas incluye
  320×568, 390×844, 740×360, 800×1100 y 1024×768, con escalas de texto de hasta 200 %.
- Pruebas específicas: `flutter test test/reuniones_test.dart test/reunion_reminders_test.dart
  test/qr_clock_submission_service_test.dart`. Antes de distribuir, verificar cámara real,
  permisos de notificación, reinicio del dispositivo, sede incorrecta y QR dinámico vencido
  con una cuenta de ensayo. La compilación iOS requiere macOS/Xcode.

## Validación de carga (contrato 1.30.1)

Contrato compartido para Flutter nativo, Flutter web y otros frontends web de empleados:
[guía de integración](../backend/docs/validacion_carga_frontend.md) y
[OpenAPI](../backend/docs/mobile_v1_openapi.yaml).

- Consultar `/api/v1/mobile/cargas/config` para mostrar el módulo y sus horarios.
- Cliente existente: `lib/src/core/network/mobile_api_client.dart` (`getCargas`, `createCarga`, `getCargaFoto`).
- Pantalla de referencia: `lib/src/presentation/attendance/cargas_page.dart`.
- Mantener UUID y fotos al reintentar; fotos por multipart con campos `fotos` repetidos, usando bytes también en web.
- La guía incluye las respuestas reales, tipos `0/1` frente a booleanos, permisos, paginación y errores. No requiere cambios de versión de la aplicación: 1.30.1 es la versión documental del contrato.

## Verificar antes de publicar

La configuración de VS Code **backend local** utiliza `http://localhost:5000`.
Las configuraciones **Railway · datos reales** utilizan producción; no son un entorno de pruebas.
Para Android emulado, usar `http://10.0.2.2:5000`.

El workflow `.github/workflows/validate.yml` ejecuta análisis, pruebas y compilación web
con Flutter 3.47.5. Su URL `https://staging.invalid` es deliberadamente ficticia:
esa compilación verifica el código y no debe distribuirse a empleados.

Antes de distribuir una versión:

1. Ejecutar `flutter analyze`, `flutter test` y compilar con la URL y el `APP_FLAVOR` del destino.
2. En `../backend`, ejecutar la suite con MariaDB aislada y generar JUnit:
   `python -m pytest tests -q --junitxml=test-results.xml`.
   Se requieren `SH_TEST_DB_PORT`, `SH_TEST_DB_PASSWORD`, `CARGA_TEST_DB_PORT` y
   `CARGA_TEST_DB_PASSWORD` del servidor local aislado. Nunca usar la base de producción.
3. Ejecutar `python scripts/check_release_tests.py test-results.xml` desde el backend.
   Rechaza pruebas fallidas y la omisión de EPP, reintegros, cierre mensual, seguridad del
   empleado y carga. El workflow del backend también aplica este control.
4. Publicar primero el backend que satisface el contrato de la app. Después del despliegue,
   ejecutar `python scripts/check_deployed_revision.py --url URL_BACKEND --expected-revision SHA_COMPLETO`.
   Railway proporciona `RAILWAY_GIT_COMMIT_SHA`; otros entornos pueden usar `BUILD_REVISION`.
5. Probar con cuentas de ensayo de empleado y aprobador: guardar talle → nuevo pedido →
   aprobación → entrega; borrador de rendición → envío → aprobación/rechazo → consulta del estado;
   sucursal e indicador de seguridad; sesión vencida y reintento tras pérdida de conexión.

Los workflows validan cambios cuando se suben al repositorio. No publican automáticamente
ni modifican la configuración de Railway. La espera de CI y la protección de ramas deben
configurarse en esos servicios para impedir un despliegue con verificaciones pendientes.

`/healthz` mide disponibilidad e identifica la revisión; no prueba la base de datos ni el
rendimiento de las consultas autenticadas. Medir estas últimas con una sesión de ensayo,
registrando latencia total y el encabezado `Server-Timing` para distinguir red y servidor.

## Run local

Desde `frontend_flutter`:

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000 --dart-define=APP_FLAVOR=DEV
```

Configuracion de sesion (opcionales):
- `SESSION_IDLE_TIMEOUT_MINUTES` (tiempo de inactividad antes de bloquear)
- `SESSION_MAX_AGE_HOURS` (vida maxima de sesion antes de forzar login)
- `SESSION_PROACTIVE_REFRESH_MINUTES` (intervalo de refresh proactivo)

Defaults por ambiente:
- `PROD`: idle `20m`, max age `10h`, refresh `8m`
- `STAGE`: idle `25m`, max age `10h`, refresh `8m`
- `DEV` (u otros): idle `30m`, max age `12h`, refresh `10m`

Ejemplo:
```bash
flutter run \
  --dart-define=APP_FLAVOR=STAGE \
  --dart-define=SESSION_IDLE_TIMEOUT_MINUTES=20 \
  --dart-define=SESSION_MAX_AGE_HOURS=8 \
  --dart-define=SESSION_PROACTIVE_REFRESH_MINUTES=6
```

Notas:
- En Android emulator usar `10.0.2.2` para host local.
- En iOS simulator usar `http://localhost:5000`.
- En dispositivo fisico usar IP LAN del backend.

## Android release signing

La app ya no usa la debug key para `release`. Para generar APK o AAB distribuibles, configura una firma real con una de estas dos opciones:

- Archivo local `android/key.properties`.
- Variables de entorno para CI.

Archivo recomendado:

```properties
storeFile=upload-keystore.jks
storePassword=tu_store_password
keyAlias=upload
keyPassword=tu_key_password
```

Referencia rapida:

- Guarda el keystore dentro de `android/` o usa una ruta absoluta en `storeFile`.
- `android/key.properties` esta ignorado por git.
- Si defines solo parte de la configuracion, Gradle falla al inicio para evitar builds ambiguos.

Variables equivalentes para CI:

```bash
ANDROID_KEYSTORE_PATH=/ruta/al/upload-keystore.jks
ANDROID_KEYSTORE_PASSWORD=tu_store_password
ANDROID_KEY_ALIAS=upload
ANDROID_KEY_PASSWORD=tu_key_password
```

Build release:

```bash
flutter build apk --release
flutter build appbundle --release
```

## Estructura inicial

- `lib/main.dart`: bootstrap
- `lib/src/app.dart`: MaterialApp y tema base
- `lib/src/config/app_config.dart`: lectura de `dart-define`
- `lib/src/presentation/splash/splash_page.dart`: pantalla inicial con config activa

## Proximo bloque tecnico

1. DTOs Dart (`lib/src/features/*/data/dto`)
2. Cliente HTTP (`/api/v1/mobile`)
3. Login + session JWT
4. Fichadas entrada/salida

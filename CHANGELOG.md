# Changelog — FichaYa

Registro de cambios version a version.  
Formato: `[version+build] — fecha`

---

## [1.20.5+26] — 2026-05-25

### Correcciones de login
- **Login colgado en Android**: `PackageInfo.fromPlatform()` no tenia timeout y colgaba indefinidamente en algunos dispositivos. Se agrego timeout de 2s en `device_telemetry.dart` y `app_version_service.dart`.
- **AppVersionGate**: agregado timeout de 10s al chequeo de version. Si el backend no responde, la app continua normalmente en vez de mostrar spinner infinito.
- **Dialogo de actualizacion forzada bloqueante**: cuando `url_descarga` era `null` el boton no hacia nada y el dialogo no se podia cerrar (`barrierDismissible: false` + `canPop: false`). Ahora muestra "Entendido" y cierra correctamente.

### Cambios de UI / UX
- **Banner DEV/PROD**: en builds de produccion (`APP_PROD=true`) el banner de entorno no se muestra. En DEV sigue apareciendo en naranja.
- **"Mis Links"**: accion rapida habilitada condicionalmente segun `historyEnabled` en vez de siempre activa.
- **Error de perfil**: solo se muestra si el error es 401/403 o si el perfil ya habia cargado previamente (evita mostrar error en el primer intento fallido).

### Eficiencia de bateria
- Timers pausados cuando la app pasa a background (`AppLifecycleState.paused`) y reanudados al volver a foreground (`resumed`).
- `_clockReadinessRefreshInterval`: 75s → 3 min.
- `_gpsCacheTtl`: 2 min → 5 min.
- Timer de sync de pendientes: 45s → 2 min.

### Build
- Version: `1.20.5+26`
- Comando: `flutter build apk --release --dart-define=API_BASE_URL=... --dart-define=APP_PROD=true --build-name=1.20.5 --build-number=26`

---

## [1.20.5+25] — 2026-05-25

### Cambios iniciales de sesion
- Commit `5cc2b82`: logging, mejoras de UX, correcciones de flujo QR y suite de tests.
- Agregado `AppVersionGate` para chequeo de version al iniciar la app.
- Agregado `mobile_sesiones` para registro de logins desde la app movil.
- Agregada tabla `app_version_config` en el backend para control de actualizaciones forzadas/recomendadas.

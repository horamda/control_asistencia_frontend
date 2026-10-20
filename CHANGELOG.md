# Changelog — FichaYa

Registro de cambios version a version.  
Formato: `[version+build] — fecha`

---

## Mejoras de interfaz — 2026-10-18 (sin publicar)

- Base visual compartida: títulos de sección compactos, texto de lectura uniforme,
  esquinas consistentes y escalado de texto del sistema conservado.
- Inicio con identidad compacta, estados suaves y accesos alfabéticos.
- Notificaciones en filas con fecha, resumen, indicador sin leer y acceso a permisos.
- Menú desplazable por grupos; perfil con acciones de foto visibles.
- Reuniones con indicadores compactos, pestañas adaptables y un único acceso mensual.
- Mercadería: descripción y código alineados junto al icono del artículo.
- Mercadería: Bultos y Unidades lado a lado en contadores compactos con borde (se apilan solo si no entran).
- EPP: foto lateral en catálogo, envío y borrador al pie, validaciones visibles arriba.
- EPP, Mis talles: miniatura de 56 px (antes un bloque de 160 de alto), datos a la izquierda, talle como
  etiqueta junto a la orientación anual y "Configurar talle" compacto a la derecha.
- Viáticos: total orientativo y acciones al pie; barra desplazable en pantallas cortas.
- Listas de vacaciones, francos, legajo, justificaciones e historial con lectura alineada.
- Validación local: 789 pruebas Flutter aprobadas y análisis estático sin problemas;
  incluye ambos temas, texto ampliado, orientación horizontal, tablets y teclado.
- No modifica reglas de fichada ni autorizaciones del servidor. La revisión física
  en el Motorola y las operaciones contra producción quedan pendientes.

## [1.24.0+32] — 2026-10-16

- Bandeja de comunicados con historial del servidor, contador de no leídos,
  paginación, detalle con imagen completa y marcado de lectura.
- Apertura de comunicados desde push Android/web, incluso al iniciar la app.
- Acceso a permisos de notificación desde Comunicados; el historial no depende del push.
- Mejoras de contraste oscuro, proporciones de tarjetas y ranking adaptable.
- Icono adaptable Android con fondo azul, sin marco blanco de compatibilidad.

## [1.23.0+31] — 2026-10-16

- Push Android/web: registro, renovación y baja del token; avisos en primer plano y
  apertura de reuniones desde notificaciones. Configuración controlada por backend.
- Se evita duplicar recordatorios locales cuando push está activo.
- Semana actual con totales del servidor, horas asistidas y avisos de superposición.
- Acceso a Cámara y permisos y nombre visible Huella y sonido.
- Tarjeta de bienvenida con foto lateral y datos al lado, adaptable a texto ampliado.
- Ajustes de temas, botones y pantallas de permisos, perfil y pendientes para móviles y tablets.
- Corrección del arranque y de la navegación inicial desde enlaces de reuniones.

## [1.22.0+30] — 2026-10-15

- Reuniones: agenda, historial, estadísticas, registro por QR y recordatorios locales.
- Apariencia clara, oscura o según el sistema; paleta alineada al panel web.
- Tarjetas con datos centrados y adaptación a celulares, tablets y texto ampliado.
- Distribución Android: script release con APK por arquitectura, símbolos separados,
  manifiesto de tamaños y SHA-256. También admite AAB y APK universal.
- Logo de login empaquetado a 512 px usando el recurso existente optimizado; se conserva
  el original de diseño. Se protege el icono de notificaciones ante la reducción de recursos.
- Se mantiene el lector QR integrado para disponibilidad sin descarga inicial.

---

## [1.20.5+27] — 2026-05-29

### Build
- Version: `1.20.5+27`
- Comando: `flutter build apk --release --dart-define=API_BASE_URL=... --dart-define=APP_PROD=true --build-name=1.20.5 --build-number=27`

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

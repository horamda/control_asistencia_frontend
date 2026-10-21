# Reconocimiento facial: auditoría y decisión de implementación

Fecha: 20/10/2026. Estado: diseño previo a implementación; función no habilitada.

## Decisión acordada

Evaluar proveedor y mantener la función desactivada hasta validarlo. No se
modificó el comportamiento de QR, GPS, fotos ni fichadas offline. No se
recopilaron rostros, contrataron servicios ni ejecutaron migraciones.

El documento solicitado termina truncado en la regla «8. No». No se infiere
el contenido faltante.

## Alcance y límites de la auditoría

Revisión estática de Flutter y del backend Flask ubicado en `../backend`,
sus repositorios, migraciones y documentación. Posteriormente se consultó
el esquema de la base configurada por el backend, usando transacciones
READ ONLY y sin arrancar Flask ni ejecutar bootstrap. Esto verifica esa
conexión; no certifica por sí solo que todos los servicios Railway usen
esa misma base o versión de código. No se ejecutaron pruebas biométricas.

## Inventario reutilizable

| Área | Evidencia | Decisión |
|---|---|---|
| Flujo QR | `lib/src/core/attendance/qr_clock_preflight_service.dart`, `qr_clock_submission_service.dart` | Extender sólo después de resolver política en servidor; conservar recorrido actual cuando esté desactivada. |
| GPS y permisos | Servicios de attendance, geolocator, permission_handler | Reutilizar permisos y manejo de errores. No pedir permisos de cámara adicionales al iniciar la app. |
| Fotos | image_picker, ClockPhotoCache | La foto de fichada y la foto de perfil no son enrolamientos biométricos. No reutilizarlas automáticamente como identidad de referencia. |
| Biometría del dispositivo | `lib/src/core/auth/biometric_auth_service.dart`, local_auth | Autoriza biometría registrada en el teléfono; no compara contra la identidad laboral del empleado. |
| Configuración móvil | AttendanceConfig en `lib/src/core/network/mobile_api_client.dart` y caché de asistencia | Agregar contrato versionado y política efectiva; el modelo actual sólo interpreta QR/foto/GPS, tolerancias y métodos. |
| Offline | `offline_clock_queue.dart`, `pending_clock_sync_service.dart` | Conservar cola por empleado. Su UUID local debe convertirse en identificador de operación persistente enviado al servidor antes de agregar biometría. |
| Empresa | Backend `repositories/configuracion_empresa_repository.py`, `web/configuracion/configuracion_empresa_routes.py`, formulario existente | Extender configuración existente; no crear otro panel. Actualmente edición restringida a admin. |
| Sucursal y empleado | Formularios y repositorios existentes del backend | Incorporar excepciones heredadas y su origen visible, respetando empresa y autorización. |
| Permisos y auditoría | `services/web_permissions_service.py`, `repositories/auditoria_repository.py` | Reutilizar sistema. Definir acciones de enrolar, suspender, revocar y aprobar contingencia. La auditoría existente registra actor/acción/tabla/id; falta detalle específico sanitizado. |
| Cifrado | cryptography ya declarada en backend | Biblioteca disponible no equivale a protección implementada: falta gestión externa de claves, rotación y borrado. |

Flutter observado: 3.47.5 / Dart 3.13.4; app 1.24.0+32.
No se observaron dependencias camera, google_mlkit_face_detection ni
tflite_flutter en pubspec. No añadirlas hasta decidir la integración:
el SDK del proveedor podría resolver la captura.

## Hallazgos y riesgos concretos

1. **La etiqueta `facial` no prueba una identidad.** El backend la incluye en
   métodos habilitados y la acepta en rutas de fichadas, pero no se encontró
   un motor de comparación ni PAD. No mostrar registros históricos de ese
   método como «identidad verificada».
2. **La autorización debe ser del servidor.** No aceptar un booleano del
   cliente ni un resultado de detección como prueba. El servidor debe obtener
   el resultado del proveedor y vincularlo con empleado, empresa, sesión,
   operación y política vigente.
3. **Falta una transacción común para el nuevo flujo.** La ruta scan actual
   actualiza resumen y crea marca mediante operaciones separadas. Consumir
   desafío, registrar resultado y fichada exige atomicidad o un protocolo
   durable equivalente. Cooldown no reemplaza idempotencia.
4. **Hay que resolver reintentos ambiguos.** Si el servidor guarda una marca
   y se pierde la respuesta, el mismo operation_id debe devolver el resultado
   original; nunca alternar ingreso/egreso ni consumir dos desafíos.
5. **Offline no equivale a prueba de vida diferida.** La cola actual conserva
   fecha, QR, ubicación y foto. No almacenar videos, embeddings ni credenciales
   del proveedor ahí. Definir contingencia supervisada para un futuro modo
   obligatorio sin conexión, conservando el evento pendiente sin declararlo
   verificado ni descartarlo.
6. **GPS tiene semántica existente que debe preservarse.** El scan puede
   registrar fuera del radio y generar alerta de fraude. La implementación
   facial no debe convertir ese comportamiento en otro bloqueo incidental.
7. **La sesión necesita vínculo explícito.** El generador JWT examinado
   agrega expiración pero no introduce por sí mismo un identificador de
   sesión. Diseñar vínculo revocable sin almacenar el bearer en auditoría.
8. **Falta protección completa del ciclo de vida biométrico:** enrolamiento
   autorizado, revocación, retención, eliminación, recuperación ante cambio
   de apariencia y procedimiento para falsos rechazos.

## Política propuesta, aún no implementada

Orden: empleado → sucursal → empresa → valor predeterminado desactivado.
Una excepción ausente hereda; «desactivado» explícito no significa heredar.
Resolver campos de forma definida y devolver origen y versión.

Separar política solicitada de capacidad habilitada. Un interruptor global
desactivado prevalece sobre cualquier excepción. No degradar silenciosamente
«obligatorio» a «prueba»: rechazar una activación inválida y explicar el motivo.
Excepciones no pueden relajar aislamiento entre empresas, verificación del
servidor, protección de claves ni requisitos de privacidad/PAD.

Modos:
- Desactivado: recorrido QR/GPS actual, sin llamadas biométricas.
- Prueba: opt-in autorizado; fallas biométricas nunca bloquean la fichada.
- Obligatorio: sólo tras aprobación técnica/legal y piloto.
- Por riesgo: reglas deterministas, versionadas y auditables; no inventar
  un puntaje opaco ni habilitarlo antes del piloto.

## Contrato y persistencia a diseñar

Extender `/api/v1/mobile/me/config-asistencia` con un objeto facial aditivo
y versionado. Los clientes antiguos deben seguir funcionando con la
función desactivada. Antes de obligatoriedad, definir actualización mínima
y contingencia; no permitir que un cliente antiguo evada la política.

Reutilizar `/me/fichadas/scan` para la marca final, añadiendo operation_id y
referencia opaca de autorización. Desafíos y enrolamiento requieren recursos
propios porque no existen equivalentes; no duplicar el endpoint de fichada.

Antes del DDL, contrastar el esquema real mediante inspección de sólo lectura.
Extender configuraciones existentes para políticas y excepciones. Crear
persistencia nueva únicamente para entidades que no existen: enrolamiento
versionado, desafío de un solo uso y resultado de verificación. Vincular
resultado con asistencia_marcas y auditoría existente, no otra asistencia.

Registrar estados pending/in_progress/active/suspended/revoked/update_required.
Guardar proveedor y versión de modelo, identificador opaco o plantilla cifrada
según solución elegida, versión de clave, fechas y actor autorizado. Nunca
guardar embeddings en logs. Definir si el proveedor conserva referencias:
su retención y borrado también forman parte del sistema.

Un desafío debe expirar, tener nonce impredecible, límites de intentos y
vínculo con operación. Revalidar política al consumirlo. Cambios de empleado,
sesión, empresa, operación o enrolamiento deben invalidarlo. Revisar todas
las rutas alternativas de fichada para evitar eludir el control.

## Evaluación preliminar de proveedores

Esta tabla compara encaje documental, no certifica seguridad ni costo.

| Candidato | Evidencia disponible | Pendiente antes de elegir |
|---|---|---|
| AWS Rekognition Face Liveness + comparación 1:1 | Documentación separa presencia real y comparación de rostros. | Prototipo Flutter Android/web, vínculo de captura y comparación, región y transferencia, retención, costo por volumen/reintento, evidencia PAD aplicable. CompareFaces utiliza imágenes: no satisface por sí solo un diseño basado exclusivamente en plantillas cifradas. |
| Facephi | Proveedor publica capacidades de biometría y evidencia de evaluación PAD. | Solicitar SDK/versiones Flutter y web, condiciones de licencia, informe independiente del producto exacto, almacenamiento, exportación/borrado, ubicación de tratamiento y cotización. No extrapolar certificación comercial a cualquier versión. |
| Motor propio con detector + modelo | Permite mayor control, pero exige validar modelos y operación completa. | Licencias de código y pesos, PAD independiente, métricas por dispositivos/población, mantenimiento y protección frente a inyección. No recomendado como primera implementación obligatoria. |

Recomendación provisional: evaluar primero un proveedor gestionado con
resultado verificable por backend. No elegir sólo por una demo que reconoce
una selfie. Solicitar a ambos la misma evidencia y probar antes de contratar.
No se contactó a proveedores ni se enviaron datos de empleados.

ML Kit sólo detecta caras; no reconoce personas. TFLite es un runtime,
no un proveedor de identidad o de PAD. Parpadear o girar la cabeza por sí
solos no constituye la validación de seguridad requerida.

## Plan y criterios de salida

| Fase | Entregable | Verificación para avanzar |
|---|---|---|
| A | Este diagnóstico y evaluación preliminar | Contrastar esquema desplegado y completar selección técnica. |
| B | Configuración integrada, resolución de herencia, contrato y bloqueo global | Pruebas de precedencia, aislamiento, defaults, clientes antiguos y activación rechazada sin proveedor validado. |
| C | Enrolamiento y ciclo de vida | Identidad autorizada, claves externas, revocación/borrado y restauración probados. |
| D | Captura accesible integrada en Flutter | Android real, cancelación, permisos denegados, lifecycle y plataforma no soportada. |
| E | Autorización servidor + fichada idempotente | Replay, expiración, concurrencia, pérdida de respuesta, cambio de política, rutas alternativas y offline. |
| F | Auditoría e indicadores sin biometría cruda | Trazabilidad, permisos, retención y exportaciones sanitizadas. |
| G | Piloto voluntario no bloqueante | Falsas aceptaciones/rechazos, ataques, latencia, iluminación, apariencia y cámaras reales. |
| H | Activación progresiva | Aprobación legal/técnica, soporte, contingencia y rollback ensayado. |

Pruebas de regresión obligatorias: facial desactivado no cambia payload
ni resultado actual de QR/GPS; cola existente sigue sincronizando; modo
prueba no bloquea; ausencia de proveedor no habilita captura/obligatoriedad.
Los resultados históricos de tests de UI no validan esta funcionalidad.

## Privacidad y operación

Revisión legal argentina previa a captura piloto: finalidad, base aplicable
en contexto laboral, información al empleado, alternativa/contingencia,
retención, derechos, encargados y transferencias internacionales. No asumir
que un checkbox de consentimiento resuelve la relación laboral.

Para Railway: verificar custodia externa de claves, acceso mínimo, backups,
rotación y eliminación; no poner claves en Flutter, repositorio o migración.
No se desplegó ninguna modificación ni se inspeccionaron secretos.

## Fuentes técnicas consultadas

- ML Kit y alcance de detección: https://developers.google.com/ml-kit/vision/face-detection
- AWS Face Liveness: https://docs.aws.amazon.com/rekognition/latest/dg/face-liveness.html
- AWS CompareFaces: https://docs.aws.amazon.com/rekognition/latest/APIReference/API_CompareFaces.html
- Facephi, declaraciones del proveedor: https://facephi.com/en/trust-center/
- AAIP, derechos: https://www.argentina.gob.ar/aaip/datospersonales/derechos

## Estado real al cerrar esta auditoría

Sólo documentación nueva. No hay reconocimiento facial implementado ni
proveedor seleccionado/validado. La configuración, contratos, migraciones,
integración y piloto de las fases B–H siguen pendientes. El modo facial
permanece sin habilitar y la fichada existente no se modificó.

## Ampliación del punto 1: comprobaciones del 20/10/2026

### Android

`android/app/build.gradle.kts` hereda los SDK del Flutter instalado.
Se verificaron los valores en
`C:/src/flutter/packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt`:
minSdk 24, compileSdk 36, targetSdk 36. Gradle declara AGP 8.11.1,
Kotlin 2.2.20, Java 11 y NDK 28.2.13676358. Son valores del entorno
revisado; antes de incorporar un SDK biométrico deberá verificarse su
compatibilidad y el manifiesto del APK resultante.

### Esquema consultado, sin cambios

Se utilizó mysql.connector con la configuración existente, sin imprimir
credenciales. Consultas a information_schema.COLUMNS,
KEY_COLUMN_USAGE y TABLES; lectura de app_schema_versions y un único
conteo agregado de ocupación del campo heredado.

- IDs de empresas, sucursales, empleados, usuarios y asistencias: INT.
- asistencia_marcas.id: BIGINT UNSIGNED.
- configuracion_empresa.empresa_id: clave primaria y FK a empresas.
- empleados.empresa_id y sucursal_id: FK individuales a sus tablas.
- sucursales.empresa_id: FK a empresas.
- No se observaron FK en asistencia_marcas en la consulta realizada.
  No agregar restricciones retroactivas sin comprobar integridad existente.
- Las FK individuales no prueban que sucursal y empleado pertenezcan a
  la misma empresa: la nueva política debe validar esa relación.
- empleados.rostro_hash: VARCHAR(255), nullable, sin valores no vacíos
  según conteo agregado. No se encontraron referencias en Python, SQL
  o plantillas HTML del backend. Es un campo heredado, no un sistema
  de enrolamiento; no borrarlo ni rellenarlo automáticamente.
- No aparecieron tablas cuyo nombre contenga facial, biometr o enroll.
  Esta búsqueda por nombre se complementa con la revisión de código;
  no demuestra por sí sola ausencia de cualquier integración externa.
- app_schema_versions registra 27 versiones, incluyendo gps_calidad,
  jornada_calculo, horas_extras y banco_horas del 19/10/2026.
- asistencia_marcas incluye gps_precision_m, gps_simulada y gps_edad_s.
  Preservar estos campos y el contrato actual al extender la fichada.

### Rutas y transacciones

Las rutas móviles scan, entrada y salida necesitan el mismo control
servidor cuando llegue la activación. Las correcciones manuales del panel
de asistencia son un flujo administrativo distinto: mantener permisos y
auditoría, sin etiquetarlas como verificación facial.

El repositorio de marcas ya admite `_db` para reutilizar conexión. Es una
capacidad reutilizable, pero scan no la pasa en el flujo examinado:
no equivale a disponer hoy de una transacción de desafío + resumen + marca.

### Ajustes al plan tras los nuevos documentos

1. Captura y enrolamiento exclusivamente en Android; el panel web administra.
2. Política obligatoria futura debe controlar clientes antiguos y fichadas
   web desde el servidor. No confiar en un encabezado de plataforma.
3. Diseñar contrato y autorización antes de enrolar; no instalar TFLite o
   ML Kit si el proveedor elegido aporta su propio SDK.
4. Separar desactivación por incidente de autorización de contingencia.
5. Despliegue y rollback inicialmente aditivos: desactivar funcionalidad
   no implica borrar tablas ni perder auditoría.
6. Modo prueba requiere preparación de privacidad, captura y protección
   aunque sus errores no bloqueen asistencia.

El siguiente punto es implementar la base de configuración con activación
bloqueada: resolución pura de políticas con pruebas, persistencia aditiva
revisada, integración con formularios existentes y contrato móvil.
No es necesario elegir el motor para probar herencia y defaults, pero no
debe habilitarse captura ni obligatoriedad antes de validar el proveedor.

Validación ejecutada: ambas consultas de esquema finalizaron correctamente;
transacciones cerradas con rollback. No se ejecutaron migraciones, bootstrap,
tests de fichada ni compilaciones, ya que esta etapa sólo amplió la auditoría.

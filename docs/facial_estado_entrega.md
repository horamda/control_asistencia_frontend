# Estado de entrega del módulo facial

20/10/2026. Esta entrega prepara configuración; no implementa verificación
facial real y no habilita un piloto biométrico.

## Implementado en código

- Auditoría de Flutter/backend y consulta de esquema en sólo lectura.
- Resolución de borradores por empleado, sucursal y empresa.
- Parámetros: modo, entrada/salida, intentos y tiempo máximo.
- Formularios administrativos existentes con campos compartidos.
- Permisos, validación de alcance, revisión concurrente y auditoría
  transaccional del borrador.
- Vista del modo y parámetros heredados en sucursal/empleado.
- Objeto facial_policy aditivo en configuración de asistencia.
- Modelo Flutter y cache compatibles con datos anteriores.
- Bloqueo de activación en servidor y cliente de preparación.

## Pendiente antes de considerar terminada la configuración

- Ejecutar migraciones en una base de pruebas y probar transacciones reales.
- Verificación visual del panel en móvil/tablet y prueba funcional autenticada.
- Revisar y aplicar despliegue cuando corresponda; no ejecutado aquí.

## Pendiente para el módulo completo solicitado

| Condiciones del documento | Estado real |
|---|---|
| 17.1 Compatibilidad | Regresiones automatizadas; sin validación completa de despliegue/dispositivos. |
| 17.2 Configuración | Borradores implementados. Activación, reglas de riesgo, contingencias, notificaciones y operación real pendientes. |
| 17.3 Flutter Android | Sólo lectura de configuración. Cámara, calidad, PAD y verificación pendientes. |
| 17.4 Enrolamiento | Pendiente completo: identidad inicial, plantillas, claves, revocación y retención. |
| 17.5 Fichadas | No se alteraron rutas de registro; desafíos, idempotencia y contingencias faciales pendientes. |
| 17.6 Seguridad/privacidad | Controles del borrador implementados. Evaluación biométrica, gestión de claves y revisión legal pendientes. |
| 17.7 Panel/auditoría | Configuración y auditoría de cambios. Historial de verificaciones y estadísticas pendientes. |
| 17.8 Rendimiento/confiabilidad | Sin mediciones biométricas ni piloto; no afirmar seguridad o precisión. |

No se seleccionó ni validó proveedor. AWS y Facephi son candidatos de
evaluación, no integraciones hechas. Se requiere comprobar SDK/licencia,
PAD de la versión exacta, tratamiento de datos y desempeño en dispositivos.
No se enviaron datos de empleados a proveedores ni se contrataron servicios.

No se incorporó un reconocimiento simulado para aparentar completar las
etapas restantes. No hay embeddings, imágenes biométricas o claves nuevas.

## Próxima dependencia

Obtener un entorno de evaluación del proveedor elegido y su documentación
técnica/contractual. Después: enrolamiento protegido, desafíos y autorización
servidor, captura Android, regresión, piloto no bloqueante y revisión de
producción. El código actual debe continuar desactivado hasta entonces.

## Evidencia de cierre

- Flutter: suite completa, **797 passed**. Análisis estático: sin problemas.
- Backend: selección de suites facial, mobile_v1_api, configuración, empleados,
  permisos y sucursal_geo: **217 passed, 2 skipped, 1 failed**.
- El fallo estaba en el texto esperado de la prueba del mapa de sucursal.
  Se observó que esos archivos se modificaron concurrentemente durante la
  ejecución; no se editaron para resolver ese fallo.
- Reejecución de sucursal_geo y renderizado facial sobre el estado actual:
  **5 passed, 2 skipped**. El fallo no se reprodujo. Las omitidas siguen
  pendientes; no sumar ejecuciones como si fueran casos únicos.
- Tests nuevos comprueban renderizado Jinja, CSRF presente, permisos,
  concurrencia, rollback y herencia. No sustituyen pruebas visuales ni
  transacciones reales en una base migrada.

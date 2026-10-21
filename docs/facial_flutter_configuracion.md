# Configuración facial en Flutter — preparación

20/10/2026.

## Incorporado

AttendanceConfig interpreta el nuevo objeto facial_policy mediante
FacialPolicyConfig. Conserva modo solicitado, origen, versión de esquema,
estado y motivo de bloqueo, parámetros de entrada/salida, límites propuestos
y revisiones por alcance. Es información de preparación, no autorización
para fichar. Los parámetros no se usan para ejecutar captura.

Se reutiliza AttendanceConfigCache y su almacenamiento seguro existente.
No se crea otra cola, otro servicio de fichada ni persistencia biométrica.
Los datos antiguos sin facial_policy siguen siendo válidos.

En esta versión el modo efectivo local siempre es disabled y captureEnabled
y activationAvailable siempre false. Si el servidor intenta indicar una
activación, el modelo informa unsupported. No se implementó una pantalla
para ese estado ni obligatoriedad. Antes de habilitar el backend será
necesaria una versión de app con el flujo completo y control servidor de
clientes antiguos; este bloqueo local no es una medida antievasión.

No se consulta requestedMode desde QR, GPS o la sincronización. La presencia
de un borrador required no impone pasos adicionales. No se agregaron
dependencias, permisos, captura, modelos ni SDKs.

## Archivos

- lib/src/core/network/facial_policy_config.dart: modelo informativo.
- lib/src/core/network/mobile_api_client.dart: lectura/serialización aditiva.
- test/facial_policy_config_test.dart: datos antiguos, borradores, caché,
  activación no soportada y configuración inválida.

## Verificación ejecutada

```text
flutter test test/facial_policy_config_test.dart test/qr_clock_preflight_service_test.dart test/qr_clock_submission_service_test.dart test/pending_clock_sync_service_test.dart test/mobile_api_client_test.dart --reporter expanded
36 tests passed

flutter analyze
No issues found!
```

No se compiló APK ni se probaron dispositivos reales: no hay UI ni captura
nueva. No se desplegó backend ni se ejecutaron sus migraciones.

Validación de cierre tras completar parámetros: suite completa `flutter test`
con **797 pruebas aprobadas** y `flutter analyze` sin problemas.

## Estado y recuperación

La configuración de preparación está integrada; el módulo facial completo
no está implementado. Pendientes: reglas operativas de riesgo/contingencias,
pruebas con base migrada, proveedor/PAD, enrolamiento, autorización segura,
UI de verificación, contingencias y piloto.

Para revertir esta unidad, retirar el campo del modelo AttendanceConfig y
el nuevo modelo. El caché contiene un campo JSON adicional que los lectores
anteriores ignoran; no hace falta borrar fichadas ni almacenamiento local.

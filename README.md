# control_asistencia_mobile

Frontend Flutter separado para empleados (fichar entrada/salida, ver perfil y asistencias).

## Alcance

- Solo app de empleado.
- Backend objetivo: `../backend`.
- Contrato congelado: `../backend/docs/mobile_v1_openapi.yaml`.

## Run local

Desde `frontend_flutter`:

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000 --dart-define=APP_FLAVOR=DEV
```

Notas:
- En Android emulator usar `10.0.2.2` para host local.
- En iOS simulator usar `http://localhost:5000`.
- En dispositivo fisico usar IP LAN del backend.

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

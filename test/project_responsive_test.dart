import 'package:package_info_plus/package_info_plus.dart';
import 'package:ficharqr/src/presentation/attendance/reintegros_page.dart';
import 'package:ficharqr/src/presentation/attendance/epp_page.dart';
import 'package:ficharqr/src/presentation/attendance/justificaciones_page.dart';
import 'package:ficharqr/src/presentation/attendance/pedidos_mercaderia_page.dart';
import 'package:ficharqr/src/presentation/attendance/feedback_page.dart';
import 'package:ficharqr/src/presentation/attendance/employee_alerts_page.dart';
import 'package:ficharqr/src/presentation/attendance/attendance_history_page.dart';
import 'package:ficharqr/src/presentation/attendance/security_events_page.dart';
import 'package:ficharqr/src/presentation/attendance/historial_adelantos_page.dart';
import 'package:ficharqr/src/presentation/attendance/premios_page.dart';
import 'package:ficharqr/src/presentation/attendance/horarios_page.dart';
import 'package:ficharqr/src/presentation/attendance/francos_page.dart';
import 'package:ficharqr/src/presentation/attendance/about_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ficharqr/src/core/network/mobile_api_client.dart';
import 'package:ficharqr/src/presentation/theme/app_theme.dart';
import 'package:ficharqr/src/presentation/attendance/qr_display_page.dart';
import 'package:ficharqr/src/presentation/attendance/adelantos_page.dart';
import 'package:ficharqr/src/presentation/attendance/vacaciones_page.dart';
import 'package:ficharqr/src/presentation/attendance/legajo_page.dart';
import 'package:ficharqr/src/presentation/attendance/employee_stats_page.dart';
import 'package:ficharqr/src/presentation/trivia/trivia_result_screen.dart';
import 'package:ficharqr/src/presentation/auth/login_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'FichaYa',
      packageName: 'test',
      version: '1.0',
      buildNumber: '1',
      buildSignature: '',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/connectivity'),
          (_) async => ['wifi'],
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/connectivity_status'),
          (_) async => null,
        );
  });
  final scenarios = [
    (size: const Size(320, 568), scale: 2.0, keyboard: 0.0),
    (size: const Size(740, 360), scale: 1.5, keyboard: 0.0),
    (size: const Size(390, 844), scale: 1.3, keyboard: 300.0),
    (size: const Size(800, 1024), scale: 1.0, keyboard: 0.0),
    (size: const Size(600, 960), scale: 1.3, keyboard: 0.0),
    (size: const Size(1024, 768), scale: 1.5, keyboard: 0.0),
    (size: const Size(1920, 1080), scale: 1.0, keyboard: 0.0),
  ];
  for (final brightness in Brightness.values) {
    for (final s in scenarios) {
      for (final name in [
        'QR',
        'Trivia',
        'Adelantos',
        'Vacaciones',
        'Legajo',
        'Estadísticas',
        'Login',
        'AboutPage',
        'FrancosPage',
        'HorariosPage',
        'PremiosPage',
        'HistorialAdelantosPage',
        'SecurityEventsPage',
        'AttendanceHistoryPage',
        'EmployeeAlertsPage',
        'FeedbackPage',
        'PedidosMercaderiaPage',
        'JustificacionesPage',
        'EppPage',
        'ReintegrosPage',
      ]) {
        testWidgets(
          '$name $brightness fits ${s.size}, text ${s.scale}, keyboard ${s.keyboard}',
          (tester) async {
            await tester.binding.setSurfaceSize(s.size);
            addTearDown(() => tester.binding.setSurfaceSize(null));
            final api = _Api();
            addTearDown(api.dispose);
            final page = switch (name) {
              'AboutPage' => AboutPage(),
              'FrancosPage' => FrancosPage(apiClient: api, token: 'test'),
              'HorariosPage' => HorariosPage(apiClient: api, token: 'test'),
              'PremiosPage' => PremiosPage(apiClient: api, token: 'test'),
              'HistorialAdelantosPage' => HistorialAdelantosPage(
                apiClient: api,
                token: 'test',
              ),
              'SecurityEventsPage' => SecurityEventsPage(
                apiClient: api,
                token: 'test',
              ),
              'AttendanceHistoryPage' => AttendanceHistoryPage(
                apiClient: api,
                token: 'test',
              ),
              'EmployeeAlertsPage' => EmployeeAlertsPage(
                apiClient: api,
                token: 'test',
              ),
              'FeedbackPage' => FeedbackPage(apiClient: api, token: 'test'),
              'PedidosMercaderiaPage' => PedidosMercaderiaPage(
                apiClient: api,
                token: 'test',
              ),
              'JustificacionesPage' => JustificacionesPage(
                apiClient: api,
                token: 'test',
              ),
              'EppPage' => EppPage(api: api, token: 'test'),
              'ReintegrosPage' => ReintegrosPage(api: api, token: 'test'),
              'QR' => QrDisplayPage(apiClient: api, token: 'test'),
              'Trivia' => TriviaResultScreen(
                apiClient: api,
                token: 'test',
                triviaId: 1,
                empleadoDni: 'test',
                resultado: const TriviaFinalizarResponse(
                  puntosTotal: 12345,
                  correctas: 100,
                  incorrectas: 20,
                  tiempoTotalSegundos: 1500,
                  posicion: 12345,
                ),
              ),
              'Adelantos' => AdelantosPage(apiClient: api, token: 'test'),
              'Vacaciones' => VacacionesPage(apiClient: api, token: 'test'),
              'Legajo' => LegajoPage(apiClient: api, token: 'test'),
              'Login' => LoginPage(
                apiClient: api,
                onLoginSuccess: (_) async {},
                biometricAvailable: true,
                hasStoredSession: true,
                onBiometricLogin: () async {},
              ),
              _ => EmployeeStatsPage(apiClient: api, token: 'test'),
            };
            await tester.pumpWidget(
              MaterialApp(
                theme: buildAppTheme(brightness: brightness),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(s.scale),
                    viewInsets: EdgeInsets.only(bottom: s.keyboard),
                  ),
                  child: AppViewport(child: child!),
                ),
                home: page,
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            final scrollable = find.byType(Scrollable);
            if (scrollable.evaluate().isNotEmpty) {
              for (var i = 0; i < 4; i++) {
                await tester.drag(scrollable.first, const Offset(0, -300));
                await tester.pumpAndSettle();
                expect(tester.takeException(), isNull);
              }
            }
          },
        );
      }
    }
  }
}

class _Api extends MobileApiClient {
  _Api()
    : super(
        baseUrl: 'https://example.test',
        httpClient: MockClient(
          (_) async => http.Response(
            '{"error":"No se pudo cargar la información solicitada. Reintentá cuando vuelva la conexión."}',
            503,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );
  @override
  Future<GenerarQrResponse> generarQr({
    required String token,
    String accion = 'auto',
    String scope = 'empresa',
    String tipoMarca = 'jornada',
    int vigenciaSegundos = 2592000,
  }) async => const GenerarQrResponse(
    accion: 'Registrar asistencia',
    scope: 'Empleado de la sucursal principal',
    tipoMarca: 'Ingreso a la jornada laboral',
    vigenciaSegundos: 300,
    expiraAt: '2026-10-08T23:00:00-03:00',
  );
}

import 'package:ficharqr/src/core/offline/offline_clock_queue.dart';
import 'package:ficharqr/src/core/offline/pending_clock_sync_service.dart';
import 'package:ficharqr/src/core/offline/pending_queue_controller.dart';
import 'package:ficharqr/src/presentation/attendance/widgets/pending_queue_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PendingQueueSheet', () {
    testWidgets('muestra estado vacio y ejecuta acciones superiores', (
      tester,
    ) async {
      final queueState = ValueNotifier(const PendingQueueState());
      var syncCalls = 0;
      var clearCalls = 0;

      await tester.pumpWidget(
        _wrap(
          PendingQueueSheet(
            queueState: queueState,
            formatDateTime: _formatDateTime,
            onSync: () async {
              syncCalls += 1;
            },
            onClearAll: (_) async {
              clearCalls += 1;
            },
            onRetry: (_) async {},
            onDelete: (_) async {},
          ),
        ),
      );

      expect(find.text('Bandeja de sincronizacion'), findsOneWidget);
      expect(find.text('No hay fichadas pendientes.'), findsOneWidget);

      await tester.tap(find.text('Sincronizar ahora'));
      await tester.pump();
      await tester.tap(find.text('Limpiar cola'));
      await tester.pump();

      expect(syncCalls, 1);
      expect(clearCalls, 1);

      queueState.value = const PendingQueueState(syncing: true);
      await tester.pump();

      expect(find.text('Sincronizando...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renderiza items y dispara retry/delete', (tester) async {
      final queueState = ValueNotifier(
        PendingQueueState(
          snapshot: PendingClockSnapshot.fromRecords([
            OfflineClockRecord(
              id: 'failed-1',
              employeeId: 9,
              qrToken: 'qr-demo',
              eventAt: DateTime(2026, 3, 17, 8, 15),
              createdAt: DateTime(2026, 3, 17, 8, 16),
              status: OfflineClockStatus.failed,
              attempts: 2,
              lastAttemptAt: DateTime(2026, 3, 17, 8, 20),
              lastError: 'Sin conectividad.',
            ),
          ]),
          lastMessage: 'Hay items pendientes.',
        ),
      );
      var retryCalls = 0;
      var deleteCalls = 0;

      await tester.pumpWidget(
        _wrap(
          PendingQueueSheet(
            queueState: queueState,
            formatDateTime: _formatDateTime,
            onSync: () async {},
            onClearAll: (_) async {},
            onRetry: (record) async {
              if (record.id == 'failed-1') {
                retryCalls += 1;
              }
            },
            onDelete: (record) async {
              if (record.id == 'failed-1') {
                deleteCalls += 1;
              }
            },
          ),
        ),
      );

      expect(find.text('Hay items pendientes.'), findsOneWidget);
      expect(find.text('Fecha: 2026-03-17 08:15'), findsOneWidget);
      expect(find.text('Intentos: 2'), findsOneWidget);
      expect(find.text('Ultimo intento: 2026-03-17 08:20'), findsOneWidget);
      expect(find.text('Ultimo error: Sin conectividad.'), findsOneWidget);
      expect(find.text('Error'), findsOneWidget);

      await tester.tap(find.text('Reintentar'));
      await tester.pump();
      await tester.tap(find.text('Eliminar'));
      await tester.pump();

      expect(retryCalls, 1);
      expect(deleteCalls, 1);
    });
  });
}

String _formatDateTime(DateTime dateTime) {
  final month = dateTime.month.toString().padLeft(2, '0');
  final day = dateTime.day.toString().padLeft(2, '0');
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '${dateTime.year}-$month-$day $hour:$minute';
}

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/auth/session_manager.dart';
import '../../core/network/mobile_api_client.dart';
import '../../core/offline/offline_clock_queue.dart';
import '../../core/offline/pending_queue_controller.dart';
import '../auth/biometric_settings_page.dart';
import '../profile/profile_page.dart';
import 'attendance_history_page.dart';
import 'employee_stats_page.dart';
import 'adelantos_page.dart';
import 'historial_adelantos_page.dart';
import 'vacaciones_page.dart';
import 'francos_page.dart';
import 'legajo_page.dart';
import 'justificaciones_page.dart';
import 'marks_history_page.dart';
import 'pedidos_mercaderia_page.dart';
import 'kpis_sector_page.dart';
import 'qr_scan_page.dart';
import 'security_events_page.dart';
import 'widgets/pending_queue_sheet.dart';

class AttendanceHomeCoordinator {
  const AttendanceHomeCoordinator();

  Future<void> openSecurityEvents(
    BuildContext context, {
    required MobileApiClient apiClient,
    required String token,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SecurityEventsPage(apiClient: apiClient, token: token),
      ),
    );
  }

  Future<void> openAttendanceHistory(
    BuildContext context, {
    required MobileApiClient apiClient,
    required String token,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AttendanceHistoryPage(apiClient: apiClient, token: token),
      ),
    );
  }

  Future<void> openMarksHistory(
    BuildContext context, {
    required MobileApiClient apiClient,
    required String token,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MarksHistoryPage(apiClient: apiClient, token: token),
      ),
    );
  }

  Future<void> openJustificaciones(
    BuildContext context, {
    required MobileApiClient apiClient,
    required String token,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            JustificacionesPage(apiClient: apiClient, token: token),
      ),
    );
  }

  Future<void> openAdelantos(
    BuildContext context, {
    required MobileApiClient apiClient,
    required String token,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdelantosPage(apiClient: apiClient, token: token),
      ),
    );
  }

  Future<void> openHistorialAdelantos(
    BuildContext context, {
    required MobileApiClient apiClient,
    required String token,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            HistorialAdelantosPage(apiClient: apiClient, token: token),
      ),
    );
  }

  Future<void> openVacaciones(
    BuildContext context, {
    required MobileApiClient apiClient,
    required String token,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VacacionesPage(apiClient: apiClient, token: token),
      ),
    );
  }

  Future<void> openFrancos(
    BuildContext context, {
    required MobileApiClient apiClient,
    required String token,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FrancosPage(apiClient: apiClient, token: token),
      ),
    );
  }

  Future<void> openLegajo(
    BuildContext context, {
    required MobileApiClient apiClient,
    required String token,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LegajoPage(apiClient: apiClient, token: token),
      ),
    );
  }

  Future<void> openPedidosMercaderia(
    BuildContext context, {
    required MobileApiClient apiClient,
    required String token,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PedidosMercaderiaPage(apiClient: apiClient, token: token),
      ),
    );
  }

  Future<void> openKpisSector(
    BuildContext context, {
    required MobileApiClient apiClient,
    required String token,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => KpisSectorPage(apiClient: apiClient, token: token),
      ),
    );
  }

  Future<void> openStats(
    BuildContext context, {
    required MobileApiClient apiClient,
    required String token,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EmployeeStatsPage(apiClient: apiClient, token: token),
      ),
    );
  }

  Future<void> openProfile(
    BuildContext context, {
    required MobileApiClient apiClient,
    required String token,
    String? employeeDni,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfilePage(
          apiClient: apiClient,
          token: token,
          employeeDni: employeeDni,
        ),
      ),
    );
  }

  Future<void> openBiometricSettings(
    BuildContext context, {
    required SessionManager sessionManager,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BiometricSettingsPage(sessionManager: sessionManager),
      ),
    );
  }

  Future<String?> scanQr(BuildContext context, {bool requiresPhoto = false}) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => QrScanPage(
          title: 'Escanear QR para fichar',
          requiresPhoto: requiresPhoto,
        ),
      ),
    );
  }

  Future<void> showPendingQueueSheet(
    BuildContext context, {
    required ValueListenable<PendingQueueState> queueState,
    required String Function(DateTime dateTime) formatDateTime,
    required Future<void> Function() onSync,
    required Future<void> Function(BuildContext context) onClearAll,
    required Future<void> Function(OfflineClockRecord record) onRetry,
    required Future<void> Function(OfflineClockRecord record) onDelete,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return PendingQueueSheet(
          queueState: queueState,
          formatDateTime: formatDateTime,
          onSync: onSync,
          onClearAll: onClearAll,
          onRetry: onRetry,
          onDelete: onDelete,
        );
      },
    );
  }

  Future<bool> confirmClearPendingQueue(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Limpiar pendientes'),
          content: const Text(
            'Se eliminaran todas las fichadas pendientes y con error.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Limpiar'),
            ),
          ],
        );
      },
    );
    return confirmed == true;
  }

  Future<AttendanceSessionExitAction?> showSessionExitOptions(
    BuildContext context,
  ) {
    return showModalBottomSheet<AttendanceSessionExitAction>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('Bloquear con huella'),
                  subtitle: const Text(
                    'Protege la pantalla. Al volver, desbloqueas con tu huella sin volver a ingresar.',
                  ),
                  onTap: () => Navigator.of(
                    sheetContext,
                  ).pop(AttendanceSessionExitAction.lock),
                ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Salir de la cuenta'),
                  subtitle: const Text(
                    'Cierra la sesión completamente. Necesitarás ingresar DNI y contraseña la próxima vez.',
                  ),
                  onTap: () => Navigator.of(
                    sheetContext,
                  ).pop(AttendanceSessionExitAction.logout),
                ),
                ListTile(
                  leading: const Icon(Icons.close),
                  title: const Text('Cancelar'),
                  onTap: () => Navigator.of(sheetContext).pop(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

enum AttendanceSessionExitAction { lock, logout }

import '../feedback/clock_feedback_audio_service.dart';
import '../network/mobile_api_client.dart';
import 'qr_clock_submission_service.dart';

class ClockFeedbackPresenter {
  const ClockFeedbackPresenter();

  ClockUserNotice invalidQr() {
    return const ClockUserNotice(
      message: 'QR invalido.',
      isError: true,
    );
  }

  ClockUserNotice missingConfig() {
    return const ClockUserNotice(
      message: 'No se pudo obtener la configuracion de fichada. Reintenta.',
      isError: true,
    );
  }

  ClockUserNotice qrDisabled() {
    return const ClockUserNotice(
      message: 'El metodo QR no esta habilitado para tu empresa en este momento.',
      isError: true,
    );
  }

  ClockUserNotice permissionSettings({required String missing}) {
    return ClockUserNotice(
      message: 'Debes habilitar $missing en Ajustes para continuar.',
      isError: true,
      duration: const Duration(seconds: 5),
      action: missing.trim().toLowerCase() == 'la camara'
          ? ClockNoticeAction.openAppSettings
          : ClockNoticeAction.openAppSettings,
    );
  }

  ClockUserNotice locationServiceDisabled() {
    return const ClockUserNotice(
      message: 'Activa el GPS del telefono para continuar con la fichada.',
      isError: true,
      duration: Duration(seconds: 5),
      action: ClockNoticeAction.openLocationSettings,
    );
  }

  ClockSubmissionPresentation presentSubmissionResult(
    QrClockSubmissionResult result, {
    required String Function(Duration duration) formatDuration,
  }) {
    switch (result.status) {
      case QrClockSubmissionStatus.success:
        final response = result.response!;
        final accion = (response.accion ?? 'movimiento').trim();
        final estado = response.estado ?? '-';
        return ClockSubmissionPresentation(
          notice: ClockUserNotice(
            message:
                'Fichada de $accion registrada. ID: ${response.id}. Estado: $estado. '
                'Tiempo total: ${formatDuration(result.totalDuration)}.',
          ),
          shouldSyncPendingSilently: true,
        );
      case QrClockSubmissionStatus.offlineQueued:
        return const ClockSubmissionPresentation(
          notice: ClockUserNotice(
            message:
                'Sin internet: fichada guardada como pendiente de sincronizacion.',
            tone: ClockFeedbackTone.offlineQueued,
          ),
        );
      case QrClockSubmissionStatus.offlineQueueFull:
        return ClockSubmissionPresentation(
          notice: ClockUserNotice(
            message:
                'Sin internet y la cola offline ya tiene ${result.queueFullError!.maxItems} fichadas. '
                'Sincroniza o limpia la bandeja antes de volver a fichar.',
            isError: true,
          ),
        );
      case QrClockSubmissionStatus.offlineQueueFailed:
        return const ClockSubmissionPresentation(
          notice: ClockUserNotice(
            message:
                'Sin internet y no se pudo guardar la fichada pendiente. Reintenta.',
            isError: true,
          ),
        );
      case QrClockSubmissionStatus.apiFailure:
        return ClockSubmissionPresentation(
          notice: _apiFailureNotice(result.apiError!),
        );
      case QrClockSubmissionStatus.unexpectedFailure:
        return const ClockSubmissionPresentation(
          notice: ClockUserNotice(
            message: 'Error inesperado al registrar la fichada.',
            isError: true,
          ),
        );
    }
  }

  ClockUserNotice _apiFailureNotice(ApiException error) {
    if (error.code == 'scan_cooldown') {
      final remaining = error.cooldownSegundosRestantes;
      return ClockUserNotice(
        message: (remaining != null && remaining > 0)
            ? 'Escaneo duplicado. Espera $remaining segundos para volver a fichar.'
            : error.message,
        isError: true,
        tone: ClockFeedbackTone.warning,
      );
    }

    if (error.alertaFraude == true) {
      final eventSuffix = error.eventoId != null
          ? ' Evento #${error.eventoId}.'
          : '';
      return ClockUserNotice(
        message: '${error.message}$eventSuffix',
        isError: true,
        tone: ClockFeedbackTone.fraud,
        duration: const Duration(seconds: 8),
        action: ClockNoticeAction.openSecurityEvents,
        style: ClockNoticeStyle.fraud,
      );
    }

    return ClockUserNotice(
      message: error.message,
      isError: true,
    );
  }
}

class ClockSubmissionPresentation {
  const ClockSubmissionPresentation({
    required this.notice,
    this.shouldSyncPendingSilently = false,
  });

  final ClockUserNotice notice;
  final bool shouldSyncPendingSilently;
}

class ClockUserNotice {
  const ClockUserNotice({
    required this.message,
    this.isError = false,
    this.tone,
    this.action,
    this.duration = const Duration(seconds: 3),
    this.style = ClockNoticeStyle.standard,
  });

  final String message;
  final bool isError;
  final ClockFeedbackTone? tone;
  final ClockNoticeAction? action;
  final Duration duration;
  final ClockNoticeStyle style;

  ClockFeedbackTone get effectiveTone =>
      tone ?? (isError ? ClockFeedbackTone.error : ClockFeedbackTone.success);
}

enum ClockNoticeAction {
  openAppSettings,
  openLocationSettings,
  openSecurityEvents,
}

enum ClockNoticeStyle { standard, fraud }

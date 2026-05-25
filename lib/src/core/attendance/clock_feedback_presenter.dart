import '../feedback/clock_feedback_audio_service.dart';
import '../network/mobile_api_client.dart';
import 'qr_clock_submission_service.dart';

class ClockFeedbackPresenter {
  const ClockFeedbackPresenter();

  ClockUserNotice invalidQr() {
    return const ClockUserNotice(message: 'QR invalido.', isError: true);
  }

  ClockUserNotice missingConfig() {
    return const ClockUserNotice(
      message: 'No se pudo obtener la configuración de fichada. Reintenta.',
      isError: true,
    );
  }

  ClockUserNotice qrDisabled() {
    return const ClockUserNotice(
      message:
          'El metodo QR no esta habilitado para tu empresa en este momento.',
      isError: true,
    );
  }

  ClockUserNotice permissionSettings({required String missing}) {
    return ClockUserNotice(
      message: 'Debes habilitar $missing en Ajustes para continuar.',
      isError: true,
      duration: const Duration(seconds: 5),
      action: missing.trim().toLowerCase() == 'la cámara'
          ? ClockNoticeAction.openAppSettings
          : ClockNoticeAction.openAppSettings,
    );
  }

  ClockUserNotice locationServiceDisabled() {
    return const ClockUserNotice(
      message: 'Activá el GPS del teléfono para continuar con la fichada.',
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
        return ClockSubmissionPresentation(
          notice: ClockUserNotice(
            message: 'Fichada de $accion registrada correctamente.',
            duration: const Duration(seconds: 4),
          ),
          shouldSyncPendingSilently: true,
        );
      case QrClockSubmissionStatus.offlineQueued:
        return const ClockSubmissionPresentation(
          notice: ClockUserNotice(
            message:
                'Sin conexión — fichada guardada. Se enviará automáticamente cuando recuperés internet.',
            tone: ClockFeedbackTone.offlineQueued,
            duration: Duration(seconds: 5),
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

    final qrNotice = _qrFailureNotice(error);
    if (qrNotice != null) {
      return qrNotice;
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

    return ClockUserNotice(message: error.message, isError: true);
  }

  ClockUserNotice? _qrFailureNotice(ApiException error) {
    final code = error.code?.trim();
    final isQrCode =
        code != null &&
        (code.startsWith('qr_') || code.startsWith('qr_token_'));
    final loweredMessage = error.message.toLowerCase();
    final isLegacyQrError =
        loweredMessage.contains('token invalido') ||
        loweredMessage.contains('token inválido') ||
        loweredMessage.contains('qr invalido') ||
        loweredMessage.contains('qr inválido');
    if (!isQrCode && !isLegacyQrError) {
      return null;
    }

    var message = error.message;
    switch (code) {
      case 'qr_token_invalid_signature':
        message =
            'QR generado en otro ambiente. Pedi que generen uno nuevo desde el panel actual.';
        break;
      case 'qr_token_expired':
        message = 'QR vencido. Pedi que generen uno nuevo.';
        break;
      case 'qr_inactive':
        message = 'QR inactivo. Pedi que generen uno nuevo desde el panel.';
        break;
      case 'qr_not_registered':
        message =
            'QR no registrado. Pedi que generen uno nuevo desde el panel.';
        break;
      case 'qr_wrong_empresa':
        message = 'Este QR pertenece a otra empresa.';
        break;
      case 'qr_wrong_empleado':
        message = 'Este QR no corresponde a tu usuario.';
        break;
      case 'qr_token_malformed':
      case 'qr_token_invalid':
      case 'qr_token_wrong_type':
        message = 'QR invalido. Escanea un QR generado por el sistema.';
        break;
    }

    return ClockUserNotice(
      message: message,
      isError: true,
      tone: ClockFeedbackTone.warning,
      duration: const Duration(seconds: 5),
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

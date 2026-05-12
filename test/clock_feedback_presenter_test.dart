import 'package:ficharqr/src/core/attendance/clock_feedback_presenter.dart';
import 'package:ficharqr/src/core/attendance/qr_clock_submission_service.dart';
import 'package:ficharqr/src/core/feedback/clock_feedback_audio_service.dart';
import 'package:ficharqr/src/core/network/mobile_api_client.dart';
import 'package:ficharqr/src/core/offline/offline_clock_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ClockFeedbackPresenter', () {
    const presenter = ClockFeedbackPresenter();

    test('presenta exito con mensaje y sync pendiente', () {
      final result = QrClockSubmissionResult(
        status: QrClockSubmissionStatus.success,
        totalDuration: const Duration(seconds: 4),
        response: FichadaResponse(id: 15, estado: 'ok', accion: 'ingreso'),
      );

      final presentation = presenter.presentSubmissionResult(
        result,
        formatDuration: (duration) => '${duration.inSeconds}s',
      );

      expect(presentation.shouldSyncPendingSilently, isTrue);
      expect(presentation.notice.isError, isFalse);
      expect(presentation.notice.effectiveTone, ClockFeedbackTone.success);
      expect(presentation.notice.message, contains('ingreso'));
      expect(presentation.notice.message, isNotEmpty);
    });

    test('presenta fraude con accion a eventos y estilo destacado', () {
      final result = QrClockSubmissionResult(
        status: QrClockSubmissionStatus.apiFailure,
        totalDuration: const Duration(seconds: 2),
        apiError: ApiException(
          message: 'Posible fraude detectado.',
          alertaFraude: true,
          eventoId: 99,
        ),
      );

      final presentation = presenter.presentSubmissionResult(
        result,
        formatDuration: (_) => '2s',
      );

      expect(presentation.shouldSyncPendingSilently, isFalse);
      expect(presentation.notice.effectiveTone, ClockFeedbackTone.fraud);
      expect(presentation.notice.action, ClockNoticeAction.openSecurityEvents);
      expect(presentation.notice.style, ClockNoticeStyle.fraud);
      expect(presentation.notice.message, contains('Evento #99'));
    });

    test('presenta cooldown con tono warning', () {
      final result = QrClockSubmissionResult(
        status: QrClockSubmissionStatus.apiFailure,
        totalDuration: const Duration(seconds: 1),
        apiError: ApiException(
          message: 'Cooldown.',
          code: 'scan_cooldown',
          cooldownSegundosRestantes: 7,
        ),
      );

      final presentation = presenter.presentSubmissionResult(
        result,
        formatDuration: (_) => '1s',
      );

      expect(presentation.notice.isError, isTrue);
      expect(presentation.notice.effectiveTone, ClockFeedbackTone.warning);
      expect(presentation.notice.message, contains('7 segundos'));
    });

    test('presenta cola offline llena con mensaje de limite', () {
      final result = QrClockSubmissionResult(
        status: QrClockSubmissionStatus.offlineQueueFull,
        totalDuration: const Duration(seconds: 1),
        queueFullError: const OfflineClockQueueFullException(maxItems: 40),
      );

      final presentation = presenter.presentSubmissionResult(
        result,
        formatDuration: (_) => '1s',
      );

      expect(presentation.notice.isError, isTrue);
      expect(presentation.notice.message, contains('40 fichadas'));
    });
  });
}

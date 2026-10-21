import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ficharqr/src/core/attendance/attendance_config_cache.dart';
import 'package:ficharqr/src/core/network/mobile_api_client.dart';
import 'package:ficharqr/src/core/network/facial_policy_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Map<String, dynamic> policy({String mode = 'required'}) => {
    'schema_version': 1,
    'requested': {'mode': mode},
    'origins': {'mode': 'company'},
    'configuration_status': 'ok',
    'effective_mode': 'disabled',
    'capture_enabled': false,
    'activation_available': false,
  };

  test('Legacy attendance config retains QR/GPS and disables facial', () {
    final config = AttendanceConfig.fromJson({
      'requiere_qr': true,
      'requiere_geo': true,
      'metodos_habilitados': ['qr'],
    });
    expect(config.requiereQr, isTrue);
    expect(config.requiereGeo, isTrue);
    expect(config.facialPolicy.captureEnabled, isFalse);
    expect(config.facialPolicy.configurationStatus, 'unavailable');
  });

  test('Draft required never activates and survives cache serialization', () {
    final config = AttendanceConfig.fromJson({'facial_policy': policy()});
    final restored = AttendanceConfig.fromJson(config.toJson());
    expect(restored.facialPolicy.requestedMode, 'required');
    expect(restored.facialPolicy.modeOrigin, 'company');
    expect(restored.facialPolicy.effectiveMode, 'disabled');
    expect(restored.facialPolicy.captureEnabled, isFalse);
  });

  test('Server activation is explicitly unsupported by this app', () {
    final input = policy()..['effective_mode'] = 'required';
    input['capture_enabled'] = true;
    final result = FacialPolicyConfig.fromJson(input);
    expect(result.configurationStatus, 'unsupported');
    expect(result.activationAvailable, isFalse);
    expect(result.captureEnabled, isFalse);
  });

  test('Unknown versions and malformed payloads never enable capture', () {
    for (final input in [
      null,
      [],
      'required',
      {'schema_version': 99},
      {'schema_version': 1},
    ]) {
      expect(FacialPolicyConfig.fromJson(input).captureEnabled, isFalse);
    }
  });

  test('Invalid configuration preserves unrelated attendance settings', () {
    final config = AttendanceConfig.fromJson({
      'cooldown_scan_segundos': 60,
      'facial_policy': {...policy(), 'configuration_status': 'invalid'},
    });
    expect(config.cooldownScanSegundos, 60);
    expect(config.facialPolicy.configurationStatus, 'invalid');
  });

  test(
    'Existing secure cache persists the draft without enabling capture',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final cache = AttendanceConfigCache();
      await cache.save(
        AttendanceConfig.fromJson({
          'requiere_qr': true,
          'facial_policy': policy(),
        }),
      );
      final restored = await cache.load();
      expect(restored?.requiereQr, isTrue);
      expect(restored?.facialPolicy.requestedMode, 'required');
      expect(restored?.facialPolicy.captureEnabled, isFalse);
    },
  );

  test('Unsupported activation stays unsupported after serialization', () {
    final config = FacialPolicyConfig.fromJson({
      ...policy(),
      'capture_enabled': true,
    });
    expect(
      FacialPolicyConfig.fromJson(config.toJson()).configurationStatus,
      'unsupported',
    );
  });

  test('Draft parameters and revisions survive serialization', () {
    final value = policy();
    value['requested'] = {
      'mode': 'trial',
      'on_entry': true,
      'on_exit': false,
      'max_attempts': 4,
      'timeout_seconds': 45,
    };
    value['revisions'] = {'company': 2, 'branch': 3, 'employee': 4};
    final restored = FacialPolicyConfig.fromJson(
      FacialPolicyConfig.fromJson(value).toJson(),
    );
    expect(restored.onEntry, isTrue);
    expect(restored.onExit, isFalse);
    expect(restored.maxAttempts, 4);
    expect(restored.timeoutSeconds, 45);
    expect(restored.employeeRevision, 4);
    expect(restored.captureEnabled, isFalse);
  });
}

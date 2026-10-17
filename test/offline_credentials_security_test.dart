import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ficharqr/src/core/auth/offline_credentials_cache.dart';
import 'package:ficharqr/src/core/network/mobile_api_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final stamp in [
    null,
    'invalid',
    DateTime.now().add(const Duration(days: 1)).toIso8601String(),
    DateTime.now().subtract(const Duration(hours: 73)).toIso8601String(),
  ]) {
    test('offline rejects invalid or expired timestamp $stamp', () async {
      FlutterSecureStorage.setMockInitialValues({
        '_off_cred_dni': '1',
        '_off_cred_pw_hash': 'x',
        '_off_cred_pw_salt': 'x',
        '_off_cred_emp': '{}',
        if (stamp != null) '_off_cred_at': stamp,
      });
      expect(
        (await OfflineCredentialsCache().validate(
          dni: '1',
          password: 'test',
        )).status,
        OfflineValidationStatus.expired,
      );
    });
  }
  test('fresh offline credentials still allow clock access', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final cache = OfflineCredentialsCache();
    await cache.save(
      dni: '1',
      password: 'local-test',
      empleado: EmployeeSummary(
        id: 1,
        dni: '1',
        nombre: 'Test',
        apellido: null,
        empresaId: 1,
      ),
    );
    expect(
      (await cache.validate(dni: '1', password: 'local-test')).isOk,
      isTrue,
    );
    expect((await cache.validate(dni: '1', password: 'wrong')).isOk, isFalse);
  });
}

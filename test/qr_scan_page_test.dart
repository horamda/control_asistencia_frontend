import 'package:ficharqr/src/presentation/attendance/qr_scan_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizeQrScanValue extrae token desde formatos comunes', () {
    const token = 'aaa.bbb.ccc';

    expect(normalizeQrScanValue(token), token);
    expect(normalizeQrScanValue('Bearer $token'), token);
    expect(
      normalizeQrScanValue('https://app.example/scan?qr_token=$token'),
      token,
    );
    expect(normalizeQrScanValue('{"qr_token":"$token"}'), token);
    expect(
      normalizeQrScanValue('https://app.example/#/scan?token=$token'),
      token,
    );
  });

  test('normalizeQrScanValue conserva valores no reconocidos', () {
    expect(normalizeQrScanValue('texto libre'), 'texto libre');
  });
}

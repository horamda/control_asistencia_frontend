import 'package:flutter_test/flutter_test.dart';
import 'package:ficharqr/src/core/image/profile_photo_cache.dart';

void main() {
  final backend = Uri.parse('https://api.example.com');
  final page = Uri.parse('https://app.example.com/perfil?old=1#section');
  test('profile images use web origin and retain version', () {
    expect(
      ProfilePhotoCache.webImageUrl(
        'https://api.example.com/empleados/imagen/123?v=28',
        backend: backend,
        page: page,
      ),
      'https://app.example.com/empleados/imagen/123?v=28',
    );
    expect(
      ProfilePhotoCache.webImageUrl(
        'https://api.example.com/empleados/imagen/123',
        backend: backend,
        page: page,
      ),
      'https://app.example.com/empleados/imagen/123',
    );
  });
  test('external hosts and unrelated backend routes are not rewritten', () {
    for (final url in [
      'https://other.example.com/empleados/imagen/123',
      'https://api.example.com/api/profile',
      'blob:https://app.example.com/photo',
    ]) {
      expect(
        ProfilePhotoCache.webImageUrl(url, backend: backend, page: page),
        url,
      );
    }
  });
}

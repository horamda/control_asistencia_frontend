import 'package:cached_network_image/cached_network_image.dart';

class ProfilePhotoCache {
  ProfilePhotoCache._();

  static int _revision = DateTime.now().millisecondsSinceEpoch;

  static void bump() {
    _revision = DateTime.now().millisecondsSinceEpoch;
  }

  static String withRevision(String? rawUrl) {
    final clean = (rawUrl ?? '').trim();
    if (clean.isEmpty) {
      return '';
    }

    final uri = Uri.tryParse(clean);
    if (uri == null) {
      return clean;
    }

    final query = Map<String, String>.from(uri.queryParameters);
    query['v'] = _revision.toString();
    return uri.replace(queryParameters: query).toString();
  }

  static Future<void> evict(String? rawUrl) async {
    final clean = (rawUrl ?? '').trim();
    if (clean.isEmpty) {
      return;
    }
    await CachedNetworkImage.evictFromCache(clean);
  }
}

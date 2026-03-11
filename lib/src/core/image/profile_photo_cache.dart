import 'package:cached_network_image/cached_network_image.dart';

class ProfilePhotoCache {
  ProfilePhotoCache._();

  static String withVersion(String? rawUrl, {int? version}) {
    final clean = (rawUrl ?? '').trim();
    if (clean.isEmpty) {
      return '';
    }

    final uri = Uri.tryParse(clean);
    if (uri == null) {
      return clean;
    }

    final query = Map<String, String>.from(uri.queryParameters);
    final safeVersion = version;
    if (safeVersion != null && safeVersion > 0) {
      query['v'] = safeVersion.toString();
    }
    return uri.replace(queryParameters: query).toString();
  }

  static String resolve({
    String? rawUrl,
    String? dni,
    int? version,
    String Function(String dni, int version)? fallbackBuilder,
  }) {
    final fromRaw = withVersion(rawUrl, version: version);
    if (fromRaw.isNotEmpty) {
      return fromRaw;
    }

    final safeDni = (dni ?? '').trim();
    final safeVersion = version;
    if (fallbackBuilder == null ||
        safeDni.isEmpty ||
        safeVersion == null ||
        safeVersion <= 0) {
      return '';
    }
    return fallbackBuilder.call(safeDni, safeVersion);
  }

  static Future<void> evict(String? rawUrl, {int? version}) async {
    final resolved = withVersion(rawUrl, version: version);
    if (resolved.isEmpty) {
      return;
    }
    await CachedNetworkImage.evictFromCache(resolved);
  }
}

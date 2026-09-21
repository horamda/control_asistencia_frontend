import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../config/app_config.dart';
import '../../core/image/profile_photo_cache.dart';

import '../../core/image/employee_photo_cache_manager.dart';

class EmployeePhotoWidget extends StatelessWidget {
  const EmployeePhotoWidget({
    super.key,
    this.photoUrl,
    this.localPhotoPath,
    this.token,
    this.radius = 26,
    this.placeholderSize = 14,
    this.iconSize,
    this.backgroundColor = const Color(0xFFE5ECF3),
  });

  final String? photoUrl;
  final String? localPhotoPath;
  final String? token;
  final double radius;
  final double placeholderSize;
  final double? iconSize;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final local = (localPhotoPath ?? '').trim();
    final remote = (photoUrl ?? '').trim();

    if (local.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor,
        backgroundImage: kIsWeb
            ? NetworkImage(local)
            : FileImage(File(local)) as ImageProvider,
      );
    }

    if (remote.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor,
        child: ClipOval(
          child: kIsWeb
              ? Image.network(
                  ProfilePhotoCache.webImageUrl(
                    remote,
                    backend: Uri.parse(AppConfig.current.apiBaseUrl),
                    page: Uri.base,
                  ),
                  headers: _headers(),
                  width: radius * 2,
                  height: radius * 2,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) => progress == null
                      ? child
                      : SizedBox(
                          width: placeholderSize,
                          height: placeholderSize,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        ),
                  errorBuilder: (_, __, ___) =>
                      Icon(Icons.person_outline, size: iconSize),
                )
              : CachedNetworkImage(
                  imageUrl: remote,
                  cacheManager: EmployeePhotoCacheManager.instance,
                  httpHeaders: _headers(),
                  width: radius * 2,
                  height: radius * 2,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => SizedBox(
                    width: placeholderSize,
                    height: placeholderSize,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  ),
                  errorWidget: (_, __, ___) =>
                      Icon(Icons.person_outline, size: iconSize),
                ),
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      child: Icon(Icons.person_outline, size: iconSize),
    );
  }

  Map<String, String>? _headers() {
    final bearer = (token ?? '').trim();
    if (bearer.isEmpty) {
      return null;
    }
    return <String, String>{'Authorization': 'Bearer $bearer'};
  }
}

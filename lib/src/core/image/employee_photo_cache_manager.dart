import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class EmployeePhotoCacheManager {
  EmployeePhotoCacheManager._();

  static const String _cacheKey = 'employee_photo_cache_v1';

  static final CacheManager instance = CacheManager(
    Config(
      _cacheKey,
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 3000,
    ),
  );
}

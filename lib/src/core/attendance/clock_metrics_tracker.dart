class ClockMetricsTracker {
  ClockMetricsTracker({DateTime Function()? nowProvider})
    : _nowProvider = nowProvider ?? DateTime.now;

  final DateTime Function() _nowProvider;

  ClockMetricsSnapshot record({
    required ClockMetricsSnapshot current,
    required Duration total,
    Duration? api,
    Duration? gps,
    Duration? photo,
  }) {
    final apiMs = api?.inMilliseconds ?? 0;
    final hasApiSample = api != null;
    return current.copyWith(
      lastClockAt: _nowProvider(),
      lastClockTotalDuration: total,
      lastClockApiDuration: api,
      lastClockGpsDuration: gps,
      lastClockPhotoDuration: photo,
      sampleCount: current.sampleCount + 1,
      totalMs: current.totalMs + total.inMilliseconds,
      apiMs: current.apiMs + (hasApiSample ? apiMs : 0),
      apiCount: current.apiCount + (hasApiSample ? 1 : 0),
    );
  }
}

class ClockMetricsSnapshot {
  static const Object _notSet = Object();

  const ClockMetricsSnapshot({
    this.lastClockAt,
    this.lastClockTotalDuration,
    this.lastClockApiDuration,
    this.lastClockGpsDuration,
    this.lastClockPhotoDuration,
    this.sampleCount = 0,
    this.totalMs = 0,
    this.apiMs = 0,
    this.apiCount = 0,
  });

  final DateTime? lastClockAt;
  final Duration? lastClockTotalDuration;
  final Duration? lastClockApiDuration;
  final Duration? lastClockGpsDuration;
  final Duration? lastClockPhotoDuration;
  final int sampleCount;
  final int totalMs;
  final int apiMs;
  final int apiCount;

  bool get hasSamples => sampleCount > 0;

  Duration? get averageTotalDuration {
    if (sampleCount <= 0) {
      return null;
    }
    return Duration(milliseconds: (totalMs / sampleCount).round());
  }

  Duration? get averageApiDuration {
    if (apiCount <= 0) {
      return null;
    }
    return Duration(milliseconds: (apiMs / apiCount).round());
  }

  ClockMetricsSnapshot copyWith({
    Object? lastClockAt = _notSet,
    Object? lastClockTotalDuration = _notSet,
    Object? lastClockApiDuration = _notSet,
    Object? lastClockGpsDuration = _notSet,
    Object? lastClockPhotoDuration = _notSet,
    int? sampleCount,
    int? totalMs,
    int? apiMs,
    int? apiCount,
  }) {
    return ClockMetricsSnapshot(
      lastClockAt: identical(lastClockAt, _notSet)
          ? this.lastClockAt
          : lastClockAt as DateTime?,
      lastClockTotalDuration: identical(lastClockTotalDuration, _notSet)
          ? this.lastClockTotalDuration
          : lastClockTotalDuration as Duration?,
      lastClockApiDuration: identical(lastClockApiDuration, _notSet)
          ? this.lastClockApiDuration
          : lastClockApiDuration as Duration?,
      lastClockGpsDuration: identical(lastClockGpsDuration, _notSet)
          ? this.lastClockGpsDuration
          : lastClockGpsDuration as Duration?,
      lastClockPhotoDuration: identical(lastClockPhotoDuration, _notSet)
          ? this.lastClockPhotoDuration
          : lastClockPhotoDuration as Duration?,
      sampleCount: sampleCount ?? this.sampleCount,
      totalMs: totalMs ?? this.totalMs,
      apiMs: apiMs ?? this.apiMs,
      apiCount: apiCount ?? this.apiCount,
    );
  }
}

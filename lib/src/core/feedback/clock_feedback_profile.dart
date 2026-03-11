enum ClockFeedbackProfile { subtle, balanced, strong }

extension ClockFeedbackProfileCodec on ClockFeedbackProfile {
  String get storageValue {
    switch (this) {
      case ClockFeedbackProfile.subtle:
        return 'subtle';
      case ClockFeedbackProfile.balanced:
        return 'balanced';
      case ClockFeedbackProfile.strong:
        return 'strong';
    }
  }

  String get label {
    switch (this) {
      case ClockFeedbackProfile.subtle:
        return 'Discreto';
      case ClockFeedbackProfile.balanced:
        return 'Balanceado';
      case ClockFeedbackProfile.strong:
        return 'Fuerte';
    }
  }

  static ClockFeedbackProfile fromStorageValue(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'subtle':
        return ClockFeedbackProfile.subtle;
      case 'strong':
        return ClockFeedbackProfile.strong;
      case 'balanced':
      default:
        return ClockFeedbackProfile.balanced;
    }
  }
}

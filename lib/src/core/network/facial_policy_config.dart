/// Informational draft only. This app version cannot perform facial verification.
/// Cached policy is never proof of identity or authorization to clock in.
class FacialPolicyConfig {
  const FacialPolicyConfig({
    this.schemaVersion,
    this.requestedMode,
    this.modeOrigin,
    this.configurationStatus = 'unavailable',
    this.blockReason = 'client_not_implemented',
    this.onEntry,
    this.onExit,
    this.maxAttempts,
    this.timeoutSeconds,
    this.companyRevision = 0,
    this.branchRevision = 0,
    this.employeeRevision = 0,
  });

  final int? schemaVersion;
  final String? requestedMode;
  final String? modeOrigin;
  final String configurationStatus;
  final String blockReason;
  final bool? onEntry;
  final bool? onExit;
  final int? maxAttempts;
  final int? timeoutSeconds;
  final int companyRevision;
  final int branchRevision;
  final int employeeRevision;

  // Deliberately not configurable until capture and server authorization exist.
  String get effectiveMode => 'disabled';
  bool get captureEnabled => false;
  bool get activationAvailable => false;

  factory FacialPolicyConfig.fromJson(dynamic value) {
    if (value == null) return const FacialPolicyConfig();
    if (value is! Map) {
      return const FacialPolicyConfig(configurationStatus: 'invalid');
    }
    if (value['schema_version'] == null &&
        value['configuration_status'] == 'unavailable') {
      return const FacialPolicyConfig();
    }
    if (value['schema_version'] != 1) {
      return const FacialPolicyConfig(configurationStatus: 'unsupported');
    }
    final requested = value['requested'];
    final origins = value['origins'];
    final mode = requested is Map ? requested['mode'] : null;
    final origin = origins is Map ? origins['mode'] : null;
    final revisions = value['revisions'];
    int revision(String key) {
      final raw = revisions is Map ? revisions[key] : null;
      return raw is int && raw >= 0 ? raw : 0;
    }

    int? bounded(String key, int min, int max) {
      final raw = requested is Map ? requested[key] : null;
      return raw is int && raw >= min && raw <= max ? raw : null;
    }

    bool? flag(String key) {
      final raw = requested is Map ? requested[key] : null;
      return raw is bool ? raw : null;
    }

    const modes = {'disabled', 'trial', 'required', 'risk'};
    const sources = {'default', 'company', 'branch', 'employee'};
    final status = value['configuration_status'];
    final serverWantsActivation =
        value['effective_mode'] != 'disabled' ||
        value['capture_enabled'] != false ||
        value['activation_available'] != false;
    return FacialPolicyConfig(
      schemaVersion: 1,
      onEntry: flag('on_entry'),
      onExit: flag('on_exit'),
      maxAttempts: bounded('max_attempts', 1, 5),
      timeoutSeconds: bounded('timeout_seconds', 10, 120),
      companyRevision: revision('company'),
      branchRevision: revision('branch'),
      employeeRevision: revision('employee'),
      requestedMode: modes.contains(mode) ? mode as String : null,
      modeOrigin: sources.contains(origin) ? origin as String : null,
      configurationStatus: serverWantsActivation
          ? 'unsupported'
          : status == 'ok' || status == 'invalid' || status == 'unsupported'
          ? status as String
          : 'invalid',
      blockReason: serverWantsActivation || status == 'unsupported'
          ? 'client_not_implemented'
          : 'provider_and_authorization_not_validated',
    );
  }

  Map<String, dynamic> toJson() => {
    'schema_version': schemaVersion,
    'requested': {
      if (requestedMode != null) 'mode': requestedMode,
      if (onEntry != null) 'on_entry': onEntry,
      if (onExit != null) 'on_exit': onExit,
      if (maxAttempts != null) 'max_attempts': maxAttempts,
      if (timeoutSeconds != null) 'timeout_seconds': timeoutSeconds,
    },
    'revisions': {
      'company': companyRevision,
      'branch': branchRevision,
      'employee': employeeRevision,
    },
    if (modeOrigin != null) 'origins': {'mode': modeOrigin},
    'configuration_status': configurationStatus,
    'effective_mode': effectiveMode,
    'capture_enabled': captureEnabled,
    'activation_available': activationAvailable,
    'activation_block_reason': blockReason,
  };
}

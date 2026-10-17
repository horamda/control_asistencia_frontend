import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'employee_alerts_repository.dart';
import '../network/mobile_api_client.dart';

/// Tracks viewed module snapshots on this device, separately from workflow status.
class EmployeeAlertsReadState {
  EmployeeAlertsReadState({required String server, required int employeeId})
    : _key =
          'alerts_seen_v1_${sha256.convert(utf8.encode('$server|$employeeId'))}';
  final String _key;
  static const _storage = FlutterSecureStorage();

  Map<String, String> fingerprints(EmployeeAlertsSnapshot snapshot) {
    final result = <String, String>{};
    final a = snapshot.adelantos;
    final m = snapshot.mercaderia;
    if (a != null && snapshot.adelantosError == null) {
      final items = [
        a.adelantoMesActual,
        a.ultimoAdelanto,
      ].whereType<AdelantoItem>();
      if (items.isNotEmpty) {
        result['adelantos'] = jsonEncode(
          items.map((e) => [e.id, e.estado, e.resueltoAt]).toList(),
        );
      }
    }
    if (m != null && snapshot.mercaderiaError == null) {
      final items = [
        m.pedidoMesActual,
        m.ultimoPedido,
        m.ultimoPedidoAprobado,
      ].whereType<PedidoMercaderiaItem>();
      if (items.isNotEmpty) {
        result['mercaderia'] = jsonEncode(
          items.map((e) => [e.id, e.estado, e.resueltaAt]).toList(),
        );
      }
    }
    final f = snapshot.feedbackDashboard?.resumen;
    if (f != null && snapshot.feedbackError == null && (f.total ?? 0) > 0) {
      result['feedback'] = jsonEncode([
        f.total,
        f.pendientes,
        f.enProceso,
        f.resueltos,
        f.vencidos,
        for (final e in snapshot.feedbackRecent)
          [e.id, e.estado, e.updatedAt, e.resueltoAt],
      ]);
    }
    return result.map(
      (key, value) =>
          MapEntry(key, sha256.convert(utf8.encode(value)).toString()),
    );
  }

  Future<Map<String, dynamic>> _read() async {
    final value = await _storage.read(key: _key);
    return value == null
        ? {}
        : Map<String, dynamic>.from(jsonDecode(value) as Map);
  }

  Future<Set<String>> unreadModules(EmployeeAlertsSnapshot snapshot) async {
    final seen = await _read();
    return fingerprints(
      snapshot,
    ).entries.where((e) => seen[e.key] != e.value).map((e) => e.key).toSet();
  }

  Future<int> unreadCount(EmployeeAlertsSnapshot snapshot) async =>
      (await unreadModules(snapshot)).length;

  Future<void> markViewed(EmployeeAlertsSnapshot snapshot) async {
    final seen = await _read();
    seen.addAll(fingerprints(snapshot));
    await _storage.write(key: _key, value: jsonEncode(seen));
  }
}

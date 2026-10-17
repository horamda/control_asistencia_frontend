bool isReunionQr(String value) => value.startsWith('fichaya://reunion?');

List<Map<String, dynamic>> reunionMaps(dynamic value) => value is List
    ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : [];

/// Preserve the server's resolved branch, calendar dates and display messages.
class ReunionOccurrence {
  ReunionOccurrence(this.data);
  final Map<String, dynamic> data;
  int get reunionId => (data['reunion_id'] as num).toInt();
  String get fecha => data['fecha'] as String;
  String get nombre => data['nombre'] as String? ?? 'Reunión';
  String get estado => data['estado'] as String? ?? 'pendiente';
  bool get cancelada => data['cancelada'] == true || estado == 'cancelada';
  DateTime get inicio => DateTime.parse(data['inicio'] as String);
  String get key => '$reunionId:$fecha';
  String get location => [
    data['sucursal_nombre'],
    data['lugar'],
  ].whereType<String>().where((e) => e.isNotEmpty).join(' · ');
}

String reunionStateLabel(String? state) =>
    const {
      'pendiente': 'Pendiente',
      'abierta': 'Registro abierto',
      'presente': 'Presente',
      'tarde': 'Tarde',
      'ausente': 'Ausente',
      'justificado': 'Justificado',
      'cancelada': 'Cancelada',
    }[state] ??
    state ??
    'Sin datos';

/// Display the server's Argentina wall time, regardless of device timezone.
String reunionDateTime(dynamic value) {
  if (value == null) return '—';
  final text = value.toString();
  final match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})(?:T(\d{2}:\d{2}))?',
  ).firstMatch(text);
  if (match == null) return text;
  return '${match[3]}/${match[2]}/${match[1]}${match[4] == null ? '' : ' ${match[4]}'}';
}

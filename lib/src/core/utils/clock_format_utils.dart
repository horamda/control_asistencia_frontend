/// Funciones de formateo puras para la vista de asistencia (fichadas).
///
/// Todas son funciones de nivel superior sin estado. Se usan tanto en la page
/// de inicio como en la capa de view-model para evitar duplicacion.
library;

/// Formatea una [Duration] como milisegundos o segundos con dos decimales.
///
/// Ejemplos: "850 ms", "1.23 s"
String fmtClockDuration(Duration duration) {
  if (duration.inMilliseconds < 1000) {
    return '${duration.inMilliseconds} ms';
  }
  return '${(duration.inMilliseconds / 1000).toStringAsFixed(2)} s';
}

/// Formatea un [DateTime] como "HH:MM:SS".
String fmtClockTimeOfDay(DateTime dateTime) {
  final hh = dateTime.hour.toString().padLeft(2, '0');
  final mm = dateTime.minute.toString().padLeft(2, '0');
  final ss = dateTime.second.toString().padLeft(2, '0');
  return '$hh:$mm:$ss';
}

/// Formatea un [DateTime] como "DD/MM/YYYY HH:MM:SS".
String fmtClockDateTime(DateTime dateTime) {
  final d = dateTime.day.toString().padLeft(2, '0');
  final m = dateTime.month.toString().padLeft(2, '0');
  final y = dateTime.year.toString().padLeft(4, '0');
  return '$d/$m/$y ${fmtClockTimeOfDay(dateTime)}';
}

/// Formatea la antiguedad de [dateTime] respecto a ahora como texto relativo.
///
/// Ejemplos: "hace segundos", "hace 5 min", "hace 2 h", "hace 3 d"
String fmtClockRelative(DateTime dateTime) {
  var diff = DateTime.now().difference(dateTime);
  if (diff.isNegative) {
    diff = Duration.zero;
  }
  if (diff.inSeconds < 45) return 'hace segundos';
  if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'hace ${diff.inHours} h';
  return 'hace ${diff.inDays} d';
}

/// Devuelve `true` si [a] y [b] corresponden al mismo dia calendario.
bool clockIsSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Abrevia un token QR largo para mostrarlo en la UI.
///
/// Si el token tiene 38 caracteres o menos lo devuelve sin cambios.
/// Si es mas largo muestra los primeros 22 y los ultimos 12 separados por "…".
String shortQrToken(String token) {
  if (token.length <= 38) return token;
  return '${token.substring(0, 22)}...${token.substring(token.length - 12)}';
}

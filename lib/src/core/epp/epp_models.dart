typedef EppData = Map<String, dynamic>;

List<EppData> eppRows(dynamic value) => value is List
    ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : [];
int eppInt(dynamic value) => int.tryParse('$value') ?? 0;
String eppText(dynamic value) => value?.toString() ?? '';
const eppStates = {
  'borrador': 'Borrador',
  'pendiente': 'Pendiente de aprobación',
  'aprobado': 'Aprobado',
  'parcial': 'Entrega parcial',
  'entregado': 'Entregado',
  'rechazado': 'Rechazado',
  'cancelado': 'Cancelado',
};
bool eppEditable(EppData order) =>
    ['borrador', 'pendiente'].contains(order['estado']);

class EppArticle {
  EppArticle(EppData data)
    : id = eppInt(data['id']),
      name = eppText(data['nombre']),
      category = eppText(data['categoria']),
      description = eppText(data['descripcion']),
      sizes = (data['talles'] as List? ?? []).map((e) => '$e').toList(),
      hasImage = eppInt(data['tiene_imagen']) == 1,
      active = data['activo'] == null || eppInt(data['activo']) == 1,
      annualNotice = eppInt(data['aviso_anual']);
  final int id, annualNotice;
  final String name, category, description;
  final List<String> sizes;
  final bool hasImage, active;
}

class EppConfig {
  EppConfig(EppData data)
    : articles = eppRows(
        data['articulos'],
      ).map(EppArticle.new).where((a) => a.active).toList(),
      sizes = eppRows(data['talles']),
      concepts = eppRows(
        data['conceptos_reposicion'],
      ).where((r) => eppInt(r['activo']) == 1).toList(),
      maxItems = eppInt(data['max_items']) > 0
          ? eppInt(data['max_items']).clamp(1, 50)
          : 50;
  final List<EppArticle> articles;
  final List<EppData> sizes, concepts;
  final int maxItems;
  EppData saved(int id) =>
      sizes.firstWhere((s) => eppInt(s['articulo_id']) == id, orElse: () => {});
}

import 'package:flutter/material.dart';
import '../../core/network/mobile_api_client.dart';

/// Reads the authorized catalog again on opening, so panel changes are visible.
class SeguridadExternalDialog extends StatefulWidget {
  const SeguridadExternalDialog({
    super.key,
    required this.api,
    required this.token,
    required this.onConfig,
  });
  final MobileApiClient api;
  final String token;
  final void Function(Map<String, dynamic>) onConfig;
  @override
  State<SeguridadExternalDialog> createState() =>
      _SeguridadExternalDialogState();
}

class _SeguridadExternalDialogState extends State<SeguridadExternalDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _company = TextEditingController();
  final _search = TextEditingController();
  List<Map<String, dynamic>> _people = [];
  bool _loading = true;
  bool _creating = false;
  bool _catalogSupported = true;
  String? _error;
  int? _selected;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _company.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final config = await widget.api.getSeguridad(token: widget.token);
      if (!mounted) return;
      widget.onConfig(config);
      setState(() {
        _catalogSupported = config['externos'] is List;
        _people = (config['externos'] as List? ?? [])
            .map((p) => Map<String, dynamic>.from(p as Map))
            .toList();
        if (!_people.any((p) => p['id'] == _selected)) _selected = null;
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is ApiException
              ? e.message
              : 'No se pudo actualizar la lista de personas.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _people
        .where(
          (p) => '${p['nombre']} ${p['empresa'] ?? ''}'.toLowerCase().contains(
            _search.text.trim().toLowerCase(),
          ),
        )
        .toList();
    return AlertDialog(
      title: const Text('Persona externa'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Ya registrada'),
                    selected: !_creating,
                    onSelected: (_) => setState(() => _creating = false),
                  ),
                  ChoiceChip(
                    label: const Text('Crear persona nueva'),
                    selected: _creating,
                    onSelected: (_) => setState(() => _creating = true),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_creating)
                Form(
                  key: _form,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _name,
                        maxLength: 180,
                        decoration: const InputDecoration(
                          labelText: 'Nombre del externo',
                        ),
                        validator: (v) => (v ?? '').trim().isEmpty
                            ? 'Ingresá el nombre.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _company,
                        maxLength: 180,
                        decoration: const InputDecoration(
                          labelText: 'Empresa / procedencia (opcional)',
                        ),
                      ),
                      const Text(
                        'Usá esta opción solo si la persona no está registrada.',
                      ),
                    ],
                  ),
                )
              else ...[
                TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    labelText: 'Buscar nombre o empresa',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                if (_loading)
                  const LinearProgressIndicator()
                else if (_error != null) ...[
                  Text(_error!),
                  TextButton(onPressed: _load, child: const Text('Reintentar')),
                ] else if (!_catalogSupported) ...[
                  const Text(
                    'El servidor no está enviando el catálogo de personas externas. Solicitá su habilitación a administración.',
                  ),
                  TextButton(
                    onPressed: _load,
                    child: const Text('Actualizar lista'),
                  ),
                ] else ...[
                  Text(
                    '${_people.length} personas registradas',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  if (visible.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        _people.isEmpty
                            ? 'No hay personas externas disponibles para tu empresa.'
                            : 'No hay coincidencias con esta búsqueda.',
                      ),
                    ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 260),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final person = visible[index];
                        final selected = _selected == person['id'];
                        return ListTile(
                          selected: selected,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                          ),
                          leading: Icon(
                            selected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                          ),
                          title: Text('${person['nombre']}'),
                          subtitle: Text(
                            '${person['empresa'] ?? ''}'.isEmpty
                                ? 'Sin empresa informada'
                                : '${person['empresa']}',
                          ),
                          onTap: () =>
                              setState(() => _selected = person['id'] as int),
                        );
                      },
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Actualizar lista'),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed:
              !_creating && (_selected == null || _loading || _error != null)
              ? null
              : () {
                  if (_creating && !_form.currentState!.validate()) return;
                  Navigator.pop(
                    context,
                    _creating
                        ? <String, dynamic>{
                            'nombre': _name.text.trim(),
                            'empresa': _company.text.trim(),
                          }
                        : <String, dynamic>{'id': _selected},
                  );
                },
          child: const Text('Agregar'),
        ),
      ],
    );
  }
}

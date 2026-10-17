import 'package:flutter/material.dart';
import '../../core/network/mobile_api_client.dart';

/// Reads the authorized catalog again on opening, so panel changes are visible.
class SeguridadExternalDialog extends StatefulWidget {
  const SeguridadExternalDialog({
    super.key,
    required this.api,
    required this.token,
    required this.onConfig,
    this.existingIds = const {},
  });
  final MobileApiClient api;
  final String token;
  final Set<int> existingIds;
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
  final _selected = <int>{};

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
        _selected.retainAll(_people.map((p) => p['id']).whereType<int>());
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      scrollable: true,
      title: Text(
        _creating ? 'Persona externa' : 'Personas externas',
        textAlign: TextAlign.center,
      ),
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
                alignment: WrapAlignment.center,
                children: [
                  ChoiceChip(
                    label: const Text(
                      'Ya registrada',
                      textAlign: TextAlign.center,
                    ),
                    selected: !_creating,
                    onSelected: (_) => setState(() => _creating = false),
                  ),
                  ChoiceChip(
                    label: const Text(
                      'Crear persona nueva',
                      textAlign: TextAlign.center,
                    ),
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
                    crossAxisAlignment: CrossAxisAlignment.center,
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
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else ...[
                TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    labelText: 'Buscar nombre o empresa',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Limpiar búsqueda',
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => setState(_search.clear),
                          ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                if (_loading)
                  const LinearProgressIndicator()
                else if (_error != null) ...[
                  Text(_error!, textAlign: TextAlign.center),
                  TextButton(
                    onPressed: _load,
                    child: const Text(
                      'Reintentar',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ] else if (!_catalogSupported) ...[
                  const Text(
                    'El servidor no está enviando el catálogo de personas externas. Solicitá su habilitación a administración.',
                    textAlign: TextAlign.center,
                  ),
                  TextButton(
                    onPressed: _load,
                    child: const Text(
                      'Actualizar lista',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ] else ...[
                  Text(
                    '${_people.length} personas registradas',
                    style: Theme.of(context).textTheme.labelLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Podés elegir varias personas. Seleccionadas: ${_selected.length}',
                    textAlign: TextAlign.center,
                  ),
                  if (visible.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        _people.isEmpty
                            ? 'No hay personas externas disponibles para tu empresa.'
                            : 'No hay coincidencias con esta búsqueda.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  SizedBox(
                    height: visible.isEmpty
                        ? 0
                        : (MediaQuery.sizeOf(context).height * .32).clamp(
                            120.0,
                            300.0,
                          ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final person = visible[index];
                        final id = person['id'] as int;
                        final alreadyAdded = widget.existingIds.contains(id);
                        final selected = alreadyAdded || _selected.contains(id);
                        return CheckboxListTile(
                          value: selected,
                          controlAffinity: ListTileControlAffinity.leading,
                          selected: selected,
                          selectedTileColor: Theme.of(
                            context,
                          ).colorScheme.primaryContainer,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                          ),
                          title: Text(
                            '${person['nombre']}',
                            textAlign: TextAlign.center,
                          ),
                          subtitle: Text(
                            alreadyAdded
                                ? 'Ya agregada al reporte'
                                : '${person['empresa'] ?? ''}'.isEmpty
                                ? 'Sin empresa informada'
                                : '${person['empresa']}',
                            textAlign: TextAlign.center,
                          ),
                          onChanged: alreadyAdded
                              ? null
                              : (value) => setState(() {
                                  if (value == true) {
                                    _selected.add(id);
                                  } else {
                                    _selected.remove(id);
                                  }
                                }),
                        );
                      },
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text(
                      'Actualizar lista',
                      textAlign: TextAlign.center,
                    ),
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
          child: const Text('Cancelar', textAlign: TextAlign.center),
        ),
        FilledButton(
          onPressed:
              !_creating && (_selected.isEmpty || _loading || _error != null)
              ? null
              : () {
                  if (_creating && !_form.currentState!.validate()) return;
                  Navigator.pop(
                    context,
                    _creating
                        ? <Map<String, dynamic>>[
                            {
                              'nombre': _name.text.trim(),
                              'empresa': _company.text.trim(),
                            },
                          ]
                        : [
                            for (final id in _selected)
                              <String, dynamic>{'id': id},
                          ],
                  );
                },
          child: Text(
            !_creating && _selected.length > 1
                ? 'Agregar (${_selected.length})'
                : 'Agregar',
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

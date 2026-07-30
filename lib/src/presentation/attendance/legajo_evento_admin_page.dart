import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/network/mobile_api_client.dart';

class LegajoEventoAdminPage extends StatefulWidget {
  const LegajoEventoAdminPage({
    super.key,
    required this.apiClient,
    required this.token,
  });

  final MobileApiClient apiClient;
  final String token;

  @override
  State<LegajoEventoAdminPage> createState() => _LegajoEventoAdminPageState();
}

class _LegajoEventoAdminPageState extends State<LegajoEventoAdminPage> {
  final _searchCtrl = TextEditingController();
  final _tituloCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();

  bool _loading = true;
  bool _searching = false;
  bool _saving = false;
  bool _pickingAttachment = false;
  String? _error;
  String? _alcance;
  List<LegajoEventosAdminEmpleadoItem> _empleados = [];
  List<LegajoTipoEventoItem> _tipos = [];
  final List<_DraftLegajoAdjunto> _adjuntos = [];
  LegajoEventosAdminEmpleadoItem? _empleado;
  LegajoTipoEventoItem? _tipo;
  DateTime _fechaEvento = DateTime.now();
  DateTime? _fechaDesde;
  DateTime? _fechaHasta;
  String _severidad = 'leve';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tituloCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        widget.apiClient.getLegajoEventosAdminPermisos(token: widget.token),
        widget.apiClient.getLegajoEventosAdminTipos(token: widget.token),
        widget.apiClient.getLegajoEventosAdminEmpleados(
          token: widget.token,
          per: 12,
        ),
      ]);
      final permisos = results[0] as LegajoEventosAdminPermisosResponse;
      if (!permisos.puedeCargar) {
        throw ApiException(
          message: 'No tenes permiso para cargar eventos de legajo.',
        );
      }
      final tipos = results[1] as LegajoEventosAdminTiposResponse;
      final empleados = results[2] as LegajoEventosAdminEmpleadosResult;
      if (!mounted) return;
      setState(() {
        _alcance = permisos.alcance;
        _tipos = tipos.items;
        _tipo = tipos.items.isNotEmpty ? tipos.items.first : null;
        _empleados = empleados.items;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Error inesperado al cargar la pantalla.';
        _loading = false;
      });
    }
  }

  Future<void> _search() async {
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final result = await widget.apiClient.getLegajoEventosAdminEmpleados(
        token: widget.token,
        queryText: _searchCtrl.text,
        per: 20,
      );
      if (!mounted) return;
      setState(() {
        _empleados = result.items;
        _searching = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _searching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo buscar empleados.';
        _searching = false;
      });
    }
  }

  Future<void> _pickDate({
    required DateTime initial,
    required ValueChanged<DateTime> onSelected,
  }) async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 2),
      initialDate: initial,
    );
    if (picked != null) onSelected(picked);
  }

  Future<void> _save() async {
    final empleado = _empleado;
    final tipo = _tipo;
    final descripcion = _descripcionCtrl.text.trim();
    if (empleado == null) {
      _show('Selecciona un empleado.', isError: true);
      return;
    }
    if (tipo == null) {
      _show('Selecciona un tipo de evento.', isError: true);
      return;
    }
    if (descripcion.isEmpty) {
      _show('Carga una descripcion.', isError: true);
      return;
    }
    if (tipo.requiereRangoFechas &&
        (_fechaDesde == null || _fechaHasta == null)) {
      _show('Este tipo requiere fecha desde y hasta.', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.apiClient.createLegajoEventoAdmin(
        token: widget.token,
        empleadoId: empleado.id,
        tipoId: tipo.id,
        fechaEvento: _dateParam(_fechaEvento),
        fechaDesde: _fechaDesde == null ? null : _dateParam(_fechaDesde!),
        fechaHasta: _fechaHasta == null ? null : _dateParam(_fechaHasta!),
        titulo: _tituloCtrl.text,
        descripcion: descripcion,
        severidad: _severidad,
        adjuntos: _adjuntos.map((item) => item.upload).toList(),
      );
      if (!mounted) return;
      _show('Evento cargado correctamente.');
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _show(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _show('No se pudo cargar el evento.', isError: true);
    }
  }

  Future<void> _addAttachment() async {
    if (_saving || _pickingAttachment) return;
    final tipo = _tipo;
    if (tipo == null || !tipo.permiteAdjuntos) {
      _show('Este tipo de evento no permite adjuntos.', isError: true);
      return;
    }
    final source = await _showLegajoAttachmentSourceSheet(context);
    if (!mounted || source == null) return;
    setState(() {
      _pickingAttachment = true;
      _error = null;
    });
    try {
      final picked = switch (source) {
        _LegajoAttachmentSource.camera => await _pickLegajoCameraAttachment(),
        _LegajoAttachmentSource.gallery =>
          await _pickLegajoGalleryAttachments(),
        _LegajoAttachmentSource.file => await _pickLegajoFileAttachments(),
      };
      if (!mounted || picked.isEmpty) return;
      setState(() => _adjuntos.addAll(picked));
    } catch (_) {
      if (!mounted) return;
      _show('No se pudo adjuntar el archivo.', isError: true);
    } finally {
      if (mounted) setState(() => _pickingAttachment = false);
    }
  }

  void _removeAdjuntoAt(int index) {
    if (_saving) return;
    setState(() => _adjuntos.removeAt(index));
  }

  void _show(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? Colors.red[700] : Colors.green[700],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Cargar evento de legajo')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _tipos.isEmpty && _empleados.isEmpty
          ? _ErrorState(message: _error!, onRetry: _load)
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: [
                _HeaderCard(alcance: _alcance),
                const SizedBox(height: 12),
                if (_error != null) _InlineError(_error!),
                _SectionCard(
                  title: 'Empleado',
                  icon: Icons.person_search_outlined,
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchCtrl,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _search(),
                        decoration: InputDecoration(
                          labelText: 'Buscar por nombre, DNI o legajo',
                          suffixIcon: IconButton(
                            onPressed: _searching ? null : _search,
                            icon: _searching
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.search),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ..._empleados.map(
                        (e) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            _empleado?.id == e.id
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: _empleado?.id == e.id
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                          title: Text(e.title),
                          subtitle: Text(e.subtitle),
                          onTap: () => setState(() => _empleado = e),
                        ),
                      ),
                      if (_empleados.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 18),
                          child: Text('No hay empleados para mostrar.'),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'Evento',
                  icon: Icons.assignment_outlined,
                  child: Column(
                    children: [
                      DropdownButtonFormField<int>(
                        initialValue: _tipo?.id,
                        decoration: const InputDecoration(labelText: 'Tipo'),
                        items: _tipos
                            .map(
                              (t) => DropdownMenuItem<int>(
                                value: t.id,
                                child: Text(t.nombre),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          LegajoTipoEventoItem? selected;
                          for (final item in _tipos) {
                            if (item.id == value) {
                              selected = item;
                              break;
                            }
                          }
                          setState(() {
                            _tipo = selected;
                            if (selected?.permiteAdjuntos != true) {
                              _adjuntos.clear();
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _tituloCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Titulo opcional',
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: _severidad,
                        decoration: const InputDecoration(
                          labelText: 'Severidad',
                        ),
                        items: const [
                          DropdownMenuItem(value: 'leve', child: Text('Leve')),
                          DropdownMenuItem(
                            value: 'media',
                            child: Text('Media'),
                          ),
                          DropdownMenuItem(
                            value: 'grave',
                            child: Text('Grave'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => _severidad = value);
                        },
                      ),
                      const SizedBox(height: 10),
                      _DateTile(
                        label: 'Fecha del evento',
                        value: _dateLabel(_fechaEvento),
                        onTap: () => _pickDate(
                          initial: _fechaEvento,
                          onSelected: (d) => setState(() => _fechaEvento = d),
                        ),
                      ),
                      if (_tipo?.requiereRangoFechas == true) ...[
                        const SizedBox(height: 10),
                        _DateTile(
                          label: 'Desde',
                          value: _fechaDesde == null
                              ? 'Seleccionar'
                              : _dateLabel(_fechaDesde!),
                          onTap: () => _pickDate(
                            initial: _fechaDesde ?? _fechaEvento,
                            onSelected: (d) => setState(() => _fechaDesde = d),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _DateTile(
                          label: 'Hasta',
                          value: _fechaHasta == null
                              ? 'Seleccionar'
                              : _dateLabel(_fechaHasta!),
                          onTap: () => _pickDate(
                            initial: _fechaHasta ?? _fechaDesde ?? _fechaEvento,
                            onSelected: (d) => setState(() => _fechaHasta = d),
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      TextField(
                        controller: _descripcionCtrl,
                        minLines: 4,
                        maxLines: 7,
                        maxLength: 1200,
                        decoration: const InputDecoration(
                          labelText: 'Descripcion',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _AttachmentPickerBlock(
                        enabled:
                            _tipo?.permiteAdjuntos == true &&
                            !_saving &&
                            !_pickingAttachment,
                        picking: _pickingAttachment,
                        adjuntos: _adjuntos,
                        onAdd: _addAttachment,
                        onRemove: _removeAdjuntoAt,
                      ),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(_saving ? 'Guardando...' : 'Guardar evento'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            backgroundColor: cs.primary,
          ),
        ),
      ),
    );
  }
}

enum _LegajoAttachmentSource { camera, gallery, file }

class _DraftLegajoAdjunto {
  const _DraftLegajoAdjunto({
    required this.upload,
    required this.name,
    this.sizeBytes,
  });

  final JustificacionAdjuntoUpload upload;
  final String name;
  final int? sizeBytes;
}

class _AttachmentPickerBlock extends StatelessWidget {
  const _AttachmentPickerBlock({
    required this.enabled,
    required this.picking,
    required this.adjuntos,
    required this.onAdd,
    required this.onRemove,
  });

  final bool enabled;
  final bool picking;
  final List<_DraftLegajoAdjunto> adjuntos;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: enabled ? onAdd : null,
          icon: picking
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.attach_file),
          label: const Text('Agregar foto o archivo'),
        ),
        const SizedBox(height: 6),
        Text(
          enabled
              ? 'Fotos JPG/PNG/WebP o archivos PDF.'
              : 'El tipo seleccionado no permite adjuntos.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        if (adjuntos.isNotEmpty) ...[
          const SizedBox(height: 10),
          for (var i = 0; i < adjuntos.length; i++)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(_legajoAttachmentIcon(adjuntos[i].name)),
              title: Text(adjuntos[i].name),
              subtitle: Text(_formatLegajoBytes(adjuntos[i].sizeBytes)),
              trailing: IconButton(
                tooltip: 'Quitar adjunto',
                onPressed: enabled ? () => onRemove(i) : null,
                icon: const Icon(Icons.close),
              ),
            ),
        ],
      ],
    );
  }
}

Future<_LegajoAttachmentSource?> _showLegajoAttachmentSourceSheet(
  BuildContext context,
) {
  return showModalBottomSheet<_LegajoAttachmentSource>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Tomar foto'),
            onTap: () => Navigator.pop(context, _LegajoAttachmentSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Elegir fotos'),
            onTap: () =>
                Navigator.pop(context, _LegajoAttachmentSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.upload_file_outlined),
            title: const Text('Elegir archivo'),
            subtitle: const Text('PDF o imagen'),
            onTap: () => Navigator.pop(context, _LegajoAttachmentSource.file),
          ),
        ],
      ),
    ),
  );
}

Future<List<_DraftLegajoAdjunto>> _pickLegajoCameraAttachment() async {
  final photo = await ImagePicker().pickImage(
    source: ImageSource.camera,
    imageQuality: 85,
    maxWidth: 2048,
    maxHeight: 2048,
    requestFullMetadata: false,
  );
  if (photo == null) return const <_DraftLegajoAdjunto>[];
  final bytes = await photo.readAsBytes();
  if (bytes.isEmpty) return const <_DraftLegajoAdjunto>[];
  final filename = _normalizeLegajoAttachmentFilename(
    photo.name,
    fallbackExtension: 'jpg',
  );
  return [
    _DraftLegajoAdjunto(
      upload: JustificacionAdjuntoUpload(
        filename: filename,
        bytes: bytes,
        sizeBytes: bytes.length,
      ),
      name: filename,
      sizeBytes: bytes.length,
    ),
  ];
}

Future<List<_DraftLegajoAdjunto>> _pickLegajoGalleryAttachments() async {
  final images = await ImagePicker().pickMultiImage(
    imageQuality: 85,
    maxWidth: 2048,
    maxHeight: 2048,
    requestFullMetadata: false,
  );
  final items = <_DraftLegajoAdjunto>[];
  for (final image in images) {
    final bytes = await image.readAsBytes();
    if (bytes.isEmpty) continue;
    final filename = _normalizeLegajoAttachmentFilename(
      image.name,
      fallbackExtension: 'jpg',
    );
    items.add(
      _DraftLegajoAdjunto(
        upload: JustificacionAdjuntoUpload(
          filename: filename,
          bytes: bytes,
          sizeBytes: bytes.length,
        ),
        name: filename,
        sizeBytes: bytes.length,
      ),
    );
  }
  return items;
}

Future<List<_DraftLegajoAdjunto>> _pickLegajoFileAttachments() async {
  final result = await FilePicker.pickFiles(
    allowMultiple: true,
    withData: kIsWeb,
    type: FileType.custom,
    allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
  );
  if (result == null || result.files.isEmpty) {
    return const <_DraftLegajoAdjunto>[];
  }
  final items = <_DraftLegajoAdjunto>[];
  for (final file in result.files) {
    final filename = _normalizeLegajoAttachmentFilename(file.name);
    final bytes = file.bytes;
    if (bytes != null && bytes.isNotEmpty) {
      items.add(
        _DraftLegajoAdjunto(
          upload: JustificacionAdjuntoUpload(
            filename: filename,
            bytes: bytes,
            sizeBytes: file.size,
          ),
          name: filename,
          sizeBytes: file.size,
        ),
      );
      continue;
    }
    final path = file.path;
    if (path != null && path.trim().isNotEmpty) {
      items.add(
        _DraftLegajoAdjunto(
          upload: JustificacionAdjuntoUpload(
            filename: filename,
            path: path,
            sizeBytes: file.size,
          ),
          name: filename,
          sizeBytes: file.size,
        ),
      );
    }
  }
  return items;
}

String _normalizeLegajoAttachmentFilename(
  String rawName, {
  String fallbackExtension = 'pdf',
}) {
  final cleaned = rawName.trim().replaceAll(RegExp(r'[\\/]+'), ' ');
  final fallback = cleaned.isEmpty ? 'adjunto.$fallbackExtension' : cleaned;
  var base = fallback;
  var ext = fallbackExtension;
  final dot = fallback.lastIndexOf('.');
  if (dot > 0 && dot < fallback.length - 1) {
    base = fallback.substring(0, dot);
    ext = fallback.substring(dot + 1);
  }
  final safeBase = base
      .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  final safeExt = ext.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  final allowedExt = switch (safeExt) {
    'jpg' || 'jpeg' || 'png' || 'webp' || 'pdf' => safeExt,
    _ => fallbackExtension,
  };
  return '${safeBase.isEmpty ? 'adjunto' : safeBase}.$allowedExt';
}

IconData _legajoAttachmentIcon(String name) {
  final ext = name.split('.').last.toLowerCase();
  return switch (ext) {
    'jpg' || 'jpeg' || 'png' || 'webp' => Icons.image_outlined,
    'pdf' => Icons.picture_as_pdf_outlined,
    _ => Icons.attach_file,
  };
}

String _formatLegajoBytes(int? bytes) {
  if (bytes == null || bytes <= 0) return 'Tamano no disponible';
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(kb >= 100 ? 0 : 1)} KB';
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(mb >= 100 ? 0 : 1)} MB';
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({this.alcance});

  final String? alcance;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.admin_panel_settings_outlined, color: cs.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Carga administrativa',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                Text('Alcance: ${alcance ?? 'configurado'}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: cs.primary),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.event_outlined),
      title: Text(label),
      subtitle: Text(value),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red[700]),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

String _dateLabel(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String _dateParam(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

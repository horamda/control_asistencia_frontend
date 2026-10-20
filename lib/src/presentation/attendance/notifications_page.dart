import '../../core/utils/date_formatter.dart';
import '../theme/app_visual.dart';
import 'notification_settings_page.dart';
import 'package:flutter/material.dart';
import '../../core/network/mobile_api_client.dart';
import '../../core/reuniones/notifications_navigation.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({
    super.key,
    required this.api,
    required this.token,
    required this.onDestination,
    this.initialId,
  });
  final MobileApiClient api;
  final String token;
  final int? initialId;
  final Future<void> Function(Map<String, dynamic>) onDestination;
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.item, this.onTap});
  final Map<String, dynamic> item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final unread = item['leida'] != true;
    final icon = switch (item['modulo']) {
      'comunicados' => Icons.campaign_outlined,
      'reuniones' => Icons.groups_outlined,
      'vacaciones' => Icons.beach_access_outlined,
      _ => Icons.notifications_outlined,
    };
    final date = DateFormatter.formatApiDateForDisplay(
      item['creado_at']?.toString(),
      fallback: '',
    );
    return Semantics(
      button: true,
      label: unread ? 'Sin leer' : 'Leída',
      child: Material(
        color: unread
            ? Color.alphaBlend(cs.primary.withValues(alpha: .08), cs.surface)
            : cs.surface,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(AppVisual.cardPadding),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: .5),
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: cs.primaryContainer,
                    child: Icon(icon, color: cs.onPrimaryContainer, size: 21),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item['titulo'] ?? 'Notificación'}',
                        textAlign: TextAlign.start,
                        style: AppVisual.body.copyWith(
                          color: cs.onSurface,
                          fontWeight: unread
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item['mensaje'] ?? ''}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.start,
                        style: AppVisual.body.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      if (date.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          date,
                          style: AppVisual.caption.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (unread) ...[
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Icon(Icons.circle, size: 8, color: cs.primary),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationsPageState extends State<NotificationsPage>
    with WidgetsBindingObserver {
  final List<Map<String, dynamic>> items = [];
  String filter = 'todas';
  bool announcementsOnly = false;
  int? next, cutoff;
  int unread = 0, generation = 0;
  bool loading = false, writing = false;
  String? error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NotificationsNavigation.refresh.addListener(refresh);
    load();
    if ((widget.initialId ?? 0) > 0) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => open(widget.initialId!),
      );
    }
  }

  void refresh() {
    if (!writing) load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    NotificationsNavigation.refresh.removeListener(refresh);
    super.dispose();
  }

  String message(Object e) =>
      e is ApiException && [404, 503].contains(e.statusCode)
      ? 'La bandeja todavía no está disponible en el servidor. Volvé a intentar más tarde.'
      : e is ApiException
      ? e.message
      : 'No se pudo completar la operación. Reintentá.';
  Future<void> load({bool more = false}) async {
    if (more && (loading || next == null)) return;
    final request = ++generation;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await widget.api.getNotifications(
        token: widget.token,
        query: {
          'estado': filter,
          if (announcementsOnly) 'modulo': 'comunicados',
          'limite': '20',
          if (more) 'antes_de': '$next',
        },
      );
      if (!mounted || request != generation) return;
      setState(() {
        if (!more) {
          items.clear();
          cutoff = (data['corte'] as num?)?.toInt();
        }
        for (final raw in (data['items'] as List? ?? [])) {
          final item = Map<String, dynamic>.from(raw as Map);
          if (!items.any((old) => old['id'] == item['id'])) items.add(item);
        }
        next = (data['siguiente'] as num?)?.toInt();
        unread = (data['no_leidas'] as num?)?.toInt() ?? 0;
      });
    } catch (e) {
      if (mounted && request == generation) setState(() => error = message(e));
    } finally {
      if (mounted && request == generation) setState(() => loading = false);
    }
  }

  Future<void> open(int id) async {
    if (writing) return;
    setState(() {
      generation++;
      loading = false;
      writing = true;
      error = null;
    });
    bool success = false;
    try {
      final detail = await widget.api.getNotifications(
        token: widget.token,
        suffix: '/$id',
      );
      await widget.api.readNotifications(token: widget.token, id: id);
      success = true;
      NotificationsNavigation.refresh.value++;
      if (!mounted) return;
      setState(() => writing = false);
      final available = (detail['referencia'] as Map?)?['disponible'] != false;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          scrollable: true,
          title: Text('${detail['titulo'] ?? 'Notificación'}'),
          content: Text(
            '${detail['mensaje'] ?? ''}${available ? '' : '\n\nEste trámite ya no está disponible.'}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar'),
            ),
            if (available && detail['destino'] is Map)
              FilledButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await widget.onDestination(
                    Map<String, dynamic>.from(detail['destino']),
                  );
                },
                child: const Text('Ver detalle'),
              ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) setState(() => error = message(e));
    } finally {
      if (mounted) {
        setState(() => writing = false);
        if (success) await load();
      }
    }
  }

  Future<void> readAll() async {
    if (cutoff == null || writing || loading) return;
    setState(() => writing = true);
    try {
      final data = await widget.api.readNotifications(
        token: widget.token,
        cutoff: cutoff,
        module: announcementsOnly ? 'comunicados' : null,
      );
      if (!mounted) return;
      setState(() => unread = (data['no_leidas'] as num?)?.toInt() ?? unread);
      NotificationsNavigation.refresh.value++;
      await load();
    } catch (e) {
      if (mounted) setState(() => error = message(e));
    } finally {
      if (mounted) setState(() => writing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Notificaciones'),
      actions: [
        IconButton(
          tooltip: 'Permisos de avisos',
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const NotificationSettingsPage(),
            ),
          ),
        ),
      ],
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: RefreshIndicator(
            onRefresh: () => load(),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverMainAxisGroup(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '$unread sin leer',
                              style: AppVisual.sectionTitle,
                              textAlign: TextAlign.start,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              alignment: WrapAlignment.start,
                              spacing: 8,
                              children: [
                                for (final entry in {
                                  'todas': 'Todas',
                                  'no_leidas': 'Sin leer',
                                  'leidas': 'Leídas',
                                }.entries)
                                  ChoiceChip(
                                    label: Text(entry.value),
                                    selected: filter == entry.key,
                                    onSelected: writing
                                        ? null
                                        : (_) {
                                            setState(() => filter = entry.key);
                                            load();
                                          },
                                  ),
                              ],
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: FilterChip(
                                label: const Text('Solo comunicados'),
                                avatar: const Icon(
                                  Icons.campaign_outlined,
                                  size: 18,
                                ),
                                selected: announcementsOnly,
                                onSelected: writing
                                    ? null
                                    : (value) {
                                        setState(
                                          () => announcementsOnly = value,
                                        );
                                        load();
                                      },
                              ),
                            ),
                            TextButton.icon(
                              onPressed:
                                  writing ||
                                      loading ||
                                      unread == 0 ||
                                      cutoff == null
                                  ? null
                                  : readAll,
                              icon: const Icon(Icons.done_all),
                              label: Text(
                                announcementsOnly
                                    ? 'Marcar comunicados como leídos'
                                    : 'Marcar todas como leídas',
                              ),
                            ),
                            if (loading || writing)
                              const LinearProgressIndicator(),
                            if (error != null) ...[
                              Text(error!, textAlign: TextAlign.center),
                              TextButton(
                                onPressed: loading ? null : () => load(),
                                child: const Text('Reintentar'),
                              ),
                            ],
                            if (!loading && error == null && items.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(24),
                                child: Text(
                                  'No hay notificaciones para mostrar.',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                          ],
                        ),
                      ),
                      SliverList.builder(
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return _NotificationRow(
                            item: item,
                            onTap: writing
                                ? null
                                : () => open((item['id'] as num).toInt()),
                          );
                        },
                      ),
                      SliverToBoxAdapter(
                        child: Column(
                          children: [
                            if (next != null)
                              OutlinedButton(
                                onPressed: loading || writing
                                    ? null
                                    : () => load(more: true),
                                child: const Text('Cargar más'),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

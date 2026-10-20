import 'package:flutter/material.dart';
import '../../../core/network/reuniones_models.dart';
import '../../widgets/app_card.dart';

/// A short home preview; the full agenda and statistics live in Mis reuniones.
class HomeReunionesCard extends StatelessWidget {
  const HomeReunionesCard({
    super.key,
    required this.items,
    required this.onOpen,
    required this.onDetail,
    required this.onRetry,
    this.onScan,
    this.summary,
    this.next,
    this.hasNext,
    this.loading = false,
    this.error,
  });
  final List<ReunionOccurrence> items;
  final Map<String, dynamic>? summary, next;
  final bool? hasNext;
  final bool loading;
  final String? error;
  final VoidCallback onOpen, onRetry;
  final VoidCallback? onScan;
  final ValueChanged<int> onDetail;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    int priority(ReunionOccurrence item) => item.cancelada
        ? 3
        : switch (item.estado) {
            'abierta' => 0,
            'pendiente' => 1,
            _ => 2,
          };
    final sorted = [...items]
      ..sort((a, b) {
        final order = priority(a).compareTo(priority(b));
        return order != 0 ? order : a.inicio.compareTo(b.inicio);
      });
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: onOpen,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(
                  children: [
                    Icon(
                      Icons.groups_outlined,
                      size: 20,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Reuniones · esta semana',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 20),
                  ],
                ),
              ),
            ),
            if (loading) const LinearProgressIndicator(minHeight: 2),
            if (summary != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${summary!['reuniones'] ?? items.length} reuniones · ${summary!['pendientes'] ?? 0} pendientes · ${summary!['registradas'] ?? 0} registradas',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.3,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            if (error != null) ...[
              Text(
                error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
              TextButton(onPressed: onRetry, child: const Text('Reintentar')),
            ],
            if (!loading && error == null && items.isEmpty)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  next != null
                      ? 'Pr?xima: ${next!['nombre'] ?? 'Reuni?n'} ? ${reunionDateTime(next!['inicio'] ?? next!['fecha'])}'
                      : hasNext == false
                      ? 'No hay pr?ximas reuniones.'
                      : 'No ten?s reuniones esta semana.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            for (final item in sorted.take(2)) ...[
              const Divider(height: 1),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => onDetail(item.reunionId),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Column(
                          children: [
                            Tooltip(
                              message: item.nombre,
                              child: Text(
                                item.nombre,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.2,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${reunionDateTime(item.data['inicio'])} · ${reunionStateLabel(item.cancelada ? 'cancelada' : item.estado)}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.3,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (item.data['puede_registrar'] == true && !item.cancelada)
                    IconButton(
                      onPressed: onScan,
                      tooltip: 'Escanear QR de reunión',
                      icon: Icon(
                        Icons.qr_code_scanner,
                        size: 22,
                        color: colors.primary,
                      ),
                    ),
                ],
              ),
            ],
            TextButton(
              onPressed: onOpen,
              child: const Text(
                'Ver agenda completa',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

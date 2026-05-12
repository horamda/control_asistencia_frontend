import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/offline/offline_clock_queue.dart';
import '../../../core/offline/pending_queue_controller.dart';

class PendingQueueSheet extends StatelessWidget {
  const PendingQueueSheet({
    super.key,
    required this.queueState,
    required this.formatDateTime,
    required this.onSync,
    required this.onClearAll,
    required this.onRetry,
    required this.onDelete,
  });

  final ValueListenable<PendingQueueState> queueState;
  final String Function(DateTime dateTime) formatDateTime;
  final Future<void> Function() onSync;
  final Future<void> Function(BuildContext context) onClearAll;
  final Future<void> Function(OfflineClockRecord record) onRetry;
  final Future<void> Function(OfflineClockRecord record) onDelete;

  @override
  Widget build(BuildContext context) {
    // Calculamos la altura disponible real restando safe-area y el padding del
    // sheet. Sin este calculo, en pantallas < 500px de alto (landscape o
    // celulares muy pequeños) el SizedBox puede desbordar y causar un overflow.
    final mq = MediaQuery.of(context);
    final availableH = mq.size.height
        - mq.viewPadding.top
        - mq.viewPadding.bottom
        - 32; // padding vertical del sheet
    final sheetH = (mq.size.height * 0.82).clamp(280.0, availableH);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: sheetH,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bandeja de sincronización',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              const Text(
                'Fichadas guardadas localmente hasta recuperar internet.',
              ),
              const SizedBox(height: 10),
              ValueListenableBuilder<PendingQueueState>(
                valueListenable: queueState,
                builder: (_, state, __) {
                  return Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: state.syncing ? null : () => unawaited(onSync()),
                          icon: state.syncing
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.sync),
                          label: Text(
                            state.syncing
                                ? 'Sincronizando...'
                                : 'Sincronizar ahora',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: state.syncing
                              ? null
                              : () => unawaited(onClearAll(context)),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Limpiar cola'),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<PendingQueueState>(
                valueListenable: queueState,
                builder: (_, state, __) {
                  final text = state.lastMessage;
                  if (text == null || text.trim().isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(text),
                  );
                },
              ),
              Expanded(
                child: ValueListenableBuilder<PendingQueueState>(
                  valueListenable: queueState,
                  builder: (_, state, __) {
                    final items = state.records;
                    if (items.isEmpty) {
                      return const Center(
                        child: Text('No hay fichadas pendientes.'),
                      );
                    }
                    return ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, index) {
                        final item = items[index];
                        final cs = Theme.of(context).colorScheme;
                        final isFailed =
                            item.status == OfflineClockStatus.failed;
                        final statusBg =
                            isFailed ? cs.errorContainer : cs.secondaryContainer;
                        final statusFg = isFailed
                            ? cs.onErrorContainer
                            : cs.onSecondaryContainer;
                        final statusLabel = isFailed ? 'Error' : 'Pendiente';
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Fecha: ${formatDateTime(item.eventAt)}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall,
                                      ),
                                    ),
                                    Chip(
                                      label: Text(
                                        statusLabel,
                                        style: TextStyle(color: statusFg),
                                      ),
                                      backgroundColor: statusBg,
                                    ),
                                  ],
                                ),
                                Text('Intentos: ${item.attempts}'),
                                if (item.lastAttemptAt != null)
                                  Text(
                                    'Último intento: ${formatDateTime(item.lastAttemptAt!)}',
                                  ),
                                if ((item.lastError ?? '').trim().isNotEmpty)
                                  Text(
                                    'Último error: ${item.lastError}',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.error,
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      onPressed: state.syncing
                                          ? null
                                          : () => unawaited(onRetry(item)),
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('Reintentar'),
                                    ),
                                    const SizedBox(width: 6),
                                    TextButton.icon(
                                      onPressed: state.syncing
                                          ? null
                                          : () => unawaited(onDelete(item)),
                                      icon: const Icon(Icons.delete_outline),
                                      label: const Text('Eliminar'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


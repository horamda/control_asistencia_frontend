import 'package:ficharqr/src/presentation/widgets/app_card.dart';
import 'package:ficharqr/src/presentation/theme/app_palette.dart';
import 'dart:async';
import '../../widgets/app_page_layout.dart';

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
  Widget build(BuildContext context) => SafeArea(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final media = MediaQuery.of(context);
        final available = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : media.size.height -
                  media.viewInsets.bottom -
                  media.padding.vertical;
        final height = (media.size.height * .82).clamp(
          0.0,
          available.clamp(0.0, double.infinity),
        );
        return SizedBox(
          height: height,
          child: ValueListenableBuilder<PendingQueueState>(
            valueListenable: queueState,
            builder: (context, state, _) {
              final items = state.records;
              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        children: [
                          Text(
                            'Bandeja de sincronización',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Fichadas guardadas localmente hasta recuperar internet.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          AppAdaptiveActions(
                            children: [
                              OutlinedButton.icon(
                                onPressed: state.syncing
                                    ? null
                                    : () => unawaited(onSync()),
                                icon: state.syncing
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.sync_rounded),
                                label: Text(
                                  state.syncing
                                      ? 'Sincronizando...'
                                      : 'Sincronizar ahora',
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: state.syncing
                                    ? null
                                    : () => unawaited(onClearAll(context)),
                                icon: const Icon(Icons.delete_outline_rounded),
                                label: const Text('Limpiar cola'),
                              ),
                            ],
                          ),
                          if ((state.lastMessage ?? '').isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                state.lastMessage!,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          if (items.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'No hay fichadas pendientes.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverList.builder(
                      itemCount: items.length,
                      itemBuilder: (_, index) {
                        final item = items[index];
                        final cs = Theme.of(context).colorScheme;
                        final isFailed =
                            item.status == OfflineClockStatus.failed;
                        final statusBg = isFailed
                            ? cs.errorContainer
                            : cs.secondaryContainer;
                        final statusFg = isFailed
                            ? cs.onErrorContainer
                            : cs.onSecondaryContainer;
                        final statusLabel = isFailed ? 'Error' : 'Pendiente';
                        return AppCard(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Fecha: ${formatDateTime(item.eventAt)}',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleSmall,
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    Chip(
                                      label: Text(
                                        statusLabel,
                                        style: TextStyle(
                                          color: AppColors.of(
                                            context,
                                          ).foreground(statusFg),
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      backgroundColor: AppColors.of(
                                        context,
                                      ).surface(statusBg),
                                    ),
                                  ],
                                ),
                                Text(
                                  'Intentos: ${item.attempts}',
                                  textAlign: TextAlign.center,
                                ),
                                if (item.lastAttemptAt != null)
                                  Text(
                                    'Último intento: ${formatDateTime(item.lastAttemptAt!)}',
                                    textAlign: TextAlign.center,
                                  ),
                                if ((item.lastError ?? '').trim().isNotEmpty)
                                  Text(
                                    'Último error: ${item.lastError}',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                const SizedBox(height: 8),
                                AppAdaptiveActions(
                                  children: [
                                    TextButton.icon(
                                      onPressed: state.syncing
                                          ? null
                                          : () => unawaited(onRetry(item)),
                                      icon: const Icon(Icons.refresh_rounded),
                                      label: const Text(
                                        'Reintentar',
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    TextButton.icon(
                                      onPressed: state.syncing
                                          ? null
                                          : () => unawaited(onDelete(item)),
                                      icon: const Icon(Icons.delete_rounded),
                                      label: const Text(
                                        'Eliminar',
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    ),
  );
}

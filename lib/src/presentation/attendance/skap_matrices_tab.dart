import 'package:flutter/material.dart';
import '../../core/network/mobile_api_client.dart';
import 'widgets/skap_matrix_dashboard.dart';
import 'widgets/skap_evaluations_list.dart';

/// Personal, read-only operational evaluations. Historical roles remain separate.
class SkapMatricesTab extends StatefulWidget {
  const SkapMatricesTab({
    super.key,
    required this.apiClient,
    required this.token,
  });
  final MobileApiClient apiClient;
  final String token;
  @override
  State<SkapMatricesTab> createState() => _SkapMatricesTabState();
}

class _SkapMatricesTabState extends State<SkapMatricesTab> {
  late Future<List<Map<String, dynamic>>> _future;
  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() =>
      widget.apiClient.getSkapMatrices(token: widget.token);
  Future<void> _refresh() async {
    final next = _load();
    setState(() {
      _future = next;
    });
    try {
      await next;
    } catch (_) {
      /* FutureBuilder displays the error. */
    }
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No se pudieron cargar tus evaluaciones.'),
                  TextButton(
                    onPressed: _refresh,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }
          return SkapEvaluationsList(
            rows: snapshot.data ?? [],
            onRefresh: _refresh,
            onOpen: (row) => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => _MatrizDetail(
                  apiClient: widget.apiClient,
                  token: widget.token,
                  id: row['id'] as int,
                ),
              ),
            ),
          );
        },
      );
}

class _MatrizDetail extends StatefulWidget {
  const _MatrizDetail({
    required this.apiClient,
    required this.token,
    required this.id,
  });
  final MobileApiClient apiClient;
  final String token;
  final int id;
  @override
  State<_MatrizDetail> createState() => _MatrizDetailState();
}

class _MatrizDetailState extends State<_MatrizDetail> {
  late Future<Map<String, dynamic>> _future;
  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() =>
      widget.apiClient.getSkapMatriz(token: widget.token, id: widget.id);
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mi evaluación')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('La evaluación no está disponible.'),
                TextButton(
                  onPressed: () => setState(() {
                    _future = _load();
                  }),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          );
        }
        return SafeArea(
          top: false,
          child: SkapMatrixDashboard(data: snapshot.data!),
        );
      },
    ),
  );
}

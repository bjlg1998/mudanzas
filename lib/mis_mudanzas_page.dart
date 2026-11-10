import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_theme.dart';
import 'core/backend.dart';
import 'move_detail_page.dart';
import 'services/auth_service.dart';
import 'services/move_service.dart';
import 'services/route_service.dart';

class MisMudanzasPage extends StatefulWidget {
  const MisMudanzasPage({
    super.key,
    this.embedded = false,
    this.role = AccountRole.customer,
  });

  final bool embedded;
  final AccountRole role;

  @override
  State<MisMudanzasPage> createState() => _MisMudanzasPageState();
}

class _MisMudanzasPageState extends State<MisMudanzasPage> {
  late Future<List<MoveSummary>> _moves;
  RealtimeChannel? _channel;
  String? _updatingId;

  @override
  void initState() {
    super.initState();
    _moves = _load();
    if (Backend.isConfigured) {
      _channel =
          Backend.client
              .channel('my-moves-${Backend.client.auth.currentUser?.id}')
              .onPostgresChanges(
                event: PostgresChangeEvent.all,
                schema: 'public',
                table: 'move_requests',
                callback: (_) => _refresh(),
              )
            ..subscribe();
    }
  }

  @override
  void dispose() {
    final channel = _channel;
    if (channel != null && Backend.isConfigured) {
      Backend.client.removeChannel(channel);
    }
    super.dispose();
  }

  Future<List<MoveSummary>> _load() {
    if (!Backend.isConfigured) return Future.value(const <MoveSummary>[]);
    return widget.role == AccountRole.driver
        ? MoveService().driverMoves()
        : MoveService().customerMoves();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    final next = _load();
    setState(() => _moves = next);
    await next;
  }

  Future<void> _updateMove(MoveSummary move, {required bool cancel}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(cancel ? Icons.cancel_outlined : Icons.task_alt),
        title: Text(cancel ? '¿Cancelar servicio?' : '¿Finalizar servicio?'),
        content: Text(
          cancel
              ? 'Esta acción dejará la solicitud como cancelada.'
              : 'Confirma que la mudanza ya terminó.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(cancel ? 'Sí, cancelar' : 'Sí, finalizar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _updatingId = move.id);
    try {
      if (cancel) {
        await MoveService().cancelMove(move.id);
      } else {
        await MoveService().completeMove(move.id);
      }
      await _refresh();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            cancel
                ? 'No se pudo cancelar el servicio.'
                : 'No se pudo finalizar el servicio.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _updatingId = null);
    }
  }

  Future<void> _openMove(MoveSummary move) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MoveDetailPage(move: move, role: widget.role),
      ),
    );
    if (mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final content = FutureBuilder<List<MoveSummary>>(
      future: _moves,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _MessageState(
            icon: Icons.cloud_off_outlined,
            title: 'No pudimos cargar tus mudanzas',
            actionLabel: 'Reintentar',
            onAction: _refresh,
          );
        }
        final moves = snapshot.data ?? const <MoveSummary>[];
        if (moves.isEmpty) {
          return _MessageState(
            icon: Icons.inventory_2_outlined,
            title: widget.role == AccountRole.driver
                ? 'No tienes servicios asignados'
                : 'Aún no tienes mudanzas',
            description: widget.role == AccountRole.driver
                ? 'Cuando tomes un servicio, aparecerá aquí.'
                : 'Cuando solicites una, aparecerá aquí.',
          );
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.separated(
            key: const Key('movesList'),
            padding: const EdgeInsets.all(20),
            itemCount: moves.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final move = moves[index];
              return _MoveCard(
                move: move,
                role: widget.role,
                loading: _updatingId == move.id,
                onCancel: () => _updateMove(move, cancel: true),
                onComplete: () => _updateMove(move, cancel: false),
                onOpen: () => _openMove(move),
              );
            },
          ),
        );
      },
    );
    if (widget.embedded) {
      return SafeArea(top: false, child: content);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Mis mudanzas')),
      body: content,
    );
  }
}

class _MoveCard extends StatelessWidget {
  const _MoveCard({
    required this.move,
    required this.role,
    required this.loading,
    required this.onCancel,
    required this.onComplete,
    required this.onOpen,
  });

  final MoveSummary move;
  final AccountRole role;
  final bool loading;
  final VoidCallback onCancel;
  final VoidCallback onComplete;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final status = _statusInfo(move.status);
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        key: Key('openMove-${move.id}'),
        onTap: onOpen,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _vehicleLabel(move.vehicleType),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: status.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      status.label,
                      style: TextStyle(
                        color: status.color,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              if (move.routeDistanceMeters != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.route, size: 20, color: AppColors.teal),
                    const SizedBox(width: 7),
                    Text(
                      '${distanceLabel(move.routeDistanceMeters)} de recorrido',
                      style: const TextStyle(
                        color: AppColors.teal,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              _LocationLine(
                color: const Color(0xFF28A66A),
                label: 'Inicio',
                address: move.originAddress,
              ),
              Padding(
                padding: const EdgeInsets.only(left: 5),
                child: Container(
                  width: 2,
                  height: 14,
                  color: const Color(0xFFD7DDE8),
                ),
              ),
              _LocationLine(
                color: const Color(0xFFE45858),
                label: 'Destino',
                address: move.destinationAddress,
              ),
              if (move.customerNotes?.trim().isNotEmpty ?? false) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3D6),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5B94F)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.campaign_outlined,
                        color: Color(0xFF805B00),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Indicaciones del cliente',
                              style: TextStyle(
                                color: Color(0xFF5E4300),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              move.customerNotes!.trim(),
                              style: const TextStyle(
                                color: Color(0xFF4D3A0A),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Text(
                _dateLabel(move.createdAt),
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.map_outlined,
                    size: 19,
                    color: AppColors.blue,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'Ver mapa y detalles',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right, color: AppColors.muted),
                ],
              ),
              if (_canCancel || _canComplete) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (_canCancel)
                      OutlinedButton.icon(
                        key: Key('cancelMove-${move.id}'),
                        onPressed: loading ? null : onCancel,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error,
                        ),
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Cancelar'),
                      ),
                    if (_canComplete)
                      FilledButton.icon(
                        key: Key('completeMove-${move.id}'),
                        onPressed: loading ? null : onComplete,
                        icon: const Icon(Icons.task_alt),
                        label: const Text('Marcar finalizado'),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  bool get _canCancel =>
      role == AccountRole.customer &&
      move.status != 'completed' &&
      move.status != 'cancelled';

  bool get _canComplete =>
      (move.status == 'driver_assigned' || move.status == 'in_progress') &&
      (role == AccountRole.customer || role == AccountRole.driver);
}

class _LocationLine extends StatelessWidget {
  const _LocationLine({
    required this.color,
    required this.label,
    required this.address,
  });

  final Color color;
  final String label;
  final String address;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              Text(
                address,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: const Color(0xFF9AA3B7)),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (description != null) ...[
              const SizedBox(height: 8),
              Text(
                description!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted),
              ),
            ],
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: 20),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

({String label, Color color}) _statusInfo(String value) => switch (value) {
  'draft' => (label: 'Borrador', color: AppColors.muted),
  'requested' => (label: 'Solicitada', color: AppColors.blue),
  'quoted' => (label: 'Cotizada', color: const Color(0xFF8A5BD7)),
  'accepted' => (label: 'Aceptada', color: const Color(0xFF168A55)),
  'driver_assigned' => (
    label: 'Conductor asignado',
    color: const Color(0xFF168A55),
  ),
  'in_progress' => (label: 'En camino', color: const Color(0xFFE58A21)),
  'completed' => (label: 'Completada', color: const Color(0xFF168A55)),
  'cancelled' => (label: 'Cancelada', color: const Color(0xFFD14343)),
  _ => (label: value, color: AppColors.muted),
};

String _vehicleLabel(String value) => switch (value) {
  'motocarro' => 'Motocarro',
  'camioneta_estacas' => 'Camioneta de estacas',
  'turbo' => 'Turbo',
  _ => value,
};

String _dateLabel(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(value.day)}/${two(value.month)}/${value.year} · '
      '${two(value.hour)}:${two(value.minute)}';
}

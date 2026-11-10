import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_theme.dart';
import 'core/backend.dart';
import 'move_detail_page.dart';
import 'services/move_service.dart';
import 'services/route_service.dart';

class ServiciosDisponiblesPage extends StatefulWidget {
  const ServiciosDisponiblesPage({super.key});

  @override
  State<ServiciosDisponiblesPage> createState() =>
      _ServiciosDisponiblesPageState();
}

class _ServiciosDisponiblesPageState extends State<ServiciosDisponiblesPage> {
  late Future<List<MoveSummary>> _moves;
  RealtimeChannel? _channel;
  String? _claimingId;

  @override
  void initState() {
    super.initState();
    _moves = _load();
    if (Backend.isConfigured) {
      _channel =
          Backend.client
              .channel('available-moves')
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

  Future<List<MoveSummary>> _load() => Backend.isConfigured
      ? MoveService().availableMoves()
      : Future.value(const <MoveSummary>[]);

  Future<void> _refresh() async {
    if (!mounted) return;
    final next = _load();
    setState(() => _moves = next);
    await next;
  }

  Future<void> _confirmClaim(MoveSummary move) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.local_shipping_outlined, size: 44),
        title: const Text('¿Tomar este servicio?'),
        content: const Text(
          'Al confirmar, la mudanza quedará asignada a tu cuenta.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('confirmClaimMove'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, tomar servicio'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _claimingId = move.id);
    try {
      await MoveService().claimMove(move.id);
      if (!mounted) return;
      final assignedMove = await MoveService().moveById(move.id);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MoveDetailPage(move: assignedMove),
        ),
      );
      if (!mounted) return;
      await _refresh();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El servicio ya fue tomado o no está disponible.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _claimingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Servicios disponibles')),
      body: FutureBuilder<List<MoveSummary>>(
        future: _moves,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _EmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'No pudimos cargar los servicios',
              description: 'Revisa tu conexión e inténtalo de nuevo.',
              onRefresh: _refresh,
            );
          }
          final moves = snapshot.data ?? const <MoveSummary>[];
          if (moves.isEmpty) {
            return _EmptyState(
              icon: Icons.notifications_none,
              title: 'No hay solicitudes disponibles',
              description:
                  'Esta pantalla se actualizará cuando llegue una nueva.',
              onRefresh: _refresh,
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              key: const Key('availableMovesList'),
              padding: const EdgeInsets.all(20),
              itemCount: moves.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final move = moves[index];
                return _AvailableMoveCard(
                  move: move,
                  loading: _claimingId == move.id,
                  onClaim: () => _confirmClaim(move),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _AvailableMoveCard extends StatelessWidget {
  const _AvailableMoveCard({
    required this.move,
    required this.loading,
    required this.onClaim,
  });

  final MoveSummary move;
  final bool loading;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.local_shipping_outlined,
                  color: AppColors.blue,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _vehicleLabel(move.vehicleType),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE4F1F3),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    distanceLabel(move.routeDistanceMeters),
                    style: const TextStyle(
                      color: AppColors.teal,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _RouteLine(
              icon: Icons.radio_button_checked,
              label: 'Recoger en',
              value: move.originAddress,
            ),
            const SizedBox(height: 12),
            _RouteLine(
              icon: Icons.location_on,
              label: 'Entregar en',
              value: move.destinationAddress,
            ),
            if (move.customerNotes?.trim().isNotEmpty ?? false) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3D6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5B94F)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.campaign_outlined,
                      color: Color(0xFF805B00),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        move.customerNotes!.trim(),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              key: Key('claimMove-${move.id}'),
              onPressed: loading ? null : onClaim,
              icon: Icon(loading ? Icons.hourglass_top : Icons.check_circle),
              label: Text(loading ? 'Asignando…' : 'Tomar servicio'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteLine extends StatelessWidget {
  const _RouteLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.teal),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.description,
    required this.onRefresh,
  });

  final IconData icon;
  final String title;
  final String description;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: AppColors.muted),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(description, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Actualizar'),
            ),
          ],
        ),
      ),
    );
  }
}

String _vehicleLabel(String value) => switch (value) {
  'motocarro' => 'Motocarro',
  'camioneta_estacas' => 'Camioneta de estacas',
  'turbo' => 'Turbo',
  _ => value,
};

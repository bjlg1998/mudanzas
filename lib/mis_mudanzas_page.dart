import 'package:flutter/material.dart';

import 'core/backend.dart';
import 'services/move_service.dart';

class MisMudanzasPage extends StatefulWidget {
  const MisMudanzasPage({super.key});

  @override
  State<MisMudanzasPage> createState() => _MisMudanzasPageState();
}

class _MisMudanzasPageState extends State<MisMudanzasPage> {
  late Future<List<MoveSummary>> _moves;

  @override
  void initState() {
    super.initState();
    _moves = _load();
  }

  Future<List<MoveSummary>> _load() => Backend.isConfigured
      ? MoveService().myMoves()
      : Future.value(const <MoveSummary>[]);

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _moves = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis mudanzas')),
      body: FutureBuilder<List<MoveSummary>>(
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
            return const _MessageState(
              icon: Icons.inventory_2_outlined,
              title: 'Aún no tienes mudanzas',
              description: 'Cuando solicites una, aparecerá aquí.',
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              key: const Key('movesList'),
              padding: const EdgeInsets.all(20),
              itemCount: moves.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _MoveCard(move: moves[index]),
            ),
          );
        },
      ),
    );
  }
}

class _MoveCard extends StatelessWidget {
  const _MoveCard({required this.move});

  final MoveSummary move;

  @override
  Widget build(BuildContext context) {
    final status = _statusInfo(move.status);
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE5E9F1)),
      ),
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
            const SizedBox(height: 14),
            Text(
              _dateLabel(move.createdAt),
              style: const TextStyle(color: Color(0xFF7A8398), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
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
                style: const TextStyle(color: Color(0xFF7A8398), fontSize: 12),
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
                style: const TextStyle(color: Color(0xFF7A8398)),
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
  'draft' => (label: 'Borrador', color: const Color(0xFF7A8398)),
  'requested' => (label: 'Solicitada', color: const Color(0xFF2457C5)),
  'quoted' => (label: 'Cotizada', color: const Color(0xFF8A5BD7)),
  'accepted' => (label: 'Aceptada', color: const Color(0xFF168A55)),
  'driver_assigned' => (
    label: 'Conductor asignado',
    color: const Color(0xFF168A55),
  ),
  'in_progress' => (label: 'En camino', color: const Color(0xFFE58A21)),
  'completed' => (label: 'Completada', color: const Color(0xFF168A55)),
  'cancelled' => (label: 'Cancelada', color: const Color(0xFFD14343)),
  _ => (label: value, color: const Color(0xFF7A8398)),
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

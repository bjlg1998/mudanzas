import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:map_launcher/map_launcher.dart';

import 'app_theme.dart';
import 'services/auth_service.dart';
import 'services/move_service.dart';
import 'services/route_service.dart';

class MoveDetailPage extends StatefulWidget {
  const MoveDetailPage({
    super.key,
    required this.move,
    this.role = AccountRole.driver,
  });

  final MoveSummary move;
  final AccountRole role;

  @override
  State<MoveDetailPage> createState() => _MoveDetailPageState();
}

class _MoveDetailPageState extends State<MoveDetailPage> {
  final _mapController = MapController();
  late MoveSummary _move;
  late Future<List<LatLng>> _route;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _move = widget.move;
    _route = _loadRoute();
  }

  Future<List<LatLng>> _loadRoute() async {
    final points = await RouteService().path(
      originLatitude: _move.originLatitude,
      originLongitude: _move.originLongitude,
      destinationLatitude: _move.destinationLatitude,
      destinationLongitude: _move.destinationLongitude,
    );
    return points
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList(growable: false);
  }

  Future<void> _openMaps({required bool completeRoute}) async {
    final request = MapLauncher.directions(
      Location.coords(
        completeRoute ? _move.destinationLatitude : _move.originLatitude,
        completeRoute ? _move.destinationLongitude : _move.originLongitude,
        title: completeRoute ? 'Punto de entrega' : 'Punto de recogida',
      ),
      from: completeRoute
          ? Location.coords(
              _move.originLatitude,
              _move.originLongitude,
              title: 'Punto de recogida',
            )
          : null,
      mode: TravelMode.driving,
    );

    try {
      final supported = await request.getSupportedMaps(const [
        MapApp.google,
        MapApp.waze,
      ]);
      final installed = supported.where((map) => map.isInstalled).toList();
      if (!mounted) return;

      if (installed.length == 1) {
        await installed.first.show();
        return;
      }
      if (installed.length > 1) {
        final selected = await showModalBottomSheet<SupportedMap>(
          context: context,
          showDragHandle: true,
          builder: (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Text(
                    'Abrir con',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                for (final map in installed)
                  ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(map.iconBytes, width: 40, height: 40),
                    ),
                    title: Text(map.name),
                    trailing: const Icon(Icons.open_in_new),
                    onTap: () => Navigator.pop(context, map),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
        await selected?.show();
        return;
      }

      // Si no hay una app compatible instalada, abre la ruta universal.
      await request.show();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No pudimos abrir una aplicación de mapas.'),
        ),
      );
    }
  }

  Future<void> _completeMove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.task_alt, size: 42),
        title: const Text('¿Finalizar el servicio?'),
        content: const Text('Confirma que la mudanza ya fue completada.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, finalizar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _updating = true);
    try {
      await MoveService().completeMove(_move.id);
      final updated = await MoveService().moveById(_move.id);
      if (!mounted) return;
      setState(() => _move = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Servicio marcado como finalizado.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo finalizar el servicio.')),
      );
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final origin = LatLng(_move.originLatitude, _move.originLongitude);
    final destination = LatLng(
      _move.destinationLatitude,
      _move.destinationLongitude,
    );
    final center = LatLng(
      (origin.latitude + destination.latitude) / 2,
      (origin.longitude + destination.longitude) / 2,
    );
    final canComplete =
        widget.role == AccountRole.driver &&
        (_move.status == 'driver_assigned' || _move.status == 'in_progress');

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del servicio')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          SizedBox(
            height: 310,
            child: FutureBuilder<List<LatLng>>(
              future: _route,
              builder: (context, snapshot) {
                final route = snapshot.data ?? [origin, destination];
                if (snapshot.hasData) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    _mapController.fitCamera(
                      CameraFit.bounds(
                        bounds: LatLngBounds.fromPoints(route),
                        padding: const EdgeInsets.all(44),
                      ),
                    );
                  });
                }
                return FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(initialCenter: center, initialZoom: 11),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.mudanzas',
                      maxZoom: 19,
                    ),
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: route,
                          strokeWidth: 5,
                          color: AppColors.blue,
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        _marker(origin, const Color(0xFF28A66A), Icons.home),
                        _marker(
                          destination,
                          const Color(0xFFE45858),
                          Icons.flag,
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _vehicleLabel(_move.vehicleType),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    _StatusChip(status: _move.status),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _InfoChip(
                      icon: Icons.route,
                      label: distanceLabel(_move.routeDistanceMeters),
                    ),
                    if (_move.routeDurationSeconds != null)
                      _InfoChip(
                        icon: Icons.schedule,
                        label: _durationLabel(_move.routeDurationSeconds!),
                      ),
                    _InfoChip(
                      icon: Icons.calendar_today_outlined,
                      label: _dateLabel(_move.createdAt),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _AddressBlock(
                  color: const Color(0xFF28A66A),
                  title: 'Punto de recogida',
                  address: _move.originAddress,
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 10),
                  child: SizedBox(
                    height: 24,
                    child: VerticalDivider(width: 2, thickness: 2),
                  ),
                ),
                _AddressBlock(
                  color: const Color(0xFFE45858),
                  title: 'Punto de entrega',
                  address: _move.destinationAddress,
                ),
                if (_move.customerNotes?.trim().isNotEmpty ?? false) ...[
                  const SizedBox(height: 22),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3D6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5B94F)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.campaign_outlined,
                              color: Color(0xFF805B00),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Indicaciones importantes',
                              style: TextStyle(
                                color: Color(0xFF5E4300),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _move.customerNotes!.trim(),
                          style: const TextStyle(
                            color: Color(0xFF4D3A0A),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  key: const Key('navigateToPickupButton'),
                  onPressed: () => _openMaps(completeRoute: false),
                  icon: const Icon(Icons.navigation),
                  label: const Text('Navegar al punto de recogida'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  key: const Key('openCompleteRouteButton'),
                  onPressed: () => _openMaps(completeRoute: true),
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Ver ruta completa en Mapas'),
                ),
                if (canComplete) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _updating ? null : _completeMove,
                    icon: _updating
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.task_alt),
                    label: const Text('Marcar servicio como finalizado'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Marker _marker(LatLng point, Color color, IconData icon) => Marker(
    point: point,
    width: 48,
    height: 48,
    child: Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 8)],
      ),
      child: Icon(icon, color: Colors.white, size: 23),
    ),
  );
}

class _AddressBlock extends StatelessWidget {
  const _AddressBlock({
    required this.color,
    required this.title,
    required this.address,
  });

  final Color color;
  final String title;
  final String address;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: const Icon(Icons.location_on, size: 14, color: Colors.white),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 3),
            Text(
              address,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    ],
  );
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFF1F5F8),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: AppColors.teal),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      'driver_assigned' => 'Asignado',
      'in_progress' => 'En camino',
      'completed' => 'Finalizado',
      'cancelled' => 'Cancelado',
      _ => 'Solicitado',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFE4F1F3),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.teal,
          fontWeight: FontWeight.w800,
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

String _durationLabel(int seconds) {
  final minutes = (seconds / 60).round();
  if (minutes < 60) return '$minutes min aprox.';
  final hours = minutes ~/ 60;
  final remaining = minutes % 60;
  return remaining == 0 ? '$hours h aprox.' : '$hours h $remaining min';
}

String _dateLabel(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(value.day)}/${two(value.month)}/${value.year}';
}

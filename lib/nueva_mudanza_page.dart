import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'core/backend.dart';
import 'location_picker_page.dart';
import 'services/move_service.dart';
import 'services/route_service.dart';

enum VehicleType {
  motocarro(
    'Motocarro',
    'Para cargas pequeñas y trayectos urbanos',
    Icons.electric_rickshaw_outlined,
  ),
  camionetaEstacas(
    'Camioneta de estacas',
    'Ideal para mudanzas medianas',
    Icons.local_shipping_outlined,
  ),
  turbo(
    'Turbo',
    'Mayor capacidad para mudanzas grandes',
    Icons.fire_truck_outlined,
  );

  const VehicleType(this.label, this.description, this.icon);

  final String label;
  final String description;
  final IconData icon;
}

class NuevaMudanzaPage extends StatefulWidget {
  const NuevaMudanzaPage({super.key});

  @override
  State<NuevaMudanzaPage> createState() => _NuevaMudanzaPageState();
}

class _NuevaMudanzaPageState extends State<NuevaMudanzaPage> {
  final _formKey = GlobalKey<FormState>();
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  final _notesController = TextEditingController();

  PickedLocation? _origin;
  PickedLocation? _destination;
  VehicleType? _vehicle;
  bool _vehicleError = false;
  bool _submitting = false;

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickLocation({required bool isOrigin}) async {
    final result = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(
        builder: (_) => LocationPickerPage(
          title: isOrigin ? 'Punto de inicio' : 'Punto de destino',
          initialLocation: isOrigin ? _origin : _destination,
          useCurrentLocationOnOpen: isOrigin,
          centerOnCurrentLocationOnOpen: !isOrigin,
        ),
      ),
    );

    if (result == null || !mounted) return;
    setState(() {
      if (isOrigin) {
        _origin = result;
        _originController.text = result.address;
      } else {
        _destination = result;
        _destinationController.text = result.address;
      }
    });
  }

  Future<void> _submit() async {
    final validForm = _formKey.currentState!.validate();
    setState(() => _vehicleError = _vehicle == null);
    if (!validForm || _vehicle == null) return;

    if (Backend.isConfigured && (_origin == null || _destination == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Confirma inicio y destino en el mapa.')),
      );
      return;
    }

    if (Backend.isConfigured) {
      setState(() => _submitting = true);
      try {
        final route = await RouteService().calculate(
          originLatitude: _origin!.latitude,
          originLongitude: _origin!.longitude,
          destinationLatitude: _destination!.latitude,
          destinationLongitude: _destination!.longitude,
        );
        await MoveService().create(
          MoveDraft(
            vehicleType: switch (_vehicle!) {
              VehicleType.motocarro => 'motocarro',
              VehicleType.camionetaEstacas => 'camioneta_estacas',
              VehicleType.turbo => 'turbo',
            },
            originAddress: _originController.text.trim(),
            originLatitude: _origin!.latitude,
            originLongitude: _origin!.longitude,
            destinationAddress: _destinationController.text.trim(),
            destinationLatitude: _destination!.latitude,
            destinationLongitude: _destination!.longitude,
            customerNotes: _notesController.text,
            routeDistanceMeters: route.distanceMeters,
            routeDurationSeconds: route.durationSeconds,
          ),
        );
      } catch (error) {
        if (!mounted) return;
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.toString().contains('2 servicios activos')
                  ? 'Ya tienes 2 servicios activos. Finaliza o cancela uno.'
                  : 'No pudimos crear la solicitud.',
            ),
          ),
        );
        return;
      }
    }

    if (!mounted) return;
    setState(() => _submitting = false);

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle_outline, size: 48),
        title: const Text('Solicitud preparada'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SummaryRow(label: 'Inicio', value: _originController.text),
              const SizedBox(height: 12),
              _SummaryRow(label: 'Destino', value: _destinationController.text),
              const SizedBox(height: 12),
              _SummaryRow(label: 'Vehículo', value: _vehicle!.label),
              if (_notesController.text.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                _SummaryRow(
                  label: 'Indicaciones',
                  value: _notesController.text.trim(),
                ),
              ],
            ],
          ),
        ),
        actions: [
          FilledButton(
            key: const Key('closeMoveSummary'),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Ver mis mudanzas'),
          ),
        ],
      ),
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva mudanza')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.route_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Tu recorrido',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _RouteCard(
                    originController: _originController,
                    destinationController: _destinationController,
                    originFromMap: _origin != null,
                    destinationFromMap: _destination != null,
                    onOriginMap: () => _pickLocation(isOrigin: true),
                    onDestinationMap: () => _pickLocation(isOrigin: false),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('moveNotesField'),
                    controller: _notesController,
                    minLines: 3,
                    maxLines: 5,
                    maxLength: 500,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Indicaciones para la mudanza (opcional)',
                      hintText:
                          'Ejemplo: tercer piso sin ascensor, llamar al llegar…',
                      alignLabelWithHint: true,
                      prefixIcon: Padding(
                        padding: EdgeInsets.only(bottom: 58),
                        child: Icon(Icons.sticky_note_2_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  Row(
                    children: [
                      Icon(
                        Icons.local_shipping_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Elige el vehículo',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ...VehicleType.values.map(
                    (vehicle) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _VehicleCard(
                        vehicle: vehicle,
                        selected: _vehicle == vehicle,
                        onTap: () {
                          setState(() {
                            _vehicle = vehicle;
                            _vehicleError = false;
                          });
                        },
                      ),
                    ),
                  ),
                  if (_vehicleError)
                    Text(
                      'Selecciona un tipo de vehículo',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    key: const Key('continueMoveButton'),
                    onPressed: _submitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: Icon(
                      _submitting ? Icons.hourglass_top : Icons.arrow_forward,
                    ),
                    label: Text(_submitting ? 'Enviando...' : 'Continuar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({
    required this.originController,
    required this.destinationController,
    required this.originFromMap,
    required this.destinationFromMap,
    required this.onOriginMap,
    required this.onDestinationMap,
  });

  final TextEditingController originController;
  final TextEditingController destinationController;
  final bool originFromMap;
  final bool destinationFromMap;
  final VoidCallback onOriginMap;
  final VoidCallback onDestinationMap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 23),
              child: Column(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.primary, width: 4),
                    ),
                  ),
                  Container(
                    width: 2,
                    height: 67,
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    color: colors.primary.withValues(alpha: 0.25),
                  ),
                  Icon(Icons.location_on, color: colors.primary, size: 20),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                children: [
                  _RouteInput(
                    fieldKey: const Key('originField'),
                    mapButtonKey: const Key('originMapButton'),
                    label: 'Recoger en',
                    hint: 'Escribe o ubica el inicio',
                    controller: originController,
                    selectedFromMap: originFromMap,
                    onMapPressed: onOriginMap,
                  ),
                  const Divider(height: 1),
                  _RouteInput(
                    fieldKey: const Key('destinationField'),
                    mapButtonKey: const Key('destinationMapButton'),
                    label: 'Entregar en',
                    hint: 'Escribe o ubica el destino',
                    controller: destinationController,
                    selectedFromMap: destinationFromMap,
                    onMapPressed: onDestinationMap,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteInput extends StatelessWidget {
  const _RouteInput({
    required this.fieldKey,
    required this.mapButtonKey,
    required this.label,
    required this.hint,
    required this.controller,
    required this.selectedFromMap,
    required this.onMapPressed,
  });

  final Key fieldKey;
  final Key mapButtonKey;
  final String label;
  final String hint;
  final TextEditingController controller;
  final bool selectedFromMap;
  final VoidCallback onMapPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return TextFormField(
      key: fieldKey,
      controller: controller,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: false,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        suffixIcon: IconButton(
          key: mapButtonKey,
          tooltip: selectedFromMap ? 'Cambiar en el mapa' : 'Elegir en el mapa',
          onPressed: onMapPressed,
          icon: Icon(
            selectedFromMap ? Icons.edit_location_alt : Icons.map_outlined,
            color: selectedFromMap ? Colors.green : colors.primary,
          ),
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Ingresa una dirección';
        }
        return null;
      },
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    required this.vehicle,
    required this.selected,
    required this.onTap,
  });

  final VehicleType vehicle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: selected ? colors.primaryContainer : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: selected ? colors.primary : AppColors.border,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        key: Key('vehicle-${vehicle.name}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: selected
                    ? colors.primary
                    : colors.surfaceContainerHighest,
                child: Icon(
                  vehicle.icon,
                  color: selected ? colors.onPrimary : colors.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicle.label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(vehicle.description),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                color: selected ? colors.primary : const Color(0xFF9AA3B5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 3),
        Text(value),
      ],
    );
  }
}

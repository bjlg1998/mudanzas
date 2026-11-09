import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class PickedLocation {
  const PickedLocation({
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  final String address;
  final double latitude;
  final double longitude;

  LatLng get point => LatLng(latitude, longitude);
}

class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({
    super.key,
    required this.title,
    this.initialLocation,
    this.useCurrentLocationOnOpen = false,
    this.centerOnCurrentLocationOnOpen = false,
  });

  final String title;
  final PickedLocation? initialLocation;
  final bool useCurrentLocationOnOpen;
  final bool centerOnCurrentLocationOnOpen;

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  static const _colombiaCenter = LatLng(4.5709, -74.2973);

  final _mapController = MapController();
  final _searchController = TextEditingController();
  final _geocoder = _NominatimGeocoder();

  PickedLocation? _selectedLocation;
  LatLng? _searchFocus;
  bool _loading = false;
  bool _locating = false;
  bool _showSettingsAction = false;
  bool _openLocationSettings = false;
  String? _error;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
    _searchFocus = widget.initialLocation?.point;
    _searchController.text = widget.initialLocation?.address ?? '';
    if (widget.initialLocation == null &&
        (widget.useCurrentLocationOnOpen ||
            widget.centerOnCurrentLocationOnOpen)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _useCurrentLocation(selectPoint: widget.useCurrentLocationOnOpen);
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _geocoder.close();
    super.dispose();
  }

  Future<void> _searchAddress() async {
    final query = _searchController.text.trim();
    if (query.length < 3) {
      setState(() => _error = 'Escribe una dirección más completa');
      return;
    }

    FocusScope.of(context).unfocus();
    final currentRequest = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _geocoder.search(query, focus: _searchFocus);
      if (!mounted || currentRequest != _requestId) return;
      if (result == null) {
        setState(() => _error = 'No encontramos esa dirección');
        return;
      }

      setState(() {
        _selectedLocation = result;
        _searchFocus = result.point;
        _searchController.text = result.address;
      });
      _mapController.move(result.point, 16);
    } catch (_) {
      if (mounted && currentRequest == _requestId) {
        setState(() => _error = 'No fue posible consultar la dirección');
      }
    } finally {
      if (mounted && currentRequest == _requestId) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _selectPoint(LatLng point) async {
    final currentRequest = ++_requestId;
    final coordinateLabel =
        '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';

    setState(() {
      _loading = true;
      _error = null;
      _searchFocus = point;
      _selectedLocation = PickedLocation(
        address: 'Consultando dirección…',
        latitude: point.latitude,
        longitude: point.longitude,
      );
    });

    try {
      final address = await _geocoder.reverse(point);
      if (!mounted || currentRequest != _requestId) return;
      final result = PickedLocation(
        address: address ?? coordinateLabel,
        latitude: point.latitude,
        longitude: point.longitude,
      );
      setState(() {
        _selectedLocation = result;
        _searchController.text = result.address;
      });
    } catch (_) {
      if (!mounted || currentRequest != _requestId) return;
      final result = PickedLocation(
        address: coordinateLabel,
        latitude: point.latitude,
        longitude: point.longitude,
      );
      setState(() {
        _selectedLocation = result;
        _searchController.text = result.address;
        _error = 'Guardaremos las coordenadas seleccionadas';
      });
    } finally {
      if (mounted && currentRequest == _requestId) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _useCurrentLocation({bool selectPoint = true}) async {
    if (_locating) return;
    setState(() {
      _locating = true;
      _error = null;
      _showSettingsAction = false;
      _openLocationSettings = false;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _error = 'Activa la ubicación (GPS) para encontrar tu posición.';
          _showSettingsAction = !kIsWeb;
          _openLocationSettings = true;
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        setState(() {
          _error =
              'Permiso de ubicación rechazado. Puedes marcar el punto manualmente.';
        });
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _error =
              'El permiso está bloqueado. Habilítalo en los ajustes de la aplicación.';
          _showSettingsAction = !kIsWeb;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (!mounted) return;

      final point = LatLng(position.latitude, position.longitude);
      _searchFocus = point;
      _mapController.move(point, selectPoint ? 17 : 13.5);
      if (selectPoint) await _selectPoint(point);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error =
              'No pudimos obtener el GPS. Puedes buscar o marcar el punto en el mapa.';
        });
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _openRequiredSettings() async {
    if (kIsWeb) return;
    if (_openLocationSettings) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final initialCenter = widget.initialLocation?.point ?? _colombiaCenter;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: widget.initialLocation == null ? 5.5 : 16,
              minZoom: 3,
              maxZoom: 19,
              onTap: _locating ? null : (_, point) => _selectPoint(point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.mudanzas',
                maxZoom: 19,
              ),
              if (_selectedLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedLocation!.point,
                      width: 52,
                      height: 52,
                      alignment: Alignment.topCenter,
                      child: Icon(
                        Icons.location_pin,
                        size: 52,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              RichAttributionWidget(
                alignment: AttributionAlignment.bottomRight,
                attributions: [
                  TextSourceAttribution(
                    'OpenStreetMap contributors',
                    onTap: () => launchUrl(
                      Uri.parse('https://www.openstreetmap.org/copyright'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: SafeArea(
              bottom: false,
              child: Material(
                elevation: 5,
                borderRadius: BorderRadius.circular(16),
                child: TextField(
                  key: const Key('mapSearchField'),
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _searchAddress(),
                  decoration: InputDecoration(
                    hintText: 'Buscar una dirección',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      key: const Key('mapSearchButton'),
                      tooltip: 'Buscar',
                      onPressed: _loading || _locating ? null : _searchAddress,
                      icon: const Icon(Icons.arrow_forward),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_loading || _locating)
            const Positioned(
              top: 92,
              left: 0,
              right: 0,
              child: Center(child: CircularProgressIndicator()),
            ),
          Positioned(
            right: 12,
            bottom: 190,
            child: FloatingActionButton.extended(
              key: const Key('currentLocationButton'),
              heroTag: 'currentLocation',
              onPressed: _locating ? null : _useCurrentLocation,
              icon: _locating
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
              label: const Text('Mi ubicación'),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 18,
            child: SafeArea(
              top: false,
              child: Card(
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _selectedLocation?.address ??
                            'Toca el mapa para marcar el punto exacto',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        if (_showSettingsAction)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: _openRequiredSettings,
                              icon: const Icon(Icons.settings),
                              label: const Text('Abrir ajustes'),
                            ),
                          ),
                      ],
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        key: const Key('confirmMapLocation'),
                        onPressed:
                            _selectedLocation == null || _loading || _locating
                            ? null
                            : () =>
                                  Navigator.of(context).pop(_selectedLocation),
                        icon: const Icon(Icons.check),
                        label: const Text('Usar esta ubicación'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NominatimGeocoder {
  final http.Client _client = http.Client();
  DateTime _lastRequest = DateTime.fromMillisecondsSinceEpoch(0);

  Future<PickedLocation?> search(String query, {LatLng? focus}) async {
    final parameters = <String, String>{
      'format': 'jsonv2',
      'limit': '1',
      'addressdetails': '0',
      'accept-language': 'es',
      'q': query,
    };
    if (focus != null) {
      const radius = 0.7;
      parameters['viewbox'] =
          '${focus.longitude - radius},${focus.latitude + radius},'
          '${focus.longitude + radius},${focus.latitude - radius}';
      parameters['bounded'] = '0';
    }
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', parameters);
    final data = await _getJson(uri);
    if (data is! List || data.isEmpty) return null;

    final item = data.first as Map<String, dynamic>;
    return PickedLocation(
      address: item['display_name'] as String,
      latitude: double.parse(item['lat'] as String),
      longitude: double.parse(item['lon'] as String),
    );
  }

  Future<String?> reverse(LatLng point) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'format': 'jsonv2',
      'lat': point.latitude.toString(),
      'lon': point.longitude.toString(),
      'zoom': '18',
      'addressdetails': '0',
      'accept-language': 'es',
    });
    final data = await _getJson(uri);
    if (data is! Map<String, dynamic>) return null;
    return data['display_name'] as String?;
  }

  Future<dynamic> _getJson(Uri uri) async {
    final elapsed = DateTime.now().difference(_lastRequest);
    const minimumInterval = Duration(seconds: 1);
    if (elapsed < minimumInterval) {
      await Future<void>.delayed(minimumInterval - elapsed);
    }

    final headers = <String, String>{'Accept-Language': 'es'};
    if (!kIsWeb) {
      headers['User-Agent'] = 'MudanzasApp/1.0 (com.example.mudanzas)';
    }

    _lastRequest = DateTime.now();
    final response = await _client
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Geocoding request failed: ${response.statusCode}',
        uri,
      );
    }
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  void close() => _client.close();
}

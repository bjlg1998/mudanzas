import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/backend.dart';

class MoveDraft {
  const MoveDraft({
    required this.vehicleType,
    required this.originAddress,
    required this.originLatitude,
    required this.originLongitude,
    required this.destinationAddress,
    required this.destinationLatitude,
    required this.destinationLongitude,
    this.customerNotes,
    this.routeDistanceMeters,
    this.routeDurationSeconds,
  });

  final String vehicleType;
  final String originAddress;
  final double originLatitude;
  final double originLongitude;
  final String destinationAddress;
  final double destinationLatitude;
  final double destinationLongitude;
  final String? customerNotes;
  final int? routeDistanceMeters;
  final int? routeDurationSeconds;
}

class MoveSummary {
  const MoveSummary({
    required this.id,
    required this.status,
    required this.vehicleType,
    required this.originAddress,
    required this.destinationAddress,
    required this.customerNotes,
    required this.originLatitude,
    required this.originLongitude,
    required this.destinationLatitude,
    required this.destinationLongitude,
    required this.routeDistanceMeters,
    required this.routeDurationSeconds,
    required this.createdAt,
  });

  factory MoveSummary.fromJson(Map<String, dynamic> json) {
    return MoveSummary(
      id: json['id'] as String,
      status: json['status'] as String,
      vehicleType: json['vehicle_type'] as String,
      originAddress: json['origin_address'] as String,
      destinationAddress: json['destination_address'] as String,
      customerNotes: json['customer_notes'] as String?,
      originLatitude: (json['origin_latitude'] as num).toDouble(),
      originLongitude: (json['origin_longitude'] as num).toDouble(),
      destinationLatitude: (json['destination_latitude'] as num).toDouble(),
      destinationLongitude: (json['destination_longitude'] as num).toDouble(),
      routeDistanceMeters: (json['route_distance_meters'] as num?)?.round(),
      routeDurationSeconds: (json['route_duration_seconds'] as num?)?.round(),
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }

  final String id;
  final String status;
  final String vehicleType;
  final String originAddress;
  final String destinationAddress;
  final String? customerNotes;
  final double originLatitude;
  final double originLongitude;
  final double destinationLatitude;
  final double destinationLongitude;
  final int? routeDistanceMeters;
  final int? routeDurationSeconds;
  final DateTime createdAt;
}

class MoveService {
  SupabaseClient get _client => Backend.client;

  Future<Map<String, dynamic>> create(MoveDraft draft) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Debes iniciar sesión.');

    final created = await _client
        .from('move_requests')
        .insert({
          'customer_id': user.id,
          'vehicle_type': draft.vehicleType,
          'origin_address': draft.originAddress,
          'origin_latitude': draft.originLatitude,
          'origin_longitude': draft.originLongitude,
          'destination_address': draft.destinationAddress,
          'destination_latitude': draft.destinationLatitude,
          'destination_longitude': draft.destinationLongitude,
          'customer_notes': draft.customerNotes?.trim(),
          'route_distance_meters': draft.routeDistanceMeters,
          'route_duration_seconds': draft.routeDurationSeconds,
          'status': 'requested',
        })
        .select()
        .single();
    try {
      await _client.functions.invoke(
        'notify-drivers',
        body: {'move_id': created['id']},
      );
    } catch (_) {
      // La solicitud sigue creada aunque la notificación no pueda enviarse.
    }
    return created;
  }

  Future<List<MoveSummary>> customerMoves() async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Debes iniciar sesión.');
    final rows = await _baseMovesQuery()
        .eq('customer_id', user.id)
        .order('created_at', ascending: false);
    return _summaries(rows);
  }

  Future<List<MoveSummary>> driverMoves() async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Debes iniciar sesión.');
    final rows = await _baseMovesQuery()
        .eq('driver_id', user.id)
        .order('created_at', ascending: false);
    return _summaries(rows);
  }

  Future<List<MoveSummary>> availableMoves() async {
    final rows = await _baseMovesQuery()
        .eq('status', 'requested')
        .isFilter('driver_id', null)
        .order('created_at', ascending: false);
    return _summaries(rows);
  }

  Future<MoveSummary> moveById(String moveId) async {
    final row = await _baseMovesQuery().eq('id', moveId).single();
    return MoveSummary.fromJson(row);
  }

  Future<void> claimMove(String moveId) async {
    await _client.rpc('claim_available_move', params: {'p_move_id': moveId});
  }

  Future<void> cancelMove(String moveId) async {
    await _client.rpc('cancel_move', params: {'p_move_id': moveId});
  }

  Future<void> completeMove(String moveId) async {
    await _client.rpc('complete_move', params: {'p_move_id': moveId});
  }

  PostgrestFilterBuilder<List<Map<String, dynamic>>> _baseMovesQuery() {
    return _client
        .from('move_requests')
        .select(
          'id,status,vehicle_type,origin_address,origin_latitude,origin_longitude,'
          'destination_address,destination_latitude,destination_longitude,'
          'customer_notes,route_distance_meters,route_duration_seconds,created_at',
        );
  }

  List<MoveSummary> _summaries(dynamic rows) {
    return List<Map<String, dynamic>>.from(
      rows,
    ).map(MoveSummary.fromJson).toList();
  }
}

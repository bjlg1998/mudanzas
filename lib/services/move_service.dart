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
  });

  final String vehicleType;
  final String originAddress;
  final double originLatitude;
  final double originLongitude;
  final String destinationAddress;
  final double destinationLatitude;
  final double destinationLongitude;
}

class MoveSummary {
  const MoveSummary({
    required this.id,
    required this.status,
    required this.vehicleType,
    required this.originAddress,
    required this.destinationAddress,
    required this.createdAt,
  });

  factory MoveSummary.fromJson(Map<String, dynamic> json) {
    return MoveSummary(
      id: json['id'] as String,
      status: json['status'] as String,
      vehicleType: json['vehicle_type'] as String,
      originAddress: json['origin_address'] as String,
      destinationAddress: json['destination_address'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }

  final String id;
  final String status;
  final String vehicleType;
  final String originAddress;
  final String destinationAddress;
  final DateTime createdAt;
}

class MoveService {
  SupabaseClient get _client => Backend.client;

  Future<Map<String, dynamic>> create(MoveDraft draft) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Debes iniciar sesión.');

    return _client
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
          'status': 'requested',
        })
        .select()
        .single();
  }

  Future<List<MoveSummary>> myMoves() async {
    final rows = await _client
        .from('move_requests')
        .select(
          'id,status,vehicle_type,origin_address,destination_address,created_at',
        )
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(
      rows,
    ).map(MoveSummary.fromJson).toList();
  }
}

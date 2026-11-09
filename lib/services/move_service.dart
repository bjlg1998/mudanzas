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

  Future<List<Map<String, dynamic>>> myMoves() async {
    final rows = await _client
        .from('move_requests')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }
}

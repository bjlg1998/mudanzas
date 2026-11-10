import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../core/backend.dart';
import '../firebase_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

class NotificationService {
  NotificationService._();

  static final instance = NotificationService._();

  final _openedController = StreamController<String>.broadcast();
  StreamSubscription<String>? _tokenSubscription;
  String? _currentRegistrationId;
  String? _pendingType;

  Stream<String> get opened => _openedController.stream;

  Future<void> initialize() async {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleOpenedMessage(initialMessage);
    }
  }

  Future<void> registerCurrentDevice() async {
    if (!Backend.isConfigured || Backend.client.auth.currentUser == null) {
      return;
    }
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      await _tokenSubscription?.cancel();
      _tokenSubscription = FirebaseMessaging.instance.onRegistered.listen((
        registrationId,
      ) async {
        _currentRegistrationId = registrationId;
        await _saveToken(registrationId);
      });
      await FirebaseMessaging.instance.register();
    } catch (_) {
      // Las notificaciones no deben impedir que el usuario use la aplicación.
    }
  }

  Future<void> unregisterCurrentDevice() async {
    try {
      final user = Backend.isConfigured
          ? Backend.client.auth.currentUser
          : null;
      final registrationId = _currentRegistrationId;
      if (user != null && registrationId != null) {
        await Backend.client
            .from('push_tokens')
            .delete()
            .eq('user_id', user.id)
            .eq('token', registrationId);
      }
      await FirebaseMessaging.instance.unregister();
      await _tokenSubscription?.cancel();
      _tokenSubscription = null;
      _currentRegistrationId = null;
    } catch (_) {
      // El cierre de sesión continúa aunque el dispositivo no tenga conexión.
    }
  }

  String? consumePendingType() {
    final value = _pendingType;
    _pendingType = null;
    return value;
  }

  Future<void> _saveToken(String token) async {
    final user = Backend.client.auth.currentUser;
    if (user == null) return;
    await Backend.client.from('push_tokens').upsert({
      'user_id': user.id,
      'token': token,
      'platform': 'android',
    }, onConflict: 'token');
  }

  void _handleOpenedMessage(RemoteMessage message) {
    final type = message.data['type'];
    if (type is! String || type.isEmpty) return;
    _pendingType = type;
    _openedController.add(type);
  }
}

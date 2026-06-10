import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'event_service.dart';
import 'supabase_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // FCM muestra la notificación automáticamente cuando hay notification payload
}

class NotificationService {
  NotificationService._();

  static final _messaging = FirebaseMessaging.instance;
  static final _local = FlutterLocalNotificationsPlugin();

  static const _channelId = 'sentry_channel';
  static const _channelName = 'Sentry Notificaciones';

  static Future<void> initialize() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    await _local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );

    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            importance: Importance.high,
          ),
        );

    FirebaseMessaging.onMessage.listen(_showLocal);

    await _saveToken();
    _messaging.onTokenRefresh.listen(_upsertToken);
  }

  static Future<void> _showLocal(RemoteMessage message) async {
    final n = message.notification;
    if (n == null) return;
    await _local.show(
      message.hashCode,
      n.title,
      n.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  static Future<void> _saveToken() async {
    final token = await _messaging.getToken();
    if (token != null) await _upsertToken(token);
  }

  static Future<void> _upsertToken(String token) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;

    final idUsuario = await EventService.getCurrentUserId();

    try {
      await SupabaseService.client.from('device_tokens').upsert(
        {
          'user_id': userId,
          'id_usuario': idUsuario,
          'token': token,
        },
        onConflict: 'user_id,token',
      );
    } catch (e) {
      debugPrint('NotificationService._upsertToken: $e');
    }
  }

  static Future<void> deleteToken() async {
    final token = await _messaging.getToken();
    final userId = SupabaseService.currentUser?.id;
    if (token == null || userId == null) return;
    try {
      await SupabaseService.client
          .from('device_tokens')
          .delete()
          .eq('user_id', userId)
          .eq('token', token);
      await _messaging.deleteToken();
    } catch (e) {
      debugPrint('NotificationService.deleteToken: $e');
    }
  }

  /// Envía una notificación push a un usuario via Supabase Edge Function.
  static Future<void> sendToUser({
    required int idUsuario,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      final payload = <String, dynamic>{
        'id_usuario': idUsuario,
        'title': title,
        'body': body,
      };
      if (data != null) payload['data'] = data;
      await SupabaseService.client.functions.invoke(
        'send-notification',
        body: payload,
      );
    } catch (e) {
      debugPrint('NotificationService.sendToUser: $e');
    }
  }
}

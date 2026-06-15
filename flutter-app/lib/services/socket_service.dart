import 'dart:async';
import 'dart:convert';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'auth_storage_service.dart';
import 'api_config.dart';
import 'notification_service.dart';

class SocketService {
  static final SocketService _instance = SocketService._();
  factory SocketService() => _instance;
  SocketService._();

  IO.Socket? _socket;
  String? _currentUserId;

  final StreamController<Map<String, dynamic>> _newMessageController = StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _messageSentController = StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _messagesReadController = StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<String> _typingController = StreamController<String>.broadcast();
  final StreamController<String> _stopTypingController = StreamController<String>.broadcast();
  final StreamController<List<String>> _onlineUsersController = StreamController<List<String>>.broadcast();
  final StreamController<Map<String, dynamic>> _errorController = StreamController<Map<String, dynamic>>.broadcast();
  
  final StreamController<Map<String, dynamic>> _vitalsUpdateController = StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _emergencyController = StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _sosController = StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _appointmentController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onNewMessage => _newMessageController.stream;
  Stream<Map<String, dynamic>> get onMessageSent => _messageSentController.stream;
  Stream<Map<String, dynamic>> get onMessagesRead => _messagesReadController.stream;
  Stream<String> get onTyping => _typingController.stream;
  Stream<String> get onStopTyping => _stopTypingController.stream;
  Stream<List<String>> get onOnlineUsers => _onlineUsersController.stream;
  Stream<Map<String, dynamic>> get onError => _errorController.stream;
  Stream<Map<String, dynamic>> get onVitalsUpdate => _vitalsUpdateController.stream;
  Stream<Map<String, dynamic>> get onEmergency => _emergencyController.stream;
  Stream<Map<String, dynamic>> get onSosAlert => _sosController.stream;
  Stream<Map<String, dynamic>> get onAppointmentUpdate => _appointmentController.stream;

  bool get isConnected => _socket?.connected ?? false;
  String? get currentUserId => _currentUserId;

  Future<void> connect() async {
    if (_socket?.connected == true) return;

    final token = await AuthStorageService().getToken();
    if (token == null) return;

    try {
      final parts = token.split('.');
      if (parts.length == 3) {
        final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
        _currentUserId = payload['userId']?.toString();
      }
    } catch (_) {}

    final host = ApiConfig.host;

    _socket = IO.io('https://$host', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
      'auth': {'token': token},
    });

    _socket!.on('connect', (_) {});
    _socket!.on('disconnect', (_) {});

    _socket!.on('new_message', (data) {
      _newMessageController.add(data is Map<String, dynamic> ? data : {});
      if (data is Map<String, dynamic>) {
        _showNotificationForMessage(data);
      }
    });

    _socket!.on('message_sent', (data) {
      _messageSentController.add(data is Map<String, dynamic> ? data : {});
    });

    _socket!.on('messages_read', (data) {
      _messagesReadController.add(data is Map<String, dynamic> ? data : {});
    });

    _socket!.on('user_typing', (data) {
      final contactId = (data is Map) ? data['userId']?.toString() : null;
      if (contactId != null) _typingController.add(contactId);
    });

    _socket!.on('user_stop_typing', (data) {
      final contactId = (data is Map) ? data['userId']?.toString() : null;
      if (contactId != null) _stopTypingController.add(contactId);
    });

    _socket!.on('users_online', (data) {
      if (data is List) {
        _onlineUsersController.add(data.cast<String>());
      }
    });

    _socket!.on('connect_error', (data) {
      _errorController.add({'type': 'connect_error', 'data': data});
    });

    _socket!.on('vitals:update', (data) {
      if (data is Map<String, dynamic>) {
        _vitalsUpdateController.add(data);
        _showVitalsNotification(data);
      }
    });

    _socket!.on('emergency:new', (data) {
      if (data is Map<String, dynamic>) {
        _emergencyController.add(data);
        _showEmergencyNotification(data);
      }
    });

    _socket!.on('sos:new', (data) {
      if (data is Map<String, dynamic>) {
        _sosController.add(data);
        _showSosNotification(data);
      }
    });

    _socket!.on('appointment:new', (data) {
      if (data is Map<String, dynamic>) {
        _appointmentController.add(data);
      }
    });

    _socket!.on('appointment:updated', (data) {
      if (data is Map<String, dynamic>) {
        _appointmentController.add(data);
      }
    });

    _socket!.connect();
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }

  void sendMessage({required String receiverId, String? content, String? type, Map<String, dynamic>? attachment, String? localId}) {
    _socket?.emit('send_message', {
      'receiverId': receiverId,
      'content': content ?? '',
      'type': type ?? 'text',
      if (attachment != null) 'attachment': attachment,
      if (localId != null) '_localId': localId,
    });
  }

  void markRead({required String messageId, required String contactId}) {
    _socket?.emit('mark_read', {
      'messageId': messageId,
      'contactId': contactId,
    });
  }

  void markAllRead({required String contactId}) {
    _socket?.emit('mark_all_read', {
      'contactId': contactId,
    });
  }

  void sendTyping({required String contactId}) {
    _socket?.emit('typing', {'contactId': contactId});
  }

  void sendStopTyping({required String contactId}) {
    _socket?.emit('stop_typing', {'contactId': contactId});
  }

  void subscribePatientVitals(String patientId) {
    _socket?.emit('subscribe:patient', patientId);
  }

  void unsubscribePatientVitals(String patientId) {
    _socket?.emit('unsubscribe:patient', patientId);
  }

  void subscribeAllVitals() {
    _socket?.emit('subscribe:all');
  }

  void unsubscribeAllVitals() {
    _socket?.emit('unsubscribe:all');
  }

  void _showNotificationForMessage(Map<String, dynamic> data) {
    final sender = data['sender'] is Map ? data['sender'] as Map : null;
    final senderName = sender?['name']?.toString() ?? 'Nouveau message';
    final content = data['content']?.toString() ?? '';
    final type = data['type']?.toString() ?? 'text';
    final preview = type == 'file' ? '\u{1F4CE} Fichier re\u00e7u' :
        type == 'image' ? '\u{1F4F7} Image re\u00e7ue' : content;
    NotificationService().showMessageNotification(
      title: senderName,
      body: preview.length > 100 ? '${preview.substring(0, 97)}...' : preview,
    );
  }

  void _showEmergencyNotification(Map<String, dynamic> data) {
    final patientName = data['patientName']?.toString() ?? 'Patient';
    NotificationService().showMessageNotification(
      title: 'URGENCE',
      body: 'Alerte d\'urgence déclenchée par $patientName',
    );
  }

  void _showSosNotification(Map<String, dynamic> data) {
    final patientName = data['patientName']?.toString() ?? 'Patient';
    NotificationService().showMessageNotification(
      title: 'SOS',
      body: '$patientName a déclenché une alerte SOS',
    );
  }

  void _showVitalsNotification(Map<String, dynamic> data) {
    final alerts = data['alerts'] as List?;
    if (alerts != null && alerts.isNotEmpty) {
      for (final alert in alerts) {
        final severity = alert['severity']?.toString() ?? 'warning';
        final message = alert['message']?.toString() ?? 'Vital sign alert';
        final patientId = data['patientId']?.toString() ?? '';
        
        if (severity == 'critical') {
          NotificationService().showMessageNotification(
            title: '\u{1F6A8} ALERTE CRITIQUE',
            body: '$message (Patient: $patientId)',
          );
        } else {
          NotificationService().showMessageNotification(
            title: '\u26A0\uFE0F Alerte',
            body: message,
          );
        }
      }
    }
  }

  void dispose() {
    disconnect();
    _newMessageController.close();
    _messageSentController.close();
    _messagesReadController.close();
    _typingController.close();
    _stopTypingController.close();
    _onlineUsersController.close();
    _errorController.close();
    _vitalsUpdateController.close();
    _emergencyController.close();
    _sosController.close();
    _appointmentController.close();
  }
}

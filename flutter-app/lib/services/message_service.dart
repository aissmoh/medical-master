import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'auth_storage_service.dart';

class Message {
  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final String type;
  final bool isRead;
  final DateTime? readAt;
  final String? appointmentId;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? sender;
  final Map<String, dynamic>? receiver;

  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.type,
    required this.isRead,
    this.readAt,
    this.appointmentId,
    this.metadata,
    required this.createdAt,
    required this.updatedAt,
    this.sender,
    this.receiver,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: (json['_id'] ?? json['id'])?.toString() ?? '',
      senderId: (json['sender'] is Map<String, dynamic>)
          ? json['sender']['_id']?.toString() ?? ''
          : json['sender']?.toString() ?? '',
      receiverId: (json['receiver'] is Map<String, dynamic>)
          ? json['receiver']['_id']?.toString() ?? ''
          : json['receiver']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      type: json['type']?.toString() ?? 'text',
      isRead: json['isRead'] as bool? ?? false,
      readAt: json['readAt'] != null
          ? DateTime.parse(json['readAt'].toString())
          : null,
      appointmentId: json['appointmentId']?.toString(),
      metadata: json['metadata'] is Map<String, dynamic>
          ? json['metadata'] as Map<String, dynamic>?
          : null,
      createdAt: DateTime.parse(json['createdAt'].toString()),
      updatedAt: DateTime.parse(json['updatedAt'].toString()),
      sender: json['sender'] is Map<String, dynamic>
          ? json['sender'] as Map<String, dynamic>?
          : null,
      receiver: json['receiver'] is Map<String, dynamic>
          ? json['receiver'] as Map<String, dynamic>?
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'content': content,
      'type': type,
      'isRead': isRead,
      'readAt': readAt?.toIso8601String(),
      'appointmentId': appointmentId,
      'metadata': metadata,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'sender': sender,
      'receiver': receiver,
    };
  }
}

class Conversation {
  final String contactId;
  final Map<String, dynamic> contact;
  final Message lastMessage;
  final int unreadCount;

  Conversation({
    required this.contactId,
    required this.contact,
    required this.lastMessage,
    required this.unreadCount,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      contactId: json['_id']?.toString() ?? '',
      contact: json['contact'] is Map<String, dynamic>
          ? json['contact'] as Map<String, dynamic>
          : {},
      lastMessage: Message.fromJson(
        json['lastMessage'] as Map<String, dynamic>,
      ),
      unreadCount: json['unreadCount'] as int? ?? 0,
    );
  }
}

class MessageService {
  static final MessageService _instance = MessageService._internal();
  factory MessageService() => _instance;
  MessageService._internal();

  Future<String?> _getToken() async {
    final authStorage = AuthStorageService();
    return await authStorage.getToken();
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Récupérer les conversations
  Future<List<Conversation>> getConversations() async {
    try {
      final headers = await _getHeaders();
      print('DEBUG: Message Headers: $headers');

      final uri = Uri.parse('${ApiConfig.baseUrl}/messages/conversations');
      print('DEBUG: Request URL: $uri');

      final response = await http.get(uri, headers: headers);
      print('DEBUG: Response status: ${response.statusCode}');
      print('DEBUG: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final conversations = data['data'] as List;
          print('DEBUG: Parsed ${conversations.length} conversations');
          return conversations
              .map((json) => Conversation.fromJson(json))
              .toList();
        }
      }
      throw Exception('Failed to load conversations: ${response.statusCode}');
    } catch (e) {
      print('DEBUG: Exception in getConversations: $e');
      throw Exception('Error loading conversations: $e');
    }
  }

  // Récupérer les messages d'une conversation
  Future<List<Message>> getConversationMessages(
    String contactId, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final headers = await _getHeaders();
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };

      final uri = Uri.parse(
        '${ApiConfig.baseUrl}/messages/conversation/$contactId',
      ).replace(queryParameters: queryParams);

      print('DEBUG: Getting messages for contact: $contactId');

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final messages = data['data'] as List;
          return messages.map((json) => Message.fromJson(json)).toList();
        }
      }
      throw Exception('Failed to load messages: ${response.statusCode}');
    } catch (e) {
      print('DEBUG: Exception in getConversationMessages: $e');
      throw Exception('Error loading messages: $e');
    }
  }

  // Envoyer un message
  Future<Message> sendMessage({
    required String receiverId,
    required String content,
    String type = 'text',
    String? appointmentId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = json.encode({
        'receiverId': receiverId,
        'content': content,
        'type': type,
        if (appointmentId != null) 'appointmentId': appointmentId,
        if (metadata != null) 'metadata': metadata,
      });

      print('DEBUG: Sending message to: $receiverId');
      print('DEBUG: Body: $body');

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/messages'),
        headers: headers,
        body: body,
      );

      print('DEBUG: Response status: ${response.statusCode}');
      print('DEBUG: Response body: ${response.body}');

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return Message.fromJson(data['data'] as Map<String, dynamic>);
        }
      }
      throw Exception(
        'Failed to send message - Status: ${response.statusCode}, Body: ${response.body}',
      );
    } catch (e) {
      print('DEBUG: Exception in sendMessage: $e');
      throw Exception('Error sending message: $e');
    }
  }

  // Compter les messages non lus
  Future<int> getUnreadCount() async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('${ApiConfig.baseUrl}/messages/unread/count');

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['count'] as int? ?? 0;
        }
      }
      return 0;
    } catch (e) {
      print('DEBUG: Exception in getUnreadCount: $e');
      return 0;
    }
  }

  // Marquer un message comme lu
  Future<void> markAsRead(String messageId) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('${ApiConfig.baseUrl}/messages/$messageId/read');

      final response = await http.patch(uri, headers: headers);

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to mark message as read: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('DEBUG: Exception in markAsRead: $e');
      throw Exception('Error marking message as read: $e');
    }
  }

  // Marquer tous les messages comme lus
  Future<void> markAllAsRead({String? senderId}) async {
    try {
      final headers = await _getHeaders();
      final body = senderId != null
          ? json.encode({'senderId': senderId})
          : null;

      final uri = Uri.parse('${ApiConfig.baseUrl}/messages/read-all');

      final response = await http.patch(uri, headers: headers, body: body);

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to mark all messages as read: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('DEBUG: Exception in markAllAsRead: $e');
      throw Exception('Error marking all messages as read: $e');
    }
  }

  // Supprimer un message
  Future<void> deleteMessage(String messageId) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('${ApiConfig.baseUrl}/messages/$messageId');

      final response = await http.delete(uri, headers: headers);

      if (response.statusCode != 200) {
        throw Exception('Failed to delete message: ${response.statusCode}');
      }
    } catch (e) {
      print('DEBUG: Exception in deleteMessage: $e');
      throw Exception('Error deleting message: $e');
    }
  }

  // Récupérer les messages reçus
  Future<List<Message>> getReceivedMessages({
    bool? isRead,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final headers = await _getHeaders();
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (isRead != null) {
        queryParams['isRead'] = isRead.toString();
      }

      final uri = Uri.parse(
        '${ApiConfig.baseUrl}/messages/received',
      ).replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final messages = data['data'] as List;
          return messages.map((json) => Message.fromJson(json)).toList();
        }
      }
      throw Exception(
        'Failed to load received messages: ${response.statusCode}',
      );
    } catch (e) {
      print('DEBUG: Exception in getReceivedMessages: $e');
      throw Exception('Error loading received messages: $e');
    }
  }

  // Récupérer les messages envoyés
  Future<List<Message>> getSentMessages({int page = 1, int limit = 20}) async {
    try {
      final headers = await _getHeaders();
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };

      final uri = Uri.parse(
        '${ApiConfig.baseUrl}/messages/sent',
      ).replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final messages = data['data'] as List;
          return messages.map((json) => Message.fromJson(json)).toList();
        }
      }
      throw Exception('Failed to load sent messages: ${response.statusCode}');
    } catch (e) {
      print('DEBUG: Exception in getSentMessages: $e');
      throw Exception('Error loading sent messages: $e');
    }
  }

  // Récupérer la liste des utilisateurs disponibles
  Future<List<Map<String, dynamic>>> getUsers() async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('${ApiConfig.baseUrl}/users');

      print('DEBUG: Getting users from: $uri');

      final response = await http.get(uri, headers: headers);

      print('DEBUG: Users response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final users = data['data'] as List;
          print('DEBUG: Loaded ${users.length} users');
          return users.cast<Map<String, dynamic>>();
        }
      }
      throw Exception('Failed to load users: ${response.statusCode}');
    } catch (e) {
      print('DEBUG: Exception in getUsers: $e');
      throw Exception('Error loading users: $e');
    }
  }

  // Rechercher des utilisateurs
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse(
        '${ApiConfig.baseUrl}/users/search',
      ).replace(queryParameters: {'query': query});

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final users = data['data'] as List;
          return users.cast<Map<String, dynamic>>();
        }
      }
      throw Exception('Failed to search users: ${response.statusCode}');
    } catch (e) {
      print('DEBUG: Exception in searchUsers: $e');
      throw Exception('Error searching users: $e');
    }
  }
}

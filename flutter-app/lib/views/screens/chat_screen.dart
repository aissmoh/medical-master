import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import '../../services/message_service.dart';
import '../../services/socket_service.dart';
import '../../services/api_config.dart';
import '../../services/auth_storage_service.dart';

class ChatScreen extends StatefulWidget {
  final String contactId;
  final String contactName;

  const ChatScreen({
    super.key,
    required this.contactId,
    required this.contactName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final MessageService _messageService = MessageService();
  final SocketService _socketService = SocketService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _error;
  bool _isTyping = false;
  Timer? _typingTimer;
  bool _isOnline = false;
  List<String> _onlineUsers = [];
  StreamSubscription? _newMessageSub;
  StreamSubscription? _messageSentSub;
  StreamSubscription? _messagesReadSub;
  StreamSubscription? _typingSub;
  StreamSubscription? _stopTypingSub;
  StreamSubscription? _onlineSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadMessages();
    _setupSocketListeners();
    _messageController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _typingTimer?.cancel();
    _newMessageSub?.cancel();
    _messageSentSub?.cancel();
    _messagesReadSub?.cancel();
    _typingSub?.cancel();
    _stopTypingSub?.cancel();
    _onlineSub?.cancel();
    _socketService.sendStopTyping(contactId: widget.contactId);
    _socketService.markAllRead(contactId: widget.contactId);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadMessages();
    }
  }

  void _setupSocketListeners() {
    _newMessageSub = _socketService.onNewMessage.listen((data) {
      final rawSender = data['sender'];
      final rawReceiver = data['receiver'];
      final senderId = rawSender is Map ? rawSender['_id']?.toString() : rawSender?.toString();
      final receiverId = rawReceiver is Map ? rawReceiver['_id']?.toString() : rawReceiver?.toString();
      if (senderId == widget.contactId || receiverId == widget.contactId) {
        setState(() => _messages.add(data));
        _scrollToBottom();
        if (senderId == widget.contactId) {
          final messageId = data['_id']?.toString() ?? data['id']?.toString() ?? '';
          if (messageId.isNotEmpty) {
            _socketService.markRead(messageId: messageId, contactId: widget.contactId);
          }
        }
      }
    });

    _messageSentSub = _socketService.onMessageSent.listen((data) {
      final localId = data['_localId']?.toString();
      setState(() {
        final idx = localId != null
            ? _messages.indexWhere((m) => m['_localId']?.toString() == localId)
            : -1;
        if (idx >= 0) {
          _messages[idx] = data;
        } else {
          _messages.add(data);
        }
      });
      _scrollToBottom();
    });

    _messagesReadSub = _socketService.onMessagesRead.listen((data) {
      setState(() {
        for (var i = 0; i < _messages.length; i++) {
          if (_messages[i]['sender'] is Map) {
            final senderId = _messages[i]['sender']['_id']?.toString();
            if (senderId == _socketService.currentUserId) {
              _messages[i]['isRead'] = true;
              _messages[i]['readAt'] = DateTime.now().toIso8601String();
            }
          }
        }
      });
    });

    _typingSub = _socketService.onTyping.listen((userId) {
      if (userId == widget.contactId) {
        setState(() => _isTyping = true);
      }
    });

    _stopTypingSub = _socketService.onStopTyping.listen((userId) {
      if (userId == widget.contactId) {
        setState(() => _isTyping = false);
      }
    });

    _onlineSub = _socketService.onOnlineUsers.listen((users) {
      setState(() {
        _onlineUsers = users;
        _isOnline = users.contains(widget.contactId);
      });
    });

    _socketService.connect();
  }

  void _onTextChanged() {
    if (_messageController.text.isNotEmpty) {
      _socketService.sendTyping(contactId: widget.contactId);
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 2), () {
        _socketService.sendStopTyping(contactId: widget.contactId);
      });
    }
  }

  Future<void> _loadMessages() async {
    try {
      setState(() { _isLoading = true; _error = null; });
      final messages = await _messageService.getConversationMessages(widget.contactId);
      setState(() {
        _messages = messages.map((m) {
          final json = m.toJson();
          json['_id'] = json['id'];
          json['sender'] = {'_id': m.senderId, 'name': m.sender?['name']?.toString() ?? ''};
          json['receiver'] = {'_id': m.receiverId, 'name': m.receiver?['name']?.toString() ?? ''};
          return json;
        }).toList();
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() { _error = 'Erreur de chargement'; _isLoading = false; });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage({String? content, String? type, Map<String, dynamic>? attachment}) async {
    final text = content ?? _messageController.text.trim();
    if (text.isEmpty && attachment == null) return;

    setState(() => _isSending = true);
    final localId = DateTime.now().millisecondsSinceEpoch.toString();

    final tempMsg = {
      '_id': localId,
      '_localId': localId,
      'sender': {'_id': _socketService.currentUserId, 'name': 'Moi', 'isPatient': true},
      'receiver': {'_id': widget.contactId, 'name': widget.contactName},
      'content': text,
      'type': type ?? 'text',
      'isRead': false,
      'createdAt': DateTime.now().toIso8601String(),
      if (attachment != null) 'attachment': attachment,
    };
    setState(() {
      _messages.add(tempMsg);
      if (content == null) _messageController.clear();
    });
    _scrollToBottom();

    _socketService.sendMessage(
      receiverId: widget.contactId,
      content: text,
      type: type ?? 'text',
      attachment: attachment,
      localId: localId,
    );

    setState(() => _isSending = false);
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'png', 'jpg', 'jpeg', 'gif', 'bmp'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) return;

      final uri = Uri.parse('${ApiConfig.baseUrl}/messages/upload');
      final token = await AuthStorageService().getToken();

      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(http.MultipartFile.fromBytes('file', file.bytes!, filename: file.name));

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      final body = jsonDecode(response.body);

      if (body['success'] == true && body['attachment'] != null) {
        final isImage = file.name.toLowerCase().endsWith('.png') ||
            file.name.toLowerCase().endsWith('.jpg') ||
            file.name.toLowerCase().endsWith('.jpeg') ||
            file.name.toLowerCase().endsWith('.gif') ||
            file.name.toLowerCase().endsWith('.bmp');

        _sendMessage(
          content: file.name,
          type: isImage ? 'image' : 'file',
          attachment: Map<String, dynamic>.from(body['attachment']),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erreur lors de l\'upload'), behavior: SnackBarBehavior.floating),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  String _formatMessageTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inDays == 0) {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Hier ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays < 7) {
      return '${dateTime.day}/${dateTime.month} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  String _fileIcon(String mimeType) {
    if (mimeType.contains('pdf')) return '📄';
    if (mimeType.contains('word') || mimeType.contains('doc')) return '📝';
    if (mimeType.contains('excel') || mimeType.contains('sheet') || mimeType.contains('xls')) return '📊';
    if (mimeType.contains('presentation') || mimeType.contains('powerpoint') || mimeType.contains('ppt')) return '📽';
    if (mimeType.contains('text') || mimeType.contains('txt')) return '📃';
    return '📎';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isOnline ? Colors.green[100] : Colors.grey[200],
              ),
              child: Center(
                child: Text(
                  widget.contactName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _isOnline ? Colors.green[700] : Colors.grey[600],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.contactName,
                    style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_isTyping)
                    Text(
                      'En train d\'écrire...',
                      style: TextStyle(color: Colors.blue[600], fontSize: 12, fontStyle: FontStyle.italic),
                    )
                  else
                    Text(
                      _isOnline ? 'En ligne' : 'Hors ligne',
                      style: TextStyle(color: _isOnline ? Colors.green[600] : Colors.grey[500], fontSize: 12),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildBody()),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadMessages, child: const Text('Réessayer')),
          ],
        ),
      );
    }

    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('Commencez la conversation', style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            Text('Envoyez un message à ${widget.contactName.split(' ').first}', style: TextStyle(fontSize: 14, color: Colors.grey[400])),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) => _buildMessageBubble(_messages[index]),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final sender = message['sender'] is Map
        ? (message['sender'] as Map<String, dynamic>)
        : <String, dynamic>{};
    final senderId = sender['_id']?.toString() ?? '';
    final isMe = senderId == _socketService.currentUserId || senderId.isEmpty;
    final type = message['type']?.toString() ?? 'text';
    final content = message['content']?.toString() ?? '';
    final attachment = message['attachment'] is Map
        ? (message['attachment'] as Map<String, dynamic>)
        : null;
    final isRead = message['isRead'] == true;
    final isFailed = message['_error'] == true;
    final createdAtStr = message['createdAt']?.toString() ?? '';
    final createdAt = createdAtStr.isNotEmpty ? DateTime.tryParse(createdAtStr) ?? DateTime.now() : DateTime.now();

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(left: 44, bottom: 2),
                child: Text(sender['name']?.toString() ?? '', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isMe) const SizedBox(width: 0),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isMe ? const Color(0xFF0084FF) : const Color(0xFFE4E6EB),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: Radius.circular(isMe ? 20 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 20),
                      ),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 1)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (type == 'file' && attachment != null)
                          _buildFileBubble(attachment, isMe, content)
                        else if (type == 'image' && attachment != null)
                          _buildImageBubble(attachment, isMe, content)
                        else
                          Text(
                            content,
                            style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 15, height: 1.3),
                          ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatMessageTime(createdAt),
                              style: TextStyle(color: isMe ? Colors.white70 : Colors.grey[500], fontSize: 11),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 3),
                              Icon(
                                isRead ? Icons.done_all : Icons.done,
                                size: 14,
                                color: isRead ? Colors.blue[200] : Colors.white70,
                              ),
                            ],
                            if (isFailed)
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Icon(Icons.error_outline, size: 14, color: Colors.red),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileBubble(Map<String, dynamic> attachment, bool isMe, String fileName) {
    final mimeType = attachment['mimeType']?.toString() ?? '';
    final size = attachment['size'] != null ? _formatFileSize(attachment['size']) : '';
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isMe ? Colors.white.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_fileIcon(mimeType), style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName.length > 30 ? '${fileName.substring(0, 27)}...' : fileName,
                    style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  if (size.isNotEmpty)
                    Text(size, style: TextStyle(color: isMe ? Colors.white60 : Colors.grey[500], fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageBubble(Map<String, dynamic> attachment, bool isMe, String caption) {
    final url = attachment['url']?.toString() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            url,
            width: 200,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 200,
              height: 120,
              color: Colors.grey[200],
              child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
            ),
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return Container(
                width: 200,
                height: 120,
                color: Colors.grey[100],
                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            },
          ),
        ),
        if (caption.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(caption, style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 13)),
        ],
      ],
    );
  }

  String _formatFileSize(dynamic size) {
    final bytes = (size is int) ? size : int.tryParse(size.toString()) ?? 0;
    if (bytes < 1024) return '$bytes o';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} Ko';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 4),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: _pickFile,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: Icon(Icons.attach_file_rounded, color: Colors.grey[600], size: 24),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                controller: _messageController,
                focusNode: _focusNode,
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) _sendMessage();
                },
                decoration: InputDecoration(
                  hintText: 'Écrire un message...',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF0F2F5),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              margin: const EdgeInsets.only(bottom: 4),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: _isSending || _messageController.text.trim().isEmpty
                      ? null
                      : () => _sendMessage(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (_isSending || _messageController.text.trim().isEmpty)
                          ? Colors.grey[200]
                          : const Color(0xFF0084FF),
                      shape: BoxShape.circle,
                    ),
                    child: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Icon(Icons.send_rounded, color: (_isSending || _messageController.text.trim().isEmpty)
                            ? Colors.grey[400]
                            : Colors.white, size: 20),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

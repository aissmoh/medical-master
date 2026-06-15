import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/message_service.dart';
import '../../services/socket_service.dart';
import 'chat_screen.dart';

class PatientMessagesScreen extends StatefulWidget {
  const PatientMessagesScreen({super.key});

  @override
  State<PatientMessagesScreen> createState() => _PatientMessagesScreenState();
}

class _PatientMessagesScreenState extends State<PatientMessagesScreen> with WidgetsBindingObserver {
  final MessageService _messageService = MessageService();
  final SocketService _socketService = SocketService();
  List<Conversation> _conversations = [];
  List<Map<String, dynamic>> _availableUsers = [];
  bool _isLoading = true;
  bool _isLoadingUsers = false;
  String? _error;
  List<String> _onlineUsers = [];
  StreamSubscription? _newMessageSub;
  StreamSubscription? _onlineSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadConversations();
    _setupSocket();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _newMessageSub?.cancel();
    _onlineSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadConversations();
    }
  }

  void _setupSocket() {
    _socketService.connect();
    _newMessageSub = _socketService.onNewMessage.listen((_) => _loadConversations());
    _onlineSub = _socketService.onOnlineUsers.listen((users) {
      setState(() => _onlineUsers = users);
    });
  }

  Future<void> _loadConversations() async {
    try {
      setState(() { _isLoading = true; _error = null; });
      final conversations = await _messageService.getConversations();
      if (mounted) setState(() { _conversations = conversations; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Erreur de chargement'; _isLoading = false; });
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24) return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    if (diff.inDays < 7) return ['Dim', 'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam'][dateTime.weekday % 7];
    return '${dateTime.day} ${['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin', 'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc'][dateTime.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Mes Messages', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(onPressed: _isLoading ? null : _loadConversations, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showNewMessageDialog,
        backgroundColor: Colors.red[500],
        child: const Icon(Icons.edit, color: Colors.white),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadConversations, child: const Text('Réessayer')),
          ],
        ),
      );
    }
    if (_conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.message_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('Aucune conversation', style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Text('Commencez une nouvelle conversation', style: TextStyle(fontSize: 14, color: Colors.grey[400])),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadConversations,
      child: ListView.builder(
        padding: const EdgeInsets.all(15),
        itemCount: _conversations.length,
        itemBuilder: (context, index) => _buildConversationCard(_conversations[index]),
      ),
    );
  }

  Widget _buildConversationCard(Conversation conversation) {
    final contact = conversation.contact;
    final lastMessage = conversation.lastMessage;
    final senderName = contact['name']?.toString() ?? 'Inconnu';
    final messageContent = lastMessage.type == 'file' ? '📎 Fichier' :
        lastMessage.type == 'image' ? '📷 Image' : lastMessage.content;
    final time = _formatTime(lastMessage.createdAt);
    final unreadCount = conversation.unreadCount;
    final isUnread = unreadCount > 0;
    final isOnline = _onlineUsers.contains(conversation.contactId);
    final initials = senderName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join();

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(contactId: conversation.contactId, contactName: senderName),
          ),
        ).then((_) => _loadConversations());
      },
      borderRadius: BorderRadius.circular(15),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, spreadRadius: 2)],
        ),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 55, height: 55,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: isUnread ? Colors.red[100] : Colors.grey[200]),
                  child: Center(
                    child: Text(initials, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isUnread ? Colors.red[700] : Colors.grey[600])),
                  ),
                ),
                if (isOnline)
                  Positioned(
                    bottom: 1, right: 1,
                    child: Container(
                      width: 14, height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.green[500],
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(senderName, style: TextStyle(fontSize: 16, fontWeight: isUnread ? FontWeight.bold : FontWeight.w600, color: Colors.black87)),
                          if (isOnline) ...[
                            const SizedBox(width: 6),
                            Container(
                              width: 7, height: 7,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.green[400]),
                            ),
                          ],
                        ],
                      ),
                      Text(time, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          messageContent,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14, color: isUnread ? Colors.black87 : Colors.grey[600], fontWeight: isUnread ? FontWeight.w500 : FontWeight.normal),
                        ),
                      ),
                      if (unreadCount > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red[500],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(unreadCount.toString(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadAvailableUsers() async {
    try {
      setState(() => _isLoadingUsers = true);
      final users = await _messageService.getUsers();
      if (mounted) setState(() { _availableUsers = users; _isLoadingUsers = false; });
    } catch (e) {
      if (mounted) { setState(() => _isLoadingUsers = false); }
    }
  }

  void _showNewMessageDialog() async {
    await _loadAvailableUsers();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nouveau message', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: _isLoadingUsers
              ? const Center(child: CircularProgressIndicator())
              : _availableUsers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline, size: 48, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text('Aucun utilisateur disponible', style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _availableUsers.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, index) {
                        final user = _availableUsers[index];
                        final userId = user['_id']?.toString() ?? user['id']?.toString() ?? '';
                        final userName = user['name']?.toString() ?? 'Inconnu';
                        final isPatient = user['isPatient'] as bool? ?? true;
                        return ListTile(
                          leading: Stack(
                            children: [
                              CircleAvatar(
                                backgroundColor: isPatient ? Colors.blue[100] : Colors.green[100],
                                child: Text(
                                  userName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join(),
                                  style: TextStyle(color: isPatient ? Colors.blue[700] : Colors.green[700], fontWeight: FontWeight.bold),
                                ),
                              ),
                              if (_onlineUsers.contains(userId))
                                Positioned(
                                  bottom: 0, right: 0,
                                  child: Container(
                                    width: 12, height: 12,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.green[500],
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          title: Text(userName),
                          subtitle: Text(isPatient ? 'Patient' : 'Soignant'),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(contactId: userId, contactName: userName)))
                                .then((_) => _loadConversations());
                          },
                        );
                      },
                    ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../controllers/companion_controller.dart';
import '../../controllers/logout_controller.dart';
import '../../services/nurse_service.dart';
import '../../services/socket_service.dart';
import '../../services/message_service.dart';
import '../widgets/language_selector.dart';
import 'settings_page.dart';
import 'help_page.dart';
import 'about_page.dart';
import 'login_screen.dart';
import '../widgets/common/app_toast.dart';
import 'medications_page.dart';
import 'emergency_page.dart';
import 'patient_messages_screen.dart';
import 'chat_screen.dart';
import 'patient_tracking_screen.dart';

class CompanionDashboardScreen extends StatefulWidget {
  const CompanionDashboardScreen({super.key});

  @override
  State<CompanionDashboardScreen> createState() =>
      _CompanionDashboardScreenState();
}

class _CompanionDashboardScreenState extends State<CompanionDashboardScreen> {
  final CompanionController _controller = CompanionController();
  final SocketService _socketService = SocketService();
  final MessageService _messageService = MessageService();
  int _selectedIndex = 0;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerUpdate);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.fetchDashboardData();
    });
    _setupSocket();
  }

  void _setupSocket() {
    _socketService.connect();
    _loadUnreadCount();
    _socketService.onNewMessage.listen((_) => _loadUnreadCount());
  }

  Future<void> _loadUnreadCount() async {
    try {
      final count = await _messageService.getUnreadCount();
      if (mounted) setState(() => _unreadCount = count);
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerUpdate() {
    setState(() {});
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_controller.isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: Colors.teal),
        ),
      );
    }

    final List<Widget> _pages = [
      _buildHomePage(),
      _buildPatientsPage(),
      const PatientMessagesScreen(),
      _buildAlertsPage(),
      _buildProfilePage(),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(child: _pages[_selectedIndex]),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildHomePage() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildHeader()),
        SliverToBoxAdapter(child: _buildStatsSection()),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bienvenue dans Medical Master',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Utilisez le menu en bas pour naviguer entre les différentes sections.',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 20),
                _buildQuickActions(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Actions rapides',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                'Voir tous les patients',
                Icons.people,
                Colors.blue,
                () => _onItemTapped(1),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildQuickActionCard(
                'Alertes',
                Icons.notifications,
                Colors.red,
                () => _onItemTapped(2),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withAlpha(51), color.withAlpha(26)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withAlpha(77)),
        ),
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withAlpha(100), color.withAlpha(50)],
                ),
                shape: BoxShape.circle,
                border: Border.all(color: color.withAlpha(100)),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade800,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientsPage() {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Mes Patients',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.teal.withAlpha(30),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_controller.patients.length} patients',
                        style: TextStyle(
                          color: Colors.teal.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                ..._controller.patients.map(
                  (patient) => _buildPatientCard(patient),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAlertsPage() {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: _controller.alerts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_none,
                        size: 80,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Aucune alerte pour le moment',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _controller.alerts.length,
                  itemBuilder: (context, index) {
                    final alert = _controller.alerts[index];
                    return _buildAlertCard(alert);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAlertCard(AlertMessage alert) {
    final isCritical = alert.type == 'critical';
    final color = isCritical ? Colors.red : Colors.orange;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isCritical
            ? Colors.red.withAlpha(20)
            : Colors.orange.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCritical ? Icons.emergency : Icons.medication,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.patientName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  alert.message,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 4),
                Text(
                  '${alert.timestamp.hour}:${alert.timestamp.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          if (!alert.isRead)
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
        ],
      ),
    );
  }

  // NEW: Tasks Page
  Widget _buildTasksPage() {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    indicator: BoxDecoration(
                      color: Colors.teal,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.grey.shade600,
                    tabs: const [
                      Tab(text: 'À faire'),
                      Tab(text: 'Terminées'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildTaskList(_controller.pendingTasks),
                      _buildTaskList(_controller.completedTasks),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTaskList(List<TaskItem> tasks) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.task_alt, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 20),
            Text(
              'Aucune tâche',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return _buildTaskCard(task);
      },
    );
  }

  Widget _buildTaskCard(TaskItem task) {
    final typeColor = _getTaskTypeColor(task.type);
    final typeIcon = _getTaskTypeIcon(task.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: task.isCompleted ? Colors.grey.shade100 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: typeColor.withAlpha(100), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: typeColor.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: Icon(typeIcon, color: typeColor, size: 24),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: task.isCompleted ? Colors.grey : Colors.black87,
                    decoration: task.isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  task.patientName,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${task.scheduledTime.hour.toString().padLeft(2, '0')}:${task.scheduledTime.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: typeColor.withAlpha(30),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _getTaskTypeLabel(task.type),
                        style: TextStyle(color: typeColor, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!task.isCompleted)
            GestureDetector(
              onTap: () => _controller.completeTask(task.id),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.green, size: 20),
              ),
            ),
        ],
      ),
    );
  }

  Color _getTaskTypeColor(String type) {
    switch (type) {
      case 'medication':
        return Colors.orange;
      case 'checkup':
        return Colors.blue;
      case 'exercise':
        return Colors.green;
      case 'meal':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getTaskTypeIcon(String type) {
    switch (type) {
      case 'medication':
        return Icons.medication;
      case 'checkup':
        return Icons.medical_services;
      case 'exercise':
        return Icons.directions_walk;
      case 'meal':
        return Icons.restaurant;
      default:
        return Icons.task;
    }
  }

  String _getTaskTypeLabel(String type) {
    switch (type) {
      case 'medication':
        return 'Médicament';
      case 'checkup':
        return 'Contrôle';
      case 'exercise':
        return 'Activité';
      case 'meal':
        return 'Repas';
      default:
        return 'Tâche';
    }
  }

  Widget _buildProfilePage() {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.teal.shade400, Colors.blue.shade400],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _controller.companionName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Companion',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 30),
                _buildProfileMenuItem(
                  Icons.settings,
                  'Paramètres',
                  () => _showSettingsPage(),
                ),
                _buildProfileMenuItem(
                  Icons.help,
                  'Aide',
                  () => _showHelpPage(),
                ),
                _buildProfileMenuItem(
                  Icons.info,
                  'À propos',
                  () => _showAboutPage(),
                ),
                _buildProfileMenuItem(
                  Icons.logout,
                  'Déconnexion',
                  () => _showLogoutDialog(),
                  isDestructive: true,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileMenuItem(
    IconData icon,
    String title,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isDestructive
                ? Colors.red.withOpacity(0.1)
                : Colors.teal.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: isDestructive ? Colors.red : Colors.teal,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: isDestructive ? Colors.red : Colors.black87,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: isDestructive ? Colors.red.withOpacity(0.5) : Colors.grey,
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.teal,
        unselectedItemColor: Colors.grey.shade600,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Accueil'),
          const BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Patients'),
          BottomNavigationBarItem(
            icon: _unreadCount > 0
                ? Badge(
                    label: Text(
                      _unreadCount > 99 ? '99+' : _unreadCount.toString(),
                      style: const TextStyle(fontSize: 10, color: Colors.white),
                    ),
                    child: const Icon(Icons.message_rounded),
                  )
                : const Icon(Icons.message_rounded),
            label: 'Messages',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Alertes'),
          const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal.shade400, Colors.blue.shade400],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.medical_services, color: Colors.white),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bonjour',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                Text(
                  _controller.companionName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          const LanguageSelector(), // ← زر تغيير اللغة
          const SizedBox(width: 8),
          _buildNotificationButton(),
        ],
      ),
    );
  }

  Widget _buildNotificationButton() {
    return GestureDetector(
      onTap: () => _showPendingRequestsBottomSheet(context),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Stack(
          children: [
            Icon(Icons.notifications_outlined, color: Colors.grey.shade700),
            if (_controller.pendingNotifications > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      _controller.pendingNotifications.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showPendingRequestsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.fromLTRB(24, 16, 16, 20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.teal.shade700, Colors.teal.shade500],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Demandes de soins',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_controller.pendingRequests.length} en attente',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withValues(alpha: 0.85),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.close, color: Colors.white),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // List
                      if (_controller.pendingRequests.isEmpty)
                        Expanded(
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_outline, size: 64, color: Colors.grey.shade300),
                                const SizedBox(height: 12),
                                Text(
                                  'Aucune demande en attente',
                                  style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                            itemCount: _controller.pendingRequests.length,
                            itemBuilder: (context, index) {
                              final req = _controller.pendingRequests[index];
                              final initials = req.patientName.isNotEmpty
                                  ? req.patientName.split(' ').map((e) => e[0]).take(2).join().toUpperCase()
                                  : '?';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.06),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Top section: avatar + name + time
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 24,
                                            backgroundColor: Colors.teal.shade100,
                                            child: Text(
                                              initials,
                                              style: TextStyle(
                                                color: Colors.teal.shade800,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  req.patientName,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  req.requestAge,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.grey.shade500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (req.patientBloodGroup != null)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.red.shade50,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: Colors.red.shade200),
                                              ),
                                              child: Text(
                                                req.patientBloodGroup!,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                  color: Colors.red.shade700,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    // Divider
                                    Divider(height: 1, color: Colors.grey.shade100),
                                    // Details section
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                                      child: Column(
                                        children: [
                                          // Urgency badge
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: req.urgencyColor.withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: req.urgencyColor.withValues(alpha: 0.4)),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(req.urgencyIcon, size: 14, color: req.urgencyColor),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      req.urgencyLabel,
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 12,
                                                        color: req.urgencyColor,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const Spacer(),
                                              Icon(Icons.access_time_rounded, size: 14, color: Colors.grey[400]),
                                              const SizedBox(width: 4),
                                              Text(
                                                req.requestAge,
                                                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          _buildRequestInfoRow(Icons.phone_outlined, req.patientPhone, 'Téléphone'),
                                          if (req.patientEmail != null)
                                            _buildRequestInfoRow(Icons.email_outlined, req.patientEmail!, 'Email'),
                                          if (req.patientChamber != null || req.patientBed != null)
                                            _buildRequestInfoRow(
                                              Icons.meeting_room_outlined,
                                              [if (req.patientChamber != null) 'Ch: ${req.patientChamber}', if (req.patientBed != null) 'Lit: ${req.patientBed}'].join(' · '),
                                              'Chambre',
                                            ),
                                          if (req.reason.isNotEmpty)
                                            _buildRequestInfoRow(Icons.edit_rounded, req.reason, 'Motif'),
                                          if (req.symptoms.isNotEmpty)
                                            _buildRequestInfoRow(
                                              Icons.healing_rounded,
                                              req.symptoms.join(', '),
                                              'Symptômes',
                                            ),
                                          if (req.preferredContactTime.isNotEmpty)
                                            _buildRequestInfoRow(Icons.access_time_rounded, req.preferredContactTime, 'Contact préféré'),
                                          if (req.locationLat != null && req.locationLng != null)
                                            _buildRequestInfoRow(
                                              Icons.location_on_rounded,
                                              '${req.locationLat?.toStringAsFixed(6)}, ${req.locationLng?.toStringAsFixed(6)}',
                                              'Localisation',
                                            ),
                                          if (req.patientNotes.isNotEmpty)
                                            _buildRequestInfoRow(Icons.note_rounded, req.patientNotes, 'Notes'),
                                        ],
                                      ),
                                    ),
                                    // Action buttons
                                    Container(
                                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              onPressed: req.status == 'pending' ? () async {
                                                await _controller.refuseRequest(req.id);
                                                setModalState(() {});
                                                setState(() {});
                                              } : null,
                                              icon: const Icon(Icons.close, size: 18),
                                              label: const Text('Refuser'),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: Colors.red.shade600,
                                                side: BorderSide(color: Colors.red.shade300),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                padding: const EdgeInsets.symmetric(vertical: 12),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            flex: 2,
                                            child: ElevatedButton.icon(
                                              onPressed: req.status == 'pending' ? () async {
                                                await _controller.acceptRequest(req.id);
                                                setModalState(() {});
                                                setState(() {});
                                                if (_controller.pendingRequests.isEmpty && context.mounted) {
                                                  Navigator.pop(context);
                                                }
                                              } : null,
                                              icon: const Icon(Icons.check_circle_outline, size: 18),
                                              label: const Text('Accepter la demande'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.teal,
                                                foregroundColor: Colors.white,
                                                elevation: 0,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                padding: const EdgeInsets.symmetric(vertical: 12),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildStatsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _buildStatCard(
            'Patients',
            _controller.totalPatients.toString(),
            Colors.blue,
            iconWidget: Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                image: DecorationImage(
                  image: AssetImage('assets/icons/icon1.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            onTap: () => _showAllPatientsList(),
          ),
          const SizedBox(width: 10),
          _buildStatCard(
            'Medicaments',
            _controller.pendingMedications.toString(),
            Colors.orange,
            icon: Icons.medication,
            onTap: () => _showMedicationsPage(),
          ),
          const SizedBox(width: 10),
          _buildStatCard(
            'Alertes',
            _controller.criticalAlerts.toString(),
            Colors.red,
            icon: Icons.warning,
            onTap: () => _showEmergencyPage(),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestInfoRow(IconData icon, String text, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade500),
          const SizedBox(width: 10),
          Text(
            text,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
          ),
          const Spacer(),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    Color color, {
    IconData? icon,
    Widget? iconWidget,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withAlpha(51), color.withAlpha(26)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withAlpha(77)),
          ),
          child: Column(
            children: [
              // Icon or custom widget
              iconWidget ??
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color.withAlpha(100), color.withAlpha(50)],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(color: color.withAlpha(100)),
                    ),
                    child: Icon(icon ?? Icons.help, color: color, size: 28),
                  ),
              const SizedBox(height: 10),
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPatientCard(PatientSummary patient) {
    return GestureDetector(
      onTap: () => _showPatientDetails(patient),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade300,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: _getStatusColor(patient.status).withAlpha(100),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Profile Image
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _getStatusColor(patient.status).withAlpha(150),
                  width: 3,
                ),
                image: patient.profileImage != null
                    ? DecorationImage(
                        image: AssetImage(patient.profileImage!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: patient.profileImage == null
                  ? Icon(Icons.person, color: Colors.grey.shade400, size: 30)
                  : null,
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    patient.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    patient.roomNumber,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.cake, size: 12, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(
                        '${patient.age} ans',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        patient.gender == 'Homme' ? Icons.male : Icons.female,
                        size: 12,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        patient.gender,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Status Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _getStatusColor(patient.status).withAlpha(30),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: _getStatusColor(patient.status).withAlpha(100),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getStatusIcon(patient.status),
                    color: _getStatusColor(patient.status),
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _getStatusText(patient.status),
                    style: TextStyle(
                      color: _getStatusColor(patient.status),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientVitalCard(
    String label,
    String value,
    IconData icon,
    String trend,
    Color color,
    String backgroundImage,
  ) {
    return Container(
      height: 90,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withAlpha(60), color.withAlpha(30)],
        ),
        border: Border.all(color: color.withAlpha(80)),
        image: DecorationImage(
          image: AssetImage(backgroundImage),
          fit: BoxFit.cover,
          opacity: 0.3,
        ),
      ),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withAlpha(60)],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(icon, color: Colors.white, size: 20),
                    if (trend.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: trend.startsWith('+')
                              ? Colors.green.withAlpha(60)
                              : trend.startsWith('-')
                              ? Colors.red.withAlpha(60)
                              : Colors.grey.withAlpha(60),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          trend,
                          style: TextStyle(
                            color: trend.startsWith('+')
                                ? Colors.green
                                : trend.startsWith('-')
                                ? Colors.red
                                : Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      label,
                      style: TextStyle(
                        color: Colors.white.withAlpha(200),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientVitalCharts(PatientSummary patient) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tendances des signes vitaux',
            style: TextStyle(
              color: Colors.grey.shade800,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 100,
            child: Row(
              children: [
                Expanded(
                  child: _buildPatientMiniChart('Heart Rate', [
                    70,
                    75,
                    72,
                    78,
                    76,
                    75,
                    78,
                  ], Colors.red),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildPatientMiniChart('Température', [
                    36.5,
                    36.6,
                    36.7,
                    36.8,
                    36.6,
                    36.5,
                    36.8,
                  ], Colors.orange),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientMiniChart(
    String label,
    List<double> values,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade700, fontSize: 11),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: CustomPaint(
              size: const Size(double.infinity, 60),
              painter: VitalChartPainter(values, color),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPatientVitalHistory(PatientSummary patient) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Historique des signes vitaux',
            style: TextStyle(
              color: Colors.grey.shade800,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          _buildPatientHistoryHeader(),
          const SizedBox(height: 8),
          _buildPatientHistoryRow(
            '08:00',
            '75 bpm',
            '36.5°C',
            '98%',
            Colors.green,
          ),
          _buildPatientHistoryRow(
            '12:00',
            '78 bpm',
            '36.7°C',
            '97%',
            Colors.orange,
          ),
          _buildPatientHistoryRow(
            '16:00',
            '76 bpm',
            '36.6°C',
            '98%',
            Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildPatientHistoryHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              'Heure',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Icon(Icons.favorite, color: Colors.red, size: 12),
                const SizedBox(width: 2),
                Text(
                  'Heart',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Icon(Icons.thermostat, color: Colors.orange, size: 12),
                const SizedBox(width: 2),
                Text(
                  'Temp',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Icon(Icons.water_drop, color: Colors.blue, size: 12),
                const SizedBox(width: 2),
                Text(
                  'O2',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientHistoryRow(
    String time,
    String heartRate,
    String temp,
    String oxygen,
    Color statusColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: statusColor, width: 3)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.withAlpha(20),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                time,
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              heartRate,
              style: TextStyle(color: Colors.grey.shade800, fontSize: 11),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              temp,
              style: TextStyle(color: Colors.grey.shade800, fontSize: 11),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              oxygen,
              style: TextStyle(color: Colors.grey.shade800, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String value, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(value, style: TextStyle(color: Colors.black87, fontSize: 11)),
        ],
      ),
    );
  }

  Color _getStatusColor(PatientStatus status) {
    switch (status) {
      case PatientStatus.stable:
        return Colors.green;
      case PatientStatus.critical:
        return Colors.red;
      case PatientStatus.monitoring:
        return Colors.orange;
    }
  }

  String _getStatusText(PatientStatus status) {
    switch (status) {
      case PatientStatus.stable:
        return 'Stable';
      case PatientStatus.critical:
        return 'Critique';
      case PatientStatus.monitoring:
        return 'Surveillance';
    }
  }

  IconData _getStatusIcon(PatientStatus status) {
    switch (status) {
      case PatientStatus.stable:
        return Icons.check_circle;
      case PatientStatus.critical:
        return Icons.emergency;
      case PatientStatus.monitoring:
        return Icons.visibility;
    }
  }

  void _showAllPatientsList() {
    _onItemTapped(1);
  }

  void _showMedicationsPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MedicationsPage(controller: _controller),
      ),
    );
  }

  void _showEmergencyPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EmergencyPage(controller: _controller),
      ),
    );
  }

  void _showPatientDetails(PatientSummary patient) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => PatientDetailsSheet(patient: patient),
    );
  }

  void _showSettingsPage() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const SettingsPage()));
  }

  void _showHelpPage() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const HelpPage()));
  }

  void _showAboutPage() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const AboutPage()));
  }

  final LogoutController _logoutController = LogoutController();
  bool _isLoggingOut = false;

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performLogout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );
  }

  Future<void> _performLogout() async {
    final result = await _logoutController.logout();

    if (!mounted) return;

    AppToast.show(
      context,
      message: result.message,
      type: result.success ? AppToastType.success : AppToastType.error,
    );

    if (result.success) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }
}

class PatientDetailsSheet extends StatefulWidget {
  final PatientSummary patient;

  const PatientDetailsSheet({super.key, required this.patient});

  @override
  State<PatientDetailsSheet> createState() => _PatientDetailsSheetState();
}

class _PatientDetailsSheetState extends State<PatientDetailsSheet> {
  List<Map<String, dynamic>>? _chartData;
  bool _isLoadingVitals = true;
  Timer? _refreshTimer;

  PatientSummary get patient => widget.patient;

  @override
  void initState() {
    super.initState();
    _fetchVitalsData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _fetchVitalsData();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchVitalsData() async {
    try {
      final result = await NurseService.getPatientVitalsChart(
        patient.id,
        days: 7,
      );
      if (result['success'] == true && result['data'] != null) {
        final raw = result['data'] as List;
        setState(() {
          _chartData = raw.cast<Map<String, dynamic>>();
          _isLoadingVitals = false;
        });
      } else {
        if (mounted) setState(() => _isLoadingVitals = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingVitals = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                children: [
                  _buildProfileHeader(context),
                  const SizedBox(height: 15),
                  _buildActionButtons(context),
                  const SizedBox(height: 15),
                  _buildLocationSection(context),
                  const SizedBox(height: 15),
                  _buildVitalCardsGrid(),
                  const SizedBox(height: 15),
                  _buildVitalChartsSection(),
                  const SizedBox(height: 15),
                  _buildVitalHistoryTable(),
                  const SizedBox(height: 15),
                  _buildChatSection(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _getStatusColor(patient.status).withAlpha(150),
                width: 3,
              ),
              image: patient.profileImage != null
                  ? DecorationImage(
                      image: AssetImage(patient.profileImage!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: patient.profileImage == null
                ? Icon(Icons.person, color: Colors.grey.shade400, size: 40)
                : null,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patient.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  patient.roomNumber,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.cake, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      '${patient.age} ans',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      patient.gender == 'Homme' ? Icons.male : Icons.female,
                      size: 14,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      patient.gender,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getStatusColor(patient.status).withAlpha(30),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _getStatusColor(patient.status).withAlpha(100),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getStatusIcon(patient.status),
                  color: _getStatusColor(patient.status),
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  _getStatusText(patient.status),
                  style: TextStyle(
                    color: _getStatusColor(patient.status),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.black87, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            children: [
              // Tracking Button
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PatientTrackingScreen(
                          patientId: patient.id,
                          patientName: patient.name,
                          patientAge: patient.age,
                          patientGender: patient.gender,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.indigo.withAlpha(30),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.indigo.withAlpha(100)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.monitor_heart_outlined, color: Colors.indigo, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Suivi médical',
                          style: TextStyle(
                            color: Colors.indigo,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Emergency Button (full width)
          GestureDetector(
            onTap: () => _showEmergencyAlert(context),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(30),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.red.withAlpha(100)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.emergency, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Urgence',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEmergencyAlert(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.red.shade50,
        title: Row(
          children: [
            Icon(Icons.emergency, color: Colors.red),
            const SizedBox(width: 10),
            const Text('Alerte d\'urgence'),
          ],
        ),
        content: Text(
          'Une alerte d\'urgence sera envoyée pour ${patient.name}. '
          'Le médecin et l\'équipe médicale seront notifiés.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Send emergency alert
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Alerte d\'urgence envoyée pour ${patient.name}',
                  ),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSection(BuildContext context) {
    final lat = patient.location?.latitude;
    final lng = patient.location?.longitude;
    final hasCoords = lat != null && lng != null;
    final existingAddress = patient.location?.address;

    final displayAddress = existingAddress != null && existingAddress.isNotEmpty
        ? existingAddress
        : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade100.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: hasCoords
              ? () => _openInGoogleMaps(context, lat, lng)
              : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: hasCoords ? Colors.blue.shade50 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        hasCoords ? Icons.location_on : Icons.location_off,
                        color: hasCoords ? Colors.blue.shade600 : Colors.grey,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Localisation du patient',
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (hasCoords)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.open_in_new, size: 14, color: Colors.blue.shade600),
                            const SizedBox(width: 4),
                            Text(
                              'Ouvrir',
                              style: TextStyle(
                                color: Colors.blue.shade600,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  height: 140,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      colors: hasCoords
                          ? [Colors.blue.shade400, Colors.blue.shade700]
                          : [Colors.grey.shade300, Colors.grey.shade400],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          hasCoords ? Icons.map_rounded : Icons.map_outlined,
                          size: 44,
                          color: hasCoords ? Colors.white.withValues(alpha: 0.9) : Colors.white54,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          hasCoords ? 'Cliquez pour ouvrir' : 'Position non disponible',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (hasCoords)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 11,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.place, color: Colors.blue.shade600, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: displayAddress != null
                          ? Text(
                              displayAddress,
                              style: TextStyle(
                                color: Colors.grey.shade800,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            )
                          : _buildAddressFallback(context, lat, lng),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.access_time, color: Colors.grey.shade400, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      patient.location?.lastUpdated != null
                          ? 'Mis à jour le ${patient.location!.lastUpdated.day.toString().padLeft(2, '0')}/${patient.location!.lastUpdated.month.toString().padLeft(2, '0')} à ${patient.location!.lastUpdated.hour.toString().padLeft(2, '0')}:${patient.location!.lastUpdated.minute.toString().padLeft(2, '0')}'
                          : 'Position non mise à jour',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddressFallback(BuildContext context, double? lat, double? lng) {
    if (lat == null || lng == null) {
      return Text(
        'Aucune position',
        style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
      );
    }

    return FutureBuilder<String>(
      future: _reverseGeocode(lat, lng),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.grey.shade400,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Récupération...',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              ),
            ],
          );
        }
        return Text(
          snapshot.data ?? '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
          style: TextStyle(
            color: Colors.grey.shade800,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        );
      },
    );
  }

  Future<String> _reverseGeocode(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final p = placemarks[0];
        final parts = <String>[
          if (p.street != null && p.street!.isNotEmpty) p.street!,
          if (p.locality != null && p.locality!.isNotEmpty) p.locality!,
          if (p.country != null && p.country!.isNotEmpty) p.country!,
        ];
        if (parts.isNotEmpty) return parts.join(', ');
      }
    } catch (_) {}
    return '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
  }

  Future<void> _openInGoogleMaps(BuildContext ctx, double? lat, double? lng) async {
    if (lat != null && lng != null) {
      final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('Position non disponible')),
        );
      }
    }
  }

  Widget _buildChatSection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.chat_bubble, color: Colors.teal, size: 20),
              const SizedBox(width: 8),
              Text(
                'Conversation',
                style: TextStyle(
                  color: Colors.grey.shade800,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      contactId: patient.id,
                      contactName: patient.name,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.message_rounded, color: Colors.white),
              label: const Text(
                'Ouvrir la conversation',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalCardsGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildVitalCard(
                  'Oxygène',
                  Icons.air,
                  patient.lastOxygen,
                  _getOxygenTrend(),
                  Colors.teal,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildVitalCard(
                  'Heart Rate',
                  Icons.favorite,
                  patient.lastHeartRate,
                  _getHeartRateTrend(),
                  Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildVitalCard(
                  'Température',
                  Icons.thermostat,
                  patient.lastTemperature,
                  'Normal',
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildVitalCard(
                  'الدوخة',
                  Icons.psychology,
                  'Stable',
                  '',
                  Colors.blue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getOxygenTrend() {
    if (_chartData == null || _chartData!.length < 2) return '';
    final last = _chartData!.last['oxygenLevel'] as num?;
    final prev = _chartData![_chartData!.length - 2]['oxygenLevel'] as num?;
    if (last == null || prev == null) return '';
    final diff = last - prev;
    if (diff > 0) return '+${diff.toStringAsFixed(1)}%';
    if (diff < 0) return '${diff.toStringAsFixed(1)}%';
    return 'Stable';
  }

  String _getHeartRateTrend() {
    if (_chartData == null || _chartData!.length < 2) return '';
    final last = _chartData!.last['heartRate'] as num?;
    final prev = _chartData![_chartData!.length - 2]['heartRate'] as num?;
    if (last == null || prev == null) return '';
    final diff = last - prev;
    if (diff > 0) return '+${diff.toStringAsFixed(0)}';
    if (diff < 0) return '${diff.toStringAsFixed(0)}';
    return 'Stable';
  }

  Widget _buildVitalCard(
    String label,
    IconData icon,
    String displayValue,
    String trend,
    Color color,
  ) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withAlpha(60), color.withAlpha(30)],
        ),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withAlpha(50)],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(icon, color: Colors.white, size: 24),
                    if (trend.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: trend.startsWith('+')
                              ? Colors.green.withAlpha(60)
                              : trend.startsWith('-')
                              ? Colors.red.withAlpha(60)
                              : Colors.grey.withAlpha(60),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          trend,
                          style: TextStyle(
                            color: trend.startsWith('+')
                                ? Colors.green
                                : trend.startsWith('-')
                                ? Colors.red
                                : Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayValue,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      label,
                      style: TextStyle(
                        color: Colors.white.withAlpha(200),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalChartsSection() {
    final hrValues = _extractChartValues('heartRate');
    final tempValues = _extractChartValues('temperature');
    final hasData = hrValues.isNotEmpty || tempValues.isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tendances des signes vitaux',
            style: TextStyle(
              color: Colors.grey.shade800,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          if (_isLoadingVitals)
            const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (!hasData)
            SizedBox(
              height: 120,
              child: Center(
                child: Text(
                  'Aucune donnée de tendance disponible',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                ),
              ),
            )
          else
            SizedBox(
              height: 120,
              child: Row(
                children: [
                  Expanded(
                    child: _buildMiniChart(
                      'Heart Rate',
                      hrValues,
                      Colors.red,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMiniChart(
                      'Température',
                      tempValues,
                      Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<double> _extractChartValues(String key) {
    if (_chartData == null || _chartData!.isEmpty) return [];
    return _chartData!
        .map((e) => (e[key] as num?)?.toDouble())
        .where((v) => v != null)
        .cast<double>()
        .toList();
  }

  Widget _buildMiniChart(String label, List<double> values, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: CustomPaint(
              size: const Size(double.infinity, 80),
              painter: VitalChartPainter(values, color),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVitalHistoryTable() {
    final recentEntries = _getRecentHistoryEntries();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Historique des signes vitaux',
                  style: TextStyle(
                    color: Colors.grey.shade800,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_isLoadingVitals)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.grey.shade400,
                    ),
                  ),
              ],
            ),
          ),
          if (recentEntries.isEmpty && !_isLoadingVitals)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
              child: Center(
                child: Text(
                  'Aucune donnée disponible',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                ),
              ),
            )
          else
            ListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 15),
              children: [
                _buildHistoryTableHeader(),
                ...recentEntries,
              ],
            ),
        ],
      ),
    );
  }

  List<Widget> _getRecentHistoryEntries() {
    if (_chartData == null || _chartData!.isEmpty) return [];

    final entries = _chartData!.reversed.take(10).toList();
    return entries.map((entry) {
      final hr = entry['heartRate'] as num?;
      final temp = entry['temperature'] as num?;
      final o2 = entry['oxygenLevel'] as num?;
      final date = entry['date'] as String?;

      final timeStr = date != null
          ? _formatTime(date)
          : '--:--';
      final hrStr = hr != null ? '${hr.toStringAsFixed(0)} bpm' : '--';
      final tempStr = temp != null ? '${temp.toStringAsFixed(1)}°C' : '--';
      final o2Str = o2 != null ? '${o2.toStringAsFixed(0)}%' : '--';

      Color statusColor;
      if (hr != null && (hr < 60 || hr > 100)) {
        statusColor = Colors.red;
      } else if (temp != null && (temp < 36.0 || temp > 37.5)) {
        statusColor = Colors.orange;
      } else {
        statusColor = Colors.green;
      }

      return _buildHistoryTableRow(timeStr, hrStr, tempStr, o2Str, statusColor);
    }).toList();
  }

  String _formatTime(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '--:--';
    }
  }

  Widget _buildHistoryTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              'Heure',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Icon(Icons.favorite, color: Colors.red, size: 14),
                const SizedBox(width: 4),
                Text(
                  'Heart',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Icon(Icons.thermostat, color: Colors.orange, size: 14),
                const SizedBox(width: 4),
                Text(
                  'Temp',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Icon(Icons.water_drop, color: Colors.blue, size: 14),
                const SizedBox(width: 4),
                Text(
                  'O2',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTableRow(
    String time,
    String heartRate,
    String temp,
    String oxygen,
    Color statusColor,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: statusColor, width: 3)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                time,
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              heartRate,
              style: TextStyle(color: Colors.grey.shade800, fontSize: 13),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              temp,
              style: TextStyle(color: Colors.grey.shade800, fontSize: 13),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              oxygen,
              style: TextStyle(color: Colors.grey.shade800, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(PatientStatus status) {
    switch (status) {
      case PatientStatus.stable:
        return Colors.green;
      case PatientStatus.critical:
        return Colors.red;
      case PatientStatus.monitoring:
        return Colors.orange;
    }
  }

  String _getStatusText(PatientStatus status) {
    switch (status) {
      case PatientStatus.stable:
        return 'Stable';
      case PatientStatus.critical:
        return 'Critique';
      case PatientStatus.monitoring:
        return 'Surveillance';
    }
  }

  IconData _getStatusIcon(PatientStatus status) {
    switch (status) {
      case PatientStatus.stable:
        return Icons.check_circle;
      case PatientStatus.critical:
        return Icons.emergency;
      case PatientStatus.monitoring:
        return Icons.visibility;
    }
  }

}

class VitalChartPainter extends CustomPainter {
  final List<double> values;
  final Color color;

  VitalChartPainter(this.values, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = color.withAlpha(30)
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final range = max - min;

    final stepX = size.width / (values.length - 1);

    for (int i = 0; i < values.length; i++) {
      final x = i * stepX;
      final y =
          size.height - ((values[i] - min) / range) * size.height * 0.8 - 10;

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    final pointPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    for (int i = 0; i < values.length; i++) {
      final x = i * stepX;
      final y =
          size.height - ((values[i] - min) / range) * size.height * 0.8 - 10;
      canvas.drawCircle(Offset(x, y), 3, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

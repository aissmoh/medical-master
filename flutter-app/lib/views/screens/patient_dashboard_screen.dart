import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import '../../controllers/patient_dashboard_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../services/vital_signs_service.dart';
import '../../services/patient_service.dart';
import '../../services/socket_service.dart';
import '../../services/message_service.dart';
import '../widgets/patient/nurse_info_card.dart';
import 'patient_profile_screen.dart';
import 'patient_calendar_screen_real.dart';
import 'patient_messages_screen.dart';
import 'patient_alerts_screen.dart';
import 'patient_requests_screen.dart';
import 'sos_screen.dart';
import 'find_nurse_choice_screen.dart';

class PatientDashboardScreen extends StatefulWidget {
  const PatientDashboardScreen({super.key});

  @override
  State<PatientDashboardScreen> createState() => _PatientDashboardScreenState();
}

class _PatientDashboardScreenState extends State<PatientDashboardScreen> {
  final PatientDashboardController _controller = PatientDashboardController();
  final ThemeController _themeController = ThemeController();

  Map<String, dynamic>? _nurseInfo;
  bool _isLoadingNurse = false;
  int _unreadCount = 0;
  final SocketService _socketService = SocketService();
  final MessageService _messageService = MessageService();

  Timer? _locationTimer;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerUpdate);
    _themeController.addListener(_onControllerUpdate);
    _controller.loadPatientName();
    _controller.loadProfileAndVitals();
    _loadNurseInfo();
    _setupSocket();
    _startPeriodicLocationUpdate();
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

  Future<void> _loadNurseInfo() async {
    setState(() => _isLoadingNurse = true);
    try {
      final result = await PatientService.getMyNurse();
      setState(() {
        _nurseInfo = (result['success'] == true && result['nurse'] != null)
            ? result['nurse'] as Map<String, dynamic>
            : null;
        _isLoadingNurse = false;
      });
    } catch (e) {
      setState(() => _isLoadingNurse = false);
    }
  }

  void _startPeriodicLocationUpdate() {
    _sendCurrentLocation();
    _locationTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _sendCurrentLocation();
    });
  }

  Future<void> _sendCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) return;
      if (permission == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      String? address;
      try {
        final placemarks = await placemarkFromCoordinates(
          pos.latitude,
          pos.longitude,
        );
        if (placemarks.isNotEmpty) {
          final p = placemarks[0];
          final parts = <String>[
            if (p.street != null && p.street!.isNotEmpty) p.street!,
            if (p.locality != null && p.locality!.isNotEmpty) p.locality!,
            if (p.country != null && p.country!.isNotEmpty) p.country!,
          ];
          address = parts.isNotEmpty ? parts.join(', ') : null;
        }
      } catch (_) {}

      await PatientService.sendMyLocation(
        lat: pos.latitude,
        lng: pos.longitude,
        address: address,
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerUpdate() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _buildBody(),
      bottomNavigationBar: _buildModernBottomNav(),
      floatingActionButton: _buildEmergencyButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildBody() {
    switch (_controller.selectedIndex) {
      case 0:
        return _buildModernDashboard();
      case 1:
        return const PatientCalendarScreenReal();
      case 2:
        return const PatientMessagesScreen();
      case 3:
        return const PatientProfileScreen();
      default:
        return _buildModernDashboard();
    }
  }

  Widget _buildModernDashboard() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGreetingHeader(),
            const SizedBox(height: 16),
            _buildNurseSection(),
            const SizedBox(height: 16),
            _buildVitalCardsGrid(),
            const SizedBox(height: 20),
            _buildFindNurseButton(),
            const SizedBox(height: 20),
            _buildVideoConsultationCard(),
            const SizedBox(height: 20),
            _buildStressLevelSection(),
            const SizedBox(height: 30),
            _buildHeartRateVariabilityChart(),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildGreetingHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Profile image
        Container(
          width: 55,
          height: 55,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipOval(
            child: _controller.profileImageUrl != null
                ? Image.network(
                    _controller.profileImageUrl!,
                    fit: BoxFit.cover,
                    width: 50,
                    height: 50,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[200],
                        child: Icon(
                          Icons.person_rounded,
                          size: 28,
                          color: Colors.grey[500],
                        ),
                      );
                    },
                  )
                : Image.asset(
                    'assets/images/profil1.jpg',
                    fit: BoxFit.cover,
                    width: 50,
                    height: 50,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[200],
                        child: Icon(
                          Icons.person_rounded,
                          size: 28,
                          color: Colors.grey[500],
                        ),
                      );
                    },
                  ),
          ),
        ),
        // Greeting
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bonjour 👋',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                _controller.isLoadingName
                    ? Row(
                        children: [
                          Text(
                            'Chargement',
                            style: TextStyle(
                              fontSize: 20,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.grey[400],
                            ),
                          ),
                        ],
                      )
                    : Text(
                        _controller.patientName,
                        style: const TextStyle(
                          fontSize: 20,
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
              ],
            ),
          ),
        ),
        // Icons row
        Row(
          children: [
            // Theme toggle
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[100],
              ),
              child: IconButton(
                onPressed: () {
                  _themeController.toggleTheme();
                },
                icon: Icon(
                  _themeController.isDarkMode
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                  color: _themeController.isDarkMode
                      ? Colors.yellow[700]
                      : Colors.orange[600],
                  size: 20,
                ),
                padding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(width: 10),
            // Settings
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[100],
              ),
              child: IconButton(
                onPressed: () {},
                icon: Icon(
                  Icons.settings_outlined,
                  color: Colors.grey[600],
                  size: 20,
                ),
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNurseSection() {
    return Column(
      children: [
        NurseInfoCard(
          nurseInfo: _nurseInfo,
          isLoading: _isLoadingNurse,
          onContact: _nurseInfo != null
              ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PatientMessagesScreen()),
                  );
                }
              : null,
          onAlert: _nurseInfo != null
              ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SOSScreen()),
                  );
                }
              : null,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _QuickLinkCard(
                icon: Icons.history_rounded,
                label: 'Mes alertes',
                color: const Color(0xFFEF4444),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PatientAlertsScreen())),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickLinkCard(
                icon: Icons.person_add_alt_rounded,
                label: 'Mes demandes',
                color: const Color(0xFF3B82F6),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PatientRequestsScreen())),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVitalCardsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 15,
      crossAxisSpacing: 15,
      childAspectRatio: 1.4,
      children: [
        _buildVitalCard(
          'Oxygène',
          '96%',
          '+2%',
          Colors.blue[400]!,
          Colors.blue[100]!,
        ),
        _buildVitalCard(
          'Fréquence Cardiaque',
          '78 bpm',
          '-4%',
          Colors.red[400]!,
          Colors.red[100]!,
        ),
        _buildVitalCard(
          'Température',
          '36.8°C',
          'Normal',
          Colors.orange[400]!,
          Colors.orange[100]!,
        ),
        _buildVitalCard(
          'Vertige',
          '16 rpm',
          'Stable',
          Colors.green[400]!,
          Colors.green[100]!,
        ),
      ],
    );
  }

  Widget _buildVitalCard(
    String title,
    String value,
    String change,
    Color primaryColor,
    Color backgroundColor,
  ) {
    final bool hasBackgroundImage =
        title == 'Oxygène' ||
        title == 'Fréquence Cardiaque' ||
        title == 'Vertige' ||
        title == 'Température';
    final String imagePath = title == 'Oxygène'
        ? 'assets/images/OXYGINE.jpg'
        : title == 'Fréquence Cardiaque'
        ? 'assets/images/heart.jpg'
        : title == 'Vertige'
        ? 'assets/images/VERITQGE.jpg'
        : title == 'Température'
        ? 'assets/images/.png'
        : '';

    // Determine health status color
    final Color statusColor = _getHealthStatusColor(title, value);
    final bool isHealthy = statusColor == Colors.green;

    return InkWell(
      onTap: () => _showVitalDetails(title, value, change),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: hasBackgroundImage ? null : backgroundColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
          border: Border.all(
            color: statusColor.withValues(alpha: 0.5),
            width: 2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasBackgroundImage)
                Image.asset(
                  imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(color: backgroundColor);
                  },
                )
              else
                Container(color: backgroundColor),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Health status indicator dot
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: statusColor,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: statusColor.withValues(alpha: 0.6),
                                blurRadius: 8,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isHealthy
                                ? Colors.green[100]
                                : Colors.red[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            change,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isHealthy
                                  ? Colors.green[700]
                                  : Colors.red[700],
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
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: hasBackgroundImage
                                ? Colors.white
                                : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            color: hasBackgroundImage
                                ? Colors.white70
                                : Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getHealthStatusColor(String title, String value) {
    switch (title) {
      case 'Oxygène':
        // Normal: 95-100%, Warning: below 95%
        final int oxygen = int.tryParse(value.replaceAll('%', '')) ?? 96;
        return oxygen >= 95 ? Colors.green : Colors.red;
      case 'Fréquence Cardiaque':
        // Normal: 60-100 bpm
        final int heartRate = int.tryParse(value.replaceAll(' bpm', '')) ?? 78;
        return (heartRate >= 60 && heartRate <= 100)
            ? Colors.green
            : Colors.red;
      case 'Température':
        // Normal: 36-37.5°C
        final double temp = double.tryParse(value.replaceAll('°C', '')) ?? 36.8;
        return (temp >= 36.0 && temp <= 37.5) ? Colors.green : Colors.red;
      case 'Vertige':
        // Normal: 12-20 rpm
        final int resp = int.tryParse(value.replaceAll(' rpm', '')) ?? 16;
        return (resp >= 12 && resp <= 20) ? Colors.green : Colors.red;
      default:
        return Colors.green;
    }
  }

  Widget _buildStressLevelSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Niveau de Stress',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Faible',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[600],
                ),
              ),
            ],
          ),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Colors.green[300]!, Colors.green[500]!],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withValues(alpha: 0.3),
                  blurRadius: 15,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: Icon(
              Icons.psychology_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeartRateVariabilityChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Variabilité de la Fréquence Cardiaque',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            height: 150,
            child: CustomPaint(
              painter: HeartRateChartPainter(),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '12 am',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '12 pm',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.red[700],
                        ),
                      ),
                    ),
                    Text(
                      '8 pm',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Statistics row
          Row(
            children: [
              Expanded(child: _buildStatCard('Min', '62', 'bpm', Colors.blue)),
              const SizedBox(width: 10),
              Expanded(child: _buildStatCard('Moy', '78', 'bpm', Colors.green)),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatCard('Max', '95', 'bpm', Colors.orange),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Health tip
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal[50]!, Colors.teal[100]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.teal[200]!),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.teal[500],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.favorite,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '💡 Conseil Santé',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal[700],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Votre rythme cardiaque est stable. Continuez à faire de l\'exercice régulièrement !',
                        style: TextStyle(fontSize: 12, color: Colors.teal[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, String unit, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 10,
                  color: color.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showVitalDetails(String title, String value, String change) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          VitalDetailsSheet(title: title, value: value, change: change),
    );
  }

  Widget _buildFindNurseButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const FindNurseChoiceScreen(),
          ),
        ),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF00BFA5), Color(0xFF00796B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00BFA5).withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 4,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.medical_services_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Trouver un Garde Malade',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Recherchez par contact ou parcourez la liste',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.8),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Color(0xFF00BFA5),
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoConsultationCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple[600]!, Colors.purple[800]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withValues(alpha: 0.3),
            blurRadius: 15,
            spreadRadius: 3,
          ),
        ],
      ),
      child: InkWell(
        onTap: _startVideoConsultation,
        borderRadius: BorderRadius.circular(20),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.2),
              ),
              child: const Icon(
                Icons.video_call_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Consultation Vidéo',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Appeler Dr. Ahmed Ben Ali',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.call, color: Colors.purple, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Appeler',
                    style: TextStyle(
                      color: Colors.purple,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startVideoConsultation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.video_call, color: Colors.purple, size: 30),
            SizedBox(width: 10),
            Text('Consultation Vidéo'),
          ],
        ),
        content: const Text(
          'L\'appel vidéo avec Dr. Ahmed Ben Ali va démarrer. Êtes-vous prêt?',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showCallingDialog();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Commencer'),
          ),
        ],
      ),
    );
  }

  void _showCallingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 20),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.purple[100],
              ),
              child: Icon(Icons.video_call, color: Colors.purple, size: 40),
            ),
            const SizedBox(height: 20),
            const Text(
              'Appel en cours...',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Connexion avec Dr. Ahmed Ben Ali',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(15),
                  ),
                  child: const Icon(Icons.call_end),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildModernBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _controller.selectedIndex,
        onTap: _controller.onTabChanged,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: Colors.red[500],
        unselectedItemColor: Colors.grey[400],
        type: BottomNavigationBarType.fixed,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Accueil',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_rounded),
            label: 'Calendrier',
          ),
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
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyButton() {
    return Container(
      width: 65,
      height: 65,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Colors.red[600]!, Colors.red[800]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.4),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: _triggerEmergency,
          customBorder: const CircleBorder(),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.warning_rounded, color: Colors.white, size: 28),
                Text(
                  'SOS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _triggerEmergency() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SOSScreen()),
    );
  }

  void _sendEmergencyAlert() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 30),
            SizedBox(width: 10),
            Text('Envoyé!'),
          ],
        ),
        content: const Text(
          'L\'alerte d\'urgence a été envoyée avec succès. L\'équipe de soins vous contactera dans quelques minutes.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('D\'accord'),
          ),
        ],
      ),
    );
  }
}

class HeartRateChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red[400]!
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = Colors.red[100]!
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    final points = _generateHeartRatePoints(size);

    // Create fill path
    fillPath.moveTo(0, size.height);
    fillPath.lineTo(points.first.dx, points.first.dy);

    // Create main path
    path.moveTo(points.first.dx, points.first.dy);

    for (int i = 1; i < points.length; i++) {
      final current = points[i];
      final previous = points[i - 1];

      final controlPoint1 = Offset(
        previous.dx + (current.dx - previous.dx) * 0.3,
        previous.dy,
      );
      final controlPoint2 = Offset(
        previous.dx + (current.dx - previous.dx) * 0.7,
        current.dy,
      );

      path.cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        current.dx,
        current.dy,
      );

      fillPath.cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        current.dx,
        current.dy,
      );
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    // Draw fill
    canvas.drawPath(fillPath, fillPaint);

    // Draw line
    canvas.drawPath(path, paint);

    // Draw dots at data points
    final dotPaint = Paint()
      ..color = Colors.red[500]!
      ..style = PaintingStyle.fill;

    for (final point in points) {
      canvas.drawCircle(point, 4, dotPaint);
    }
  }

  List<Offset> _generateHeartRatePoints(Size size) {
    final points = <Offset>[];
    final random = Random(42);

    for (int i = 0; i <= 20; i++) {
      final x = (i / 20) * size.width;
      final baseY = size.height * 0.5;
      final variation = (random.nextDouble() - 0.5) * size.height * 0.3;
      final y = baseY + variation;
      points.add(Offset(x, y));
    }

    return points;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class VitalDetailsSheet extends StatefulWidget {
  final String title;
  final String value;
  final String change;

  const VitalDetailsSheet({
    super.key,
    required this.title,
    required this.value,
    required this.change,
  });

  @override
  State<VitalDetailsSheet> createState() => _VitalDetailsSheetState();
}

class _VitalDetailsSheetState extends State<VitalDetailsSheet> {
  final TextEditingController _valueController = TextEditingController();
  bool _isLoading = false;
  String? _message;
  bool _isLoadingHistory = true;
  List<Map<String, dynamic>> _historyData = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoadingHistory = true;
    });

    try {
      final history = await VitalSignsService.getMyVitalSignsHistory(days: 7);

      // تحويل البيانات للشكل المطلوب
      final processedData = <Map<String, dynamic>>[];

      for (var i = 0; i < history.length; i++) {
        final record = history[i];
        final date = record.measuredAt;
        final formattedDate =
            '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

        // استخراج القيمة حسب نوع العلامة الحيوية
        String value = '';
        if (widget.title == 'Oxygène') {
          value = '${record.oxygenLevel?.value?.toString() ?? '--'}%';
        } else if (widget.title == 'Fréquence Cardiaque') {
          value = '${record.heartRate?.value?.toString() ?? '--'} bpm';
        } else if (widget.title == 'Température') {
          value = '${record.temperature?.value?.toString() ?? '--'}°C';
        } else if (widget.title == 'Vertige') {
          value = '${record.vertigo?.value?.toString() ?? '--'} rpm';
        }

        // حساب التغيير
        String change = 'Normal';
        if (i > 0) {
          final prevRecord = history[i - 1];
          final currentVal = _extractNumericValueFromRecord(
            record,
            widget.title,
          );
          final prevVal = _extractNumericValueFromRecord(
            prevRecord,
            widget.title,
          );
          if (currentVal != null && prevVal != null && prevVal != 0) {
            final diff = ((currentVal - prevVal) / prevVal * 100).round();
            change = diff >= 0 ? '+$diff%' : '$diff%';
          }
        } else {
          change = widget.change;
        }

        processedData.add({
          'date': formattedDate,
          'value': value,
          'change': change,
          'rawData': record,
        });
      }

      // إضافة القيمة الحالية في البداية
      if (processedData.isEmpty || processedData[0]['date'] != _formatToday()) {
        processedData.insert(0, {
          'date': _formatToday(),
          'value': widget.value,
          'change': widget.change,
          'rawData': null,
        });
      }

      setState(() {
        _historyData = processedData;
        _isLoadingHistory = false;
      });
    } catch (e) {
      print('Erreur chargement historique: $e');
      setState(() {
        _isLoadingHistory = false;
      });
    }
  }

  double? _extractNumericValueFromRecord(
    VitalSignsReading record,
    String title,
  ) {
    if (title == 'Oxygène') return record.oxygenLevel?.value;
    if (title == 'Fréquence Cardiaque')
      return record.heartRate?.value?.toDouble();
    if (title == 'Température') return record.temperature?.value;
    if (title == 'Vertige') return record.vertigo?.value?.toDouble();
    return null;
  }

  String _formatToday() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
  }

  double? _extractNumericValue(Map<String, dynamic> record, String title) {
    if (title == 'Oxygène') return record['oxygenLevel']?.toDouble();
    if (title == 'Fréquence Cardiaque') return record['heartRate']?.toDouble();
    if (title == 'Température') return record['temperature']?.toDouble();
    if (title == 'Vertige') return record['vertigo']?.toDouble();
    return null;
  }

  bool _isError = false;

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  Future<void> _saveValue() async {
    if (_valueController.text.isEmpty) return;

    final value = double.tryParse(_valueController.text);
    if (value == null) {
      setState(() {
        _message = 'Valeur invalide';
        _isError = true;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      // Save to database via API
      final result = await VitalSignsService.recordVitalSigns(
        oxygenLevel: widget.title == 'Oxygène' ? value : null,
        heartRate: widget.title == 'Fréquence Cardiaque' ? value : null,
        temperature: widget.title == 'Température' ? value : null,
        vertigo: widget.title == 'Vertige' ? value : null,
      );

      if (result['success'] == true) {
        // Check for alerts based on thresholds
        final alertMessage = _checkAlert(value);

        setState(() {
          _isLoading = false;
          _message =
              alertMessage ??
              'Valeur enregistrée avec succès dans la base de données!';
          _isError = alertMessage != null;
        });

        // Clear input after success
        _valueController.clear();

        // Reload history with new value
        await _loadHistory();

        // Clear message after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _message = null;
            });
          }
        });
      } else {
        setState(() {
          _isLoading = false;
          _message =
              'Erreur: ${result['message'] ?? 'Échec de l\'enregistrement'}';
          _isError = true;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _message = 'Erreur de connexion: $e';
        _isError = true;
      });
    }
  }

  String? _checkAlert(double value) {
    switch (widget.title) {
      case 'Oxygène':
        if (value < 90)
          return '⚠️ ALERTE CRITIQUE: Oxygène très bas!\nVotre infirmier a été notifié.';
        if (value < 95)
          return '⚠️ Attention: Oxygène bas\nVotre infirmier a été notifié.';
        break;
      case 'Fréquence Cardiaque':
        if (value < 50 || value > 120)
          return '⚠️ ALERTE CRITIQUE: Fréquence cardiaque anormale!\nVotre infirmier a été notifié.';
        if (value > 100)
          return '⚠️ Attention: Fréquence élevée\nVotre infirmier a été notifié.';
        break;
      case 'Température':
        if (value < 35 || value > 39)
          return '⚠️ ALERTE CRITIQUE: Température anormale!\nVotre infirmier a été notifié.';
        if (value > 37.5)
          return '⚠️ Attention: Fièvre détectée\nVotre infirmier a été notifié.';
        break;
      case 'Vertige':
        if (value > 30)
          return '⚠️ ALERTE CRITIQUE: Vertige critique!\nVotre infirmier a été notifié.';
        if (value > 20)
          return '⚠️ Attention: Vertige élevé\nVotre infirmier a été notifié.';
        break;
    }
    return null;
  }

  String _getUnit() {
    switch (widget.title) {
      case 'Oxygène':
        return '%';
      case 'Fréquence Cardiaque':
        return 'bpm';
      case 'Température':
        return '°C';
      case 'Vertige':
        return 'rpm';
      default:
        return '';
    }
  }

  String _getHint() {
    switch (widget.title) {
      case 'Oxygène':
        return '95-100';
      case 'Fréquence Cardiaque':
        return '60-100';
      case 'Température':
        return '36.1-37.2';
      case 'Vertige':
        return '0-20';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _getColorForTitle(widget.title),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      widget.value,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🆕 INPUT SECTION
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _getColorForTitle(
                        widget.title,
                      ).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _getColorForTitle(
                          widget.title,
                        ).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.edit,
                              color: _getColorForTitle(widget.title),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Nouvelle mesure',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _getColorForTitle(widget.title),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Entrez votre valeur ${_getHint().isNotEmpty ? '(normale: $_getHint())' : ''}:',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _valueController,
                                keyboardType: TextInputType.numberWithOptions(
                                  decimal: widget.title == 'Température',
                                ),
                                decoration: InputDecoration(
                                  hintText: _getHint(),
                                  suffixText: _getUnit(),
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                ),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _saveValue,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _getColorForTitle(
                                    widget.title,
                                  ),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.save),
                              ),
                            ),
                          ],
                        ),
                        if (_message != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _isError
                                  ? Colors.red.shade50
                                  : Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _isError
                                    ? Colors.red.shade200
                                    : Colors.green.shade200,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _isError ? Icons.warning : Icons.check_circle,
                                  color: _isError
                                      ? Colors.red.shade700
                                      : Colors.green.shade700,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _message!,
                                    style: TextStyle(
                                      color: _isError
                                          ? Colors.red.shade700
                                          : Colors.green.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                  // Graph
                  Text(
                    'Historique des valeurs',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 15),
                  Container(
                    height: 200,
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: CustomPaint(
                      size: const Size(double.infinity, 200),
                      painter: VitalChartPainter(
                        color: _getColorForTitle(widget.title),
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),
                  // Table
                  Text(
                    'Détails des mesures',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 15),
                  _buildDataTable(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getColorForTitle(String title) {
    switch (title) {
      case 'Oxygène':
        return Colors.blue;
      case 'Fréquence Cardiaque':
        return Colors.red;
      case 'Température':
        return Colors.orange;
      case 'Vertige':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  Widget _buildDataTable() {
    // إظهار indicator أثناء التحميل
    if (_isLoadingHistory) {
      return Container(
        height: 150,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: _getColorForTitle(widget.title)),
              const SizedBox(height: 8),
              Text(
                'Chargement de l\'historique...',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    final data = _generateSampleData();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            decoration: BoxDecoration(
              color: _getColorForTitle(widget.title).withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(15),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Date',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _getColorForTitle(widget.title),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Valeur',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _getColorForTitle(widget.title),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Changement',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _getColorForTitle(widget.title),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Data rows
          ...data.map((row) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      row['date']!,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      row['value']!,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _getColorForTitle(widget.title),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      row['change']!,
                      style: TextStyle(
                        fontSize: 12,
                        color: row['change']!.contains('+')
                            ? Colors.green
                            : row['change']!.contains('-')
                            ? Colors.red
                            : Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _generateSampleData() {
    // استخدام البيانات الحقيقية من قاعدة البيانات
    if (_historyData.isNotEmpty) {
      return _historyData.take(5).toList(); // أخذ آخر 5 قياسات
    }

    // Fallback: بيانات تجريبية إذا لم تكن هناك بيانات حقيقية
    return [
      {
        'date': '30/03/2025',
        'value': widget.value,
        'change': widget.change,
        'rawData': null,
      },
      {
        'date': '29/03/2025',
        'value': _getPreviousValue(),
        'change': _getChangeValue(),
        'rawData': null,
      },
      {
        'date': '28/03/2025',
        'value': _getPreviousValue(),
        'change': _getChangeValue(),
        'rawData': null,
      },
      {
        'date': '27/03/2025',
        'value': _getPreviousValue(),
        'change': 'Attention',
        'rawData': null,
      },
      {
        'date': '26/03/2025',
        'value': _getPreviousValue(),
        'change': 'Normal',
        'rawData': null,
      },
    ];
  }

  String _getChangeValue() {
    final changes = ['+1%', '-1%', 'Normal', 'Stable', '+2%'];
    return changes[DateTime.now().millisecond % changes.length];
  }

  String _getPreviousValue() {
    if (widget.title == 'Oxygène') return '95%';
    if (widget.title == 'Fréquence Cardiaque') return '76 bpm';
    if (widget.title == 'Température') return '36.6°C';
    if (widget.title == 'Vertige') return '15 rpm';
    return widget.value;
  }
}

class _QuickLinkCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickLinkCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.15)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[800])),
            ],
          ),
        ),
      ),
    );
  }
}

class VitalChartPainter extends CustomPainter {
  final Color color;

  VitalChartPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    final points = [
      Offset(0, size.height * 0.7),
      Offset(size.width * 0.2, size.height * 0.6),
      Offset(size.width * 0.4, size.height * 0.5),
      Offset(size.width * 0.6, size.height * 0.65),
      Offset(size.width * 0.8, size.height * 0.45),
      Offset(size.width, size.height * 0.4),
    ];

    fillPath.moveTo(0, size.height);
    fillPath.lineTo(points.first.dx, points.first.dy);

    path.moveTo(points.first.dx, points.first.dy);

    for (int i = 1; i < points.length; i++) {
      final current = points[i];
      final previous = points[i - 1];

      final controlPoint1 = Offset(
        previous.dx + (current.dx - previous.dx) * 0.3,
        previous.dy,
      );
      final controlPoint2 = Offset(
        previous.dx + (current.dx - previous.dx) * 0.7,
        current.dy,
      );

      path.cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        current.dx,
        current.dy,
      );

      fillPath.cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        current.dx,
        current.dy,
      );
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (final point in points) {
      canvas.drawCircle(point, 5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

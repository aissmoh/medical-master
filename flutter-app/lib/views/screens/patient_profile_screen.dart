import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../controllers/logout_controller.dart';
import '../../services/patient_service.dart';
import '../widgets/backgrounds/medical_background.dart';
import '../widgets/common/app_toast.dart';
import '../widgets/patient/nurse_info_card.dart';
import 'login_screen.dart';
import 'patient_alerts_screen.dart';
import 'patient_requests_screen.dart';

class PatientProfileScreen extends StatefulWidget {
  const PatientProfileScreen({super.key});

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> {
  final LogoutController _logoutController = LogoutController();
  final ImagePicker _picker = ImagePicker();

  Map<String, dynamic>? _nurseInfo;
  Map<String, dynamic>? _profile;
  bool _isLoadingNurse = false;
  bool _isLoadingProfile = true;
  bool _isUploading = false;

  // Editing state
  bool _isEditing = false;
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  String _selectedGroup = '';
  final List<String> _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.wait([_loadNurseInfo(), _loadProfile()]);
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

  Future<void> _loadProfile() async {
    setState(() => _isLoadingProfile = true);
    try {
      final result = await PatientService.getProfile();
      if (result['success'] == true && result['data'] != null) {
        final data = result['data'] as Map<String, dynamic>;
        setState(() {
          _profile = data;
          _nameCtrl.text = data['name']?.toString() ?? '';
          _phoneCtrl.text = data['phone']?.toString() ?? '';
          _addressCtrl.text = data['address']?.toString() ?? '';
          _selectedGroup = data['groupeSanguin']?.toString() ?? '';
          _isLoadingProfile = false;
        });
      } else {
        setState(() => _isLoadingProfile = false);
      }
    } catch (e) {
      setState(() => _isLoadingProfile = false);
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 800, maxHeight: 800);
    if (picked == null) return;

    setState(() => _isUploading = true);
    try {
      final result = await PatientService.uploadProfilePhoto(picked.path);
      if (result['success'] == true && result['data'] != null) {
        final data = result['data'] as Map<String, dynamic>;
        setState(() {
          _profile = data;
          _isUploading = false;
        });
        AppToast.show(context, message: 'Photo mise à jour', type: AppToastType.success);
      } else {
        setState(() => _isUploading = false);
        AppToast.show(context, message: result['message'] ?? 'Erreur', type: AppToastType.error);
      }
    } catch (e) {
      setState(() => _isUploading = false);
      AppToast.show(context, message: 'Erreur: $e', type: AppToastType.error);
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isUploading = true);
    try {
      final result = await PatientService.updateProfile(
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        groupeSanguin: _selectedGroup.isNotEmpty ? _selectedGroup : null,
        address: _addressCtrl.text.trim(),
      );
      if (result['success'] == true) {
        await _loadProfile();
        AppToast.show(context, message: 'Profil mis à jour', type: AppToastType.success);
      } else {
        AppToast.show(context, message: result['message'] ?? 'Erreur', type: AppToastType.error);
      }
    } catch (e) {
      AppToast.show(context, message: 'Erreur: $e', type: AppToastType.error);
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const MedicalBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: _isLoadingProfile
                  ? const SizedBox(height: 400, child: Center(child: CircularProgressIndicator()))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ProfileHeader(
                          profile: _profile,
                          isUploading: _isUploading,
                          onTapPhoto: _pickAndUploadPhoto,
                          isEditing: _isEditing,
                        ),
                        const SizedBox(height: 24),
                        _ProfileCard(
                          title: 'Informations personnelles',
                          trailing: TextButton.icon(
                            onPressed: () {
                              if (_isEditing) {
                                _saveProfile();
                              }
                              setState(() => _isEditing = !_isEditing);
                            },
                            icon: Icon(_isEditing ? Icons.save_rounded : Icons.edit_rounded, size: 18),
                            label: Text(_isEditing ? 'Enregistrer' : 'Modifier', style: const TextStyle(fontSize: 13)),
                          ),
                          children: [
                            _ProfileItem(
                              label: 'Nom complet',
                              value: _profile?['name']?.toString() ?? '--',
                              icon: Icons.person_rounded,
                              editing: _isEditing,
                              controller: _nameCtrl,
                            ),
                            _ProfileItem(
                              label: 'Email',
                              value: _profile?['email']?.toString() ?? '--',
                              icon: Icons.email_rounded,
                            ),
                            _ProfileItem(
                              label: 'Groupe sanguin',
                              value: _profile?['groupeSanguin']?.toString() ?? 'Non renseigné',
                              icon: Icons.opacity_rounded,
                              editing: _isEditing,
                              isDropdown: true,
                              dropdownValue: _selectedGroup,
                              dropdownItems: _bloodGroups,
                              onChanged: (v) => setState(() => _selectedGroup = v!),
                            ),
                            _ProfileItem(
                              label: 'Téléphone',
                              value: _profile?['phone']?.toString() ?? '--',
                              icon: Icons.phone_rounded,
                              editing: _isEditing,
                              controller: _phoneCtrl,
                            ),
                            _ProfileItem(
                              label: 'Adresse',
                              value: _profile?['address']?.toString() ?? 'Non renseignée',
                              icon: Icons.home_rounded,
                              editing: _isEditing,
                              controller: _addressCtrl,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _HealthTipsCard(),
                        const SizedBox(height: 20),
                        _ProfileCard(
                          title: 'Mon garde malade',
                          children: [
                            NurseInfoCard(
                              nurseInfo: _nurseInfo,
                              isLoading: _isLoadingNurse,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _QuickLinkBtn(
                                    icon: Icons.history_rounded,
                                    label: 'Mes alertes',
                                    color: const Color(0xFFEF4444),
                                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PatientAlertsScreen())),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _QuickLinkBtn(
                                    icon: Icons.person_add_alt_rounded,
                                    label: 'Mes demandes',
                                    color: const Color(0xFF3B82F6),
                                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PatientRequestsScreen())),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 30),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _showLogoutDialog(context),
                            icon: const Icon(Icons.logout_rounded, color: Colors.white),
                            label: const Text('Se déconnecter', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[600],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showLogoutDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.red, size: 28),
            SizedBox(width: 10),
            Text('Déconnexion'),
          ],
        ),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter?', style: TextStyle(fontSize: 16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _performLogout();
    }
  }

  Future<void> _performLogout() async {
    final result = await _logoutController.logout();

    if (!mounted) return;

    AppToast.show(context, message: result.message, type: result.success ? AppToastType.success : AppToastType.error);

    if (result.success) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
    }
  }
}

class _ProfileHeader extends StatelessWidget {
  final Map<String, dynamic>? profile;
  final bool isUploading;
  final VoidCallback onTapPhoto;
  final bool isEditing;

  const _ProfileHeader({
    required this.profile,
    required this.isUploading,
    required this.onTapPhoto,
    required this.isEditing,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = profile?['profileImage']?.toString();
    final name = profile?['name']?.toString() ?? 'Patient';
    final email = profile?['email']?.toString() ?? '';
    final patientId = profile?['_id']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE7ECF3)),
        boxShadow: const [
          BoxShadow(color: Color(0x140F172A), blurRadius: 24, offset: Offset(0, 10)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: isUploading ? null : onTapPhoto,
                child: Stack(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: kAccent, width: 3),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 4))],
                      ),
                      child: ClipOval(
                        child: imageUrl != null && imageUrl.isNotEmpty
                            ? Image.network(imageUrl, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _avatarPlaceholder())
                            : _avatarPlaceholder(),
                      ),
                    ),
                    if (isUploading)
                      Positioned.fill(
                        child: Container(
                          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black38),
                          child: const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: kTextPrimary, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(email, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: kTextSecondary)),
                    if (patientId.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0x1464D3C6),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0x3364D3C6)),
                        ),
                        child: Text(
                          'ID: #${patientId.substring(patientId.length - 6).toUpperCase()}',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: kTextPrimary, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _avatarPlaceholder() {
    return Container(
      color: const Color(0xFFF2F4F7),
      child: const Icon(Icons.person_rounded, size: 40, color: kAccent2),
    );
  }
}

class _HealthTipsCard extends StatelessWidget {
  final List<_HealthTip> _tips = const [
    _HealthTip(Icons.local_drink_rounded, 'Hydratation', 'Buvez au moins 8 verres d\'eau par jour pour maintenir une bonne hydratation.'),
    _HealthTip(Icons.directions_walk_rounded, 'Activité physique', 'Marchez 30 minutes par jour pour améliorer votre santé cardiovasculaire.'),
    _HealthTip(Icons.nightlight_round, 'Sommeil', 'Visez 7-8 heures de sommeil par nuit pour une récupération optimale.'),
    _HealthTip(Icons.restaurant_rounded, 'Alimentation', 'Privilégiez une alimentation riche en fruits, légumes et protéines maigres.'),
    _HealthTip(Icons.favorite_rounded, 'Santé cardiaque', 'Surveillez régulièrement votre tension artérielle et votre fréquence cardiaque.'),
    _HealthTip(Icons.self_improvement_rounded, 'Gestion du stress', 'Pratiquez la respiration profonde ou la méditation 5 minutes par jour.'),
  ];

  @override
  Widget build(BuildContext context) {
    final tip = _tips[DateTime.now().day % _tips.length];
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF64D3C6), Color(0xFF3CA8C0)]),
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [BoxShadow(color: Color(0x2864D3C6), blurRadius: 20, offset: Offset(0, 8))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(tip.icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tip.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(tip.description, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthTip {
  final IconData icon;
  final String title;
  final String description;
  const _HealthTip(this.icon, this.title, this.description);
}

class _ProfileCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Widget? trailing;

  const _ProfileCard({required this.title, required this.children, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE7ECF3)),
        boxShadow: const [BoxShadow(color: Color(0x140F172A), blurRadius: 24, offset: Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: kTextPrimary, fontWeight: FontWeight.w700)),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          ...children,
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _QuickLinkBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickLinkBtn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.15)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700])),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool editing;
  final TextEditingController? controller;
  final bool isDropdown;
  final String dropdownValue;
  final List<String>? dropdownItems;
  final ValueChanged<String?>? onChanged;

  const _ProfileItem({
    required this.label,
    required this.value,
    required this.icon,
    this.editing = false,
    this.controller,
    this.isDropdown = false,
    this.dropdownValue = '',
    this.dropdownItems,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE7ECF3)),
            ),
            child: Icon(icon, color: kAccent, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: kTextSecondary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                if (editing && controller != null)
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: kTextPrimary, fontWeight: FontWeight.w500, fontSize: 14),
                  )
                else if (editing && isDropdown)
                  DropdownButtonFormField<String>(
                    value: dropdownValue.isNotEmpty ? dropdownValue : null,
                    isDense: true,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    hint: Text(value, style: const TextStyle(fontSize: 14)),
                    items: dropdownItems?.map((g) => DropdownMenuItem(value: g, child: Text(g, style: const TextStyle(fontSize: 14)))).toList(),
                    onChanged: onChanged,
                  )
                else
                  Text(
                    value,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: kTextPrimary, fontWeight: FontWeight.w500),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
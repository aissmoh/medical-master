import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/patient_service.dart';
import '../../utils/app_toast.dart';

class RequestNurseByContactScreen extends StatefulWidget {
  const RequestNurseByContactScreen({super.key});

  @override
  State<RequestNurseByContactScreen> createState() =>
      _RequestNurseByContactScreenState();
}

class _RequestNurseByContactScreenState
    extends State<RequestNurseByContactScreen> {
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _reasonController = TextEditingController();
  final _contactTimeController = TextEditingController();
  final _notesController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _gpsEnabled = false;
  bool _gpsFetching = false;
  double? _lat;
  double? _lng;
  String _address = '';

  String _urgency = 'medium';
  final List<String> _selectedSymptoms = [];

  static const _symptomOptions = [
    'Fièvre', 'Douleur', 'Nausée', 'Vertige',
    'Faiblesse', 'Essoufflement', 'Maux de tête',
    'Blessure', 'Infection', 'Autre',
  ];

  static const _reasonSuggestions = [
    'Besoin de surveillance médicale',
    'Symptômes inquiétants',
    'Suivi post-opératoire',
    'Administration de médicaments',
    'Aide pour soins quotidiens',
    'Urgence légère',
    'Autre',
  ];

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _reasonController.dispose();
    _contactTimeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _enableGps() async {
    setState(() => _gpsFetching = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          AppToast.warning(context, 'Veuillez activer la localisation');
        }
        setState(() => _gpsFetching = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _gpsFetching = false);
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          AppToast.error(context,
              'Autorisation de localisation refusée définitivement');
        }
        setState(() => _gpsFetching = false);
        return;
      }

      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
        _gpsEnabled = true;
        _gpsFetching = false;
      });
    } catch (e) {
      setState(() => _gpsFetching = false);
      if (mounted) {
        AppToast.error(context, 'Erreur de localisation: $e');
      }
    }
  }

  void _toggleSymptom(String symptom) {
    setState(() {
      if (_selectedSymptoms.contains(symptom)) {
        _selectedSymptoms.remove(symptom);
      } else {
        _selectedSymptoms.add(symptom);
      }
    });
  }

  Future<void> _sendRequest() async {
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();

    if (email.isEmpty && phone.isEmpty) {
      AppToast.warning(context, 'Veuillez saisir un email ou un numéro');
      return;
    }

    setState(() => _isLoading = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
      ),
    );

    final res = await PatientService.sendCareRequest(
      email: email.isNotEmpty ? email.toLowerCase() : null,
      phone: phone.isNotEmpty ? phone : null,
      reason: _reasonController.text.trim(),
      urgency: _urgency,
      symptoms: _selectedSymptoms.isNotEmpty ? _selectedSymptoms : null,
      lat: _lat,
      lng: _lng,
      address: _address.isNotEmpty ? _address : null,
      preferredContactTime: _contactTimeController.text.trim(),
      patientNotes: _notesController.text.trim(),
    );

    if (mounted) {
      Navigator.pop(context);
      setState(() => _isLoading = false);

      if (res['success']) {
        AppToast.success(
          context,
          res['message'] ?? 'Demande envoyée avec succès !',
        );
        _emailController.clear();
        _phoneController.clear();
        _reasonController.clear();
        _contactTimeController.clear();
        _notesController.clear();
        setState(() {
          _selectedSymptoms.clear();
          _urgency = 'medium';
          _gpsEnabled = false;
          _lat = null;
          _lng = null;
          _address = '';
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
      } else {
        AppToast.error(
          context,
          res['message'] ?? 'Erreur lors de l\'envoi de la demande',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text(
          'Nouvelle Demande',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderCard(),
              const SizedBox(height: 20),
              _buildContactSection(),
              const SizedBox(height: 20),
              _buildRequestDetailsSection(),
              const SizedBox(height: 20),
              _buildGpsSection(),
              const SizedBox(height: 24),
              _buildSubmitButton(),
              const SizedBox(height: 16),
              _buildHelpBanner(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF3F51B5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.medical_services_rounded, color: Colors.white, size: 48),
          const SizedBox(height: 12),
          const Text(
            'Envoyer une demande de soins',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Remplissez les informations ci-dessous pour contacter un garde malade',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildContactSection() {
    return _buildSectionCard(
      icon: Icons.contact_mail_rounded,
      title: 'Contact du garde malade',
      subtitle: 'Email ou téléphone requis',
      children: [
        _buildFieldLabel('Email'),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _emailController,
          hintText: 'exemple@email.com',
          icon: Icons.email_outlined,
          iconColor: const Color(0xFF6C63FF),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey[200])),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('OU',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ),
            Expanded(child: Divider(color: Colors.grey[200])),
          ],
        ),
        const SizedBox(height: 12),
        _buildFieldLabel('Téléphone'),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _phoneController,
          hintText: '+212 6 00 00 00 00',
          icon: Icons.phone_outlined,
          iconColor: const Color(0xFF00BFA5),
          keyboardType: TextInputType.phone,
        ),
      ],
    );
  }

  Widget _buildRequestDetailsSection() {
    return _buildSectionCard(
      icon: Icons.assignment_rounded,
      title: 'Détails de la demande',
      subtitle: 'Aidez le garde malade à comprendre votre besoin',
      children: [
        _buildFieldLabel('Motif de la demande'),
        const SizedBox(height: 8),
        _wrapSuggestions(_reasonSuggestions, (suggestion) {
          _reasonController.text = suggestion;
        }),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _reasonController,
          hintText: 'Décrivez le motif...',
          icon: Icons.edit_rounded,
          iconColor: const Color(0xFFFF6B6B),
          maxLines: 2,
        ),
        const SizedBox(height: 20),
        _buildFieldLabel('Urgence'),
        const SizedBox(height: 8),
        _buildUrgencySelector(),
        const SizedBox(height: 20),
        _buildFieldLabel('Symptômes (optionnel)'),
        const SizedBox(height: 8),
        _wrapSuggestions(_symptomOptions, _toggleSymptom, isToggle: true),
        const SizedBox(height: 16),
        _buildSymptomChips(),
        const SizedBox(height: 20),
        _buildFieldLabel('Meilleur moment pour vous contacter (optionnel)'),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _contactTimeController,
          hintText: 'Ex: Après 14h, en soirée...',
          icon: Icons.access_time_rounded,
          iconColor: const Color(0xFF00BFA5),
        ),
        const SizedBox(height: 20),
        _buildFieldLabel('Notes supplémentaires (optionnel)'),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _notesController,
          hintText: 'Infos utiles pour le garde malade...',
          icon: Icons.note_rounded,
          iconColor: Colors.amber[700]!,
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildGpsSection() {
    return _buildSectionCard(
      icon: Icons.location_on_rounded,
      title: 'Localisation',
      subtitle: _gpsEnabled
          ? 'Position obtenue avec succès'
          : 'Activez votre position pour que le garde vous trouve facilement',
      children: [
        if (_gpsEnabled) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Localisation partagée',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2E7D32),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_lat?.toStringAsFixed(6)}, ${_lng?.toStringAsFixed(6)}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Color(0xFF4CAF50), size: 20),
                  onPressed: _enableGps,
                  tooltip: 'Rafraîchir la position',
                ),
              ],
            ),
          ),
        ] else ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _gpsFetching ? null : _enableGps,
              icon: _gpsFetching
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location_rounded),
              label: Text(_gpsFetching
                  ? 'Obtention de la position...'
                  : 'Activer ma position GPS'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF6C63FF),
                side: const BorderSide(color: Color(0xFF6C63FF)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildUrgencySelector() {
    const levels = [
      {'value': 'low', 'label': 'Faible', 'icon': Icons.arrow_downward_rounded, 'color': Color(0xFF4CAF50)},
      {'value': 'medium', 'label': 'Moyenne', 'icon': Icons.remove_rounded, 'color': Color(0xFFFFA726)},
      {'value': 'high', 'label': 'Haute', 'icon': Icons.arrow_upward_rounded, 'color': Color(0xFFEF5350)},
      {'value': 'emergency', 'label': 'Urgence', 'icon': Icons.warning_rounded, 'color': Color(0xFFD32F2F)},
    ];

    return Row(
      children: levels.map((lvl) {
        final val = lvl['value'] as String;
        final selected = _urgency == val;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _urgency = val),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: selected
                    ? (lvl['color'] as Color).withValues(alpha: 0.12)
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? lvl['color'] as Color
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    lvl['icon'] as IconData,
                    color: selected
                        ? lvl['color'] as Color
                        : Colors.grey[500],
                    size: 20,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lvl['label'] as String,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      color: selected
                          ? lvl['color'] as Color
                          : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSymptomChips() {
    if (_selectedSymptoms.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: _selectedSymptoms.map((s) => Chip(
        label: Text(s, style: const TextStyle(fontSize: 12, color: Colors.white)),
        backgroundColor: const Color(0xFF6C63FF),
        deleteIcon: const Icon(Icons.close, size: 16, color: Colors.white70),
        onDeleted: () => _toggleSymptom(s),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      )).toList(),
    );
  }

  Widget _wrapSuggestions(List<String> items, Function(String) onTap,
      {bool isToggle = false}) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: items.map((item) {
        final selected = isToggle && _selectedSymptoms.contains(item);
        return GestureDetector(
          onTap: () => onTap(item),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFF6C63FF).withValues(alpha: 0.12)
                  : Colors.grey[100],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected
                    ? const Color(0xFF6C63FF)
                    : Colors.grey[300]!,
              ),
            ),
            child: Text(
              item,
              style: TextStyle(
                fontSize: 12,
                color: selected
                    ? const Color(0xFF6C63FF)
                    : Colors.grey[700],
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _sendRequest,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6C63FF),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
          shadowColor: const Color(0xFF6C63FF).withValues(alpha: 0.4),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 24, width: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.send_rounded, size: 22),
                  SizedBox(width: 10),
                  Text(
                    'Envoyer la demande de soins',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildHelpBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber[200]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline_rounded, color: Colors.amber[700], size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Les informations que vous fournissez permettent au garde malade '
              'd\'évaluer votre situation avant d\'accepter la demande. '
              'Activez votre position GPS pour qu\'il puisse vous localiser facilement.',
              style: TextStyle(fontSize: 12, color: Colors.amber[800], height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: const Color(0xFF6C63FF), size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A2E))),
                  Text(subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.grey[700],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    required Color iconColor,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      textInputAction: maxLines > 1 ? TextInputAction.newline : TextInputAction.next,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
        prefixIcon: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        filled: true,
        fillColor: const Color(0xFFF7F9FC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

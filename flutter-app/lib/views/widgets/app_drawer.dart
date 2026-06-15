import 'package:flutter/material.dart';

class AppDrawer extends StatelessWidget {
  final String userName;
  final String userRole;
  final String? profileImage;
  final VoidCallback onLogout;

  const AppDrawer({
    super.key,
    required this.userName,
    required this.userRole,
    this.profileImage,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Drawer(
      child: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1D1F33), Color(0xFF0A0E21)],
                )
              : null,
          color: isDark ? null : Colors.white,
        ),
        child: Column(
          children: [
            // Header with user info
            _buildHeader(context, isDark),
            
            // Menu items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildMenuSection('Menu Principal', isDark),
                  _buildMenuItem(
                    context,
                    icon: Icons.dashboard_outlined,
                    title: 'Tableau de Bord',
                    onTap: () => Navigator.pop(context),
                    isDark: isDark,
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.people_outline,
                    title: 'Mes Patients',
                    onTap: () {},
                    isDark: isDark,
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.calendar_today_outlined,
                    title: 'Rendez-vous',
                    onTap: () {},
                    isDark: isDark,
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.message_outlined,
                    title: 'Messages',
                    badge: '3',
                    onTap: () {},
                    isDark: isDark,
                  ),
                  
                  const SizedBox(height: 24),
                  _buildMenuSection('Paramètres', isDark),
                  _buildMenuItem(
                    context,
                    icon: Icons.person_outline,
                    title: 'Mon Profil',
                    onTap: () {},
                    isDark: isDark,
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.notifications_outlined,
                    title: 'Notifications',
                    onTap: () {},
                    isDark: isDark,
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.dark_mode_outlined,
                    title: 'Mode Sombre',
                    trailing: Switch(
                      value: isDark,
                      onChanged: (value) {
                        // Toggle theme
                      },
                      activeColor: const Color(0xFF00BFA5),
                    ),
                    onTap: () {},
                    isDark: isDark,
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.settings_outlined,
                    title: 'Paramètres',
                    onTap: () {},
                    isDark: isDark,
                  ),
                ],
              ),
            ),
            
            // Logout button
            _buildLogoutButton(context, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00BFA5), Color(0xFF00897B)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00BFA5).withAlpha(50),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: profileImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          profileImage!,
                          fit: BoxFit.cover,
                        ),
                      )
                    : const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 35,
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00BFA5).withAlpha(30),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        userRole,
                        style: const TextStyle(
                          color: Color(0xFF00BFA5),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 12, top: 16),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: isDark ? const Color(0xFF8B8C9B) : Colors.grey.shade600,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? badge,
    Widget? trailing,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isDark ? const Color(0xFF2C2F45).withAlpha(50) : Colors.grey.shade50,
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF00BFA5).withAlpha(20),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF00BFA5),
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: trailing ?? (badge != null
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : Icon(
                Icons.chevron_right,
                color: isDark ? const Color(0xFF8B8C9B) : Colors.grey,
                size: 20,
              )),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: GestureDetector(
        onTap: onLogout,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.red.withAlpha(100),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.logout,
                color: Colors.red.shade400,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Déconnexion',
                style: TextStyle(
                  color: Colors.red.shade400,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

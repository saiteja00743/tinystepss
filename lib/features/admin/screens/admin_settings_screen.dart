import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tinysteps/core/constants/app_theme.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final _supabase = Supabase.instance.client;
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgLight,
        surfaceTintColor: Colors.transparent,
        title: Text('Sign out?', style: AppTextStyles.heading3),
        content: Text('You will be returned to the login screen.', style: AppTextStyles.bodyMedium),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: AppTextStyles.labelBold.copyWith(color: AppColors.textMuted))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Sign out', style: AppTextStyles.buttonLabel),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _supabase.auth.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _supabase.auth.currentUser;
    final name = user?.userMetadata?['full_name'] as String? ?? 'Admin';
    final email = user?.email ?? 'admin@tinysteps.com';

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        title: Text('Settings', style: AppTextStyles.heading2),
        backgroundColor: AppColors.bgLight,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Profile Section ---
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                boxShadow: AppShadows.card,
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 35,
                    backgroundColor: AppColors.primaryLight,
                    child: Text(
                      name[0].toUpperCase(),
                      style: AppTextStyles.heading1.copyWith(color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: AppTextStyles.heading3),
                        Text(email, style: AppTextStyles.bodySmall),
                        const SizedBox(height: AppSpacing.xs),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                          child: Text(
                            'Administrator',
                            style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary, fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Edit profile functionality coming soon!')),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // --- App Preferences ---
            Text('App Preferences', style: AppTextStyles.labelBold.copyWith(color: AppColors.textMuted)),
            const SizedBox(height: AppSpacing.md),
            _buildSettingTile(
              icon: Icons.notifications_none_rounded,
              title: 'Push Notifications',
              subtitle: 'Alerts for attendance and messages',
              trailing: Switch(
                value: _notificationsEnabled,
                onChanged: (val) => setState(() => _notificationsEnabled = val),
              ),
            ),
            _buildSettingTile(
              icon: Icons.dark_mode_outlined,
              title: 'Dark Mode',
              subtitle: 'Easier on the eyes at night',
              trailing: Switch(
                value: _darkModeEnabled,
                onChanged: (val) => setState(() => _darkModeEnabled = val),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // --- Daycare Management ---
            Text('Daycare Management', style: AppTextStyles.labelBold.copyWith(color: AppColors.textMuted)),
            const SizedBox(height: AppSpacing.md),
            _buildSettingTile(
              icon: Icons.business_rounded,
              title: 'Daycare Profile',
              subtitle: 'Contact info, hours, and logo',
              onTap: () {},
            ),
            _buildSettingTile(
              icon: Icons.security_rounded,
              title: 'Roles & Permissions',
              subtitle: 'Control what teachers and staff can access',
              onTap: () {},
            ),
            _buildSettingTile(
              icon: Icons.card_membership_rounded,
              title: 'Subscription',
              subtitle: 'Manage your TinySteps plan',
              onTap: () {},
            ),
            const SizedBox(height: AppSpacing.xl),

            // --- Support & Legal ---
            Text('Support & Legal', style: AppTextStyles.labelBold.copyWith(color: AppColors.textMuted)),
            const SizedBox(height: AppSpacing.md),
            _buildSettingTile(
              icon: Icons.help_outline_rounded,
              title: 'Help Center & FAQ',
              onTap: () {},
            ),
            _buildSettingTile(
              icon: Icons.description_outlined,
              title: 'Privacy Policy',
              onTap: () {},
            ),
            _buildSettingTile(
              icon: Icons.info_outline_rounded,
              title: 'About TinySteps',
              subtitle: 'v1.0.4 - Sunrise Edition',
              onTap: () {},
            ),
            const SizedBox(height: AppSpacing.xl),

            // --- Account Actions ---
            Text('Account', style: AppTextStyles.labelBold.copyWith(color: AppColors.textMuted)),
            const SizedBox(height: AppSpacing.md),
            _buildActionTile(
              icon: Icons.lock_outline_rounded,
              title: 'Change Password',
              onTap: () {},
            ),
            _buildActionTile(
              icon: Icons.logout_rounded,
              title: 'Sign Out',
              textColor: AppColors.danger,
              onTap: _signOut,
            ),
            const SizedBox(height: 100), // Extra space for bottom nav
          ],
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        leading: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.bgLight,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.textMedium, size: 20),
        ),
        title: Text(title, style: AppTextStyles.bodyLarge),
        subtitle: subtitle != null ? Text(subtitle, style: AppTextStyles.bodySmall) : null,
        trailing: trailing ?? const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        onTap: onTap,
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    Color? textColor,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        leading: Icon(icon, color: textColor ?? AppColors.textMedium, size: 20),
        title: Text(title, style: AppTextStyles.bodyLarge.copyWith(color: textColor)),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        onTap: onTap,
      ),
    );
  }
}

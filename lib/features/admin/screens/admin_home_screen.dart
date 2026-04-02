import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:tinysteps/core/constants/app_theme.dart';
import 'package:tinysteps/core/widgets/bottom_nav_bar.dart';
import 'package:tinysteps/features/admin/screens/users_screen.dart';
import 'package:tinysteps/features/admin/screens/classrooms_screen.dart';
import 'package:tinysteps/features/admin/screens/children_overview_screen.dart';
import 'package:tinysteps/features/admin/screens/admin_settings_screen.dart';

/// Admin Home Screen — shell with bottom navigation
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _tabs = const [
    _AdminDashboardContent(),
    UsersScreen(),
    ClassroomsScreen(),
    ChildrenOverviewScreen(),
    AdminSettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_currentIndex != 0) setState(() => _currentIndex = 0);
      },
      child: Scaffold(
        body: IndexedStack(index: _currentIndex, children: _tabs),
        bottomNavigationBar: BottomNavBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          items: const [
            BottomNavBarItem(icon: Icons.dashboard_rounded, label: 'Dashboard'),
            BottomNavBarItem(icon: Icons.people_rounded, label: 'Users'),
            BottomNavBarItem(icon: Icons.class_rounded, label: 'Classrooms'),
            BottomNavBarItem(icon: Icons.child_care_rounded, label: 'Children'),
            BottomNavBarItem(icon: Icons.settings_rounded, label: 'Settings'),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dashboard tab — live stats from DB
// ─────────────────────────────────────────────────────────────────────────────
class _AdminDashboardContent extends StatefulWidget {
  const _AdminDashboardContent();

  @override
  State<_AdminDashboardContent> createState() => _AdminDashboardContentState();
}

class _AdminDashboardContentState extends State<_AdminDashboardContent> {
  final _supabase = Supabase.instance.client;
  late Future<Map<String, int>> _statsFuture;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  void _loadStats() {
    // Single RPC call replaces 6 round-trips → ~300ms vs ~3s
    _statsFuture = _supabase.rpc('admin_dashboard_stats').then((result) {
      final data = result as Map<String, dynamic>;
      return {
        'teachers': (data['teachers'] as num?)?.toInt() ?? 0,
        'pendingTeachers': (data['pendingTeachers'] as num?)?.toInt() ?? 0,
        'parents': (data['parents'] as num?)?.toInt() ?? 0,
        'children': (data['children'] as num?)?.toInt() ?? 0,
        'classrooms': (data['classrooms'] as num?)?.toInt() ?? 0,
        'unassigned': (data['unassigned'] as num?)?.toInt() ?? 0,
      };
    });
  }

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

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        title: Text('Admin Panel', style: AppTextStyles.heading2),
        backgroundColor: AppColors.bgLight,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: _signOut,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async => setState(() => _loadStats()),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xxl + 80,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hello, $name 👋', style: AppTextStyles.heading1),
              Text('Here\'s your daycare at a glance',
                  style: AppTextStyles.bodyMuted),
              const SizedBox(height: AppSpacing.xl),

              // ── Stats Grid ──────────────────────────────────────────
              FutureBuilder<Map<String, int>>(
                future: _statsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.xl),
                        child: CircularProgressIndicator(
                            color: AppColors.primary),
                      ),
                    );
                  }
                  final stats = snapshot.data ??
                      {
                        'teachers': 0,
                        'pendingTeachers': 0,
                        'parents': 0,
                        'children': 0,
                        'classrooms': 0,
                        'unassigned': 0,
                      };

                  return Column(
                    children: [
                      Row(
                        children: [
                          _StatCard(
                            label: 'Teachers',
                            value: '${stats['teachers']}',
                            icon: Icons.school,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          _StatCard(
                            label: 'Pending Approval',
                            value: '${stats['pendingTeachers']}',
                            icon: Icons.pending_actions,
                            color: AppColors.warning,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          _StatCard(
                            label: 'Parents',
                            value: '${stats['parents']}',
                            icon: Icons.family_restroom,
                            color: AppColors.secondary,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          _StatCard(
                            label: 'Children',
                            value: '${stats['children']}',
                            icon: Icons.child_care,
                            color: AppColors.accent,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          _StatCard(
                            label: 'Classrooms',
                            value: '${stats['classrooms']}',
                            icon: Icons.class_,
                            color: AppColors.success,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          _StatCard(
                            label: 'Unassigned',
                            value: '${stats['unassigned']}',
                            icon: Icons.warning_amber,
                            color: AppColors.danger,
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: AppSpacing.sm),
            Text(value,
                style: AppTextStyles.heading1.copyWith(color: color)),
            Text(label, style: AppTextStyles.bodyMuted),
          ],
        ),
      ),
    );
  }
}
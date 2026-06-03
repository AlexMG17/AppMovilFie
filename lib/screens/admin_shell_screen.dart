import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/support_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';
import 'admin_dashboard_screen.dart';
import 'admin_support_list_screen.dart';
import 'attendees_screen.dart';
import 'import_students_screen.dart';
import 'participants_screen.dart';
import 'user_management_screen.dart';

class AdminShellScreen extends StatefulWidget {
  final int initialIndex;

  const AdminShellScreen({super.key, this.initialIndex = 0});

  @override
  State<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends State<AdminShellScreen> {
  late int _selectedIndex;
  int _unreadSupport = 0;
  RealtimeChannel? _supportChannel;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex.clamp(0, 3);
    _loadUnreadCount();
    _supportChannel = SupabaseService.client
        .channel('admin-shell-support')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'soporte_mensajes',
          callback: (_) => _loadUnreadCount(),
        )
        .subscribe();
  }

  @override
  void dispose() {
    _supportChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadUnreadCount() async {
    final convs = await SupportService.getConversationList();
    if (!mounted) return;
    setState(() {
      _unreadSupport = convs.where((c) => !c.lastIsAdmin).length;
    });
  }

  void _selectTab(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      AdminDashboardScreen(onSelectTab: _selectTab),
      const ParticipantsScreen(),
      const ImportStudentsScreen(),
      _MoreScreen(unreadSupport: _unreadSupport),
    ];

    return Scaffold(
      backgroundColor: AppColors.sentryBg,
      body: Stack(
        children: [
          IndexedStack(index: _selectedIndex, children: pages),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _AdminBottomBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _selectTab,
              unreadSupport: _unreadSupport,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pantalla "Más opciones" ───────────────────────────────────────────────────
class _MoreScreen extends StatelessWidget {
  final int unreadSupport;
  const _MoreScreen({this.unreadSupport = 0});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.sentryBg,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 28.h, 20.w, 20.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Más opciones',
                style: TextStyle(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.sentryNavy,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                'Herramientas adicionales',
                style: TextStyle(fontSize: 13.sp, color: AppColors.sentryGrey),
              ),
              SizedBox(height: 24.h),
              _MoreTile(
                icon: Icons.groups_rounded,
                color: AppColors.sentryBlue,
                title: 'Asistentes',
                subtitle: 'Lista en tiempo real de entradas',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AttendeesScreen()),
                ),
              ),
              SizedBox(height: 12.h),
              _MoreTile(
                icon: Icons.manage_accounts_rounded,
                color: const Color(0xFF6A1B9A),
                title: 'Gestión de usuarios',
                subtitle: 'Ascender a admin o validador',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const UserManagementScreen()),
                ),
              ),
              SizedBox(height: 12.h),
              _MoreTile(
                icon: Icons.headset_mic_rounded,
                color: AppColors.sentryCyan,
                title: 'Soporte técnico',
                subtitle: 'Tickets y mensajes de usuarios',
                badgeCount: unreadSupport,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AdminSupportListScreen()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final int badgeCount;

  const _MoreTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: [
            BoxShadow(
              color: AppColors.sentryNavy.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Badge(
              isLabelVisible: badgeCount > 0,
              label: Text('$badgeCount'),
              backgroundColor: AppColors.error,
              child: Container(
                width: 44.w,
                height: 44.w,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(icon, color: color, size: 22.sp),
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.sentryNavy,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    subtitle,
                    style: TextStyle(
                        fontSize: 11.sp, color: AppColors.sentryGrey),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 20.sp, color: AppColors.sentryGrey),
          ],
        ),
      ),
    );
  }
}

class _AdminBottomBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final int unreadSupport;

  const _AdminBottomBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.unreadSupport = 0,
  });

  Widget _item(int idx, IconData outline, IconData filled) {
    final active = selectedIndex == idx;
    return GestureDetector(
      onTap: () => onDestinationSelected(idx),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        child: Icon(
          active ? filled : outline,
          color: active ? AppColors.sentryBlue : AppColors.sentryGrey,
          size: 26.sp,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final active3 = selectedIndex == 3;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      margin: EdgeInsets.fromLTRB(24.w, 0, 24.w, 12.h + bottomPadding),
      height: 60.h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.sentryNavy.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _item(0, Icons.home_outlined, Icons.home_rounded),
          _item(1, Icons.people_outline_rounded, Icons.people_rounded),
          _item(2, Icons.group_add_outlined, Icons.group_add_rounded),
          GestureDetector(
            onTap: () => onDestinationSelected(3),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              child: Badge(
                isLabelVisible: unreadSupport > 0,
                label: Text('$unreadSupport'),
                backgroundColor: AppColors.error,
                child: Icon(
                  Icons.grid_view_rounded,
                  color: active3 ? AppColors.sentryBlue : AppColors.sentryGrey,
                  size: 26.sp,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

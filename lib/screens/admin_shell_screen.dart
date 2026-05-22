import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/support_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';
import 'admin_dashboard_screen.dart';
import 'admin_support_list_screen.dart';
import 'attendees_screen.dart';
import 'import_students_screen.dart';
import 'payment_vouchers_screen.dart';
import 'student_list_screen.dart';

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
      const PaymentVouchersScreen(),
      const ImportStudentsScreen(),
      _MoreScreen(unreadSupport: _unreadSupport),
    ];

    return Scaffold(
      backgroundColor: AppColors.sentryBg,
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: _AdminBottomBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _selectTab,
        unreadSupport: _unreadSupport,
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
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Más opciones',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.sentryNavy,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Herramientas adicionales',
                style: TextStyle(fontSize: 13, color: AppColors.sentryGrey),
              ),
              const SizedBox(height: 28),
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
              const SizedBox(height: 12),
              _MoreTile(
                icon: Icons.list_alt_rounded,
                color: const Color(0xFF0891B2),
                title: 'Lista de estudiantes',
                subtitle: 'Consultar, editar y descargar',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StudentListScreen()),
                ),
              ),
              const SizedBox(height: 12),
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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
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
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.sentryNavy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                        fontSize: 11, color: AppColors.sentryGrey),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 20, color: AppColors.sentryGrey),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Icon(
          active ? filled : outline,
          color: active ? AppColors.sentryBlue : AppColors.sentryGrey,
          size: 26,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final active3 = selectedIndex == 3;
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
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
          _item(1, Icons.receipt_long_outlined, Icons.receipt_long_rounded),
          _item(2, Icons.group_add_outlined, Icons.group_add_rounded),
          GestureDetector(
            onTap: () => onDestinationSelected(3),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Badge(
                isLabelVisible: unreadSupport > 0,
                label: Text('$unreadSupport'),
                backgroundColor: AppColors.error,
                child: Icon(
                  Icons.grid_view_rounded,
                  color: active3 ? AppColors.sentryBlue : AppColors.sentryGrey,
                  size: 26,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

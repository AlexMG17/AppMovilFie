import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/event_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';
import 'payment_vouchers_screen.dart';
import 'student_list_screen.dart';

class ParticipantsScreen extends StatefulWidget {
  const ParticipantsScreen({super.key});

  @override
  State<ParticipantsScreen> createState() => _ParticipantsScreenState();
}

class _ParticipantsScreenState extends State<ParticipantsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  String _userName = '';
  String _eventName = '';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _loadMeta();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadMeta() async {
    final name = await EventService.getCurrentUserName();
    final event = await EventService.getActiveEvent();
    if (mounted) {
      setState(() {
        _userName = name ?? SupabaseService.currentUser?.email ?? '';
        _eventName = event?.nombre ?? '';
      });
    }
  }

  TextStyle _ts(double sz, {FontWeight fw = FontWeight.w400, Color? c}) =>
      GoogleFonts.outfit(
          fontSize: sz.sp, fontWeight: fw, color: c ?? AppColors.sentryNavy);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.sentryBg,
      appBar: AppBar(
        backgroundColor: AppColors.sentryBg,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Participantes', style: _ts(16, fw: FontWeight.w700)),
            if (_eventName.isNotEmpty)
              Text(_eventName, style: _ts(11, c: AppColors.sentryGrey)),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            offset: Offset(0, 44.h),
            onSelected: (value) async {
              if (value == 'logout') {
                final nav = Navigator.of(context);
                await SupabaseService.signOut();
                nav.pushReplacementNamed('/login');
              }
            },
            child: CircleAvatar(
              radius: 16.r,
              backgroundColor: AppColors.sentryCyan.withValues(alpha: 0.16),
              child: Icon(Icons.person_rounded,
                  size: 18.sp, color: AppColors.sentryBlue),
            ),
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _userName,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.sp,
                          color: Colors.black87),
                    ),
                    Text(
                      SupabaseService.currentUser?.email ?? '',
                      style: TextStyle(fontSize: 11.sp, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, size: 16.sp, color: Colors.red),
                    SizedBox(width: 8.w),
                    Text('Cerrar sesión',
                        style: TextStyle(color: Colors.red, fontSize: 14.sp)),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(width: 12.w),
        ],
        bottom: TabBar(
          controller: _tab,
          labelColor: AppColors.sentryBlue,
          unselectedLabelColor: AppColors.sentryGrey,
          indicatorColor: AppColors.sentryBlue,
          indicatorWeight: 3,
          labelStyle:
              GoogleFonts.outfit(fontSize: 13.sp, fontWeight: FontWeight.w600),
          unselectedLabelStyle:
              GoogleFonts.outfit(fontSize: 13.sp, fontWeight: FontWeight.w500),
          tabs: const [
            Tab(text: 'Comprobantes'),
            Tab(text: 'Lista'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          PaymentVouchersScreen(showAppBar: false),
          StudentListScreen(showAppBar: false),
        ],
      ),
    );
  }
}

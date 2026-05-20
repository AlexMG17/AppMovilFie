// SOLO PARA DESARROLLO — eliminar antes de producción
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'admin_dashboard_screen.dart';
import 'attendees_screen.dart';
import 'import_students_screen.dart';
import 'payment_vouchers_screen.dart';
import 'student_list_screen.dart';

class DevLauncherScreen extends StatelessWidget {
  const DevLauncherScreen({super.key});

  static const _screens = [
    _Entry(
      'Panel Admin (Dashboard)',
      Icons.dashboard_rounded,
      Color(0xFF1565C0),
      'AdminDashboardScreen',
    ),
    _Entry(
      'Lista de Estudiantes',
      Icons.format_list_bulleted_rounded,
      Color(0xFF06B6D4),
      'StudentListScreen',
    ),
    _Entry(
      'Importar Estudiantes',
      Icons.upload_file_rounded,
      Color(0xFF7C3AED),
      'ImportStudentsScreen',
    ),
    _Entry(
      'Asistentes (QR)',
      Icons.people_alt_rounded,
      Color(0xFF22C55E),
      'AttendeesScreen',
    ),
    _Entry(
      'Comprobantes de Pago',
      Icons.receipt_long_rounded,
      Color(0xFFF59E0B),
      'PaymentVouchersScreen',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dev Launcher',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            Text(
              'Selecciona una pantalla para previsualizar',
              style: GoogleFonts.outfit(
                fontSize: 11,
                color: const Color(0xFF8FA3B1),
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFF1E2A45)),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _screens.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final e = _screens[i];
          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => _buildScreen(i)),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF1E2A45)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: e.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(e.icon, color: e.color, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.title,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          e.tag,
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: const Color(0xFF8FA3B1),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: const Color(0xFF8FA3B1),
                    size: 14,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildScreen(int i) => switch (i) {
    0 => const AdminDashboardScreen(),
    1 => const StudentListScreen(),
    2 => const ImportStudentsScreen(),
    3 => const AttendeesScreen(),
    4 => const PaymentVouchersScreen(),
    _ => const SizedBox(),
  };
}

class _Entry {
  final String title;
  final IconData icon;
  final Color color;
  final String tag;
  const _Entry(this.title, this.icon, this.color, this.tag);
}

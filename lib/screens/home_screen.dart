import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'upload_payment_screen.dart';
import 'payment_status_screen.dart';
import 'my_qr_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // Función para cambiar de pestaña desde cualquier sub-widget
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Definimos las páginas aquí para poder pasar la función de navegación al HomeContent
    final List<Widget> _pages = [
      _HomeContent(onActionTap: _onItemTapped), // Índice 0
      const UploadPaymentScreen(),              // Índice 1
      const PaymentStatusScreen(),            // Índice 2
      const MyQrScreen(),                     // Índice 3
    ];

    return Scaffold(
      backgroundColor: AppColors.sentryBg,
      appBar: AppBar(
        backgroundColor: AppColors.sentryNavy,
        elevation: 0,
        title: const Text('Sentry',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          const CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.sentryCyan,
            child: Icon(Icons.person, color: Colors.white, size: 20),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      // IndexedStack mantiene el estado de las pantallas (no se reinician al cambiar)
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: _buildFloatingBottomBar(),
    );
  }

  Widget _buildFloatingBottomBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, -5)
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(0, Icons.home_rounded, 'Inicio'),
          _navItem(1, Icons.file_upload_outlined, 'Cargar'),
          _navItem(2, Icons.analytics_outlined, 'Estado'),
          _navItem(3, Icons.qr_code_scanner_rounded, 'Mi QR'),
        ],
      ),
    );
  }

  Widget _navItem(int idx, IconData icon, String label) {
    bool active = _selectedIndex == idx;
    return GestureDetector(
      onTap: () => _onItemTapped(idx),
      child: Container(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: active ? AppColors.sentryBlue : AppColors.sentryGrey),
            Text(label,
                style: TextStyle(
                    color: active ? AppColors.sentryBlue : AppColors.sentryGrey,
                    fontSize: 10
                )
            ),
          ],
        ),
      ),
    );
  }
}

// --- CONTENIDO DE LA PESTAÑA INICIO ---

class _HomeContent extends StatelessWidget {
  final Function(int) onActionTap;

  const _HomeContent({required this.onActionTap});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildMainEventCard(),
          const SizedBox(height: 25),
          _buildCountdownSection(),
          const SizedBox(height: 25),
          _buildAforoCard(),
          const SizedBox(height: 25),
          _buildLocationCard(),
          const SizedBox(height: 25),
          _buildQuickActions(),
          const SizedBox(height: 100), // Espacio para no chocar con la barra flotante
        ],
      ),
    );
  }

  Widget _buildMainEventCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.sentryNavy, AppColors.sentryBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: AppColors.sentryNavy.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8)
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _badge('Evento activo'),
          const SizedBox(height: 16),
          const Text('Gala FIE 2026',
              style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
          const Text('Noche de Innovación y Tecnología',
              style: TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 24),
          _infoRow(Icons.calendar_today, 'Sábado, 20 de Junio de 2026'),
          _infoRow(Icons.access_time, '19:00 – 23:00'),
          _infoRow(Icons.location_on, 'Auditorio Central · ESPOCH'),
        ],
      ),
    );
  }

  Widget _buildCountdownSection() {
    return Column(
      children: [
        const Text('CUENTA REGRESIVA',
            style: TextStyle(color: AppColors.sentryGrey, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 12)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _timeUnit('47', 'días'),
            _timeUnit('07', 'hrs'),
            _timeUnit('42', 'min'),
            _timeUnit('24', 'seg'),
          ],
        ),
      ],
    );
  }

  Widget _buildAforoCard() {
    return _baseCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('Aforo del evento', style: TextStyle(color: AppColors.sentryNavy, fontWeight: FontWeight.bold, fontSize: 16)),
              Text('218/350', style: TextStyle(color: AppColors.sentryBlue, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: 0.62,
              backgroundColor: AppColors.sentryBg,
              color: AppColors.sentryCyan,
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 8),
          const Align(
              alignment: Alignment.centerLeft,
              child: Text('62% de capacidad ocupada', style: TextStyle(color: AppColors.sentryGrey, fontSize: 12))
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    return _baseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.near_me, color: AppColors.sentryCyan, size: 20),
              SizedBox(width: 8),
              Text('Validación de ubicación',
                  style: TextStyle(color: AppColors.sentryNavy, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const Text('Av. Unidad Nacional s/n, Riobamba',
              style: TextStyle(color: AppColors.sentryGrey, fontSize: 13)),
          const SizedBox(height: 16),
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.sentryBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.sentryGrey.withOpacity(0.2)),
            ),
            child: const Center(
                child: Icon(Icons.my_location, color: AppColors.sentryBlue, size: 40)
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('No verificado',
                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w500)),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.sentryBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                ),
                child: const Text('Verificar GPS', style: TextStyle(color: Colors.white)),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => onActionTap(1), // Salta a "Cargar"
            child: _actionBtn('Cargar pago', 'Subir comprobante', Icons.cloud_upload_outlined, AppColors.sentryNavy),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: GestureDetector(
            onTap: () => onActionTap(3), // Salta a "Mi QR"
            child: _actionBtn('Ver QR', 'Código de entrada', Icons.qr_code_2_rounded, AppColors.sentryCyan),
          ),
        ),
      ],
    );
  }

  // --- Widgets Reutilizables ---

  Widget _baseCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
          ]
      ),
      child: child,
    );
  }

  Widget _badge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)),
      child: Text(text,
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
          children: [
            Icon(icon, color: Colors.white70, size: 18),
            const SizedBox(width: 12),
            Text(text, style: const TextStyle(color: Colors.white, fontSize: 14))
          ]
      ),
    );
  }

  Widget _timeUnit(String val, String label) {
    return Container(
      width: 75,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
          children: [
            Text(val,
                style: const TextStyle(color: AppColors.sentryNavy, fontSize: 22, fontWeight: FontWeight.bold)),
            Text(label,
                style: const TextStyle(color: AppColors.sentryGrey, fontSize: 10))
          ]
      ),
    );
  }

  Widget _actionBtn(String title, String sub, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          Text(sub, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }
}
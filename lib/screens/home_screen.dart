import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../services/event_service.dart';
import '../services/supabase_service.dart';
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

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  Future<void> _logout() async {
    await SupabaseService.signOut();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _HomeContent(onActionTap: _onItemTapped),
      const UploadPaymentScreen(),
      const PaymentStatusScreen(),
      const MyQrScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.sentryBg,
      appBar: AppBar(
        backgroundColor: AppColors.sentryNavy,
        elevation: 0,
        title: Text(
          'Sentry',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        actions: [
          const CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.sentryCyan,
            child: Icon(Icons.person, color: Colors.white, size: 20),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
            tooltip: 'Cerrar sesión',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: pages),
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
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
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
    final active = _selectedIndex == idx;
    return GestureDetector(
      onTap: () => _onItemTapped(idx),
      child: Container(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: active ? AppColors.sentryBlue : AppColors.sentryGrey),
            Text(
              label,
              style: TextStyle(
                color: active ? AppColors.sentryBlue : AppColors.sentryGrey,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Home tab content ──────────────────────────────────────────────────────────

class _HomeContent extends StatefulWidget {
  final Function(int) onActionTap;
  const _HomeContent({required this.onActionTap});

  @override
  State<_HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<_HomeContent> {
  EventModel? _event;
  int _aforo = 0;
  int _capacidad = 350;
  bool _loading = true;

  // Countdown
  Timer? _countdownTimer;
  Duration _remaining = Duration.zero;

  // Geofencing
  double? _distanceMeters;
  bool _insideZone = false;
  bool _loadingGps = false;
  String _gpsStatus = 'No verificado';

  final _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _loadEvent();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadEvent() async {
    final event = await EventService.getActiveEvent();
    if (!mounted) return;

    if (event != null) {
      final results = await Future.wait([
        EventService.getAforo(event.id),
        EventService.getCapacidad(),
      ]);
      if (!mounted) return;
      setState(() {
        _event = event;
        _aforo = results[0];
        _capacidad = results[1] > 0 ? results[1] : 350;
        _loading = false;
      });
      _startCountdown(event.fecha);
    } else {
      setState(() => _loading = false);
    }
  }

  void _startCountdown(DateTime eventDate) {
    _updateRemaining(eventDate);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _updateRemaining(eventDate);
    });
  }

  void _updateRemaining(DateTime eventDate) {
    final diff = eventDate.difference(DateTime.now());
    setState(() => _remaining = diff.isNegative ? Duration.zero : diff);
  }

  Future<void> _checkLocation() async {
    if (_event == null) return;
    setState(() {
      _loadingGps = true;
      _gpsStatus = 'Verificando...';
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _gpsStatus = 'GPS desactivado';
          _loadingGps = false;
        });
        return;
      }

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) {
          setState(() {
            _gpsStatus = 'Permiso denegado';
            _loadingGps = false;
          });
          return;
        }
      }
      if (perm == LocationPermission.deniedForever) {
        setState(() {
          _gpsStatus = 'Permiso bloqueado';
          _loadingGps = false;
        });
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final dist = _haversineDistance(
        pos.latitude,
        pos.longitude,
        _event!.lat,
        _event!.lng,
      );

      final inside = dist <= EventModel.radioMetros;

      setState(() {
        _distanceMeters = dist;
        _insideZone = inside;
        _gpsStatus = inside ? 'Dentro de la zona ✓' : 'Fuera de la zona';
        _loadingGps = false;
      });

      _mapController.move(LatLng(pos.latitude, pos.longitude), 16);
    } catch (e) {
      setState(() {
        _gpsStatus = 'Error: ${e.toString()}';
        _loadingGps = false;
      });
    }
  }

  /// Distancia entre dos coordenadas en metros (Haversine).
  double _haversineDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final phi1 = lat1 * pi / 180;
    final phi2 = lat2 * pi / 180;
    final dPhi = (lat2 - lat1) * pi / 180;
    final dLambda = (lon2 - lon1) * pi / 180;
    final a = sin(dPhi / 2) * sin(dPhi / 2) +
        cos(phi1) * cos(phi2) * sin(dLambda / 2) * sin(dLambda / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.sentryBlue),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadEvent,
      color: AppColors.sentryBlue,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildMainEventCard(),
            const SizedBox(height: 25),
            _buildCountdownSection(),
            const SizedBox(height: 25),
            _buildAforoCard(),
            const SizedBox(height: 25),
            _buildGeofenceCard(),
            const SizedBox(height: 25),
            _buildQuickActions(),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildMainEventCard() {
    final event = _event;
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
            color: AppColors.sentryNavy.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _badge(event != null ? 'Evento activo' : 'Sin evento activo'),
          const SizedBox(height: 16),
          Text(
            event?.nombre ?? 'Sin evento programado',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (event?.descripcion.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              event!.descripcion,
              style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14),
            ),
          ],
          const SizedBox(height: 20),
          if (event != null) ...[
            _infoRow(
              Icons.calendar_today,
              _formatDate(event.fecha),
            ),
            _infoRow(Icons.access_time, '19:00 – 23:00'),
            _infoRow(Icons.location_on, event.lugar),
          ],
        ],
      ),
    );
  }

  Widget _buildCountdownSection() {
    final days = _remaining.inDays;
    final hours = _remaining.inHours.remainder(24);
    final minutes = _remaining.inMinutes.remainder(60);
    final seconds = _remaining.inSeconds.remainder(60);

    return Column(
      children: [
        Text(
          'CUENTA REGRESIVA',
          style: GoogleFonts.outfit(
            color: AppColors.sentryGrey,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _timeUnit(_pad(days), 'días'),
            _timeUnit(_pad(hours), 'hrs'),
            _timeUnit(_pad(minutes), 'min'),
            _timeUnit(_pad(seconds), 'seg'),
          ],
        ),
      ],
    );
  }

  Widget _buildAforoCard() {
    final capacity = _capacidad;
    final ratio = capacity > 0 ? (_aforo / capacity).clamp(0.0, 1.0) : 0.0;
    final pct = (ratio * 100).toStringAsFixed(0);

    return _baseCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Aforo del evento',
                style: GoogleFonts.outfit(
                  color: AppColors.sentryNavy,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              Text(
                '$_aforo/$capacity',
                style: GoogleFonts.outfit(
                  color: AppColors.sentryBlue,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: ratio,
              backgroundColor: AppColors.sentryBg,
              valueColor: AlwaysStoppedAnimation<Color>(
                ratio > 0.9 ? AppColors.error : AppColors.sentryCyan,
              ),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '$pct% de capacidad ocupada',
              style: GoogleFonts.outfit(
                color: AppColors.sentryGrey,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeofenceCard() {
    final event = _event;
    final Color statusColor =
        _insideZone ? AppColors.success : AppColors.error;

    return _baseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.near_me, color: AppColors.sentryCyan, size: 20),
              const SizedBox(width: 8),
              Text(
                'Validación de ubicación',
                style: GoogleFonts.outfit(
                  color: AppColors.sentryNavy,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          if (event != null)
            Text(
              event.lugar,
              style: GoogleFonts.outfit(
                color: AppColors.sentryGrey,
                fontSize: 13,
              ),
            ),
          const SizedBox(height: 14),

          // Mapa con OpenStreetMap (flutter_map)
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 160,
              child: event != null
                  ? FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: LatLng(event.lat, event.lng),
                        initialZoom: 16,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.pinchZoom |
                              InteractiveFlag.drag,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.fie.sentry_app',
                        ),
                        CircleLayer(
                          circles: [
                            CircleMarker(
                              point: LatLng(event.lat, event.lng),
                              radius: EventModel.radioMetros.toDouble(),
                              useRadiusInMeter: true,
                              color: AppColors.sentryCyan.withValues(alpha: 0.15),
                              borderColor: AppColors.sentryCyan,
                              borderStrokeWidth: 2,
                            ),
                          ],
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(event.lat, event.lng),
                              child: const Icon(
                                Icons.location_pin,
                                color: AppColors.error,
                                size: 36,
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Container(
                      color: AppColors.sentryBg,
                      child: const Center(
                        child: Icon(Icons.map_outlined,
                            size: 48, color: AppColors.sentryGrey),
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 14),

          // Estado de geofencing
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _gpsStatus,
                    style: GoogleFonts.outfit(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  if (_distanceMeters != null)
                    Text(
                      '${_distanceMeters!.toStringAsFixed(0)} m del evento',
                      style: GoogleFonts.outfit(
                        color: AppColors.sentryGrey,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _loadingGps ? null : _checkLocation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.sentryBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                icon: _loadingGps
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.gps_fixed, color: Colors.white, size: 16),
                label: Text(
                  'Verificar GPS',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => widget.onActionTap(1),
            child: _actionBtn(
              'Cargar pago',
              'Subir comprobante',
              Icons.cloud_upload_outlined,
              AppColors.sentryNavy,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: GestureDetector(
            onTap: () => widget.onActionTap(3),
            child: _actionBtn(
              'Ver QR',
              'Código de entrada',
              Icons.qr_code_2_rounded,
              AppColors.sentryCyan,
            ),
          ),
        ),
      ],
    );
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  String _formatDate(DateTime d) {
    const months = [
      '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
    ];
    const days = [
      '', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo',
    ];
    return '${days[d.weekday]}, ${d.day} de ${months[d.month]} de ${d.year}';
  }

  Widget _baseCard({required Widget child}) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      );

  Widget _badge(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  Widget _infoRow(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Icon(icon, color: Colors.white70, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
        ),
      );

  Widget _timeUnit(String val, String label) => Container(
        width: 75,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              val,
              style: GoogleFonts.outfit(
                color: AppColors.sentryNavy,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: AppColors.sentryGrey,
                fontSize: 10,
              ),
            ),
          ],
        ),
      );

  Widget _actionBtn(
          String title, String sub, IconData icon, Color color) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              sub,
              style: GoogleFonts.outfit(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      );
}

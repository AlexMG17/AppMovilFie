import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/event_service.dart';
import '../services/qr_cache_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';
import 'support_chat_screen.dart';
import 'upload_payment_screen.dart';
import 'payment_status_screen.dart';
import 'my_qr_screen.dart';

// NUESTRO NUEVO SERVICIO
import '../services/geofence_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final name = await EventService.getCurrentUserName();
    if (mounted)
      setState(
        () => _userName = name ?? SupabaseService.currentUser?.email ?? '',
      );
  }

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  Future<void> _logout() async {
    final userId = SupabaseService.currentUser?.id ?? '';
    final nav = Navigator.of(context);
    await QrCacheService.clear(userId);
    await SupabaseService.signOut();
    nav.pushReplacementNamed('/login');
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
          IconButton(
            icon: const Icon(Icons.support_agent_rounded, color: Colors.white),
            tooltip: 'Soporte',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SupportChatScreen(isAdmin: false),
              ),
            ),
          ),
          PopupMenuButton<String>(
            offset: const Offset(0, 44),
            onSelected: (value) async {
              if (value == 'logout') await _logout();
            },
            child: const CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.sentryCyan,
              child: Icon(Icons.person, color: Colors.white, size: 20),
            ),
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      SupabaseService.currentUser?.email ?? '',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, size: 16, color: Colors.red),
                    SizedBox(width: 8),
                    Text(
                      'Cerrar sesión',
                      style: TextStyle(color: Colors.red, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
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
            Icon(
              icon,
              color: active ? AppColors.sentryBlue : AppColors.sentryGrey,
            ),
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

  RealtimeChannel? _eventChannel;

  Timer? _countdownTimer;
  Duration _remaining = Duration.zero;

  // Variables de Geofencing
  GeofenceService? _geofenceService;
  GeofenceState _geoState = GeofenceState.afuera;
  double? _distanceMeters;
  LatLng? _userLocation; // <-- Para pintar el punto azul
  String _gpsStatus = 'Buscando señal...';
  int _segundosSalida = 0;
  bool _isUpdatingGps = false;

  final _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _loadEvent();
    _iniciarGeocercaAutomatica();
    _subscribeToEvents();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _geofenceService?.dispose();
    _eventChannel?.unsubscribe();
    _mapController.dispose();
    super.dispose();
  }

  void _iniciarGeocercaAutomatica() {
    _geofenceService = GeofenceService(
      onStateChanged: (estado, distancia, ubicacion) {
        if (!mounted) return;
        setState(() {
          _geoState = estado;
          _distanceMeters = distancia;
          _userLocation = ubicacion;

          if (estado == GeofenceState.adentro) {
            _gpsStatus = 'Adentro de la zona ✓';
          } else if (estado == GeofenceState.cerca) {
            _gpsStatus = 'Cerca (Zona advertencia)';
          } else {
            _gpsStatus = '¡Fuera de la zona!';
          }
        });
      },
      onTimerTick: (segundos) {
        if (!mounted) return;
        setState(() => _segundosSalida = segundos);
      },
      onTimerExpired: () {
        if (!mounted) return;
        setState(() {
          _gpsStatus = 'Salida registrada. QR Invalidado.';
        });
      },
    );

    _geofenceService!.startMonitoring();
    _geofenceService!.forceUpdate();
  }

  Future<void> _forzarActualizacionGPS() async {
    setState(() => _isUpdatingGps = true);
    await _geofenceService?.forceUpdate();
    if (_userLocation != null) {
      _mapController.move(_userLocation!, 16.5);
    }
    setState(() => _isUpdatingGps = false);
  }

  void _subscribeToEvents() {
    _eventChannel = SupabaseService.client
        .channel('public:eventos')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'eventos',
          callback: (_) {
            if (mounted) _loadEvent();
          },
        )
        .subscribe();
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
            _infoRow(Icons.calendar_today, _formatDate(event.fecha)),
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

    final Color statusColor = _geoState == GeofenceState.adentro
        ? AppColors.success
        : (_geoState == GeofenceState.cerca ? Colors.orange : AppColors.error);

    return _baseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.near_me, color: AppColors.sentryCyan, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Validación de ubicación',
                  style: GoogleFonts.outfit(
                    color: AppColors.sentryNavy,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              GestureDetector(
                onTap: _isUpdatingGps ? null : _forzarActualizacionGPS,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.sentryBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      _isUpdatingGps
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(
                              Icons.my_location,
                              size: 14,
                              color: AppColors.sentryBlue,
                            ),
                      const SizedBox(width: 6),
                      Text(
                        "Centrar",
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: AppColors.sentryBlue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
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

          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 200,
              child: event != null
                  ? FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter:
                            _geofenceService?.eventCenter ??
                            LatLng(event.lat, event.lng),
                        initialZoom: 16.0,
                        interactionOptions: const InteractionOptions(
                          flags:
                              InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.fie.sentry_app',
                        ),
                        PolygonLayer(
                          polygons: [
                            if (_geofenceService != null)
                              Polygon(
                                points: _geofenceService!.eventPolygon,
                                color: AppColors.sentryCyan.withValues(
                                  alpha: 0.2,
                                ),
                                borderColor: AppColors.sentryBlue,
                                borderStrokeWidth: 2.5,
                              ),
                          ],
                        ),
                        CircleLayer(
                          circles: [
                            if (_geofenceService != null)
                              CircleMarker(
                                point: _geofenceService!.eventCenter,
                                radius: _geofenceService!.radioCerca,
                                useRadiusInMeter: true,
                                color: Colors.orange.withValues(alpha: 0.05),
                                borderColor: Colors.orange.withValues(
                                  alpha: 0.5,
                                ),
                                borderStrokeWidth: 1,
                              ),
                          ],
                        ),
                        MarkerLayer(
                          markers: [
                            if (_geofenceService != null)
                              Marker(
                                point: _geofenceService!.eventCenter,
                                child: const Icon(
                                  Icons.flag,
                                  color: AppColors.error,
                                  size: 24,
                                ),
                              ),
                            if (_userLocation != null)
                              Marker(
                                point: _userLocation!,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: AppColors.sentryBlue.withValues(
                                          alpha: 0.3,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    Container(
                                      width: 14,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        color: AppColors.sentryBlue,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    )
                  : Container(
                      color: AppColors.sentryBg,
                      child: const Center(
                        child: Icon(
                          Icons.map_outlined,
                          size: 48,
                          color: AppColors.sentryGrey,
                        ),
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _gpsStatus,
                      style: GoogleFonts.outfit(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (_distanceMeters != null)
                      Text(
                        _geoState == GeofenceState.adentro
                            ? 'Estás en zona segura'
                            : 'A ${_distanceMeters!.toStringAsFixed(0)} m del centro',
                        style: GoogleFonts.outfit(
                          color: AppColors.sentryGrey,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),

              if (_geoState == GeofenceState.afuera && _segundosSalida > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.error),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer, color: AppColors.error, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '00:${_segundosSalida.toString().padLeft(2, '0')}',
                        style: GoogleFonts.outfit(
                          color: AppColors.error,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
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
      '',
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    const days = [
      '',
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
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
          style: GoogleFonts.outfit(color: AppColors.sentryGrey, fontSize: 10),
        ),
      ],
    ),
  );

  Widget _actionBtn(String title, String sub, IconData icon, Color color) =>
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

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
import '../services/geofence_service.dart';
import '../services/payment_service.dart';
import '../services/qr_unique_service.dart';
import '../services/student_service.dart';

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
    if (mounted) {
      setState(
        () => _userName = name ?? SupabaseService.currentUser?.email ?? '',
      );
    }
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
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.cardBorder),
        ),
        title: Text(
          'Sentry',
          style: GoogleFonts.outfit(
            color: AppColors.sentryNavy,
            fontWeight: FontWeight.w800,
            fontSize: 22.sp,
          ),
        ),
        actions: [
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SupportChatScreen(isAdmin: false),
              ),
            ),
            child: Container(
              width: 38.w,
              height: 38.w,
              decoration: const BoxDecoration(
                color: AppColors.sentryNavy,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.headset_mic_rounded,
                color: Colors.white,
                size: 19.sp,
              ),
            ),
          ),
          SizedBox(width: 10.w),
          PopupMenuButton<String>(
            offset: const Offset(0, 48),
            onSelected: (value) async {
              if (value == 'logout') await _logout();
            },
            child: Container(
              width: 38.w,
              height: 38.w,
              decoration: const BoxDecoration(
                color: AppColors.sentryNavy,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person, color: Colors.white, size: 20.sp),
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
          SizedBox(width: 14.w),
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: _buildFloatingBottomBar(),
    );
  }

  Widget _buildFloatingBottomBar() {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      margin: EdgeInsets.fromLTRB(24.w, 0, 24.w, 12.h + bottomPadding),
      height: 60.h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(0, Icons.home_rounded),
          _navItem(1, Icons.file_upload_outlined),
          _navItem(2, Icons.analytics_outlined),
          _navItem(3, Icons.qr_code_2_rounded),
        ],
      ),
    );
  }

  Widget _navItem(int idx, IconData icon) {
    final active = _selectedIndex == idx;
    return GestureDetector(
      onTap: () => _onItemTapped(idx),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        child: Icon(
          icon,
          color: active ? AppColors.sentryBlue : AppColors.sentryGrey,
          size: 26.sp,
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
  RealtimeChannel? _entradaChannel;

  Timer? _countdownTimer;
  Duration _remaining = Duration.zero;

  // Variables de Geofencing
  GeofenceService? _geofenceService;
  GeofenceState _geoState = GeofenceState.afuera;
  int? _idEntrada;
  bool _activationChecked = false;
  double? _distanceMeters;
  LatLng? _userLocation;
  bool _isUpdatingGps = false;
  int _segundosSalida = 0;

  // Variable de control para el estado de ingreso (Código QR)
  bool _qrValidado = false;

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
    _entradaChannel?.unsubscribe();
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

          // Reactivación automática al salir del recinto
          if (estado == GeofenceState.afuera) {
            if (_qrValidado) {
              _qrValidado = false; // Se resetea el QR al abandonar la zona
            }
          }
        });
      },
      onTimerTick: (segundos) {
        if (!mounted) return;
        setState(() => _segundosSalida = segundos);
      },
      onTimerExpired: () {
        if (!mounted) return;
        // Si el tiempo de salida expira, registramos formalmente la salida en BD
        if (_idEntrada != null) {
          QrUniqueService.registrarSalida(_idEntrada!);
        }
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
    // Escucha cambios en aforo
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

  void _subscribeToEntrada(int idEntrada) {
    _entradaChannel?.unsubscribe();
    _entradaChannel = SupabaseService.client
        .channel('home_entradas_$idEntrada')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'entradas',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id_entrada',
            value: idEntrada,
          ),
          callback: (payload) {
            if (!mounted) return;
            final estado = payload.newRecord['estado'] as String?;
            if (estado != null) {
              setState(() {
                // Si el guardia actualiza a 'usado', lo detectamos en vivo
                _qrValidado = estado.toLowerCase() == 'usado';
              });
            }
          },
        )
        .subscribe();
  }

  Future<void> _loadEvent() async {
    final event = await EventService.getActiveEvent();
    if (!mounted) return;

    if (event != null) {
      final uidFuture = EventService.getCurrentUserId();
      final results = await Future.wait([
        EventService.getAforo(event.id),
        EventService.getCapacidad(),
      ]);
      final uid = await uidFuture;
      final aforo = results[0];
      final capacidad = results[1];

      final email = SupabaseService.currentUser?.email;
      if (!_activationChecked && uid != null && email != null) {
        _activationChecked = true;
        StudentService.checkAndActivateIfPreApproved(
          email: email,
          idUsuario: uid,
          idEvento: event.id,
        );
      }

      Map<String, dynamic>? entry;
      if (uid != null) {
        entry = await PaymentService.getMyEntry(
          idUsuario: uid,
          idEvento: event.id,
        );
      }

      if (!mounted) return;
      setState(() {
        _event = event;
        _aforo = aforo;
        _capacidad = capacidad > 0 ? capacidad : 350;

        if (entry != null) {
          _idEntrada = entry['id_entrada'] as int?;
          final estado = entry['estado'] as String? ?? 'activo';
          _qrValidado = estado.toLowerCase() == 'usado';
        }

        _loading = false;
      });
      _startCountdown(event.fecha);

      // Si tenemos entrada, escuchamos en tiempo real si el guardia nos aprueba
      if (_idEntrada != null) {
        _subscribeToEntrada(_idEntrada!);
      }
    } else {
      setState(() => _loading = false);
    }
  }

  void _startCountdown(DateTime eventDate) {
    _updateRemaining(eventDate);
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _updateRemaining(eventDate);
    });
  }

  void _updateRemaining(DateTime eventDate) {
    final diff = eventDate.difference(DateTime.now());
    setState(() => _remaining = diff.isNegative ? Duration.zero : diff);
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  // =========================================================================
  // MÉTODO PARA ABRIR MAPA EN PANTALLA COMPLETA
  // =========================================================================
  void _abrirMapaPantallaCompleta() {
    if (_event == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) {
          return Scaffold(
            body: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter:
                        _userLocation ??
                        _geofenceService?.eventCenter ??
                        LatLng(_event!.lat, _event!.lng),
                    initialZoom: 16.5,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all,
                    ),
                  ),
                  children: _buildMapLayers(),
                ),
                // Botón "X" para cerrar
                Positioned(
                  top: MediaQuery.of(context).padding.top + 16,
                  right: 16,
                  child: FloatingActionButton(
                    mini: true,
                    backgroundColor: Colors.white,
                    elevation: 4,
                    onPressed: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.close_rounded,
                      color: AppColors.sentryNavy,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Capas del mapa extraídas para reusarlas
  List<Widget> _buildMapLayers() {
    return [
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
              color: AppColors.sentryCyan.withValues(alpha: 0.2),
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
              borderColor: Colors.orange.withValues(alpha: 0.5),
              borderStrokeWidth: 1,
            ),
        ],
      ),
      MarkerLayer(
        markers: [
          if (_geofenceService != null)
            Marker(
              point: _geofenceService!.eventCenter,
              child: const Icon(Icons.flag, color: AppColors.error, size: 24),
            ),
          if (_userLocation != null)
            Marker(
              point: _userLocation!,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 24.w,
                    height: 24.w,
                    decoration: BoxDecoration(
                      color: AppColors.sentryBlue.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Container(
                    width: 14.w,
                    height: 14.w,
                    decoration: BoxDecoration(
                      color: AppColors.sentryBlue,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ];
  }

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
        padding: EdgeInsets.all(20.r),
        child: Column(
          children: [
            _buildMainEventCard(),
            SizedBox(height: 25.h),
            _buildCountdownSection(),
            SizedBox(height: 25.h),
            _buildAforoCard(),
            SizedBox(height: 25.h),
            _buildGeofenceCard(),
            SizedBox(height: 25.h),
            _buildQuickActions(),
            SizedBox(height: 100.h),
          ],
        ),
      ),
    );
  }

  Widget _buildMainEventCard() {
    final event = _event;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.sentryNavy, AppColors.sentryBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.sentryNavy.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24.r),
        child: Stack(
          children: [
            Positioned(
              right: -40,
              bottom: -40,
              child: Container(
                width: 180.w,
                height: 180.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.07),
                ),
              ),
            ),
            Positioned(
              right: 20,
              top: -30,
              child: Container(
                width: 110.w,
                height: 110.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(24.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _badge(event != null ? 'Evento activo' : 'Sin evento activo'),
                  SizedBox(height: 16.h),
                  Text(
                    event?.nombre ?? 'Sin evento programado',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (event?.descripcion.isNotEmpty == true) ...[
                    SizedBox(height: 4.h),
                    Text(
                      event!.descripcion,
                      style: GoogleFonts.outfit(
                        color: Colors.white70,
                        fontSize: 13.sp,
                      ),
                    ),
                  ],
                  SizedBox(height: 20.h),
                  if (event != null) ...[
                    _infoRow(Icons.calendar_today, _formatDate(event.fecha)),
                    _infoRow(Icons.access_time, '19:00 – 23:00'),
                    _infoRow(Icons.location_on, event.lugar),
                  ],
                ],
              ),
            ),
          ],
        ),
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
            fontSize: 11.sp,
          ),
        ),
        SizedBox(height: 16.h),
        Row(
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

  Widget _timeUnit(String val, String label) => Expanded(
    child: Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      padding: EdgeInsets.all(10.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        children: [
          Text(
            val,
            style: GoogleFonts.outfit(
              color: AppColors.sentryNavy,
              fontSize: 20.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.outfit(
              color: AppColors.sentryGrey,
              fontSize: 10.sp,
            ),
          ),
        ],
      ),
    ),
  );

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
              Row(
                children: [
                  Text(
                    'Aforo del evento',
                    style: GoogleFonts.outfit(
                      color: AppColors.sentryNavy,
                      fontWeight: FontWeight.w700,
                      fontSize: 14.sp,
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Tooltip(
                    message:
                        'Personas con pago aprobado\ny acceso confirmado al evento',
                    triggerMode: TooltipTriggerMode.tap,
                    showDuration: const Duration(seconds: 3),
                    child: Icon(
                      Icons.info_outline_rounded,
                      size: 16.sp,
                      color: AppColors.sentryGrey,
                    ),
                  ),
                ],
              ),
              Text(
                '$_aforo/$capacity',
                style: GoogleFonts.outfit(
                  color: AppColors.sentryBlue,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.sp,
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
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
          SizedBox(height: 8.h),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '$pct% de capacidad ocupada',
              style: GoogleFonts.outfit(
                color: AppColors.sentryGrey,
                fontSize: 12.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeofenceCard() {
    final event = _event;

    return _baseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.near_me, color: AppColors.sentryCyan, size: 20.sp),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  'Validación de ubicación',
                  style: GoogleFonts.outfit(
                    color: AppColors.sentryNavy,
                    fontWeight: FontWeight.w700,
                    fontSize: 14.sp,
                  ),
                ),
              ),
              GestureDetector(
                onTap: _isUpdatingGps ? null : _forzarActualizacionGPS,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 6.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.sentryBg,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Row(
                    children: [
                      _isUpdatingGps
                          ? SizedBox(
                              width: 12.w,
                              height: 12.h,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : Icon(
                              Icons.my_location,
                              size: 14.sp,
                              color: AppColors.sentryBlue,
                            ),
                      SizedBox(width: 6.w),
                      Text(
                        "Centrar",
                        style: GoogleFonts.outfit(
                          fontSize: 12.sp,
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
                fontSize: 12.sp,
              ),
            ),
          SizedBox(height: 14.h),

          // Mapa Miniatura Ampliable
          ClipRRect(
            borderRadius: BorderRadius.circular(14.r),
            child: SizedBox(
              height: 200.h,
              child: Stack(
                children: [
                  if (event != null)
                    GestureDetector(
                      onTap: _abrirMapaPantallaCompleta,
                      child: AbsorbPointer(
                        child: FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter:
                                _geofenceService?.eventCenter ??
                                LatLng(event.lat, event.lng),
                            initialZoom: 16.0,
                          ),
                          children: _buildMapLayers(),
                        ),
                      ),
                    )
                  else
                    Container(
                      color: AppColors.sentryBg,
                      child: Center(
                        child: Icon(
                          Icons.map_outlined,
                          size: 48.sp,
                          color: AppColors.sentryGrey,
                        ),
                      ),
                    ),

                  // Botón flotante para sugerir ampliación
                  if (event != null)
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: GestureDetector(
                        onTap: _abrirMapaPantallaCompleta,
                        child: Container(
                          padding: EdgeInsets.all(8.r),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.fullscreen_rounded,
                            color: AppColors.sentryNavy,
                            size: 20.sp,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(height: 14.h),

          // AVISO DINÁMICO DE GEOFENCING Y QR
          _buildStatusBanner(),
        ],
      ),
    );
  }

  // LÓGICA DEL BANNER DE AVISOS (Amarillo, Verde, Rojo)
  Widget _buildStatusBanner() {
    Color bgColor;
    Color textColor;
    IconData icon;
    String text;

    if (_geoState == GeofenceState.adentro) {
      if (_qrValidado) {
        bgColor = AppColors.success.withValues(alpha: 0.1);
        textColor = AppColors.success;
        icon = Icons.verified_user_rounded;
        text = '¡Ingreso registrado con éxito! Disfruta del evento.';
      } else {
        bgColor = Colors.amber.withValues(alpha: 0.15);
        textColor = Colors.orange.shade800;
        icon = Icons.qr_code_scanner_rounded;
        text =
            '📍 Zona alcanzada.\nMuestra tu código QR al guardia para registrar tu entrada.';
      }
    } else if (_geoState == GeofenceState.cerca) {
      bgColor = Colors.orange.withValues(alpha: 0.1);
      textColor = Colors.orange.shade800;
      icon = Icons.directions_walk_rounded;
      text = 'Acércate más a la entrada principal...';
    } else {
      bgColor = AppColors.error.withValues(alpha: 0.1);
      textColor = AppColors.error;
      icon = Icons.location_off_rounded;
      text =
          '¡Fuera de la zona!\nEstás a ${_distanceMeters?.toStringAsFixed(0) ?? 0} m del recinto.';
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 28.sp),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: GoogleFonts.outfit(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.sp,
                    height: 1.3,
                  ),
                ),
                // Si está afuera y hay timer de salida, lo mostramos integrado aquí
                if (_geoState == GeofenceState.afuera &&
                    _segundosSalida > 0) ...[
                  SizedBox(height: 8.h),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timer, color: AppColors.error, size: 14.sp),
                        SizedBox(width: 6.w),
                        Text(
                          'Tiempo para volver: 00:${_segundosSalida.toString().padLeft(2, '0')}',
                          style: GoogleFonts.outfit(
                            color: AppColors.error,
                            fontWeight: FontWeight.bold,
                            fontSize: 12.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
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
        SizedBox(width: 16.w),
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
    padding: EdgeInsets.all(20.r),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20.r),
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
    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
    decoration: BoxDecoration(
      color: Colors.white24,
      borderRadius: BorderRadius.circular(12.r),
    ),
    child: Text(
      text,
      style: GoogleFonts.outfit(
        color: Colors.white,
        fontSize: 11.sp,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _infoRow(IconData icon, String text) => Padding(
    padding: EdgeInsets.only(bottom: 10.h),
    child: Row(
      children: [
        Icon(icon, color: Colors.white70, size: 17.sp),
        SizedBox(width: 12.w),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 13.sp),
          ),
        ),
      ],
    ),
  );

  Widget _actionBtn(String title, String sub, IconData icon, Color color) =>
      Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 26.sp),
            SizedBox(height: 10.h),
            Text(
              title,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13.sp,
              ),
            ),
            Text(
              sub,
              style: GoogleFonts.outfit(color: Colors.white70, fontSize: 11.sp),
            ),
          ],
        ),
      );
}

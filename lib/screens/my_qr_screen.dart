import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/event_service.dart';
import '../services/payment_service.dart';
import '../services/qr_cache_service.dart';
import '../services/student_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';

class MyQrScreen extends StatefulWidget {
  const MyQrScreen({super.key});

  @override
  State<MyQrScreen> createState() => _MyQrScreenState();
}

class _MyQrScreenState extends State<MyQrScreen> {
  String? _codigoQr;
  String? _userName;
  String? _userEmail;
  String? _entradaEstado;
  DateTime? _expiresAt;
  int _versionQr = 1;
  int? _idEntrada;
  bool _dentroEvento = false;

  bool _loading = true;
  bool _isOffline = false;
  bool _syncing = false;
  String? _message;
  DateTime? _cachedAt;

  RealtimeChannel? _realtimeChannel;

  // Timer de polling como respaldo al Realtime, para detectar cambio de estado
  Timer? _pollingTimer;

  // Polígono del evento para verificar GPS directamente en esta pantalla
  List<LatLng>? _eventPolygon;

  bool get _isExpired =>
      _expiresAt != null && DateTime.now().isAfter(_expiresAt!);

  @override
  void initState() {
    super.initState();
    _loadWithCache();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  /// Polling cada 8 s: comprueba BD y además hace chequeo GPS+polígono
  /// si la BD sigue diciendo que está dentro. Así esta pantalla puede
  /// resetear la entrada por sí misma sin depender de home_screen.
  /// Verifica si el usuario está físicamente dentro del polígono del evento.
  /// Retorna true si está adentro, o si hay un error/falta de permisos (por seguridad).
  /// Retorna false únicamente si se pudo determinar con certeza que está afuera.
  Future<bool> _checkGpsInsidePolygon(List<LatLng> polygon) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return true; // Si el GPS está desactivado, asumimos adentro por seguridad

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return true; // Sin permisos, asumimos adentro por seguridad
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5), // Límite de tiempo para evitar bloqueos
        ),
      );

      final userPoint = LatLng(position.latitude, position.longitude);
      return _isInsidePolygon(userPoint, polygon);
    } catch (e) {
      debugPrint('Error en _checkGpsInsidePolygon: $e');
      return true; // En caso de error, asumimos adentro por seguridad
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 8), (_) async {
      final id = _idEntrada;
      if (id == null || !mounted) return;
      try {
        // 1. Consultar BD
        final row = await SupabaseService.client
            .from('entradas')
            .select('estado, dentro_evento')
            .eq('id_entrada', id)
            .maybeSingle();
        if (!mounted || row == null) return;

        final estadoDb = (row['estado'] as String? ?? 'activo').toLowerCase();
        final dentroDB = row['dentro_evento'] as bool? ?? false;
        final isInsideDB = estadoDb == 'usado' && dentroDB;

        if (!isInsideDB) {
          // BD dice que está afuera → actualizar UI
          if (_dentroEvento) {
            setState(() {
              _dentroEvento = false;
              _entradaEstado = estadoDb;
            });
          }
          _stopPolling();
          return;
        }

        // 2. BD dice que está adentro → verificar GPS contra polígono
        final polygon = _eventPolygon;
        if (polygon != null && polygon.isNotEmpty) {
          final insidePolygon = await _checkGpsInsidePolygon(polygon);
          if (!insidePolygon) {
            // GPS dice afuera → resetear BD y mostrar QR
            await SupabaseService.client
                .from('entradas')
                .update({'estado': 'activo', 'dentro_evento': false})
                .eq('id_entrada', id);

            if (mounted) {
              setState(() {
                _dentroEvento = false;
                _entradaEstado = 'activo';
              });
            }
            _stopPolling();
          }
        }
      } catch (_) {}
    });
  }

  /// Algoritmo ray-casting para verificar si un punto está dentro de un polígono.
  bool _isInsidePolygon(LatLng point, List<LatLng> polygon) {
    bool inside = false;
    int j = polygon.length - 1;
    for (int i = 0; i < polygon.length; i++) {
      final yi = polygon[i].latitude;
      final yj = polygon[j].latitude;
      final xi = polygon[i].longitude;
      final xj = polygon[j].longitude;
      final py = point.latitude;
      final px = point.longitude;
      if ((yi > py) != (yj > py) &&
          px < (xj - xi) * (py - yi) / (yj - yi) + xi) {
        inside = !inside;
      }
      j = i;
    }
    return inside;
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> _loadWithCache() async {
    setState(() {
      _loading = true;
      _message = null;
      _isOffline = false;
    });

    // Limpiar caché de eventos para asegurar que se obtengan las coordenadas y el polígono más recientes
    EventService.clearEventCache();

    final userId = SupabaseService.currentUser?.id ?? '';

    // ── Paso 1: mostrar caché inmediatamente ──────────────────────────────
    final cached = await QrCacheService.load(userId);
    if (cached != null && cached.codigoQr.isNotEmpty) {
      setState(() {
        _codigoQr = cached.codigoQr;
        _entradaEstado = cached.estado;
        // Determinamos si está adentro basándonos en el estado
        _dentroEvento = cached.estado.toLowerCase() == 'usado';
        _userName = cached.userName;
        _userEmail = cached.userEmail;
        _cachedAt = cached.cachedAt;
        _expiresAt = cached.expiresAt;
        _versionQr = cached.versionQr;
        _loading = false;
        _isOffline = true;
        _syncing = true;
      });
    }

    // ── Paso 2: intentar sincronizar con Supabase ─────────────────────────
    try {
      final user = SupabaseService.currentUser;
      final freshEmail = user?.email ?? '';
      final freshName = await EventService.getCurrentUserName() ?? freshEmail;
      final uid = await EventService.getCurrentUserId();
      final event = await EventService.getActiveEvent();

      if (uid == null) {
        if (!mounted) return;
        setState(() {
          _syncing = false;
          _loading = false;
          if (_codigoQr == null) {
            _message =
                'No se encontró tu perfil. Cierra sesión e inicia sesión nuevamente.';
          }
        });
        return;
      }

      if (event == null) {
        if (!mounted) return;
        setState(() {
          _syncing = false;
          _loading = false;
          if (_codigoQr == null) {
            _message = 'No hay evento activo en este momento.';
          }
        });
        return;
      }

      // Si el caché es de un evento diferente, descartarlo antes de continuar.
      if (cached != null && cached.eventId != event.id) {
        await QrCacheService.clear(userId);
        if (mounted) {
          setState(() {
            _codigoQr = null;
            _entradaEstado = null;
            _expiresAt = null;
            _isOffline = false;
            _cachedAt = null;
          });
        }
      }


      // Guardamos el polígono del evento activo para el chequeo GPS en polling
      _eventPolygon = event.polygon;

      Map<String, dynamic>? entry = await PaymentService.getMyEntry(
        idUsuario: uid,
        idEvento: event.id,
      );

      // Si no hay entrada, intentar activación automática
      if (entry == null && freshEmail.isNotEmpty) {
        try {
          await StudentService.checkAndActivateIfPreApproved(
            email: freshEmail,
            idUsuario: uid,
            idEvento: event.id,
          );
          entry = await PaymentService.getMyEntry(
            idUsuario: uid,
            idEvento: event.id,
          );
        } catch (e) {
          if (!mounted) return;
          setState(() {
            _syncing = false;
            _loading = false;
            _message = 'Error al activar entrada: $e';
          });
          return;
        }
      }

      if (entry == null) {
        if (!mounted) return;
        setState(() {
          _syncing = false;
          _loading = false;
          if (_codigoQr == null) {
            _message =
                'No tienes una entrada asignada.\nVerifica el estado de tu pago.';
          }
        });
        return;
      }

      final newQr = entry['codigo_qr'] as String? ?? '';
      String newEstado = entry['estado'] as String? ?? 'activo';
      final newExpiresAt = entry['fecha_expiracion'] != null
          ? DateTime.tryParse(entry['fecha_expiracion'].toString())
          : null;
      final newVersion = entry['version_qr'] as int? ?? 1;
      final newIdEntrada = entry['id_entrada'] as int?;

      // Determinamos si está dentro leyendo AMBAS columnas de la BD
      bool newDentroEvento =
          newEstado.toLowerCase() == 'usado' &&
          (entry['dentro_evento'] as bool? ?? false);

      // Si la base de datos dice que está adentro, verificar con el GPS de inmediato
      if (newDentroEvento && newIdEntrada != null && event.polygon != null && event.polygon!.isNotEmpty) {
        final insidePolygon = await _checkGpsInsidePolygon(event.polygon!);
        if (!insidePolygon) {
          // Si está físicamente fuera, resetear BD de inmediato
          try {
            await SupabaseService.client
                .from('entradas')
                .update({'estado': 'activo', 'dentro_evento': false})
                .eq('id_entrada', newIdEntrada);
            newDentroEvento = false;
            newEstado = 'activo';
          } catch (_) {
            // Asumir que está afuera y permitir ver el QR
            newDentroEvento = false;
            newEstado = 'activo';
          }
        }
      }

      final now = DateTime.now();

      await QrCacheService.save(
        userId: userId,
        data: QrCacheData(
          codigoQr: newQr,
          estado: newEstado,
          userName: freshName,
          userEmail: freshEmail,
          eventId: event.id,
          cachedAt: now,
          expiresAt: newExpiresAt,
          versionQr: newVersion,
        ),
      );

      if (!mounted) return;
      setState(() {
        _codigoQr = newQr;
        _entradaEstado = newEstado;
        _expiresAt = newExpiresAt;
        _versionQr = newVersion;
        _idEntrada = newIdEntrada;
        _dentroEvento = newDentroEvento;
        _userName = freshName;
        _userEmail = freshEmail;
        _cachedAt = now;
        _loading = false;
        _isOffline = false;
        _syncing = false;
      });

      // Suscribir a cambios en tiempo real de esta entrada
      if (_idEntrada != null) {
        _subscribeToEntrada(_idEntrada!);
      }

      // Si está marcado como adentro, iniciar polling de respaldo
      if (_dentroEvento && _idEntrada != null) {
        _startPolling();
      } else {
        _stopPolling();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _syncing = false;
        _loading = false;
        if (_codigoQr == null) {
          _message =
              'Sin conexión a internet y no hay QR guardado en este dispositivo.';
        }
      });
    }
  }

  /// Suscripción Realtime: detecta cuando el guardia escanea (estado pasa a 'usado')
  /// o cuando el geofencing resetea el estado a 'activo'
  void _subscribeToEntrada(int idEntrada) {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = SupabaseService.client
        .channel('entradas_user_$idEntrada')
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
            final newRecord = payload.newRecord;
            final estadoActualizado = newRecord['estado'] as String?;
            final dentroActualizado = newRecord['dentro_evento'] as bool?;

            if (estadoActualizado != null) {
              final isInsideNow =
                  estadoActualizado.toLowerCase() == 'usado' &&
                  (dentroActualizado ?? false);
              setState(() {
                _entradaEstado = estadoActualizado;
                _dentroEvento = isInsideNow;
              });
              // Activar/desactivar polling según estado
              if (isInsideNow) {
                _startPolling();
              } else {
                _stopPolling();
              }
            }
          },
        )
        .subscribe();
  }


  void _copyCode() {
    if (_codigoQr == null) return;
    Clipboard.setData(ClipboardData(text: _codigoQr!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Código copiado al portapapeles'),
        backgroundColor: AppColors.sentryBlue,
        duration: Duration(seconds: 2),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'justo ahora';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    return 'hace ${diff.inDays} días';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.sentryBg,
      body: RefreshIndicator(
        onRefresh: _loadWithCache,
        color: AppColors.sentryBlue,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(24.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ────────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mi Código QR',
                        style: GoogleFonts.outfit(
                          color: AppColors.sentryNavy,
                          fontWeight: FontWeight.w800,
                          fontSize: 24.sp,
                        ),
                      ),
                      Text(
                        'Entrada al evento',
                        style: GoogleFonts.outfit(
                          color: AppColors.sentryGrey,
                          fontSize: 14.sp,
                        ),
                      ),
                    ],
                  ),
                  _statusBadge(),
                ],
              ),

              // ── Banner offline ────────────────────────────────────────
              if (_isOffline && _codigoQr != null) ...[
                SizedBox(height: 14.h),
                _offlineBanner(),
              ],

              SizedBox(height: 25.h),

              // ── Contenido principal ───────────────────────────────────
              if (_loading)
                Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 60.h),
                    child: const CircularProgressIndicator(
                      color: AppColors.sentryBlue,
                    ),
                  ),
                )
              else if (_message != null)
                _buildMessageCard(_message!)
              else ...[
                _buildQrMainCard(),
                SizedBox(height: 25.h),
                Row(
                  children: [
                    Expanded(
                      child: _actionButton(
                        'Copiar código',
                        Icons.copy_rounded,
                        AppColors.sentryBlue,
                        _copyCode,
                      ),
                    ),
                    SizedBox(width: 15.w),
                    Expanded(
                      child: _actionButton(
                        _syncing ? 'Sincronizando…' : 'Actualizar',
                        _syncing ? Icons.sync_rounded : Icons.refresh_rounded,
                        AppColors.sentryGrey,
                        _syncing ? () {} : _loadWithCache,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 25.h),
                _buildInfoNotice(),
                SizedBox(height: 25.h),
                Text(
                  '¿Cómo usarlo?',
                  style: GoogleFonts.outfit(
                    color: AppColors.sentryNavy,
                    fontWeight: FontWeight.w700,
                    fontSize: 16.sp,
                  ),
                ),
                SizedBox(height: 15.h),
                _stepItem(1, 'Llega al punto de ingreso del evento'),
                _stepItem(2, 'Muestra esta pantalla al guardia'),
                _stepItem(3, 'El guardia escaneará el código con Sentry'),
                _stepItem(4, 'Recibirás confirmación de acceso'),
              ],
              SizedBox(height: 100.h),
            ],
          ),
        ),
      ),
    );
  }

  // ── Banner de modo offline ──────────────────────────────────────────────

  Widget _offlineBanner() => Container(
    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
    decoration: BoxDecoration(
      color: AppColors.warning.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(12.r),
      border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
    ),
    child: Row(
      children: [
        Icon(Icons.wifi_off_rounded, color: AppColors.warning, size: 18.sp),
        SizedBox(width: 10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Modo sin conexión',
                style: GoogleFonts.outfit(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.sp,
                ),
              ),
              if (_cachedAt != null)
                Text(
                  'Guardado ${_timeAgo(_cachedAt!)} · desliza para intentar actualizar',
                  style: GoogleFonts.outfit(
                    color: AppColors.warning.withValues(alpha: 0.8),
                    fontSize: 11.sp,
                  ),
                ),
            ],
          ),
        ),
        if (_syncing)
          SizedBox(
            width: 16.w,
            height: 16.w,
            child: const CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.warning,
            ),
          ),
      ],
    ),
  );

  // ── Badge de estado superior ────────────────────────────────────────────

  Widget _statusBadge() {
    if (_dentroEvento) {
      return _badge('Dentro del evento', AppColors.sentryBlue);
    }
    if (_isOffline && _codigoQr != null) {
      return _badge('Sin conexión', AppColors.warning);
    }
    if (_codigoQr != null) return const SizedBox.shrink();
    return _badge('Sin entrada', AppColors.sentryGrey);
  }

  Widget _badge(String label, Color color) => Container(
    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8.r),
    ),
    child: Text(
      label,
      style: GoogleFonts.outfit(
        color: color,
        fontSize: 11.sp,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  // ── Tarjeta principal del QR ────────────────────────────────────────────

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}';
  }

  Widget _buildQrMainCard() {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        children: [
          // Info del usuario
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.sentryBlue,
                radius: 22.r,
                child: Text(
                  _userName?.isNotEmpty == true
                      ? _userName![0].toUpperCase()
                      : '?',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18.sp,
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _userName ?? 'Usuario',
                      style: GoogleFonts.outfit(
                        color: AppColors.sentryNavy,
                        fontWeight: FontWeight.w700,
                        fontSize: 15.sp,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _userEmail ?? '',
                      style: GoogleFonts.outfit(
                        color: AppColors.sentryGrey,
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                ),
              ),
              _entradaStatusChip(),
            ],
          ),

          const Divider(height: 30, color: AppColors.divider),

          // QR, dentro del evento, expirado, o activo
          if (_dentroEvento)
            _buildStatusCard(
              icon: Icons.verified_user_rounded,
              color: AppColors.sentryBlue,
              title: 'Estás dentro del evento',
              subtitle:
                  'Tu QR se habilitará automáticamente cuando salgas del recinto.',
            )
          else if (_isExpired)
            _buildStatusCard(
              icon: Icons.timer_off_rounded,
              color: AppColors.warning,
              title: 'QR Expirado',
              subtitle: _expiresAt != null
                  ? 'Venció el ${_formatDate(_expiresAt!)}. Contacta al administrador.'
                  : 'Este QR ya no es válido.',
            )
          else
            Container(
              padding: EdgeInsets.all(15.r),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.sentryBg, width: 2),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: QrImageView(
                data: _codigoQr!,
                version: QrVersions.auto,
                size: 200.w,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: AppColors.sentryNavy,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: AppColors.sentryNavy,
                ),
              ),
            ),

          SizedBox(height: 15.h),
          if (!_dentroEvento && !_isExpired)
            Text(
              'Muestra este código al entrar al evento',
              style: GoogleFonts.outfit(
                color: AppColors.sentryGrey,
                fontSize: 12.sp,
                fontStyle: FontStyle.italic,
              ),
            ),
          SizedBox(height: 20.h),

          _qrDataRow(
            'Código',
            _codigoQr != null
                ? '${_codigoQr!.substring(0, _codigoQr!.length.clamp(0, 16))}…'
                : '—',
          ),
          _qrDataRow(
            'Estado',
            _dentroEvento ? 'Adentro' : (_entradaEstado ?? '—'),
          ),
          _qrDataRow('Versión', 'v$_versionQr'),
          if (_expiresAt != null)
            _qrDataRow('Expira', _formatDate(_expiresAt!)),
          if (_cachedAt != null)
            _qrDataRow('Última sync', _timeAgo(_cachedAt!)),
        ],
      ),
    );
  }

  Widget _buildStatusCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) => Container(
    padding: EdgeInsets.all(20.r),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(16.r),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Column(
      children: [
        Icon(icon, size: 64.sp, color: color),
        SizedBox(height: 8.h),
        Text(
          title,
          style: GoogleFonts.outfit(
            color: AppColors.sentryNavy,
            fontWeight: FontWeight.w700,
            fontSize: 16.sp,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            color: AppColors.sentryGrey,
            fontSize: 12.sp,
          ),
        ),
      ],
    ),
  );

  Widget _entradaStatusChip() {
    if (_dentroEvento) {
      return _chipBadge('Usado', AppColors.sentryBlue);
    }
    if (_isExpired) {
      return _chipBadge('Expirado', AppColors.warning);
    }
    return _chipBadge('Válido', AppColors.success);
  }

  Widget _chipBadge(String label, Color color) => Container(
    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8.r),
    ),
    child: Text(
      label,
      style: GoogleFonts.outfit(
        color: color,
        fontSize: 11.sp,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  // ── Tarjeta de mensaje (sin QR) ─────────────────────────────────────────

  Widget _buildMessageCard(String msg) => Container(
    padding: EdgeInsets.all(28.r),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20.r),
    ),
    child: Column(
      children: [
        Icon(Icons.qr_code_2_rounded, size: 56.sp, color: AppColors.sentryGrey),
        SizedBox(height: 16.h),
        Text(
          'QR no disponible',
          style: GoogleFonts.outfit(
            color: AppColors.sentryNavy,
            fontWeight: FontWeight.w700,
            fontSize: 16.sp,
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          msg,
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            color: AppColors.sentryGrey,
            fontSize: 13.sp,
          ),
        ),
        SizedBox(height: 16.h),
        ElevatedButton.icon(
          onPressed: _loadWithCache,
          icon: Icon(Icons.refresh_rounded, color: Colors.white, size: 18.sp),
          label: Text(
            'Reintentar',
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 14.sp),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.sentryBlue,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
          ),
        ),
      ],
    ),
  );

  // ── Helpers ─────────────────────────────────────────────────────────────

  Widget _buildInfoNotice() => Container(
    padding: EdgeInsets.all(16.r),
    decoration: BoxDecoration(
      color: AppColors.sentryNavy.withValues(alpha: 0.03),
      borderRadius: BorderRadius.circular(15.r),
      border: Border.all(color: AppColors.sentryNavy.withValues(alpha: 0.05)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.shield_outlined, color: AppColors.sentryNavy, size: 20.sp),
        SizedBox(width: 12.w),
        Expanded(
          child: Text(
            'Este QR es personal e intransferible. El sistema detecta y rechaza usos duplicados automáticamente.',
            style: GoogleFonts.outfit(
              color: AppColors.sentryNavy,
              fontSize: 12.sp,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _qrDataRow(String label, String val) => Padding(
    padding: EdgeInsets.symmetric(vertical: 4.h),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            color: AppColors.sentryGrey,
            fontSize: 13.sp,
          ),
        ),
        Text(
          val,
          style: GoogleFonts.outfit(
            color: AppColors.sentryNavy,
            fontWeight: FontWeight.w700,
            fontSize: 13.sp,
          ),
        ),
      ],
    ),
  );

  Widget _actionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) => ElevatedButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 18.sp, color: Colors.white),
    label: Text(
      label,
      style: GoogleFonts.outfit(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
    ),
    style: ElevatedButton.styleFrom(
      backgroundColor: color,
      padding: EdgeInsets.symmetric(vertical: 12.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
    ),
  );

  Widget _stepItem(int num, String text) => Padding(
    padding: EdgeInsets.only(bottom: 12.h),
    child: Row(
      children: [
        CircleAvatar(
          radius: 12.r,
          backgroundColor: AppColors.sentryBlue,
          child: Text(
            '$num',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 10.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.outfit(
              color: AppColors.sentryNavy,
              fontSize: 14.sp,
            ),
          ),
        ),
      ],
    ),
  );
}

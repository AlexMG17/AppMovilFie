import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/event_service.dart';
import '../services/payment_service.dart' show PaymentService, PagoAdminModel;
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';

class PaymentVouchersScreen extends StatefulWidget {
  const PaymentVouchersScreen({super.key, this.showAppBar = true});
  final bool showAppBar;
  @override
  State<PaymentVouchersScreen> createState() => _PaymentVouchersScreenState();
}

class _PaymentVouchersScreenState extends State<PaymentVouchersScreen> {
  List<PagoAdminModel> _pagos = [];
  List<Map<String, dynamic>> _excelPendientes = [];
  bool _loading = true;
  String? _error;
  String? _filterEstado = 'pendiente';
  final _searchCtrl = TextEditingController();
  String _query = '';
  int? _eventId;
  String _eventName = 'Gala FIE';
  final Set<int> _processing = {};
  RealtimeChannel? _channel;
  String _userName = '';
  final _scrollCtrl = ScrollController();
  bool _showScrollTop = false;

  // ── computed ──────────────────────────────────────────────────────────────

  List<PagoAdminModel> get _filteredPagos {
    final list = _pagos.where((p) {
      final ms = _filterEstado == null || p.estado == _filterEstado;
      final mq = _query.isEmpty ||
          p.nombreUsuario.toLowerCase().contains(_query.toLowerCase()) ||
          p.emailUsuario.toLowerCase().contains(_query.toLowerCase());
      return ms && mq;
    }).toList();
    if (_filterEstado == 'pendiente') {
      list.sort((a, b) {
        final aHas = a.comprobante != null ? 0 : 1;
        final bHas = b.comprobante != null ? 0 : 1;
        return aHas.compareTo(bHas);
      });
    }
    return list;
  }

  List<Map<String, dynamic>> get _filteredExcel {
    if (_filterEstado != null && _filterEstado != 'pendiente') return [];
    return _excelPendientes.where((s) {
      return _query.isEmpty ||
          (s['nombre'] ?? '').toLowerCase().contains(_query.toLowerCase()) ||
          (s['correo_electronico'] ?? '')
              .toLowerCase()
              .contains(_query.toLowerCase());
    }).toList();
  }

  int _count(String? e) {
    if (e == null) return _pagos.length + _excelPendientes.length;
    if (e == 'pendiente') {
      return _pagos.where((p) => p.estado == 'pendiente').length +
          _excelPendientes.length;
    }
    return _pagos.where((p) => p.estado == e).length;
  }

  // ── lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadUserName();
    _scrollCtrl.addListener(() {
      final show = _scrollCtrl.offset > 300;
      if (show != _showScrollTop) setState(() => _showScrollTop = show);
    });
  }

  Future<void> _loadUserName() async {
    final name = await EventService.getCurrentUserName();
    if (mounted) setState(() => _userName = name ?? SupabaseService.currentUser?.email ?? '');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    _channel?.unsubscribe();
    super.dispose();
  }

  // ── data ──────────────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final event = await EventService.getActiveEvent();
      if (event == null) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = 'No hay evento activo.';
          });
        }
        return;
      }
      _eventId = event.id;
      _eventName = event.nombre;
      final pagos = await PaymentService.getAllPagos(idEvento: event.id);
      final excelPendientes = await _loadExcelPendientes(pagos);
      if (!mounted) return;
      setState(() {
        _pagos = pagos;
        _excelPendientes = excelPendientes;
        _loading = false;
      });
      _subscribeRealtime(event.id);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  // API #4 — Supabase Realtime: nuevos comprobantes aparecen sin refrescar
  void _subscribeRealtime(int idEvento) {
    _channel?.unsubscribe();
    _channel = SupabaseService.client
        .channel('pagos-admin-$idEvento')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'pagos',
          callback: (_) {
            if (mounted) _refreshSilent();
          },
        )
        .subscribe();
  }

  Future<List<Map<String, dynamic>>> _loadExcelPendientes(
      List<PagoAdminModel> pagos) async {
    try {
      final activatedEmails =
          pagos.map((p) => p.emailUsuario.toLowerCase()).toSet();
      final rows = await SupabaseService.client
          .from('listado_estudiantes')
          .select('nombre, correo_electronico, carrera')
          .order('nombre') as List;
      return rows
          .where((r) {
            final email = (r['correo_electronico'] ?? '').toLowerCase();
            return email.isNotEmpty && !activatedEmails.contains(email);
          })
          .cast<Map<String, dynamic>>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _refreshSilent() async {
    if (_eventId == null) return;
    try {
      final pagos = await PaymentService.getAllPagos(idEvento: _eventId!);
      final excelPendientes = await _loadExcelPendientes(pagos);
      if (mounted) {
        setState(() {
          _pagos = pagos;
          _excelPendientes = excelPendientes;
        });
      }
    } catch (_) {}
  }

  // ── actions ───────────────────────────────────────────────────────────────

  Future<void> _approve(PagoAdminModel p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Aprobar pago', style: _ts(16, fw: FontWeight.w700)),
        content: Text(
          '¿Confirmas la aprobación del pago de ${p.nombreUsuario}?\n'
          'Se generará su código QR de acceso.',
          style: _ts(13, c: AppColors.sentryGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: _ts(13, c: AppColors.sentryGrey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child:
                Text('Aprobar', style: _ts(13, fw: FontWeight.w600, c: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _processing.add(p.id));
    try {
      final qrCode = await PaymentService.approvePago(
        idPago: p.id,
        idUsuario: p.idUsuario,
        idEvento: p.idEvento,
      );
      if (mounted) {
        await _refreshSilent();
        _showQrDialog(p.nombreUsuario, qrCode);
        _showSnack('✓ ${p.nombreUsuario} aprobado. QR generado.');
      }
    } catch (e) {
      if (mounted) _showSnack('Error: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _processing.remove(p.id));
    }
  }

  Future<void> _reject(PagoAdminModel p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Rechazar pago', style: _ts(16, fw: FontWeight.w700)),
        content: Text(
          '¿Rechazar el comprobante de ${p.nombreUsuario}?',
          style: _ts(13, c: AppColors.sentryGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: _ts(13, c: AppColors.sentryGrey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Rechazar',
                style: _ts(13, fw: FontWeight.w600, c: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _processing.add(p.id));
    try {
      await PaymentService.rejectPago(idPago: p.id);
      if (mounted) {
        await _refreshSilent();
        _showSnack('Comprobante de ${p.nombreUsuario} rechazado.');
      }
    } catch (e) {
      if (mounted) _showSnack('Error: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _processing.remove(p.id));
    }
  }

  Future<void> _revertApproval(PagoAdminModel p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('¿Revertir aprobación?', style: _ts(16, fw: FontWeight.w700)),
        content: Text(
          'El pago de ${p.nombreUsuario} volverá a estado Pendiente '
          'y su QR de acceso quedará cancelado.',
          style: _ts(13, c: AppColors.sentryGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: _ts(13, c: AppColors.sentryGrey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE65100),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Revertir', style: _ts(13, fw: FontWeight.w600, c: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _processing.add(p.id));
    try {
      await PaymentService.revertApproval(
        idPago: p.id,
        idUsuario: p.idUsuario,
        idEvento: p.idEvento,
      );
      if (mounted) {
        await _refreshSilent();
        _showSnack('Aprobación de ${p.nombreUsuario} revertida a pendiente.');
      }
    } catch (e) {
      if (mounted) _showSnack('Error: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _processing.remove(p.id));
    }
  }

  Future<void> _showExistingQr(PagoAdminModel p) async {
    final entry = await PaymentService.getMyEntry(
      idUsuario: p.idUsuario,
      idEvento: p.idEvento,
    );
    if (!mounted) return;
    if (entry == null) {
      setState(() => _processing.add(p.id));
      try {
        final qrCode = await PaymentService.generateEntryQr(
          idUsuario: p.idUsuario,
          idEvento: p.idEvento,
        );
        if (mounted) _showQrDialog(p.nombreUsuario, qrCode);
      } catch (e) {
        if (mounted) _showSnack('Error al generar QR: ${e.toString()}', isError: true);
      } finally {
        if (mounted) setState(() => _processing.remove(p.id));
      }
      return;
    }
    _showQrDialog(p.nombreUsuario, entry['codigo_qr'] ?? '');
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.success,
    ));
  }

  // ── dialogs / sheets ──────────────────────────────────────────────────────

  void _showVoucherSheet(PagoAdminModel p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        maxChildSize: 0.95,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              Text('Comprobante de Pago',
                  style: _ts(18, fw: FontWeight.w700)),
              const SizedBox(height: 16),
              _detailRow('Estudiante', p.nombreUsuario),
              _detailRow('Email', p.emailUsuario),
              _detailRow(
                'Fecha',
                '${p.fechaPago.day}/${p.fechaPago.month}/${p.fechaPago.year}'
                '  ${_pad(p.fechaPago.hour)}:${_pad(p.fechaPago.minute)}',
              ),
              _detailRow('Estado', p.estado.toUpperCase()),
              if (!p.comprobanteIsUrl && p.comprobante != null)
                _detailRow('Referencia', p.comprobante!),
              const SizedBox(height: 16),
              // Imagen del comprobante (API #3 — Supabase Storage serving)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: p.comprobanteIsUrl
                    ? Image.network(
                        p.comprobante!,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (_, child, prog) => prog == null
                            ? child
                            : Container(
                                height: 180,
                                color: AppColors.sentryBg,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                      color: AppColors.sentryBlue),
                                ),
                              ),
                        errorBuilder: (_, _, _) => _imgPlaceholder(
                            'No se pudo cargar la imagen'),
                      )
                    : _imgPlaceholder(
                        p.comprobante ?? 'Sin archivo adjunto'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imgPlaceholder(String text) => Container(
        width: double.infinity,
        height: 140,
        decoration: BoxDecoration(
          color: AppColors.sentryBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt_long_outlined,
                size: 40, color: AppColors.sentryGrey),
            const SizedBox(height: 8),
            Text(text,
                style: _ts(12, c: AppColors.sentryGrey),
                textAlign: TextAlign.center),
          ],
        ),
      );

  void _showQrDialog(String nombre, String qrCode) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded,
                    color: AppColors.success, size: 28),
              ),
              const SizedBox(height: 12),
              Text('QR Generado', style: _ts(16, fw: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(nombre,
                  style: _ts(13, c: AppColors.sentryGrey),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              // API #8 — qr_flutter: QR generado localmente
              QrImageView(
                data: qrCode,
                version: QrVersions.auto,
                size: 180,
                eyeStyle: const QrEyeStyle(
                  color: AppColors.sentryNavy,
                  eyeShape: QrEyeShape.square,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  color: AppColors.sentryBlue,
                  dataModuleShape: QrDataModuleShape.square,
                ),
              ),
              const SizedBox(height: 8),
              Text(qrCode,
                  style: _ts(9, c: AppColors.sentryGrey),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.sentryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Cerrar',
                      style: _ts(14, fw: FontWeight.w600, c: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.sentryBlue));
    }
    if (_error != null) return _buildError();

    return Scaffold(
      backgroundColor: AppColors.sentryBg,
      floatingActionButton: _showScrollTop
          ? FloatingActionButton.small(
              onPressed: () => _scrollCtrl.animateTo(
                0,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
              ),
              backgroundColor: AppColors.sentryBlue,
              child: const Icon(
                Icons.keyboard_arrow_up_rounded,
                color: Colors.white,
              ),
            )
          : null,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppColors.sentryBlue,
          child: CustomScrollView(
          controller: _scrollCtrl,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (widget.showAppBar) _buildAppBar(),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 8),
                  _buildSearch(),
                  const SizedBox(height: 16),
                  _buildFilters(),
                  const SizedBox(height: 16),
                  _buildSummaryRow(),
                  const SizedBox(height: 16),
                  ..._buildList(),
                ]),
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 56, color: AppColors.error),
              const SizedBox(height: 12),
              Text(_error!,
                  style: _ts(14, c: AppColors.sentryGrey),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                  onPressed: _loadData, child: const Text('Reintentar')),
            ],
          ),
        ),
      );

  SliverAppBar _buildAppBar() => SliverAppBar(
        backgroundColor: AppColors.sentryBg,
        elevation: 0,
        pinned: true,
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Comprobantes de Pago',
                style: _ts(16, fw: FontWeight.w700)),
            Text(_eventName, style: _ts(11, c: AppColors.sentryGrey)),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            offset: const Offset(0, 44),
            onSelected: (value) async {
              if (value == 'logout') {
                final nav = Navigator.of(context);
                await SupabaseService.signOut();
                nav.pushReplacementNamed('/login');
              }
            },
            child: const CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.sentryCyan,
              child: Icon(Icons.person_rounded, color: Colors.white, size: 18),
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
                          color: Colors.black87),
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
                    Text('Cerrar sesión',
                        style: TextStyle(color: Colors.red, fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: AppColors.sentryBlue),
            onPressed: _loadData,
            tooltip: 'Actualizar',
          ),
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                      color: AppColors.success, shape: BoxShape.circle),
                ),
                const SizedBox(width: 4),
                Text('En vivo',
                    style: _ts(10,
                        fw: FontWeight.w600, c: AppColors.success)),
              ],
            ),
          ),
        ],
      );

  Widget _buildSearch() => TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _query = v),
        style: _ts(14),
        decoration: InputDecoration(
          hintText: 'Buscar por nombre o email...',
          hintStyle: _ts(14, c: AppColors.sentryGrey),
          prefixIcon: const Icon(Icons.search_rounded,
              color: AppColors.sentryGrey, size: 20),
          suffixIcon: _query.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded,
                      size: 18, color: AppColors.sentryGrey),
                  onPressed: () =>
                      setState(() {
                        _query = '';
                        _searchCtrl.clear();
                      }),
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.cardBorder)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: AppColors.sentryCyan, width: 1.5)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      );

  Widget _buildFilters() => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _filterChip(null, 'Todos'),
            const SizedBox(width: 8),
            _filterChip('pendiente', 'Pendientes'),
            const SizedBox(width: 8),
            _filterChip('aprobado', 'Aprobados'),
            const SizedBox(width: 8),
            _filterChip('rechazado', 'Rechazados'),
          ],
        ),
      );

  Widget _filterChip(String? estado, String label) {
    final active = _filterEstado == estado;
    return GestureDetector(
      onTap: () => setState(() => _filterEstado = estado),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.sentryBlue : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: active ? AppColors.sentryBlue : AppColors.cardBorder),
          boxShadow: active
              ? [
                  BoxShadow(
                      color: AppColors.sentryBlue.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3))
                ]
              : [],
        ),
        child: Row(
          children: [
            Text(label,
                style: _ts(13,
                    fw: FontWeight.w600,
                    c: active
                        ? Colors.white
                        : AppColors.sentryNavy)),
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: active
                    ? Colors.white.withValues(alpha: 0.25)
                    : AppColors.sentryBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('${_count(estado)}',
                  style: _ts(11,
                      fw: FontWeight.w700,
                      c: active
                          ? Colors.white
                          : AppColors.sentryBlue)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow() => Row(
        children: [
          _summaryTile('Total', _count(null), AppColors.sentryBlue),
          const SizedBox(width: 8),
          _summaryTile(
              'Pendientes', _count('pendiente'), const Color(0xFFE65100)),
          const SizedBox(width: 8),
          _summaryTile(
              'Aprobados', _count('aprobado'), const Color(0xFF2E7D32)),
          const SizedBox(width: 8),
          _summaryTile(
              'Rechazados', _count('rechazado'), const Color(0xFFC62828)),
        ],
      );

  Widget _summaryTile(String label, int value, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            children: [
              Text('$value', style: _ts(20, fw: FontWeight.w800, c: color)),
              Text(label, style: _ts(10, c: AppColors.sentryGrey)),
            ],
          ),
        ),
      );

  List<Widget> _buildList() {
    final pagos = _filteredPagos;
    final excel = _filteredExcel;
    if (pagos.isEmpty && excel.isEmpty) {
      return [
        Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 60),
            child: Column(
              children: [
                Icon(Icons.inbox_outlined,
                    size: 64,
                    color: AppColors.sentryGrey.withValues(alpha: 0.5)),
                const SizedBox(height: 12),
                Text('Sin comprobantes',
                    style: _ts(16,
                        fw: FontWeight.w600, c: AppColors.sentryGrey)),
              ],
            ),
          ),
        )
      ];
    }
    return [
      ...pagos.map(_buildPagoCard),
      ...excel.map(_buildExcelCard),
    ];
  }

  Widget _buildPagoCard(PagoAdminModel p) {
    final processing = _processing.contains(p.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
              color: AppColors.sentryNavy.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor:
                    AppColors.sentryBlue.withValues(alpha: 0.12),
                child: Text(
                  p.nombreUsuario.isNotEmpty
                      ? p.nombreUsuario[0].toUpperCase()
                      : '?',
                  style: _ts(16,
                      fw: FontWeight.w700, c: AppColors.sentryBlue),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.nombreUsuario,
                        style: _ts(14, fw: FontWeight.w700),
                        overflow: TextOverflow.ellipsis),
                    Text(p.emailUsuario,
                        style: _ts(11, c: AppColors.sentryGrey),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              _statusChip(p.estado),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: AppColors.cardBorder, height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              _infoChip(Icons.calendar_today_outlined,
                  '${p.fechaPago.day}/${p.fechaPago.month}/${p.fechaPago.year}'),
              const SizedBox(width: 16),
              _infoChip(Icons.access_time_rounded,
                  '${_pad(p.fechaPago.hour)}:${_pad(p.fechaPago.minute)}'),
              if (p.comprobanteIsUrl) ...[
                const SizedBox(width: 16),
                _infoChip(Icons.attach_file_rounded, 'Archivo'),
              ],
            ],
          ),
          const SizedBox(height: 14),
          if (processing)
            const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    color: AppColors.sentryBlue, strokeWidth: 2),
              ),
            )
          else
            Row(
              children: [
                _iconBtn(Icons.visibility_outlined, AppColors.sentryBlue,
                    () => _showVoucherSheet(p), 'Ver'),
                const SizedBox(width: 8),
                if (p.isPending) ...[
                  Expanded(
                    child: _actionBtn('Aprobar', AppColors.success,
                        Icons.check_rounded, () => _approve(p)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _actionBtn('Rechazar', AppColors.error,
                        Icons.close_rounded, () => _reject(p)),
                  ),
                ] else if (p.isApproved) ...[
                  _iconBtn(Icons.qr_code_2_rounded, AppColors.sentryNavy,
                      () => _showExistingQr(p), 'Ver QR'),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _actionBtn('Revertir', const Color(0xFFE65100),
                        Icons.undo_rounded, () => _revertApproval(p)),
                  ),
                ]
                else if (p.isRejected)
                  Expanded(
                    child: _actionBtn('Aprobar de todas formas', AppColors.success,
                        Icons.check_rounded, () => _approve(p)),
                  )
                else
                  Text('Sin acciones',
                      style: _ts(11, c: AppColors.sentryGrey)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildExcelCard(Map<String, dynamic> s) {
    final nombre = (s['nombre'] ?? '') as String;
    final email = (s['correo_electronico'] ?? '') as String;
    final carrera = (s['carrera'] ?? '') as String;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFF8F00).withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
              color: AppColors.sentryNavy.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFFFF8F00).withValues(alpha: 0.12),
                child: Text(
                  nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                  style: _ts(16, fw: FontWeight.w700, c: const Color(0xFFFF8F00)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nombre,
                        style: _ts(14, fw: FontWeight.w700),
                        overflow: TextOverflow.ellipsis),
                    Text(email,
                        style: _ts(11, c: AppColors.sentryGrey),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              _statusChip('por_activar'),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: AppColors.cardBorder, height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.table_rows_rounded,
                  size: 13, color: AppColors.sentryGrey),
              const SizedBox(width: 4),
              Expanded(
                child: Text('Excel · $carrera',
                    style: _ts(12, c: AppColors.sentryGrey),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 13, color: AppColors.sentryGrey),
              const SizedBox(width: 4),
              Text(
                'QR se genera al iniciar sesión por primera vez',
                style: _ts(11, c: AppColors.sentryGrey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  TextStyle _ts(double sz,
          {FontWeight fw = FontWeight.w400, Color? c}) =>
      GoogleFonts.outfit(
          fontSize: sz,
          fontWeight: fw,
          color: c ?? AppColors.sentryNavy);

  Widget _statusChip(String estado) {
    const configs = {
      'pendiente': (
        label: 'Pendiente',
        bg: Color(0xFFFFF3E0),
        fg: Color(0xFFE65100)
      ),
      'aprobado': (
        label: 'Aprobado',
        bg: Color(0xFFE8F5E9),
        fg: Color(0xFF2E7D32)
      ),
      'rechazado': (
        label: 'Rechazado',
        bg: Color(0xFFFFEBEE),
        fg: Color(0xFFC62828)
      ),
      'por_activar': (
        label: 'Por activar',
        bg: Color(0xFFFFF8E1),
        fg: Color(0xFFFF8F00)
      ),
    };
    final cfg = configs[estado];
    if (cfg == null) return const SizedBox();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: cfg.bg, borderRadius: BorderRadius.circular(20)),
      child:
          Text(cfg.label, style: _ts(11, fw: FontWeight.w600, c: cfg.fg)),
    );
  }

  Widget _infoChip(IconData icon, String text) => Row(
        children: [
          Icon(icon, size: 13, color: AppColors.sentryGrey),
          const SizedBox(width: 4),
          Text(text, style: _ts(12, c: AppColors.sentryGrey)),
        ],
      );

  Widget _iconBtn(
          IconData icon, Color color, VoidCallback onTap, String tip) =>
      Tooltip(
        message: tip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
        ),
      );

  Widget _actionBtn(
          String label, Color color, IconData icon, VoidCallback onTap) =>
      ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 14),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          textStyle:
              GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700),
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          elevation: 0,
        ),
      );

  Widget _detailRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            SizedBox(
              width: 90,
              child: Text(label,
                  style: _ts(12, c: AppColors.sentryGrey)),
            ),
            Expanded(
                child: Text(value, style: _ts(13, fw: FontWeight.w600))),
          ],
        ),
      );

  String _pad(int n) => n.toString().padLeft(2, '0');
}

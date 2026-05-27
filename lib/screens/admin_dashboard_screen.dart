import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui' as ui;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:fl_chart/fl_chart.dart';
import 'package:printing/printing.dart';
import '../services/event_service.dart';
import '../services/payment_service.dart' show PaymentService;
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';
import 'attendees_screen.dart';
import 'import_students_screen.dart';
import 'payment_vouchers_screen.dart';
import 'student_list_screen.dart';

// â”€â”€â”€ Alias locales para legibilidad â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// ignore_for_file: non_constant_identifier_names
Color get _bg => AppColors.sentryBg;
Color get _border => AppColors.cardBorder;
Color get _navy => AppColors.sentryNavy;
Color get _blue => AppColors.sentryBlue;
Color get _cyan => AppColors.sentryCyan;
Color get _grey => AppColors.sentryGrey;
Color get _green => AppColors.success;
Color get _yellow => AppColors.warning;
Color get _red => AppColors.error;
Color get _divider => AppColors.divider;

// â”€â”€â”€ Modelos de datos simulados â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _Activity {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String time;
  const _Activity({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.time,
  });
}

// ══════════════════════════════════════════════════════════════════════════
class AdminDashboardScreen extends StatefulWidget {
  final ValueChanged<int>? onSelectTab;

  const AdminDashboardScreen({super.key, this.onSelectTab});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  late Timer _realtimeTimer;
  int _secondsAgo = 0;

  // ── Métricas ──────────────────────────────────────────────────────────
  int totalRegistrados = 0;
  int totalCapacidad = 350;
  int aprobados = 0;
  int pendientes = 0;
  int rechazados = 0;
  int ingresaron = 0;
  int qrGenerados = 0;
  String _eventName = 'Gala FIE';
  String _userName = '';
  EventModel? _activeEvent;
  RealtimeChannel? _realtimeChannel;

  // ── Actividad reciente ────────────────────────────────────────
  List<_Activity> _activities = [];

  // â”€â”€ Datos gráfico línea (ingresos por hora) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  bool _generatingPdf = false;
  List<FlSpot> _lineSpots = [];
  List<String> _lineLabels = [];
  List<double> _barAprobados = List.filled(7, 0);
  List<double> _barRechazados = List.filled(7, 0);
  List<String> _barDays = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    _realtimeTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _secondsAgo++);
    });

    _loadStats();
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

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _realtimeTimer.cancel();
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  // Carga métricas reales desde Supabase (API #2 — Database)
  Future<void> _loadStats() async {
    try {
      final event = await EventService.getActiveEvent();
      if (event == null || !mounted) return;

      final results = await Future.wait([
        PaymentService.getDashboardStats(idEvento: event.id),
        EventService.getCapacidad(),
        SupabaseService.client
            .from('scan_logs')
            .select('nombre_asistente, resultado, escaneado_en')
            .order('escaneado_en', ascending: false)
            .limit(3),
        SupabaseService.client
            .from('scan_logs')
            .select('escaneado_en')
            .eq('id_evento', event.id)
            .eq('resultado', 'valido'),
        SupabaseService.client
            .from('pagos')
            .select('fecha_pago, estado')
            .eq('id_evento', event.id),
      ]);

      if (!mounted) return;
      final stats = results[0] as Map<String, int>;
      final cap = results[1] as int;
      final logs = results[2] as List;
      final scansForChart = results[3] as List;
      final paymentsForChart = results[4] as List;

      final activities = logs.map<_Activity>((row) {
        final resultado = row['resultado'] as String? ?? 'invalido';
        final nombre = row['nombre_asistente'] as String? ?? 'Desconocido';
        final ts = DateTime.tryParse(row['escaneado_en'] ?? '');
        final diff = ts != null ? DateTime.now().difference(ts) : Duration.zero;
        final timeLabel = diff.inMinutes < 1
            ? 'Ahora'
            : diff.inHours < 1
                ? 'Hace ${diff.inMinutes} min'
                : 'Hace ${diff.inHours} h';
        return switch (resultado) {
          'valido' => _Activity(
              icon: Icons.login_rounded,
              iconColor: _green,
              title: '$nombre ingresó',
              time: timeLabel,
            ),
          'usado' => _Activity(
              icon: Icons.warning_rounded,
              iconColor: _yellow,
              title: '$nombre (QR ya usado)',
              time: timeLabel,
            ),
          _ => _Activity(
              icon: Icons.cancel_outlined,
              iconColor: _red,
              title: 'QR inválido – $nombre',
              time: timeLabel,
            ),
        };
      }).toList();

      // Procesar gráfico de ingresos por hora
      int startHour = 14;
      if (scansForChart.isNotEmpty) {
        int minHour = 24;
        for (final s in scansForChart) {
          final tsStr = s['escaneado_en'];
          if (tsStr != null) {
            final dt = DateTime.tryParse(tsStr);
            if (dt != null) {
              final localHour = dt.toLocal().hour;
              if (localHour < minHour) minHour = localHour;
            }
          }
        }
        if (minHour != 24) startHour = minHour;
      }

      final lineLabelsTemp = <String>[];
      final hourlyCounts = List<int>.filled(8, 0);
      for (int i = 0; i < 8; i++) {
        final h = (startHour + i) % 24;
        lineLabelsTemp.add('${h}h');
      }

      for (final s in scansForChart) {
        final tsStr = s['escaneado_en'];
        if (tsStr != null) {
          final dt = DateTime.tryParse(tsStr);
          if (dt != null) {
            final localHour = dt.toLocal().hour;
            final diff = localHour - startHour;
            if (diff >= 0 && diff < 8) {
              hourlyCounts[diff]++;
            } else if (diff < 0 && diff + 24 < 8) {
              hourlyCounts[diff + 24]++;
            }
          }
        }
      }

      // Procesar gráfico de pagos semanales (aprobados vs rechazados)
      final barAprobadosTemp = List<double>.filled(7, 0.0);
      final barRechazadosTemp = List<double>.filled(7, 0.0);
      for (final p in paymentsForChart) {
        final tsStr = p['fecha_pago'];
        final estado = p['estado'] as String?;
        if (tsStr != null) {
          final dt = DateTime.tryParse(tsStr);
          if (dt != null) {
            final weekday = dt.toLocal().weekday; // 1 (Lun) a 7 (Dom)
            final idx = weekday - 1;
            if (estado == 'aprobado') {
              barAprobadosTemp[idx]++;
            } else if (estado == 'rechazado') {
              barRechazadosTemp[idx]++;
            }
          }
        }
      }

      setState(() {
        _activeEvent = event;
        _eventName = event.nombre;
        totalCapacidad = cap > 0 ? cap : 350;
        totalRegistrados = stats['total_usuarios'] ?? 0;
        pendientes = stats['pendientes'] ?? 0;
        aprobados = stats['aprobados'] ?? 0;
        rechazados = stats['rechazados'] ?? 0;
        ingresaron = stats['ingresaron'] ?? 0;
        qrGenerados = stats['qr_generados'] ?? 0;
        _activities = activities;

        _lineLabels = lineLabelsTemp;

        _barAprobados = barAprobadosTemp;
        _barRechazados = barRechazadosTemp;
      });

      _subscribeRealtime(event.id);
      _loadChartData(event.id);
    } catch (_) {}
  }

  Future<void> _loadChartData(int idEvento) async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final weekAgo = now.subtract(const Duration(days: 6));
      final weekAgoStart = DateTime(weekAgo.year, weekAgo.month, weekAgo.day);

      final results = await Future.wait([
        SupabaseService.client
            .from('scan_logs')
            .select('escaneado_en')
            .eq('resultado', 'valido')
            .gte('escaneado_en', todayStart.toIso8601String()),
        SupabaseService.client
            .from('pagos')
            .select('fecha_pago, estado')
            .eq('id_evento', idEvento)
            .gte('fecha_pago', weekAgoStart.toIso8601String()),
      ]);

      if (!mounted) return;

      // Gráfico de línea: ingresos por hora hoy
      final scanList = results[0] as List;
      final hourCounts = <int, double>{};
      for (final row in scanList) {
        final ts = DateTime.tryParse(row['escaneado_en'] ?? '');
        if (ts != null) hourCounts[ts.hour] = (hourCounts[ts.hour] ?? 0) + 1;
      }

      List<FlSpot> newSpots;
      List<String> newLabels;

      if (hourCounts.isEmpty) {
        // Sin datos hoy: mostrar las últimas 6 horas con ceros
        newSpots = List.generate(6, (i) => FlSpot(i.toDouble(), 0));
        newLabels = List.generate(6, (i) {
          final h = ((now.hour - 5 + i) % 24).clamp(0, 23);
          return '${h}h';
        });
      } else {
        final sortedHours = hourCounts.keys.toList()..sort();
        final minH = sortedHours.first;
        final maxH = sortedHours.last;
        newSpots = [];
        newLabels = [];
        for (int h = minH; h <= maxH; h++) {
          newSpots.add(FlSpot((h - minH).toDouble(), hourCounts[h] ?? 0));
          newLabels.add('${h}h');
        }
      }

      // Gráfico de barras: pagos aprobados/rechazados por día (últimos 7 días)
      final pagosList = results[1] as List;
      final newBarAprobados = List<double>.filled(7, 0);
      final newBarRechazados = List<double>.filled(7, 0);
      final newBarDays = List<String>.generate(7, (i) {
        final d = weekAgoStart.add(Duration(days: i));
        const days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
        return days[d.weekday - 1];
      });

      for (final pago in pagosList) {
        final ts = DateTime.tryParse(pago['fecha_pago'] ?? '');
        if (ts == null) continue;
        final tsDay = DateTime(ts.year, ts.month, ts.day);
        final dayIdx = tsDay.difference(weekAgoStart).inDays;
        if (dayIdx < 0 || dayIdx >= 7) continue;
        final estado = pago['estado'] as String? ?? '';
        if (estado == 'aprobado') newBarAprobados[dayIdx] += 1;
        if (estado == 'rechazado') newBarRechazados[dayIdx] += 1;
      }

      setState(() {
        _lineSpots = newSpots;
        _lineLabels = newLabels;
        _barAprobados = newBarAprobados;
        _barRechazados = newBarRechazados;
        _barDays = newBarDays;
      });
    } catch (_) {}
  }

  // API #4 — Supabase Realtime: métricas se actualizan sin recargar
  void _subscribeRealtime(int idEvento) {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = SupabaseService.client
        .channel('dashboard-$idEvento')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'pagos',
          callback: (_) {
            if (mounted) _loadStats();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'entradas',
          callback: (_) {
            if (mounted) _loadStats();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'scan_logs',
          callback: (_) {
            if (mounted) _loadStats();
          },
        )
        .subscribe();
  }

  // â”€â”€ Helpers de texto â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  TextStyle _ts(double size, {FontWeight fw = FontWeight.w400, Color? color}) =>
      GoogleFonts.outfit(fontSize: size, fontWeight: fw, color: color ?? _navy);

  Future<void> _showEventForm() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EventFormSheet(event: _activeEvent),
    );
    if (saved == true && mounted) _loadStats();
  }

  void _openAdminTab(int index, Widget fallback) {
    if (widget.onSelectTab != null) {
      widget.onSelectTab!(index);
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => fallback));
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}  '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  double get _lineMaxX =>
      _lineSpots.isEmpty ? 5 : (_lineSpots.length - 1).toDouble();

  double get _lineMaxY {
    if (_lineSpots.isEmpty) return 10;
    double max = 5;
    for (final s in _lineSpots) {
      if (s.y > max) max = s.y;
    }
    return (max * 1.3).ceilToDouble();
  }

  double get _barMaxY {
    double max = 5;
    for (final v in [..._barAprobados, ..._barRechazados]) {
      if (v > max) max = v;
    }
    return (max * 1.3).ceilToDouble();
  }

  Future<void> _generatePdfReport() async {
    if (_generatingPdf) return;
    setState(() => _generatingPdf = true);
    try {
      final doc = pw.Document();
      final now = DateTime.now();

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          header: (_) => pw.Column(children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('SENTRY',
                        style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: const PdfColor.fromInt(0xFF0D2B6B),
                        )),
                    pw.Text('Control de Acceso \u2014 FIE ESPOCH',
                        style: const pw.TextStyle(
                            fontSize: 9, color: PdfColors.grey700)),
                  ],
                ),
                pw.Text('REPORTE DE EVENTO',
                    style: pw.TextStyle(
                        fontSize: 13, fontWeight: pw.FontWeight.bold)),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Divider(
                color: const PdfColor.fromInt(0xFF0D2B6B), thickness: 1.5),
            pw.SizedBox(height: 4),
          ]),
          footer: (ctx) => pw.Column(children: [
            pw.Divider(color: PdfColors.grey300),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Generado: ${_formatDate(now)}',
                    style: const pw.TextStyle(
                        fontSize: 8, color: PdfColors.grey)),
                pw.Text('P\u00e1gina ${ctx.pageNumber} de ${ctx.pagesCount}',
                    style: const pw.TextStyle(
                        fontSize: 8, color: PdfColors.grey)),
              ],
            ),
          ]),
          build: (_) => [
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.blueGrey200),
                borderRadius:
                    const pw.BorderRadius.all(pw.Radius.circular(8)),
                color: PdfColors.blueGrey50,
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Informaci\u00f3n del Evento',
                      style: pw.TextStyle(
                          fontSize: 13, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 8),
                  _pdfLabelRow('Nombre del evento', _eventName),
                  if (_activeEvent != null) ...[
                    _pdfLabelRow('Fecha', _formatDate(_activeEvent!.fecha)),
                    _pdfLabelRow('Lugar', _activeEvent!.lugar),
                  ],
                  _pdfLabelRow('Reporte generado', _formatDate(now)),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text('Estad\u00edsticas de Asistencia',
                style: pw.TextStyle(
                    fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(2),
              },
              children: [
                _pdfHeaderRow(['M\u00e9trica', 'Valor', 'Descripci\u00f3n']),
                _pdfDataRow(
                    ['Registrados', '$totalRegistrados', 'Total en sistema']),
                _pdfDataRow(
                    ['Aprobados', '$aprobados', 'Pagos verificados']),
                _pdfDataRow(['Pendientes', '$pendientes', 'En revisi\u00f3n']),
                _pdfDataRow(
                    ['Rechazados', '$rechazados', 'Pagos inv\u00e1lidos']),
                _pdfDataRow(
                    ['Ingresaron', '$ingresaron', 'Entradas al evento']),
                _pdfDataRow(
                    ['QR Generados', '$qrGenerados', 'C\u00f3digos activos']),
              ],
            ),
            pw.SizedBox(height: 20),
            if (aprobados + pendientes + rechazados > 0) ...[
              pw.Text('Distribuci\u00f3n de Pagos',
                  style: pw.TextStyle(
                      fontSize: 13, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              _pdfProgressBar('Aprobados', aprobados,
                  aprobados + pendientes + rechazados,
                  const PdfColor.fromInt(0xFF22C55E)),
              pw.SizedBox(height: 6),
              _pdfProgressBar('Pendientes', pendientes,
                  aprobados + pendientes + rechazados,
                  const PdfColor.fromInt(0xFFF59E0B)),
              pw.SizedBox(height: 6),
              _pdfProgressBar('Rechazados', rechazados,
                  aprobados + pendientes + rechazados,
                  const PdfColor.fromInt(0xFFEF4444)),
              pw.SizedBox(height: 20),
            ],
            pw.Text('Pagos por D\u00eda \u2014 \u00daltimos 7 d\u00edas',
                style: pw.TextStyle(
                    fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                _pdfHeaderRow(['D\u00eda', 'Aprobados', 'Rechazados', 'Total']),
                for (int i = 0; i < 7; i++)
                  _pdfDataRow([
                    _barDays[i],
                    '${_barAprobados[i].toInt()}',
                    '${_barRechazados[i].toInt()}',
                    '${(_barAprobados[i] + _barRechazados[i]).toInt()}',
                  ]),
              ],
            ),
            pw.SizedBox(height: 20),
            if (_activities.isNotEmpty) ...[
              pw.Text('Actividad Reciente',
                  style: pw.TextStyle(
                      fontSize: 13, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(1),
                },
                children: [
                  _pdfHeaderRow(['Actividad', 'Tiempo']),
                  for (final a in _activities)
                    _pdfDataRow([a.title, a.time]),
                ],
              ),
            ],
          ],
        ),
      );

      await Printing.layoutPdf(
        onLayout: (_) async => doc.save(),
        name:
            'Reporte_${_eventName.replaceAll(' ', '_')}_${now.day}-${now.month}-${now.year}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al generar PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  pw.Widget _pdfLabelRow(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(children: [
          pw.Text('$label: ',
              style: pw.TextStyle(
                  fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
        ]),
      );

  pw.TableRow _pdfHeaderRow(List<String> cells) => pw.TableRow(
        decoration: const pw.BoxDecoration(
            color: PdfColor.fromInt(0xFF0D2B6B)),
        children: cells
            .map((c) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 8, vertical: 6),
                  child: pw.Text(c,
                      style: pw.TextStyle(
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 10)),
                ))
            .toList(),
      );

  pw.TableRow _pdfDataRow(List<String> cells) => pw.TableRow(
        children: cells
            .map((c) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 8, vertical: 5),
                  child: pw.Text(c, style: const pw.TextStyle(fontSize: 10)),
                ))
            .toList(),
      );

  pw.Widget _pdfProgressBar(
      String label, int value, int total, PdfColor color) {
    final pct = total > 0 ? value / total : 0.0;
    final pctStr = '${(pct * 100).toStringAsFixed(1)}%';
    const barMaxWidth = 290.0;
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
        pw.SizedBox(
            width: 80,
            child: pw.Text(label,
                style: const pw.TextStyle(fontSize: 10))),
        pw.Stack(children: [
          pw.Container(
              width: barMaxWidth, height: 11, color: PdfColors.grey200),
          pw.Container(
              width: barMaxWidth * pct.clamp(0.0, 1.0),
              height: 11,
              color: color),
        ]),
        pw.SizedBox(width: 8),
        pw.Text('$value  ($pctStr)',
            style: const pw.TextStyle(fontSize: 10)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildAppBar(),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 8),
                    _buildDashboardHeader(),
                    const SizedBox(height: 20),
                    _buildMetricGrid(),
                    const SizedBox(height: 20),
                    _buildLineChartCard(),
                    const SizedBox(height: 16),
                    _buildBarChartCard(),
                    const SizedBox(height: 16),
                    _buildActivityCard(),
                    const SizedBox(height: 16),
                    _buildQuickAccess(),
                    const SizedBox(height: 32),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // â”€â”€ AppBar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      backgroundColor: _bg,
      elevation: 0,
      pinned: true,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          color: _bg,
          boxShadow: [
            BoxShadow(
              color: _navy.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
      automaticallyImplyLeading: false,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Panel Administrativo', style: _ts(16, fw: FontWeight.w700)),
          Text(_eventName, style: _ts(11, color: _grey)),
        ],
      ),
      actions: [
        IconButton(
          onPressed: _generatingPdf ? null : _generatePdfReport,
          tooltip: 'Generar reporte PDF',
          icon: _generatingPdf
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.picture_as_pdf_rounded),
        ),
        PopupMenuButton<String>(
          offset: const Offset(0, 44),
          onSelected: (value) async {
            if (value == 'logout') {
              await SupabaseService.signOut();
              if (mounted) Navigator.pushReplacementNamed(context, '/login');
            }
          },
          child: CircleAvatar(
            radius: 16,
            backgroundColor: _blue.withValues(alpha: 0.15),
            child: Icon(Icons.person_rounded, size: 18, color: _blue),
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
        const SizedBox(width: 4),
      ],
    );
  }

  // â”€â”€ Header Dashboard â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildDashboardHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Dashboard', style: _ts(22, fw: FontWeight.w800)),
              Text(
                'Estadísticas generales — $_eventName',
                style: _ts(11, color: _grey),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _showEventForm,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _blue.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _activeEvent != null
                            ? Icons.edit_rounded
                            : Icons.add_rounded,
                        size: 13,
                        color: _blue,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _activeEvent != null ? 'Editar evento' : 'Crear evento',
                        style: _ts(11, fw: FontWeight.w600, color: _blue),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Chip ingresados
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [_navy, _blue]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: _cyan, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '$ingresaron / $totalCapacidad',
                    style: _ts(16, fw: FontWeight.w800, color: Colors.white),
                  ),
                  Text('ingresados', style: _ts(10, color: Colors.white70)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildMetricGrid() {
    final metrics = [
      _MetricData(
        Icons.people_alt_rounded,
        _blue,
        '$totalRegistrados',
        'Registrados',
        'Total en sistema',
      ),
      _MetricData(
        Icons.check_circle_rounded,
        _green,
        '$aprobados',
        'Aprobados',
        'Pagos verificados',
      ),
      _MetricData(
        Icons.schedule_rounded,
        _yellow,
        '$pendientes',
        'Pendientes',
        'En revisión',
      ),
      _MetricData(
        Icons.cancel_rounded,
        _red,
        '$rechazados',
        'Rechazados',
        'Pagos inválidos',
      ),
      _MetricData(
        Icons.login_rounded,
        _cyan,
        '$ingresaron',
        'Ingresaron',
        'Al evento hoy',
      ),
      _MetricData(
        Icons.qr_code_2_rounded,
        _navy,
        '$qrGenerados',
        'QR Generados',
        'Códigos activos',
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.35,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: metrics.length,
      itemBuilder: (_, i) => _MetricCard(data: metrics[i]),
    );
  }

  // ── Gráfico de línea ──────────────────────────────────────────────────────
  Widget _buildLineChartCard() {
    return _CardWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ingresos por hora',
                      style: _ts(15, fw: FontWeight.w700),
                    ),
                    Text(
                      'Flujo de entrada al evento',
                      style: _ts(11, color: _grey),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _green.withValues(alpha: 0.4)),
                ),
                child: Text(
                  'Hoy',
                  style: _ts(11, color: _green, fw: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: _border, strokeWidth: 0.8),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: 25,
                      getTitlesWidget: (v, _) =>
                          Text('${v.toInt()}', style: _ts(9, color: _grey)),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (v, _) {
                        final idx = v.toInt();
                        if (idx < 0 || idx >= _lineLabels.length) {
                          return const SizedBox();
                        }
                        return Text(
                          _lineLabels[idx],
                          style: _ts(9, color: _grey),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: _lineMaxX,
                minY: 0,
                maxY: _lineMaxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: _lineSpots,
                    isCurved: true,
                    color: _blue,
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                        radius: 3.5,
                        color: _blue,
                        strokeWidth: 2,
                        strokeColor: _bg,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          _blue.withValues(alpha: 0.25),
                          _blue.withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Gráfico de barras ──────────────────────────────────────────────────────
  Widget _buildBarChartCard() {
    return _CardWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pagos semanales',
                      style: _ts(15, fw: FontWeight.w700),
                    ),
                    Text(
                      'Aprobados vs Rechazados',
                      style: _ts(11, color: _grey),
                    ),
                  ],
                ),
              ),
              _Legend(color: _blue, label: 'Aprobados'),
              const SizedBox(width: 12),
              _Legend(color: _red, label: 'Rechazados'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 170,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: _barMaxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: _border, strokeWidth: 0.8),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (v, _) {
                        final idx = v.toInt();
                        if (idx < 0 || idx >= _barDays.length) {
                          return const SizedBox();
                        }
                        return Text(_barDays[idx], style: _ts(9, color: _grey));
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: 15,
                      getTitlesWidget: (v, _) =>
                          Text('${v.toInt()}', style: _ts(9, color: _grey)),
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                barGroups: List.generate(_barDays.length, (i) {
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: _barAprobados[i],
                        color: _blue,
                        width: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      BarChartRodData(
                        toY: _barRechazados[i],
                        color: _red,
                        width: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }


  // â”€â”€ Acceso rápido â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildQuickAccess() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Acceso rápido', style: _ts(15, fw: FontWeight.w700)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickCard(
                icon: Icons.people_alt_rounded,
                color: _blue,
                title: 'Asistentes',
                subtitle: 'Lista en tiempo real',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AttendeesScreen()),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickCard(
                icon: Icons.receipt_long_rounded,
                color: _cyan,
                title: 'Comprobantes',
                subtitle: 'Gestión de pagos',
                onTap: () => _openAdminTab(1, const PaymentVouchersScreen()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickCard(
                icon: Icons.format_list_bulleted_rounded,
                color: const Color(0xFF06B6D4),
                title: 'Lista Estudiantes',
                subtitle: 'CRUD y descarga',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StudentListScreen()),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickCard(
                icon: Icons.upload_file_rounded,
                color: const Color(0xFF7C3AED),
                title: 'Importar',
                subtitle: 'Carga masiva Excel/CSV',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ImportStudentsScreen(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // â”€â”€ Actividad reciente â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildActivityCard() {
    return _CardWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Actividad reciente', style: _ts(15, fw: FontWeight.w700)),
              const Spacer(),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: _green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text('Tiempo real', style: _ts(11, color: _green)),
            ],
          ),
          const SizedBox(height: 16),
          if (_activities.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Sin actividad reciente',
                  style: _ts(13, color: _grey),
                ),
              ),
            )
          else
            ...List.generate(_activities.length, (i) {
              final a = _activities[i];
              return Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: a.iconColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(a.icon, color: a.iconColor, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          a.title,
                          style: _ts(13, fw: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(a.time, style: _ts(11, color: _grey)),
                    ],
                  ),
                  if (i < _activities.length - 1)
                    Divider(height: 20, color: _divider, thickness: 0.5),
                ],
              );
            }),
        ],
      ),
    );
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// Widgets auxiliares
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class _MetricData {
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final String sublabel;
  const _MetricData(
    this.icon,
    this.color,
    this.value,
    this.label,
    this.sublabel,
  );
}

class _MetricCard extends StatelessWidget {
  final _MetricData data;
  const _MetricCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.sentryNavy.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: data.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(data.icon, color: data.color, size: 18),
              ),
              const Spacer(),
              Icon(
                Icons.trending_up_rounded,
                size: 14,
                color: AppColors.sentryGrey,
              ),
            ],
          ),
          const Spacer(),
          Text(
            data.value,
            style: GoogleFonts.outfit(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.sentryNavy,
            ),
          ),
          Text(
            data.label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.sentryNavy,
            ),
          ),
          Text(
            data.sublabel,
            style: GoogleFonts.outfit(
              fontSize: 10,
              color: AppColors.sentryGrey,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardWrapper extends StatelessWidget {
  final Widget child;
  const _CardWrapper({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
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
      child: child,
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.outfit(fontSize: 10, color: AppColors.sentryGrey),
        ),
      ],
    );
  }
}

// â”€â”€â”€ Tarjeta de acceso rápido â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _QuickCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(14),
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
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.sentryNavy,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      color: AppColors.sentryGrey,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.sentryGrey,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Event Create / Edit Bottom Sheet ──────────────────────────────────────────

class _EventFormSheet extends StatefulWidget {
  final EventModel? event;
  const _EventFormSheet({this.event});

  @override
  State<_EventFormSheet> createState() => _EventFormSheetState();
}

class _EventFormSheetState extends State<_EventFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombre;
  late final TextEditingController _descripcion;
  late final TextEditingController _lugar;
  late final TextEditingController _lat;
  late final TextEditingController _lng;
  DateTime? _fecha;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    _nombre = TextEditingController(text: e?.nombre ?? '');
    _descripcion = TextEditingController(text: e?.descripcion ?? '');
    _lugar = TextEditingController(text: e?.lugar ?? '');
    _lat = TextEditingController(text: e != null ? e.lat.toString() : '');
    _lng = TextEditingController(text: e != null ? e.lng.toString() : '');
    _fecha = e?.fecha;
  }

  @override
  void dispose() {
    _nombre.dispose();
    _descripcion.dispose();
    _lugar.dispose();
    _lat.dispose();
    _lng.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _fecha ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_fecha ?? DateTime.now()),
    );
    if (!mounted) return;
    setState(() {
      _fecha = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? 0,
        time?.minute ?? 0,
      );
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fecha == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona la fecha del evento')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final lat = double.tryParse(_lat.text.trim()) ?? -1.6489;
      final lng = double.tryParse(_lng.text.trim()) ?? -78.6480;
      if (widget.event == null) {
        await EventService.createEvent(
          nombre: _nombre.text.trim(),
          descripcion: _descripcion.text.trim(),
          fecha: _fecha!,
          lugar: _lugar.text.trim(),
          lat: lat,
          lng: lng,
        );
      } else {
        await EventService.updateEvent(
          id: widget.event!.id,
          nombre: _nombre.text.trim(),
          descripcion: _descripcion.text.trim(),
          fecha: _fecha!,
          lugar: _lugar.text.trim(),
          lat: lat,
          lng: lng,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.event != null;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottom),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isEdit ? 'Editar evento' : 'Crear evento',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0D1B4B),
                ),
              ),
              const SizedBox(height: 20),
              _field(_nombre, 'Nombre del evento', Icons.event_rounded),
              const SizedBox(height: 12),
              _field(
                _descripcion,
                'Descripción',
                Icons.notes_rounded,
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              _field(_lugar, 'Lugar / Ubicación', Icons.location_on_rounded),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      _lat,
                      'Latitud',
                      Icons.pin_drop_rounded,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(
                      _lng,
                      'Longitud',
                      Icons.pin_drop_rounded,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.calendar_today_rounded),
                    labelText: 'Fecha y hora del evento',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF5F6FA),
                  ),
                  child: Text(
                    _fecha == null
                        ? 'Seleccionar fecha y hora'
                        : '${_fecha!.day.toString().padLeft(2, '0')}/'
                              '${_fecha!.month.toString().padLeft(2, '0')}/'
                              '${_fecha!.year}  '
                              '${_fecha!.hour.toString().padLeft(2, '0')}:'
                              '${_fecha!.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      color: _fecha == null
                          ? Colors.grey[600]
                          : const Color(0xFF0D1B4B),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0D1B4B),
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        isEdit ? 'Guardar cambios' : 'Crear evento',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) => TextFormField(
    controller: ctrl,
    maxLines: maxLines,
    keyboardType: keyboardType,
    decoration: InputDecoration(
      prefixIcon: Icon(icon),
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: const Color(0xFFF5F6FA),
    ),
    validator: (v) =>
        (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// Custom Line Chart
// ══════════════════════════════════════════════════════════════════════════════

class _LineChartWidget extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final double maxY;
  final Color lineColor;
  final Color gridColor;
  final Color labelColor;
  final Color bgColor;

  const _LineChartWidget({
    required this.values,
    required this.labels,
    required this.maxY,
    required this.lineColor,
    required this.gridColor,
    required this.labelColor,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: CustomPaint(
        painter: _LineChartPainter(
          values: values,
          labels: labels,
          maxY: maxY,
          lineColor: lineColor,
          gridColor: gridColor,
          labelColor: labelColor,
          bgColor: bgColor,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final double maxY;
  final Color lineColor;
  final Color gridColor;
  final Color labelColor;
  final Color bgColor;

  _LineChartPainter({
    required this.values,
    required this.labels,
    required this.maxY,
    required this.lineColor,
    required this.gridColor,
    required this.labelColor,
    required this.bgColor,
  });

  static const _lp = 36.0; // left padding for Y labels
  static const _bp = 22.0; // bottom padding for X labels
  static const _tp = 6.0;  // top padding
  static const _rp = 4.0;  // right padding

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final chartW = size.width - _lp - _rp;
    final chartH = size.height - _bp - _tp;
    final chartRect = Rect.fromLTWH(_lp, _tp, chartW, chartH);

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.8;

    final labelStyle = ui.TextStyle(fontSize: 9, color: labelColor);
    const gridLines = 4;

    // Draw horizontal grid lines + Y labels
    for (int i = 0; i <= gridLines; i++) {
      final frac = i / gridLines;
      final y = _tp + chartH * (1 - frac);
      canvas.drawLine(Offset(_lp, y), Offset(_lp + chartW, y), gridPaint);

      final value = (maxY * frac).toInt();
      final pb = ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: TextAlign.right))
        ..pushStyle(labelStyle)
        ..addText('$value');
      final para = pb.build()..layout(ui.ParagraphConstraints(width: _lp - 4));
      canvas.drawParagraph(para, Offset(0, y - para.height / 2));
    }

    final n = values.length;
    if (n < 2) return;

    // Compute screen points
    final pts = <Offset>[];
    for (int i = 0; i < n; i++) {
      final x = _lp + chartW * i / (n - 1);
      final y = _tp + chartH * (1 - (values[i] / maxY).clamp(0.0, 1.0));
      pts.add(Offset(x, y));
    }

    // Clip all drawing to chart area
    canvas.save();
    canvas.clipRect(chartRect);

    // Gradient fill
    final fillPath = Path()
      ..moveTo(pts.first.dx, chartRect.bottom)
      ..lineTo(pts.first.dx, pts.first.dy);
    for (int i = 0; i < pts.length - 1; i++) {
      final cpX = (pts[i].dx + pts[i + 1].dx) / 2;
      fillPath.cubicTo(cpX, pts[i].dy, cpX, pts[i + 1].dy, pts[i + 1].dx, pts[i + 1].dy);
    }
    fillPath
      ..lineTo(pts.last.dx, chartRect.bottom)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(_lp, _tp),
          Offset(_lp, _tp + chartH),
          [lineColor.withValues(alpha: 0.22), lineColor.withValues(alpha: 0.0)],
        ),
    );

    // Line
    final linePath = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 0; i < pts.length - 1; i++) {
      final cpX = (pts[i].dx + pts[i + 1].dx) / 2;
      linePath.cubicTo(cpX, pts[i].dy, cpX, pts[i + 1].dy, pts[i + 1].dx, pts[i + 1].dy);
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = lineColor
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Dots
    final dotFill = Paint()..color = lineColor;
    final dotBg = Paint()..color = bgColor;
    for (final p in pts) {
      canvas.drawCircle(p, 4.5, dotFill);
      canvas.drawCircle(p, 2.5, dotBg);
    }

    canvas.restore(); // release chart clip

    // X labels (drawn outside clip so they appear below chart)
    for (int i = 0; i < n; i++) {
      final x = _lp + chartW * i / (n - 1);
      final lbl = i < labels.length ? labels[i] : '';
      final pb = ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: TextAlign.center))
        ..pushStyle(labelStyle)
        ..addText(lbl);
      final para = pb.build()..layout(const ui.ParagraphConstraints(width: 28));
      canvas.drawParagraph(para, Offset(x - 14, _tp + chartH + 5));
    }
  }

  @override
  bool shouldRepaint(_LineChartPainter old) =>
      old.values != values || old.maxY != maxY || old.labels != labels;
}

// ══════════════════════════════════════════════════════════════════════════════
// Custom Bar Chart
// ══════════════════════════════════════════════════════════════════════════════

class _BarChartWidget extends StatelessWidget {
  final List<double> valuesA;
  final List<double> valuesB;
  final List<String> labels;
  final double maxY;
  final Color colorA;
  final Color colorB;
  final Color gridColor;
  final Color labelColor;

  const _BarChartWidget({
    required this.valuesA,
    required this.valuesB,
    required this.labels,
    required this.maxY,
    required this.colorA,
    required this.colorB,
    required this.gridColor,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: CustomPaint(
        painter: _BarChartPainter(
          valuesA: valuesA,
          valuesB: valuesB,
          labels: labels,
          maxY: maxY,
          colorA: colorA,
          colorB: colorB,
          gridColor: gridColor,
          labelColor: labelColor,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<double> valuesA;
  final List<double> valuesB;
  final List<String> labels;
  final double maxY;
  final Color colorA;
  final Color colorB;
  final Color gridColor;
  final Color labelColor;

  _BarChartPainter({
    required this.valuesA,
    required this.valuesB,
    required this.labels,
    required this.maxY,
    required this.colorA,
    required this.colorB,
    required this.gridColor,
    required this.labelColor,
  });

  static const _lp = 32.0;
  static const _bp = 22.0;
  static const _tp = 6.0;
  static const _rp = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final n = labels.length;
    if (n == 0) return;

    final chartW = size.width - _lp - _rp;
    final chartH = size.height - _bp - _tp;
    final chartRect = Rect.fromLTWH(_lp, _tp, chartW, chartH);
    final safeMaxY = maxY < 1 ? 10.0 : maxY;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.8;

    final labelStyle = ui.TextStyle(fontSize: 9, color: labelColor);
    const gridLines = 4;

    // Grid + Y labels
    for (int i = 0; i <= gridLines; i++) {
      final frac = i / gridLines;
      final y = _tp + chartH * (1 - frac);
      canvas.drawLine(Offset(_lp, y), Offset(_lp + chartW, y), gridPaint);

      final value = (safeMaxY * frac).toInt();
      final pb = ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: TextAlign.right))
        ..pushStyle(labelStyle)
        ..addText('$value');
      final para = pb.build()..layout(ui.ParagraphConstraints(width: _lp - 4));
      canvas.drawParagraph(para, Offset(0, y - para.height / 2));
    }

    // Clip bars to chart area
    canvas.save();
    canvas.clipRect(chartRect);

    final groupW = chartW / n;
    const barW = 7.0;
    const gap = 2.0;
    const radius = Radius.circular(4);

    for (int i = 0; i < n; i++) {
      final groupCenterX = _lp + groupW * i + groupW / 2;
      final aX = groupCenterX - barW - gap / 2;
      final bX = groupCenterX + gap / 2;

      void drawBar(double x, double val, Color color) {
        if (val <= 0) return;
        final barH = (val / safeMaxY).clamp(0.0, 1.0) * chartH;
        final top = _tp + chartH - barH;
        final rect = RRect.fromLTRBR(x, top, x + barW, _tp + chartH, radius);
        canvas.drawRRect(rect, Paint()..color = color);
      }

      drawBar(aX, valuesA[i], colorA);
      drawBar(bX, valuesB[i], colorB);
    }

    canvas.restore();

    // X labels
    for (int i = 0; i < n; i++) {
      final cx = _lp + groupW * i + groupW / 2;
      final lbl = i < labels.length ? labels[i] : '';
      final pb = ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: TextAlign.center))
        ..pushStyle(labelStyle)
        ..addText(lbl);
      final para = pb.build()..layout(const ui.ParagraphConstraints(width: 28));
      canvas.drawParagraph(para, Offset(cx - 14, _tp + chartH + 5));
    }
  }

  @override
  bool shouldRepaint(_BarChartPainter old) =>
      old.valuesA != valuesA ||
      old.valuesB != valuesB ||
      old.maxY != maxY ||
      old.labels != labels;
}

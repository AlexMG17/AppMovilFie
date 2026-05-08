import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
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

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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

  // â”€â”€ Métricas â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  final int totalRegistrados = 250;
  final int totalCapacidad = 250;
  final int aprobados = 218;
  final int pendientes = 19;
  final int rechazados = 13;
  final int ingresaron = 157;
  final int qrGenerados = 218;

  // â”€â”€ Actividad reciente â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  List<_Activity> get _activities => [
    _Activity(
      icon: Icons.login_rounded,
      iconColor: _green,
      title: 'Ana Torres ingresó',
      time: 'Hace 2 min',
    ),
    _Activity(
      icon: Icons.check_circle,
      iconColor: _blue,
      title: 'Luis Cáceres aprobado',
      time: 'Hace 5 min',
    ),
    _Activity(
      icon: Icons.login_rounded,
      iconColor: _green,
      title: 'María Salinas ingresó',
      time: 'Hace 8 min',
    ),
    _Activity(
      icon: Icons.qr_code_2_rounded,
      iconColor: _cyan,
      title: 'QR generado - 3 usuarios',
      time: 'Hace 12 min',
    ),
    _Activity(
      icon: Icons.login_rounded,
      iconColor: _green,
      title: 'Pedro Aguirre ingresó',
      time: 'Hace 15 min',
    ),
  ];

  // â”€â”€ Datos gráfico línea (ingresos por hora) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  final List<FlSpot> _lineSpots = const [
    FlSpot(0, 2),
    FlSpot(1, 8),
    FlSpot(2, 18),
    FlSpot(3, 35),
    FlSpot(4, 55),
    FlSpot(5, 90),
    FlSpot(6, 70),
    FlSpot(7, 25),
  ];
  final List<String> _lineLabels = const [
    '14h',
    '15h',
    '16h',
    '17h',
    '18h',
    '19h',
    '20h',
    '21h',
  ];

  // â”€â”€ Datos gráfico barras (pagos semanales) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  final List<double> _barAprobados = [15, 20, 25, 30, 60, 35, 5];
  final List<double> _barRechazados = [5, 8, 10, 12, 18, 10, 2];
  final List<String> _barDays = [
    'Lun',
    'Mar',
    'Mié',
    'Jue',
    'Vie',
    'Sáb',
    'Dom',
  ];

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
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _realtimeTimer.cancel();
    super.dispose();
  }

  // â”€â”€ Helpers de texto â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  TextStyle _ts(double size, {FontWeight fw = FontWeight.w400, Color? color}) =>
      GoogleFonts.outfit(fontSize: size, fontWeight: fw, color: color ?? _navy);

  void _openAdminTab(int index, Widget fallback) {
    if (widget.onSelectTab != null) {
      widget.onSelectTab!(index);
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => fallback));
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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
                    _buildDonutCard(),
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
      leading: IconButton(
        icon: Icon(Icons.menu_rounded, color: _navy),
        onPressed: () {},
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Panel Administrativo', style: _ts(16, fw: FontWeight.w700)),
          Text('Gala FIE 2026', style: _ts(11, color: _grey)),
        ],
      ),
      actions: [
        // Indicador online
        Container(
          margin: const EdgeInsets.only(right: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _green.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _green.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'En línea',
                style: _ts(10, color: _green, fw: FontWeight.w600),
              ),
            ],
          ),
        ),
        // Avatar
        CircleAvatar(
          radius: 16,
          backgroundColor: _blue.withValues(alpha: 0.15),
          child: Icon(Icons.person_rounded, size: 18, color: _blue),
        ),
        // Logout
        IconButton(
          icon: Icon(Icons.logout_rounded, color: _grey, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
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
                'RF23 - Estadísticas generales - Gala FIE 2026',
                style: _ts(11, color: _grey),
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

  // â”€â”€ Metric Grid â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

  // â”€â”€ Gráfico de línea â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
          const SizedBox(height: 20),
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
                maxX: 7,
                minY: 0,
                maxY: 100,
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

  // â”€â”€ Gráfico de barras â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
              _Legend(color: _green, label: 'Aprobados'),
              const SizedBox(width: 12),
              _Legend(color: _red, label: 'Rechazados'),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 170,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 70,
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

  // â”€â”€ Donut chart â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildDonutCard() {
    return _CardWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Distribución de asistentes',
            style: _ts(15, fw: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              SizedBox(
                width: 130,
                height: 130,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: 38,
                    sections: [
                      PieChartSectionData(
                        value: 157,
                        color: _green,
                        radius: 24,
                        title: '',
                        showTitle: false,
                      ),
                      PieChartSectionData(
                        value: 61,
                        color: _blue,
                        radius: 24,
                        title: '',
                        showTitle: false,
                      ),
                      PieChartSectionData(
                        value: 32,
                        color: _cyan,
                        radius: 24,
                        title: '',
                        showTitle: false,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DonutLegend(
                    color: _green,
                    value: '157',
                    label: 'Ingresaron',
                  ),
                  const SizedBox(height: 14),
                  _DonutLegend(color: _blue, value: '61', label: 'Registrados'),
                  const SizedBox(height: 14),
                  _DonutLegend(color: _cyan, value: '32', label: 'Pendientes'),
                ],
              ),
            ],
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
                subtitle: 'RF21 - RF22',
                onTap: () => _openAdminTab(3, const AttendeesScreen()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickCard(
                icon: Icons.receipt_long_rounded,
                color: _cyan,
                title: 'Comprobantes',
                subtitle: 'Gestión de pagos',
                onTap: () => _openAdminTab(4, const PaymentVouchersScreen()),
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
                subtitle: 'RF25 - RF32 - RF33',
                onTap: () => _openAdminTab(1, const StudentListScreen()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickCard(
                icon: Icons.upload_file_rounded,
                color: const Color(0xFF7C3AED),
                title: 'Importar',
                subtitle: 'RF24 - RF26-RF32',
                onTap: () => _openAdminTab(2, const ImportStudentsScreen()),
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

class _DonutLegend extends StatelessWidget {
  final Color color;
  final String value;
  final String label;
  const _DonutLegend({
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.sentryNavy,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 11,
                color: AppColors.sentryGrey,
              ),
            ),
          ],
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

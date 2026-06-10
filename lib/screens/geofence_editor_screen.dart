import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../theme/app_colors.dart';

class _GeoResult {
  final String name;
  final double lat;
  final double lng;
  const _GeoResult({required this.name, required this.lat, required this.lng});
}

class GeofenceEditorScreen extends StatefulWidget {
  final List<LatLng>? initialPolygon;
  final LatLng initialCenter;

  const GeofenceEditorScreen({
    super.key,
    this.initialPolygon,
    required this.initialCenter,
  });

  @override
  State<GeofenceEditorScreen> createState() => _GeofenceEditorScreenState();
}

class _GeofenceEditorScreenState extends State<GeofenceEditorScreen> {
  final MapController _mapController = MapController();
  final List<LatLng> _points = [];
  LatLng? _userLocation;
  bool _loadingLocation = false;

  // Search
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  List<_GeoResult> _searchResults = [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialPolygon != null && widget.initialPolygon!.isNotEmpty) {
      _points.addAll(widget.initialPolygon!);
    }
    _loadUserLocation();
  }

  @override
  void dispose() {
    _mapController.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadUserLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (mounted) {
        setState(() => _userLocation = LatLng(pos.latitude, pos.longitude));
      }
    } catch (_) {}
  }

  Future<void> _goToMyLocation() async {
    setState(() => _loadingLocation = true);
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final loc = LatLng(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() => _userLocation = loc);
        _mapController.move(loc, 18.0);
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingLocation = false);
  }

  Future<void> _doSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _searching = true;
      _searchResults = [];
    });
    _searchFocus.unfocus();
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': query,
        'format': 'json',
        'limit': '5',
        'addressdetails': '0',
      });
      final client = HttpClient();
      try {
        final request = await client.getUrl(uri);
        request.headers.set('User-Agent', 'SentryApp/1.0 (fie.sentry_app)');
        request.headers.set('Accept-Language', 'es');
        final response = await request.close();
        final body = await response.transform(utf8.decoder).join();
        final data = jsonDecode(body) as List;
        if (mounted) {
          setState(() {
            _searchResults = data
                .map((e) => _GeoResult(
                      name: e['display_name'] as String,
                      lat: double.parse(e['lat'] as String),
                      lng: double.parse(e['lon'] as String),
                    ))
                .toList();
            if (_searchResults.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No se encontraron resultados')),
              );
            }
          });
        }
      } finally {
        client.close();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al buscar. Verifica tu conexión.')),
        );
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _selectResult(_GeoResult result) {
    _mapController.move(LatLng(result.lat, result.lng), 17.0);
    setState(() => _searchResults.clear());
    _searchController.clear();
    _searchFocus.unfocus();
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchResults.clear());
    _searchFocus.unfocus();
  }

  void _onMapTap(TapPosition _, LatLng latlng) {
    // Dismiss search results on map tap
    if (_searchResults.isNotEmpty) {
      setState(() => _searchResults.clear());
      return;
    }
    setState(() => _points.add(latlng));
  }

  void _removePoint(int index) {
    setState(() => _points.removeAt(index));
  }

  void _undo() {
    if (_points.isEmpty) return;
    setState(() => _points.removeLast());
  }

  void _clear() {
    if (_points.isEmpty) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Limpiar zona',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        content:
            Text('¿Eliminar todos los puntos?', style: GoogleFonts.outfit()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _points.clear());
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Limpiar'),
          ),
        ],
      ),
    );
  }

  void _save() {
    if (_points.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Necesitas al menos 3 puntos para definir una zona')),
      );
      return;
    }
    Navigator.pop(context, List<LatLng>.from(_points));
  }

  @override
  Widget build(BuildContext context) {
    final hasEnough = _points.length >= 3;
    final hasResults = _searchResults.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: AppColors.sentryNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Dibujar geocerca',
          style: GoogleFonts.outfit(
              fontWeight: FontWeight.w700, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo_rounded),
            tooltip: 'Deshacer último punto',
            onPressed: _points.isEmpty ? null : _undo,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            tooltip: 'Limpiar todo',
            onPressed: _points.isEmpty ? null : _clear,
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── Mapa ─────────────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _userLocation ?? widget.initialCenter,
              initialZoom: 17.5,
              onTap: _onMapTap,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.fie.sentry_app',
              ),
              if (_points.length >= 3)
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: _points,
                      color: AppColors.sentryCyan.withValues(alpha: 0.25),
                      borderColor: AppColors.sentryBlue,
                      borderStrokeWidth: 2.5,
                    ),
                  ],
                ),
              if (_points.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [..._points, _points.first],
                      color: AppColors.sentryBlue.withValues(alpha: 0.7),
                      strokeWidth: 2.0,
                      pattern: StrokePattern.dashed(segments: [8, 4]),
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (_userLocation != null)
                    Marker(
                      point: _userLocation!,
                      width: 16,
                      height: 16,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.sentryBlue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ..._points.asMap().entries.map(
                        (e) => Marker(
                          point: e.value,
                          width: 32,
                          height: 32,
                          child: GestureDetector(
                            onLongPress: () => _removePoint(e.key),
                            child: Container(
                              decoration: BoxDecoration(
                                color: e.key == 0
                                    ? AppColors.sentryCyan
                                    : AppColors.sentryNavy,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  '${e.key + 1}',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                ],
              ),
            ],
          ),

          // ── Barra de búsqueda + resultados ────────────────────────────────
          Positioned(
            top: 8.h,
            left: 12.w,
            right: 12.w,
            child: Column(
              children: [
                // Barra de búsqueda
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      SizedBox(width: 4.w),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocus,
                          style: GoogleFonts.outfit(
                              fontSize: 14.sp,
                              color: AppColors.sentryNavy),
                          decoration: InputDecoration(
                            hintText: 'Buscar lugar o dirección...',
                            hintStyle: GoogleFonts.outfit(
                                fontSize: 13.sp,
                                color: AppColors.sentryGrey),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 4.w, vertical: 14.h),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: AppColors.sentryBlue,
                              size: 20.sp,
                            ),
                          ),
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _doSearch(),
                        ),
                      ),
                      if (_searching)
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12.w),
                          child: SizedBox(
                            width: 18.w,
                            height: 18.w,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.sentryBlue,
                            ),
                          ),
                        )
                      else if (_searchController.text.isNotEmpty || hasResults)
                        IconButton(
                          icon: Icon(Icons.close_rounded,
                              color: AppColors.sentryGrey, size: 18.sp),
                          onPressed: _clearSearch,
                          tooltip: 'Limpiar búsqueda',
                        )
                      else
                        TextButton(
                          onPressed: _doSearch,
                          child: Text(
                            'Buscar',
                            style: GoogleFonts.outfit(
                                color: AppColors.sentryBlue,
                                fontWeight: FontWeight.w600,
                                fontSize: 13.sp),
                          ),
                        ),
                    ],
                  ),
                ),

                // Resultados
                if (hasResults)
                  Container(
                    margin: EdgeInsets.only(top: 4.h),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.symmetric(vertical: 4.h),
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, _) => Divider(
                          height: 1, indent: 46.w, endIndent: 12.w),
                      itemBuilder: (_, i) {
                        final r = _searchResults[i];
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            Icons.location_on_rounded,
                            color: AppColors.sentryBlue,
                            size: 18.sp,
                          ),
                          title: Text(
                            r.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                                fontSize: 12.sp,
                                color: AppColors.sentryNavy),
                          ),
                          onTap: () => _selectResult(r),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // ── Instrucción (debajo de la barra de búsqueda) ─────────────────
          if (!hasResults)
            Positioned(
              top: 72.h,
              left: 16.w,
              right: 16.w,
              child: Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: AppColors.sentryNavy.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Row(
                  children: [
                    Icon(Icons.touch_app_rounded,
                        color: AppColors.sentryCyan, size: 18.sp),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        _points.isEmpty
                            ? 'Toca el mapa para agregar puntos de la zona'
                            : _points.length < 3
                                ? 'Agrega ${3 - _points.length} punto${3 - _points.length > 1 ? 's' : ''} más para cerrar la zona'
                                : 'Zona con ${_points.length} puntos — mantén presionado un punto para eliminarlo',
                        style: GoogleFonts.outfit(
                            color: Colors.white, fontSize: 12.sp),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Contador de puntos ────────────────────────────────────────────
          if (_points.isNotEmpty)
            Positioned(
              bottom: 160.h,
              right: 16.w,
              child: Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: hasEnough ? AppColors.sentryBlue : Colors.orange,
                  borderRadius: BorderRadius.circular(20.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '${_points.length} pts',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

          // ── Botón "Mi ubicación" ──────────────────────────────────────────
          Positioned(
            bottom: 100.h,
            right: 16.w,
            child: FloatingActionButton.small(
              heroTag: 'myLocation',
              backgroundColor: Colors.white,
              onPressed: _loadingLocation ? null : _goToMyLocation,
              tooltip: 'Centrar en mi ubicación',
              child: _loadingLocation
                  ? SizedBox(
                      width: 18.w,
                      height: 18.w,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.sentryNavy,
                      ),
                    )
                  : Icon(Icons.my_location_rounded,
                      color: AppColors.sentryNavy, size: 20.sp),
            ),
          ),

          // ── Botón Guardar ─────────────────────────────────────────────────
          Positioned(
            bottom: 24.h,
            left: 16.w,
            right: 16.w,
            child: FilledButton.icon(
              onPressed: hasEnough ? _save : null,
              style: FilledButton.styleFrom(
                backgroundColor:
                    hasEnough ? AppColors.sentryBlue : Colors.grey[400],
                minimumSize: Size(double.infinity, 52.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
              ),
              icon: const Icon(Icons.save_rounded, color: Colors.white),
              label: Text(
                hasEnough
                    ? 'Guardar geocerca'
                    : 'Necesitas al menos 3 puntos',
                style: GoogleFonts.outfit(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

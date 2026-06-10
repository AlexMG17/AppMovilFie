import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

enum GeofenceState { adentro, cerca, afuera }

class GeofenceService {
  // ==========================================
  // 1. DIBUJAR EL POLÍGONO DEL EVENTO (MACAJÍ)
  // ==========================================
  // Coordenadas exactas trazadas manualmente sobre el recinto ferial de Macají
  final List<LatLng> eventPolygon = [
    const LatLng(-1.6560055260174005, -78.6749951089342),
    const LatLng(-1.6557045596366962, -78.6747027427223),
    const LatLng(-1.6558334608747622, -78.67455431005503),
    const LatLng(-1.656097063174974, -78.67480476663376),
    const LatLng(-1.656020981465435, -78.67488988280404),
    const LatLng(-1.6560586132791175, -78.67493325931392),
    const LatLng(-1.6560103463875289, -78.67499382274276),
  ];

  final LatLng eventCenter = const LatLng(-1.6558909094711447, -78.67475706289616);
  final double radioCerca = 50.0;

  StreamSubscription<Position>? _positionStreamSubscription;
  Timer? _exitTimer;
  int _secondsRemaining = 60;
  bool _isTimerRunning = false;

  final Function(
    GeofenceState estado,
    double distancia,
    LatLng ubicacionUsuario,
  )
  onStateChanged;
  final Function(int segundosRestantes)? onTimerTick;
  final Function() onTimerExpired;

  GeofenceService({
    required this.onStateChanged,
    this.onTimerTick,
    required this.onTimerExpired,
  });

  void startMonitoring() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    late LocationSettings locationSettings;

    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
        intervalDuration: const Duration(seconds: 5),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.otherNavigation,
        distanceFilter: 5,
        pauseLocationUpdatesAutomatically: false,
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      );
    }

    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            _procesarUbicacion(position);
          },
        );
  }

  Future<void> forceUpdate() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      _procesarUbicacion(position);
    } catch (e) {
      debugPrint('GeofenceService.forceUpdate error: $e');
    }
  }

  void _procesarUbicacion(Position position) {
    LatLng userLoc = LatLng(position.latitude, position.longitude);

    double distanceInMeters = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      eventCenter.latitude,
      eventCenter.longitude,
    );

    bool isInsidePolygon = _isPointInPolygon(userLoc, eventPolygon);

    if (isInsidePolygon) {
      _cancelarTimer();
      onStateChanged(GeofenceState.adentro, distanceInMeters, userLoc);
    } else if (distanceInMeters <= radioCerca) {
      _cancelarTimer();
      onStateChanged(GeofenceState.cerca, distanceInMeters, userLoc);
    } else {
      onStateChanged(GeofenceState.afuera, distanceInMeters, userLoc);
      _iniciarTimerDeSalida();
    }
  }

  bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    bool isInside = false;
    int j = polygon.length - 1;
    for (int i = 0; i < polygon.length; i++) {
      if ((polygon[i].latitude > point.latitude) !=
              (polygon[j].latitude > point.latitude) &&
          (point.longitude <
              (polygon[j].longitude - polygon[i].longitude) *
                      (point.latitude - polygon[i].latitude) /
                      (polygon[j].latitude - polygon[i].latitude) +
                  polygon[i].longitude)) {
        isInside = !isInside;
      }
      j = i;
    }
    return isInside;
  }

  void _iniciarTimerDeSalida() {
    if (_isTimerRunning) return;
    _isTimerRunning = true;
    _secondsRemaining = 60;

    _exitTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        _secondsRemaining--;
        onTimerTick?.call(_secondsRemaining);
      } else {
        _exitTimer?.cancel();
        _isTimerRunning = false;
        onTimerExpired();
      }
    });
  }

  void _cancelarTimer() {
    if (_exitTimer != null) {
      _exitTimer!.cancel();
      _isTimerRunning = false;
    }
  }

  void dispose() {
    _positionStreamSubscription?.cancel();
    _exitTimer?.cancel();
  }
}

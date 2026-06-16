import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

enum GeofenceState { adentro, cerca, afuera }

// Polígono por defecto (recinto Macají) usado como fallback si el evento no tiene polígono guardado.
const List<LatLng> _defaultPolygon = [
  LatLng(-1.656042725316968, -78.67500315531241),
  LatLng(-1.6559033087010442, -78.67489854917075),
  LatLng(-1.6558832005344732, -78.67492671236273),
  LatLng(-1.6558282382114882, -78.67487709150068),
  LatLng(-1.6558456652896698, -78.67485295162182),
  LatLng(-1.655694183758768, -78.67470543014),
  LatLng(-1.6558322598449244, -78.67454852092752),
  LatLng(-1.6561231579755422, -78.67481271849041),
  LatLng(-1.6560601523932668, -78.67489989027513),
  LatLng(-1.6561030498111975, -78.67494548782406),
  LatLng(-1.656042725316968, -78.67500315531241),
];

class GeofenceService {
  final List<LatLng> eventPolygon;
  final LatLng eventCenter;
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
    List<LatLng>? polygon,
    LatLng? center,
    required this.onStateChanged,
    this.onTimerTick,
    required this.onTimerExpired,
  }) : eventPolygon = polygon ?? _defaultPolygon,
       eventCenter =
           center ?? const LatLng(-1.6558885627122442, -78.67476846204586);

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

import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

enum GeofenceState { adentro, cerca, afuera }

class GeofenceService {
  // ==========================================
  // 1. DIBUJAR EL POLÍGONO DEL EVENTO (MACAJÍ)
  // ==========================================
  // Coordenadas exactas obtenidas manualmente
  final List<LatLng> eventPolygon = [
    const LatLng(-1.6673813488288851, -78.66819099947568),
    const LatLng(-1.6676504776044883, -78.6680591826948),
    const LatLng(-1.6678018625245785, -78.6679554120375),
    const LatLng(-1.6679854868101855, -78.6677646983971),
    const LatLng(-1.6683269146604747, -78.66738210801138),
    const LatLng(-1.669393070810027, -78.66617168417751),
    const LatLng(-1.6699063889411598, -78.66552893569786),
    const LatLng(-1.670914258346672, -78.6663406541204),
    const LatLng(-1.6710158180022696, -78.6664753883537),
    const LatLng(-1.671057766550577, -78.66665319333924),
    const LatLng(-1.671069909550831, -78.66695137563836),
    const LatLng(-1.6710986111884545, -78.66701763836589),
    const LatLng(-1.6711350401894456, -78.66709384050255),
    const LatLng(-1.671202593580768, -78.6672874728221),
    const LatLng(-1.6712662563038196, -78.66771014158061),
    const LatLng(-1.6706623948160764, -78.66818112220292),
    const LatLng(-1.6701123612474726, -78.66849537488189),
    const LatLng(-1.6699398104672376, -78.66948867582258),
    const LatLng(-1.6691393485157962, -78.66918079915217),
    const LatLng(-1.6683343958391905, -78.66908995804063),
    const LatLng(-1.668115978730337, -78.66877569688279),
    const LatLng(-1.6673797411533886, -78.6681938227346),
  ];

  // Centro aproximado de Macají calculado matemáticamente (para centrar el mapa)
  final LatLng eventCenter = const LatLng(-1.669322, -78.667508);

  // Radio de advertencia (300 metros desde el centro)
  final double radioCerca = 300.0;

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
  final Function(int segundosRestantes) onTimerTick;
  final Function() onTimerExpired;

  GeofenceService({
    required this.onStateChanged,
    required this.onTimerTick,
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

    final LocationSettings locationSettings = const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 2,
    );

    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            _procesarUbicacion(position);
          },
        );
  }

  // BOTÓN MANUAL: Permite forzar la lectura del GPS de inmediato
  Future<void> forceUpdate() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      _procesarUbicacion(position);
    } catch (e) {
      print("Error obteniendo ubicación manual: $e");
    }
  }

  void _procesarUbicacion(Position position) {
    LatLng userLoc = LatLng(position.latitude, position.longitude);

    // Distancia al centro (solo para saber si está "Cerca")
    double distanceInMeters = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      eventCenter.latitude,
      eventCenter.longitude,
    );

    // Evaluamos con el algoritmo de Ray-Casting si está dentro de tu polígono de Macají
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

  // ==========================================
  // ALGORITMO RAY-CASTING (¿Punto en Polígono?)
  // ==========================================
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
        onTimerTick(_secondsRemaining);
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

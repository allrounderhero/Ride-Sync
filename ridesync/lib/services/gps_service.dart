import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../models/sensor_data.dart';

/// GPS event packet emitted whenever a GNSS fix is validated
class GpsFix {
  final double speedKmh;
  final double latitude;
  final double longitude;
  final double accuracy;
  final GpsAccuracyTier tier;
  final double distanceDeltaMeters;
  final double speedDerivativeMs2; // dv/dt in m/s²
  final DateTime timestamp;

  const GpsFix({
    required this.speedKmh,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.tier,
    required this.distanceDeltaMeters,
    required this.speedDerivativeMs2,
    required this.timestamp,
  });
}

/// Service handling device GNSS hardware, permissions, accuracy tiering,
/// speed validation, and stationary drift filtering.
class GpsService {
  StreamSubscription<Position>? _positionSubscription;
  final _gpsStreamController = StreamController<GpsFix>.broadcast();

  Stream<GpsFix> get gpsStream => _gpsStreamController.stream;

  Position? _previousPosition;
  double _previousSpeedKmh = 0.0;
  DateTime? _previousTimestamp;

  GpsAccuracyTier _currentTier = GpsAccuracyTier.searching;
  GpsAccuracyTier get currentTier => _currentTier;

  bool _isRunning = false;
  bool get isRunning => _isRunning;

  /// Check location services & permissions
  Future<bool> checkAndRequestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _currentTier = GpsAccuracyTier.unavailable;
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _currentTier = GpsAccuracyTier.unavailable;
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _currentTier = GpsAccuracyTier.unavailable;
      return false;
    }

    return true;
  }

  /// Categorize GNSS accuracy into user-defined tiers
  static GpsAccuracyTier classifyAccuracy(double accuracyMeters) {
    if (accuracyMeters <= 0.0) return GpsAccuracyTier.searching;
    if (accuracyMeters < 10.0) return GpsAccuracyTier.good;
    if (accuracyMeters <= 20.0) return GpsAccuracyTier.acceptable;
    if (accuracyMeters <= 50.0) return GpsAccuracyTier.weak;
    return GpsAccuracyTier.poor;
  }

  /// Start listening to GNSS hardware
  Future<bool> start() async {
    if (_isRunning) return true;

    final hasPermission = await checkAndRequestPermission();
    if (!hasPermission) return false;

    _isRunning = true;
    _currentTier = GpsAccuracyTier.searching;
    _previousPosition = null;
    _previousSpeedKmh = 0.0;
    _previousTimestamp = null;

    // High accuracy settings with 500ms / 1 meter resolution
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 1,
    );

    try {
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        _onPositionUpdate,
        onError: (error) {
          _currentTier = GpsAccuracyTier.unavailable;
        },
      );
      return true;
    } catch (e) {
      _currentTier = GpsAccuracyTier.unavailable;
      return false;
    }
  }

  void _onPositionUpdate(Position position) {
    final now = DateTime.now();
    final tier = classifyAccuracy(position.accuracy);
    _currentTier = tier;

    // Extract platform speed (m/s -> km/h)
    double speedKmh = 0.0;
    if (position.speed >= 0.0) {
      speedKmh = position.speed * 3.6;
    }

    // Safeguard: zero out tiny GPS noise when vehicle is practically stopped
    if (speedKmh < 1.0) {
      speedKmh = 0.0;
    }

    // Distance calculation with stationary drift protection
    double distanceDelta = 0.0;
    if (_previousPosition != null) {
      final double rawDistance = Geolocator.distanceBetween(
        _previousPosition!.latitude,
        _previousPosition!.longitude,
        position.latitude,
        position.longitude,
      );

      // Only accumulate distance if:
      // 1. Accuracy is not POOR (>50m)
      // 2. Either speed is distinctly non-zero or the displacement exceeds noise threshold
      if (tier != GpsAccuracyTier.poor) {
        if (speedKmh > 1.2 || rawDistance > 3.0) {
          distanceDelta = rawDistance;
        }
      }
    }

    // Speed derivative: acceleration in m/s² (dv/dt)
    double speedDerivative = 0.0;
    if (_previousTimestamp != null) {
      final dt = now.difference(_previousTimestamp!).inMilliseconds / 1000.0;
      if (dt > 0.1 && dt < 3.0) {
        // (km/h -> m/s) / dt
        final dvMs = (speedKmh - _previousSpeedKmh) / 3.6;
        speedDerivative = (dvMs / dt).clamp(-8.0, 8.0);
      }
    }

    _previousPosition = position;
    _previousSpeedKmh = speedKmh;
    _previousTimestamp = now;

    final fix = GpsFix(
      speedKmh: speedKmh,
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      tier: tier,
      distanceDeltaMeters: distanceDelta,
      speedDerivativeMs2: speedDerivative,
      timestamp: now,
    );

    if (!_gpsStreamController.isClosed) {
      _gpsStreamController.add(fix);
    }
  }

  /// Stop listening to GNSS hardware
  void stop() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _isRunning = false;
  }

  void dispose() {
    stop();
    _gpsStreamController.close();
  }
}

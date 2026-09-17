import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/sensor_data.dart';
import 'gps_service.dart';
import 'motion_service.dart';
import 'mount_calibration.dart';

/// Pre-flight sensor readiness assessment
class SensorReadiness {
  final bool hasLocationPermission;
  final bool isGpsReady;
  final GpsAccuracyTier gpsTier;
  final bool isAccelerometerActive;
  final bool isGyroscopeActive;
  final bool isMountCalibrated;

  const SensorReadiness({
    required this.hasLocationPermission,
    required this.isGpsReady,
    required this.gpsTier,
    required this.isAccelerometerActive,
    required this.isGyroscopeActive,
    required this.isMountCalibrated,
  });

  bool get canRide => hasLocationPermission && isGpsReady;
  bool get isFullyReady => canRide && isMountCalibrated && isAccelerometerActive;
}

/// The core sensor fusion and telemetry engine for RideSync.
/// Integrates GPS, IMU, mount calibration, filtering, and sensor fusion.
class SensorEngine {
  final GpsService _gpsService = GpsService();
  final MotionService _motionService = MotionService();
  final MountCalibration _mountCalibration = MountCalibration();

  StreamSubscription<GpsFix>? _gpsSub;
  StreamSubscription<MotionReading>? _motionSub;

  final _sensorDataController = StreamController<SensorData>.broadcast();
  Stream<SensorData> get sensorStream => _sensorDataController.stream;

  GpsService get gpsService => _gpsService;
  MotionService get motionService => _motionService;
  MountCalibration get mountCalibration => _mountCalibration;

  bool _isRunning = false;
  bool get isRunning => _isRunning;

  // Telemetry caches
  GpsFix? _latestGpsFix;
  MotionReading _latestMotion = MotionReading.zero();

  // Filter states
  double _filteredForwardAcc = 0.0;
  double _filteredLateralAcc = 0.0;
  double _filteredVerticalAcc = 0.0;
  double _fusedLongitudinalAcc = 0.0;

  // LPF coefficient (0.2 = responsive smoothing of motorcycle vibration)
  static const double _lpfAlpha = 0.20;

  SensorData _currentData = SensorData.zero();
  SensorData get currentData => _currentData;

  /// Initialize and load saved calibration parameters
  Future<void> initialize() async {
    await _mountCalibration.loadSavedCalibration();
  }

  /// Check overall sensor availability
  Future<SensorReadiness> checkReadiness() async {
    final hasPerm = await _gpsService.checkAndRequestPermission();
    return SensorReadiness(
      hasLocationPermission: hasPerm,
      isGpsReady: _gpsService.currentTier.isReady,
      gpsTier: _gpsService.currentTier,
      isAccelerometerActive: _motionService.isRunning,
      isGyroscopeActive: _motionService.isRunning,
      isMountCalibrated: _mountCalibration.isCalibrated,
    );
  }

  /// Start hardware telemetry pipeline
  Future<bool> start() async {
    if (_isRunning) return true;
    _isRunning = true;

    // Reset filters
    _filteredForwardAcc = 0.0;
    _filteredLateralAcc = 0.0;
    _filteredVerticalAcc = 0.0;
    _fusedLongitudinalAcc = 0.0;

    _motionService.start();
    _motionSub = _motionService.motionStream.listen(_onMotionUpdate);

    final gpsStarted = await _gpsService.start();
    if (gpsStarted) {
      _gpsSub = _gpsService.gpsStream.listen(_onGpsUpdate);
    } else {
      debugPrint('GPS failed to start or permission denied');
    }

    return true;
  }

  void _onMotionUpdate(MotionReading motion) {
    _latestMotion = motion;

    // 1. Transform raw IMU into motorcycle frame
    final bikeForces = _mountCalibration.transform(
      motion.accelX,
      motion.accelY,
      motion.accelZ,
    );

    // 2. Outlier rejection: clamp physical impossibilities (> 2.5G)
    final clampedForward = bikeForces.forward.clamp(-25.0, 25.0);
    final clampedLateral = bikeForces.lateral.clamp(-25.0, 25.0);
    final clampedVertical = bikeForces.vertical.clamp(-25.0, 25.0);

    // 3. Low-Pass Filter (LPF) for engine vibration suppression
    _filteredForwardAcc =
        _lpfAlpha * clampedForward + (1.0 - _lpfAlpha) * _filteredForwardAcc;
    _filteredLateralAcc =
        _lpfAlpha * clampedLateral + (1.0 - _lpfAlpha) * _filteredLateralAcc;
    _filteredVerticalAcc =
        _lpfAlpha * clampedVertical + (1.0 - _lpfAlpha) * _filteredVerticalAcc;

    _fuseAndEmit();
  }

  void _onGpsUpdate(GpsFix fix) {
    _latestGpsFix = fix;
    _fuseAndEmit();
  }

  void _fuseAndEmit() {
    final now = DateTime.now();

    final speedKmh = _latestGpsFix?.speedKmh ?? 0.0;
    final lat = _latestGpsFix?.latitude ?? 0.0;
    final lng = _latestGpsFix?.longitude ?? 0.0;
    final accuracy = _latestGpsFix?.accuracy ?? 0.0;
    final tier = _latestGpsFix?.tier ?? _gpsService.currentTier;
    final gpsSpeedDerivative = _latestGpsFix?.speedDerivativeMs2 ?? 0.0;

    // Stationarity check: when stopped, force acceleration to zero
    if (speedKmh < 0.8 && _filteredForwardAcc.abs() < 0.35) {
      _fusedLongitudinalAcc = 0.0;
    } else {
      // 4. Complementary Fusion:
      // High-frequency responsive IMU + low-frequency drift-free GNSS velocity derivative
      if (tier == GpsAccuracyTier.good || tier == GpsAccuracyTier.acceptable) {
        _fusedLongitudinalAcc =
            0.80 * _filteredForwardAcc + 0.20 * gpsSpeedDerivative;
      } else {
        // Fallback to pure calibrated IMU if GPS accuracy is degraded
        _fusedLongitudinalAcc = _filteredForwardAcc;
      }
    }

    _fusedLongitudinalAcc = _fusedLongitudinalAcc.clamp(-6.0, 6.0);

    _currentData = SensorData(
      speedKmh: speedKmh,
      latitude: lat,
      longitude: lng,
      gpsAccuracy: accuracy,
      gpsTier: tier,
      rawAccelerationX: _latestMotion.accelX,
      rawAccelerationY: _latestMotion.accelY,
      rawAccelerationZ: _latestMotion.accelZ,
      calibratedAccelerationX: _filteredLateralAcc,
      calibratedAccelerationY: _filteredForwardAcc,
      calibratedAccelerationZ: _filteredVerticalAcc,
      longitudinalAcceleration: _fusedLongitudinalAcc,
      lateralAcceleration: _filteredLateralAcc,
      gyroX: _latestMotion.gyroX,
      gyroY: _latestMotion.gyroY,
      gyroZ: _latestMotion.gyroZ,
      isCalibrated: _mountCalibration.isCalibrated,
      timestamp: now,
    );

    if (!_sensorDataController.isClosed) {
      _sensorDataController.add(_currentData);
    }
  }

  /// Stop hardware telemetry pipeline
  void stop() {
    _gpsSub?.cancel();
    _gpsSub = null;
    _motionSub?.cancel();
    _motionSub = null;

    _gpsService.stop();
    _motionService.stop();
    _isRunning = false;
  }

  void dispose() {
    stop();
    _gpsService.dispose();
    _motionService.dispose();
    _sensorDataController.close();
  }
}

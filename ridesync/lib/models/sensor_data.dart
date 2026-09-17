/// Tiered GPS accuracy classification
enum GpsAccuracyTier {
  good, // < 10 m
  acceptable, // 10 - 20 m
  weak, // 20 - 50 m
  poor, // > 50 m
  searching, // Acquisition in progress
  unavailable, // Disabled or no permission
}

extension GpsAccuracyTierExtension on GpsAccuracyTier {
  String get label {
    switch (this) {
      case GpsAccuracyTier.good:
        return 'GOOD';
      case GpsAccuracyTier.acceptable:
        return 'ACCEPTABLE';
      case GpsAccuracyTier.weak:
        return 'WEAK';
      case GpsAccuracyTier.poor:
        return 'POOR';
      case GpsAccuracyTier.searching:
        return 'SEARCHING';
      case GpsAccuracyTier.unavailable:
        return 'UNAVAILABLE';
    }
  }

  bool get isReady =>
      this == GpsAccuracyTier.good || this == GpsAccuracyTier.acceptable;
}

/// Unified telemetry packet emitted by SensorEngine and SimulatorService.
/// Retains raw, calibrated, and fused signals for robust analysis and debugging.
class SensorData {
  /// GPS validated speed in km/h
  final double speedKmh;

  /// GPS Coordinates
  final double latitude;
  final double longitude;

  /// GPS Horizontal accuracy in meters
  final double gpsAccuracy;

  /// Categorized GPS health tier
  final GpsAccuracyTier gpsTier;

  /// Raw Accelerometer readings directly from phone sensor (m/s²)
  final double rawAccelerationX;
  final double rawAccelerationY;
  final double rawAccelerationZ;

  /// Transformed forces aligned to Motorcycle coordinate frame (m/s²):
  /// X = Lateral (Right/Left)
  /// Y = Longitudinal (Forward/Braking)
  /// Z = Vertical (Road bumps / Normal)
  final double calibratedAccelerationX;
  final double calibratedAccelerationY;
  final double calibratedAccelerationZ;

  /// Filtered and fused forward acceleration (m/s²) - Positive is throttle, negative is braking
  final double longitudinalAcceleration;

  /// Filtered lateral acceleration (m/s²)
  final double lateralAcceleration;

  /// Raw Gyroscope readings (rad/s)
  final double gyroX;
  final double gyroY;
  final double gyroZ;

  /// Whether mount calibration matrix was applied
  final bool isCalibrated;

  /// High precision measurement timestamp
  final DateTime timestamp;

  const SensorData({
    required this.speedKmh,
    required this.latitude,
    required this.longitude,
    required this.gpsAccuracy,
    required this.gpsTier,
    required this.rawAccelerationX,
    required this.rawAccelerationY,
    required this.rawAccelerationZ,
    required this.calibratedAccelerationX,
    required this.calibratedAccelerationY,
    required this.calibratedAccelerationZ,
    required this.longitudinalAcceleration,
    required this.lateralAcceleration,
    required this.gyroX,
    required this.gyroY,
    required this.gyroZ,
    required this.isCalibrated,
    required this.timestamp,
  });

  /// Factory for initial / resting state
  factory SensorData.zero() {
    return SensorData(
      speedKmh: 0.0,
      latitude: 0.0,
      longitude: 0.0,
      gpsAccuracy: 0.0,
      gpsTier: GpsAccuracyTier.searching,
      rawAccelerationX: 0.0,
      rawAccelerationY: 0.0,
      rawAccelerationZ: 9.81,
      calibratedAccelerationX: 0.0,
      calibratedAccelerationY: 0.0,
      calibratedAccelerationZ: 0.0,
      longitudinalAcceleration: 0.0,
      lateralAcceleration: 0.0,
      gyroX: 0.0,
      gyroY: 0.0,
      gyroZ: 0.0,
      isCalibrated: false,
      timestamp: DateTime.now(),
    );
  }

  /// Copy with modifications
  SensorData copyWith({
    double? speedKmh,
    double? latitude,
    double? longitude,
    double? gpsAccuracy,
    GpsAccuracyTier? gpsTier,
    double? rawAccelerationX,
    double? rawAccelerationY,
    double? rawAccelerationZ,
    double? calibratedAccelerationX,
    double? calibratedAccelerationY,
    double? calibratedAccelerationZ,
    double? longitudinalAcceleration,
    double? lateralAcceleration,
    double? gyroX,
    double? gyroY,
    double? gyroZ,
    bool? isCalibrated,
    DateTime? timestamp,
  }) {
    return SensorData(
      speedKmh: speedKmh ?? this.speedKmh,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      gpsAccuracy: gpsAccuracy ?? this.gpsAccuracy,
      gpsTier: gpsTier ?? this.gpsTier,
      rawAccelerationX: rawAccelerationX ?? this.rawAccelerationX,
      rawAccelerationY: rawAccelerationY ?? this.rawAccelerationY,
      rawAccelerationZ: rawAccelerationZ ?? this.rawAccelerationZ,
      calibratedAccelerationX:
          calibratedAccelerationX ?? this.calibratedAccelerationX,
      calibratedAccelerationY:
          calibratedAccelerationY ?? this.calibratedAccelerationY,
      calibratedAccelerationZ:
          calibratedAccelerationZ ?? this.calibratedAccelerationZ,
      longitudinalAcceleration:
          longitudinalAcceleration ?? this.longitudinalAcceleration,
      lateralAcceleration: lateralAcceleration ?? this.lateralAcceleration,
      gyroX: gyroX ?? this.gyroX,
      gyroY: gyroY ?? this.gyroY,
      gyroZ: gyroZ ?? this.gyroZ,
      isCalibrated: isCalibrated ?? this.isCalibrated,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';

/// Raw motion readings package from device IMU
class MotionReading {
  final double accelX;
  final double accelY;
  final double accelZ;
  final double gyroX;
  final double gyroY;
  final double gyroZ;
  final DateTime timestamp;

  const MotionReading({
    required this.accelX,
    required this.accelY,
    required this.accelZ,
    required this.gyroX,
    required this.gyroY,
    required this.gyroZ,
    required this.timestamp,
  });

  factory MotionReading.zero() {
    return MotionReading(
      accelX: 0.0,
      accelY: 0.0,
      accelZ: 9.81,
      gyroX: 0.0,
      gyroY: 0.0,
      gyroZ: 0.0,
      timestamp: DateTime.now(),
    );
  }
}

/// Service handling raw accelerometer and gyroscope event subscriptions
class MotionService {
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;

  final _motionStreamController = StreamController<MotionReading>.broadcast();
  Stream<MotionReading> get motionStream => _motionStreamController.stream;

  double _latestAx = 0.0;
  double _latestAy = 0.0;
  double _latestAz = 9.81;

  double _latestGx = 0.0;
  double _latestGy = 0.0;
  double _latestGz = 0.0;

  bool _isRunning = false;
  bool get isRunning => _isRunning;

  MotionReading _latestReading = MotionReading.zero();
  MotionReading get latestReading => _latestReading;

  void start() {
    if (_isRunning) return;
    _isRunning = true;

    try {
      _accelSub = accelerometerEventStream().listen(
        (AccelerometerEvent event) {
          _latestAx = event.x;
          _latestAy = event.y;
          _latestAz = event.z;
          _emitReading();
        },
        onError: (err) {
          // IMU unavailable (e.g. desktop environment)
        },
      );

      _gyroSub = gyroscopeEventStream().listen(
        (GyroscopeEvent event) {
          _latestGx = event.x;
          _latestGy = event.y;
          _latestGz = event.z;
        },
        onError: (err) {
          // Gyro unavailable
        },
      );
    } catch (e) {
      _isRunning = false;
    }
  }

  void _emitReading() {
    _latestReading = MotionReading(
      accelX: _latestAx,
      accelY: _latestAy,
      accelZ: _latestAz,
      gyroX: _latestGx,
      gyroY: _latestGy,
      gyroZ: _latestGz,
      timestamp: DateTime.now(),
    );

    if (!_motionStreamController.isClosed) {
      _motionStreamController.add(_latestReading);
    }
  }

  void stop() {
    _accelSub?.cancel();
    _accelSub = null;
    _gyroSub?.cancel();
    _gyroSub = null;
    _isRunning = false;
  }

  void dispose() {
    stop();
    _motionStreamController.close();
  }
}

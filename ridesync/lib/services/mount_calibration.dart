import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

/// Mount orientation preset to establish the forward reference axis
enum MountOrientationPreset {
  portraitTopForward, // Phone in portrait, top of phone points forward (Most common)
  landscapeTopRight, // Phone landscape, top points right
  landscapeTopLeft, // Phone landscape, top points left
  flatPortrait, // Phone mounted flat on tank, top forward
}

/// Transformed 3-axis forces in the motorcycle's coordinate frame
class BikeFrameForces {
  final double forward; // Longitudinal (+ Throttle, - Braking)
  final double lateral; // Lateral (+ Right, - Left)
  final double vertical; // Vertical (+ Bump/Up, compensated for gravity)

  const BikeFrameForces({
    required this.forward,
    required this.lateral,
    required this.vertical,
  });
}

/// Manages stationary two-stage mount calibration:
/// 1. Gravity vector capture (Vertical axis)
/// 2. Forward axis reference orthogonalization (Motorcycle travel axis)
class MountCalibration {
  static const String _prefKey = 'ridesync_mount_calibration';

  // Orthonormal basis vectors in phone coordinate system
  List<double> _forwardAxis = [0.0, 1.0, 0.0]; // f_hat
  List<double> _lateralAxis = [1.0, 0.0, 0.0]; // r_hat
  List<double> _verticalAxis = [0.0, 0.0, 1.0]; // u_hat
  double _gravityMagnitude = 9.80665;
  bool _isCalibrated = false;

  MountOrientationPreset _selectedPreset =
      MountOrientationPreset.portraitTopForward;

  bool get isCalibrated => _isCalibrated;
  MountOrientationPreset get selectedPreset => _selectedPreset;
  List<double> get forwardAxis => List.unmodifiable(_forwardAxis);
  List<double> get verticalAxis => List.unmodifiable(_verticalAxis);
  double get gravityMagnitude => _gravityMagnitude;

  /// Load persisted calibration parameters from SharedPreferences
  Future<void> loadSavedCalibration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_prefKey);
      if (jsonStr != null) {
        final Map<String, dynamic> data = jsonDecode(jsonStr);
        _forwardAxis = List<double>.from(data['forward']);
        _lateralAxis = List<double>.from(data['lateral']);
        _verticalAxis = List<double>.from(data['vertical']);
        _gravityMagnitude = (data['gravity'] as num).toDouble();
        _isCalibrated = true;
      }
    } catch (_) {
      // Use defaults if corrupt or uninitialized
    }
  }

  /// Perform two-stage calibration using averaged stationary accelerometer readings
  Future<bool> calibrate({
    required double avgX,
    required double avgY,
    required double avgZ,
    MountOrientationPreset preset = MountOrientationPreset.portraitTopForward,
  }) async {
    _selectedPreset = preset;

    // 1. Calculate gravity magnitude
    final mag = sqrt(avgX * avgX + avgY * avgY + avgZ * avgZ);
    if (mag < 6.0 || mag > 14.0) {
      // Accelerometer reading is abnormal or phone was shaking violently
      return false;
    }
    _gravityMagnitude = mag;

    // Unit vertical vector (opposing gravity)
    final ux = avgX / mag;
    final uy = avgY / mag;
    final uz = avgZ / mag;
    _verticalAxis = [ux, uy, uz];

    // 2. Determine raw forward reference vector based on mount preset
    double refX = 0.0;
    double refY = 1.0;
    double refZ = 0.0;

    switch (preset) {
      case MountOrientationPreset.portraitTopForward:
      case MountOrientationPreset.flatPortrait:
        refX = 0.0;
        refY = 1.0;
        refZ = 0.0;
        break;
      case MountOrientationPreset.landscapeTopRight:
        refX = 1.0;
        refY = 0.0;
        refZ = 0.0;
        break;
      case MountOrientationPreset.landscapeTopLeft:
        refX = -1.0;
        refY = 0.0;
        refZ = 0.0;
        break;
    }

    // Gram-Schmidt orthogonalization:
    // f_ortho = ref - (ref . u) * u
    final dot = refX * ux + refY * uy + refZ * uz;
    double fx = refX - dot * ux;
    double fy = refY - dot * uy;
    double fz = refZ - dot * uz;

    final fMag = sqrt(fx * fx + fy * fy + fz * fz);
    if (fMag < 0.01) {
      // Reference is parallel to vertical (e.g. phone lying flat facing sky)
      // Pick alternative orthogonal reference
      fx = 0.0;
      fy = 1.0;
      fz = 0.0;
    } else {
      fx /= fMag;
      fy /= fMag;
      fz /= fMag;
    }
    _forwardAxis = [fx, fy, fz];

    // Lateral axis = forward x vertical (Right-handed frame)
    final rx = fy * uz - fz * uy;
    final ry = fz * ux - fx * uz;
    final rz = fx * uy - fy * ux;
    final rMag = sqrt(rx * rx + ry * ry + rz * rz);
    _lateralAxis = [rx / rMag, ry / rMag, rz / rMag];

    _isCalibrated = true;

    // Save to SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefKey,
        jsonEncode({
          'forward': _forwardAxis,
          'lateral': _lateralAxis,
          'vertical': _verticalAxis,
          'gravity': _gravityMagnitude,
          'preset': preset.index,
        }),
      );
    } catch (_) {}

    return true;
  }

  /// Transform phone-coordinate accelerometer readings into the motorcycle frame
  BikeFrameForces transform(double rawX, double rawY, double rawZ) {
    if (!_isCalibrated) {
      // Default: phone mounted portrait, forward is +Y, vertical is +Z
      return BikeFrameForces(
        forward: rawY,
        lateral: rawX,
        vertical: rawZ - 9.81,
      );
    }

    // Dot products with unit vectors
    final forward = rawX * _forwardAxis[0] +
        rawY * _forwardAxis[1] +
        rawZ * _forwardAxis[2];

    final lateral = rawX * _lateralAxis[0] +
        rawY * _lateralAxis[1] +
        rawZ * _lateralAxis[2];

    final verticalRaw = rawX * _verticalAxis[0] +
        rawY * _verticalAxis[1] +
        rawZ * _verticalAxis[2];

    // Compensate 1G gravity along vertical axis
    final verticalCompensated = verticalRaw - _gravityMagnitude;

    return BikeFrameForces(
      forward: forward,
      lateral: lateral,
      vertical: verticalCompensated,
    );
  }

  /// Reset calibration to default uncalibrated state
  Future<void> reset() async {
    _isCalibrated = false;
    _forwardAxis = [0.0, 1.0, 0.0];
    _lateralAxis = [1.0, 0.0, 0.0];
    _verticalAxis = [0.0, 0.0, 1.0];
    _gravityMagnitude = 9.80665;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKey);
    } catch (_) {}
  }
}

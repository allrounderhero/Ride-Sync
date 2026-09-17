import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ridesync/main.dart';
import 'package:ridesync/models/sensor_data.dart';
import 'package:ridesync/services/gps_service.dart';
import 'package:ridesync/services/mount_calibration.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('RideSync dashboard smoke test', (WidgetTester tester) async {
    // Set realistic motorcycle landscape cockpit resolution (1024x600)
    tester.view.physicalSize = const Size(1024, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const RideSyncApp());
    await tester.pump(const Duration(milliseconds: 200));

    // Verify key UI elements are displayed
    expect(find.text('RideSync'), findsOneWidget);
    expect(find.text('RIDE DATA'), findsOneWidget);
    expect(find.text('START RIDE'), findsOneWidget);
    expect(find.text('SIMULATOR'), findsOneWidget);
    expect(find.text('SENSORS'), findsOneWidget);
    expect(find.text('CALIBRATE'), findsOneWidget);
    expect(find.text('DEBUG'), findsOneWidget);
  });

  test('GPS tiered accuracy classification', () {
    expect(GpsService.classifyAccuracy(4.5), GpsAccuracyTier.good);
    expect(GpsService.classifyAccuracy(15.0), GpsAccuracyTier.acceptable);
    expect(GpsService.classifyAccuracy(35.0), GpsAccuracyTier.weak);
    expect(GpsService.classifyAccuracy(65.0), GpsAccuracyTier.poor);
  });

  test('MountCalibration two-stage transform and gravity compensation', () async {
    SharedPreferences.setMockInitialValues({});
    final cal = MountCalibration();
    // Phone mounted upright portrait: gravity along -Z (approx 9.81 m/s²)
    final success = await cal.calibrate(
      avgX: 0.0,
      avgY: 0.0,
      avgZ: 9.81,
      preset: MountOrientationPreset.portraitTopForward,
    );

    expect(success, isTrue);
    expect(cal.isCalibrated, isTrue);

    // When stationary, bike frame forces should have zero forward/lateral, and ~0 vertical
    final restingForces = cal.transform(0.0, 0.0, 9.81);
    expect(restingForces.forward.abs(), lessThan(0.05));
    expect(restingForces.lateral.abs(), lessThan(0.05));
    expect(restingForces.vertical.abs(), lessThan(0.05));

    // When motorcycle accelerates forward with 2.5 m/s² (phone top Y direction)
    final thrustForces = cal.transform(0.0, 2.5, 9.81);
    expect((thrustForces.forward - 2.5).abs(), lessThan(0.1));
  });
}

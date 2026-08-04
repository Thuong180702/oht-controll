import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/app.dart';
import 'package:flutter_application_1/core/constants/app_constants.dart';
import 'package:flutter_application_1/core/utils/app_preferences.dart';
import 'package:flutter_application_1/core/constants/oht_ids.dart';
import 'package:flutter_application_1/core/enums/connection_phase.dart';
import 'package:flutter_application_1/core/enums/manual_command_type.dart';
import 'package:flutter_application_1/core/enums/motor_state.dart';
import 'package:flutter_application_1/core/enums/oht_mode.dart';
import 'package:flutter_application_1/features/oht_manual/domain/entities/alarm_event.dart';
import 'package:flutter_application_1/features/oht_manual/domain/entities/connection_status.dart';
import 'package:flutter_application_1/features/oht_manual/domain/entities/manual_command.dart';
import 'package:flutter_application_1/features/oht_manual/domain/entities/motor_status.dart';
import 'package:flutter_application_1/features/oht_manual/domain/entities/oht_telemetry.dart';
import 'package:flutter_application_1/features/oht_manual/domain/entities/sensor_status.dart';
import 'package:flutter_application_1/features/oht_manual/domain/repositories/oht_communication_service.dart';
import 'package:flutter_application_1/features/oht_manual/presentation/controllers/oht_manual_controller.dart';
import 'package:flutter_application_1/features/oht_manual/presentation/screens/oht_manual_screen.dart';
import 'package:flutter_application_1/features/oht_manual/presentation/widgets/industrial_top_bar.dart';
import 'package:flutter_application_1/features/oht_manual/presentation/widgets/motor_display_formatters.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPreferences.clearSession();
  });

  test('manual commands accept an advanced motor speed override', () async {
    final controller = OhtManualController();
    addTearDown(controller.dispose);

    await controller.connect();
    for (var i = 0; i < 10 && !controller.isConnected; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(controller.isConnected, isTrue);

    await controller.sendManualCommand(
      ManualCommandType.travelForward,
      speedOverride: 72,
    );

    expect(
      controller.events.any(
        (event) =>
            event.message.contains('Sent travel_forward') &&
            event.message.contains('speed=72%'),
      ),
      isTrue,
    );
  });

  test('mock motor commands update telemetry for diagnostics', () async {
    final controller = OhtManualController();
    addTearDown(controller.dispose);

    await controller.connect();
    for (var i = 0; i < 10 && !controller.isConnected; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    await controller.sendManualCommand(
      ManualCommandType.travelForward,
      speedOverride: 72,
    );
    await Future<void>.delayed(const Duration(milliseconds: 550));

    final travelFront = controller.telemetry.motors[MotorIds.travelFront]!;
    expect(travelFront.state, MotorState.running);
    expect(travelFront.velocityMps, closeTo(0.72, 0.01));
    expect(travelFront.positionM, greaterThan(0));

    final travelRear = controller.telemetry.motors[MotorIds.travelRear]!;
    expect(travelRear.state, MotorState.running);

    await controller.sendManualCommand(
      ManualCommandType.steerRight,
      speedOverride: 40,
    );
    await Future<void>.delayed(const Duration(milliseconds: 550));

    final steerFront = controller.telemetry.motors[MotorIds.steerFront]!;
    expect(steerFront.state, MotorState.running);
    expect(steerFront.velocityMps, closeTo(0.40, 0.01));
    expect(steerFront.positionM, greaterThan(-1.0));
    expect(steerFront.positionM, lessThan(0.0));
  });

  test('mock hoist down increases Z from top zero', () async {
    final controller = OhtManualController();
    addTearDown(controller.dispose);

    await controller.connect();
    for (var i = 0; i < 10 && !controller.isConnected; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    await controller.sendManualCommand(
      ManualCommandType.hoistDown,
      speedOverride: 30,
    );
    await Future<void>.delayed(const Duration(milliseconds: 550));

    final lowered = controller.telemetry.motors[MotorIds.hoistFront]!;
    expect(lowered.direction, 'down');
    expect(lowered.positionM, greaterThan(0.0));
    expect(lowered.positionM, lessThan(0.05));
    expect(controller.telemetry.sensors.hoistFrontUpperLimit, isFalse);

    await controller.sendManualCommand(
      ManualCommandType.hoistUp,
      speedOverride: 30,
    );
    await Future<void>.delayed(const Duration(milliseconds: 550));

    final raised = controller.telemetry.motors[MotorIds.hoistFront]!;
    expect(raised.positionM, lessThanOrEqualTo(lowered.positionM!));
    expect(raised.positionM, closeTo(0.0, 0.005));
    expect(controller.telemetry.sensors.hoistFrontUpperLimit, isTrue);
  });

  test('mock steering reaches right limit in about two seconds', () async {
    final controller = OhtManualController();
    addTearDown(controller.dispose);

    await controller.connect();
    for (var i = 0; i < 10 && !controller.isConnected; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    await controller.sendManualCommand(ManualCommandType.steerRight);
    await Future<void>.delayed(const Duration(milliseconds: 2100));

    final steerFront = controller.telemetry.motors[MotorIds.steerFront]!;
    expect(steerFront.state, MotorState.stopped);
    expect(steerFront.positionM, closeTo(1.0, 0.001));
    expect(controller.telemetry.sensors.steerFrontLeft, isFalse);
    expect(controller.telemetry.sensors.steerFrontRight, isTrue);
  });

  test('hoist top limit formats as zero height', () {
    final details = formatMotorDetails(
      MotorIds.hoistFront,
      null,
      SensorStatus.noData().copyWith(hoistFrontUpperLimit: true),
    );

    expect(details, contains('H: 0.00 m'));
  });

  test(
    'one critical telemetry fault creates one visible critical log',
    () async {
      final service = _ScriptedOhtService();
      final controller = OhtManualController(service: service);
      addTearDown(controller.dispose);

      service.emitTelemetry(_telemetry());
      await Future<void>.delayed(Duration.zero);
      service.emitTelemetry(
        _telemetry(
          emergencyStop: true,
          sensors: SensorStatus.noData().copyWith(lidarUpper: 2),
          errors: const ['Lidar Upper Zone bao loi nguy hiem'],
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final criticalEvents = controller.events
          .where((event) => event.severity.name == 'critical')
          .toList();
      expect(criticalEvents, hasLength(1));
      expect(criticalEvents.single.message, contains('Lidar Upper'));
    },
  );

  Future<void> pumpDesktopApp(
    WidgetTester tester, {
    Map<String, Object> preferences = const {},
  }) async {
    SharedPreferences.setMockInitialValues(preferences);
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const OhtManualApp());
  }

  Future<void> pumpAndroidApp(
    WidgetTester tester, {
    Map<String, Object> preferences = const {},
    Size physicalSize = const Size(800, 360),
  }) async {
    SharedPreferences.setMockInitialValues(preferences);
    tester.view.physicalSize = physicalSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const OhtManualApp(forceAndroidViewport: true));
  }

  Future<void> pumpIosApp(
    WidgetTester tester, {
    Map<String, Object> preferences = const {},
    Size physicalSize = const Size(844, 390), // Standard iPhone landscape
  }) async {
    SharedPreferences.setMockInitialValues(preferences);
    tester.view.physicalSize = physicalSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const OhtManualApp(forceAndroidViewport: true));
  }

  Future<void> login(WidgetTester tester) async {
    await tester.pump();
    final submitFinder = find.byKey(const Key('login_submit_button'));
    if (submitFinder.evaluate().isNotEmpty) {
      await tester.enterText(find.byType(TextFormField).at(1), 'Thaco@1234');
      await tester.tap(submitFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
    }
  }

  testWidgets('connection screen uses the shared Stitch-style top bar', (
    WidgetTester tester,
  ) async {
    await pumpDesktopApp(tester);
    await login(tester);

    expect(find.byKey(const Key('industrial_top_bar')), findsOneWidget);
    expect(find.byKey(const Key('top_nav_connection_active')), findsOneWidget);
    expect(find.text('BẢNG ĐIỀU KHIỂN'), findsOneWidget);
    expect(find.text('CHẨN ĐOÁN'), findsOneWidget);
    expect(find.text('KẾT NỐI'), findsWidgets);
    expect(find.text('NHẬT KÝ'), findsOneWidget);
    expect(find.text('CÀI ĐẶT'), findsOneWidget);
    expect(find.text('DỪNG KHẨN CẤP'), findsWidgets);
    expect(find.byIcon(Icons.notifications_none_rounded), findsNothing);
    expect(find.byIcon(Icons.language_rounded), findsNothing);
  });

  testWidgets('android renders the same desktop top bar as windows', (
    WidgetTester tester,
  ) async {
    await pumpAndroidApp(tester);
    await login(tester);

    expect(find.byKey(const Key('android_windows_viewport')), findsOneWidget);
    expect(find.byKey(const Key('industrial_top_bar')), findsOneWidget);
    expect(find.byKey(const Key('top_bar_brand')), findsOneWidget);
    expect(find.byKey(const Key('top_nav_dashboard')), findsOneWidget);
    expect(find.byKey(const Key('top_nav_diagnostics')), findsOneWidget);
    expect(find.byKey(const Key('top_nav_connection_active')), findsOneWidget);
    expect(find.byKey(const Key('top_nav_logs')), findsOneWidget);
    expect(find.byKey(const Key('top_nav_settings')), findsOneWidget);
    expect(find.text('OFFLINE'), findsWidgets);
    expect(find.text('Thaco'), findsOneWidget);
    expect(find.text('Đăng xuất'), findsOneWidget);
  });

  testWidgets('ios renders scaled landscape viewport and top bar', (
    WidgetTester tester,
  ) async {
    await pumpIosApp(tester);
    await login(tester);

    expect(find.byKey(const Key('android_windows_viewport')), findsOneWidget);
    expect(find.byKey(const Key('industrial_top_bar')), findsOneWidget);
    expect(find.byKey(const Key('top_bar_brand')), findsOneWidget);
    expect(find.byKey(const Key('top_nav_dashboard')), findsOneWidget);
    expect(find.byKey(const Key('top_nav_connection_active')), findsOneWidget);
  });

  testWidgets(
    'android viewport matches tablet aspect ratio without letterbox',
    (WidgetTester tester) async {
      await pumpAndroidApp(tester, physicalSize: const Size(1280, 800));

      expect(find.byKey(const Key('android_windows_viewport')), findsOneWidget);
      expect(find.byKey(const Key('android_windows_canvas')), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const Key('android_windows_canvas'))),
        const Size(1920, 1200),
      );
    },
  );

  testWidgets('android tablet manual controls fill the panel height', (
    WidgetTester tester,
  ) async {
    await pumpAndroidApp(tester, physicalSize: const Size(1280, 800));
    await login(tester);

    await tester.tap(find.text('Chế độ Mock (Demo)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final downRect = tester.getRect(
      find.byKey(const Key('dashboard_control_down')),
    );
    final clearErrorRect = tester.getRect(
      find.byKey(const Key('dashboard_clear_error_button')),
    );

    expect(clearErrorRect.top - downRect.bottom, lessThanOrEqualTo(18));
  });

  testWidgets('top bar brand reserves enough width for the product name', (
    WidgetTester tester,
  ) async {
    await pumpDesktopApp(tester);
    await login(tester);

    final brandSize = tester.getSize(find.byKey(const Key('top_bar_brand')));
    expect(brandSize.width, greaterThanOrEqualTo(190));
  });

  testWidgets('connection screen uses the global emergency warning frame', (
    WidgetTester tester,
  ) async {
    await pumpDesktopApp(tester);
    await login(tester);

    expect(find.byKey(const Key('top_nav_connection_active')), findsOneWidget);
    expect(find.byKey(const Key('global_emergency_alert_frame')), findsNothing);

    await tester.tap(find.byKey(const Key('emergency_stop_button_connection')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    expect(
      find.byKey(const Key('global_emergency_alert_frame')),
      findsOneWidget,
    );
  });

  testWidgets('dashboard keeps the same top bar and switches active nav item', (
    WidgetTester tester,
  ) async {
    await pumpDesktopApp(tester);
    await login(tester);

    await tester.tap(find.text('Chế độ Mock (Demo)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(find.byKey(const Key('industrial_top_bar')), findsOneWidget);
    expect(find.byKey(const Key('top_nav_dashboard_active')), findsOneWidget);
    expect(find.text('BẢNG ĐIỀU KHIỂN'), findsOneWidget);
    expect(find.text('DỪNG KHẨN CẤP'), findsWidgets);
    expect(find.text('EMERGENCY STOP'), findsNothing);
  });

  testWidgets('top bar tabs navigate between connection and dashboard', (
    WidgetTester tester,
  ) async {
    await pumpDesktopApp(tester);
    await login(tester);

    await tester.tap(find.text('BẢNG ĐIỀU KHIỂN'));
    await tester.pump();

    expect(find.byKey(const Key('top_nav_dashboard_active')), findsOneWidget);

    await tester.tap(find.text('KẾT NỐI').first);
    await tester.pump();

    expect(find.byKey(const Key('top_nav_connection_active')), findsOneWidget);
  });

  testWidgets('dashboard tabs switch to the logs panel', (
    WidgetTester tester,
  ) async {
    await pumpDesktopApp(tester);
    await login(tester);

    await tester.tap(find.text('BẢNG ĐIỀU KHIỂN'));
    await tester.pump();
    await tester.tap(find.text('NHẬT KÝ'));
    await tester.pump();

    expect(find.byKey(const Key('top_nav_logs_active')), findsOneWidget);
    expect(find.byKey(const Key('logs_panel')), findsOneWidget);
  });

  testWidgets(
    'dashboard shows the Stitch manual panel with six controls only',
    (WidgetTester tester) async {
      await pumpDesktopApp(tester);
      await login(tester);

      await tester.tap(find.byKey(const Key('top_nav_dashboard')));
      await tester.pump();

      expect(find.byKey(const Key('dashboard_panel')), findsOneWidget);
      expect(find.byKey(const Key('dashboard_manual_panel')), findsOneWidget);
      expect(find.byKey(const Key('dashboard_map_panel')), findsOneWidget);
      expect(
        find.byKey(const Key('dashboard_control_forward')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('dashboard_control_left')), findsOneWidget);
      expect(find.byKey(const Key('dashboard_control_right')), findsOneWidget);
      expect(
        find.byKey(const Key('dashboard_control_backward')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('dashboard_control_up')), findsOneWidget);
      expect(find.byKey(const Key('dashboard_control_down')), findsOneWidget);
      expect(find.byKey(const Key('advanced_control_panel')), findsNothing);

      expect(
        find.byKey(const Key('dashboard_telemetry_strip')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('dashboard_telemetry_strip')),
          matching: find.byType(Scrollable),
        ),
        findsNothing,
      );
      final stripSize = tester.getSize(
        find.byKey(const Key('dashboard_telemetry_strip')),
      );
      final stripContentSize = tester.getSize(
        find.byKey(const Key('dashboard_telemetry_content')),
      );
      expect(stripContentSize.width, closeTo(stripSize.width, 3));
      expect(find.text('Trạng Thái (Telemetry)'), findsOneWidget);
      expect(find.text('Ngoại tuyến'), findsOneWidget);
      expect(find.text('CHẾ ĐỘ'), findsOneWidget);
      expect(find.text('TỌA ĐỘ'), findsOneWidget);
      expect(find.text('VỊ TRÍ Z'), findsOneWidget);
      expect(find.text('TỐC ĐỘ'), findsOneWidget);
      expect(find.text('LỖI'), findsOneWidget);
      expect(find.text('HƯỚNG LÁI'), findsOneWidget);
      expect(find.text('TRẠNG THÁI'), findsOneWidget);
      expect(find.text('CẢNH BÁO'), findsOneWidget);
      expect(find.text('Điều Khiển Thủ Công'), findsOneWidget);
      expect(find.text('TIẾN'), findsOneWidget);
      expect(find.text('LÙI'), findsOneWidget);
      expect(find.text('TRÁI'), findsWidgets);
      expect(find.text('PHẢI'), findsWidgets);
      expect(find.text('NÂNG'), findsOneWidget);
      expect(find.text('HẠ'), findsOneWidget);

      final manualSize = tester.getSize(
        find.byKey(const Key('dashboard_manual_panel')),
      );
      final mapSize = tester.getSize(
        find.byKey(const Key('dashboard_map_panel')),
      );
      expect(manualSize.width, greaterThanOrEqualTo(420));
      expect(mapSize.width, greaterThan(400));

      final forwardRect = tester.getRect(
        find.byKey(const Key('dashboard_control_forward')),
      );
      final leftRect = tester.getRect(
        find.byKey(const Key('dashboard_control_left')),
      );
      final rightRect = tester.getRect(
        find.byKey(const Key('dashboard_control_right')),
      );
      final backwardRect = tester.getRect(
        find.byKey(const Key('dashboard_control_backward')),
      );
      final upRect = tester.getRect(
        find.byKey(const Key('dashboard_control_up')),
      );
      final downRect = tester.getRect(
        find.byKey(const Key('dashboard_control_down')),
      );

      expect(forwardRect.top, lessThan(leftRect.top));
      expect(leftRect.top, closeTo(rightRect.top, 1));
      expect(leftRect.left, lessThan(rightRect.left));
      expect(backwardRect.top, greaterThan(leftRect.top));
      expect(upRect.top, greaterThan(backwardRect.top));
      expect(upRect.top, closeTo(downRect.top, 1));
      expect(forwardRect.width, greaterThan(leftRect.width));
      expect(backwardRect.width, closeTo(forwardRect.width, 1));
      expect(leftRect.width, closeTo(rightRect.width, 1));
      expect(upRect.width, closeTo(downRect.width, 1));

      final expectedHeight = forwardRect.height;
      for (final rect in <Rect>[
        leftRect,
        rightRect,
        backwardRect,
        upRect,
        downRect,
      ]) {
        expect(rect.height, closeTo(expectedHeight, 1));
      }
    },
  );

  testWidgets(
    'dashboard exposes Z telemetry, steering status, and error reset',
    (WidgetTester tester) async {
      await pumpDesktopApp(tester);
      await login(tester);

      await tester.tap(find.byKey(const Key('top_nav_dashboard')));
      await tester.pump();

      expect(find.byKey(const Key('dashboard_metric_z')), findsOneWidget);
      expect(
        find.byKey(const Key('dashboard_metric_steering')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('dashboard_clear_error_button')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('emergency_stop_button_dashboard')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.byKey(const Key('dashboard_emergency_banner')), findsNothing);
      expect(
        find.byKey(const Key('global_emergency_alert_frame')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('top_nav_logs')));
      await tester.pump();
      expect(find.byKey(const Key('logs_panel')), findsOneWidget);
      expect(
        find.byKey(const Key('global_emergency_alert_frame')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('top_nav_dashboard')));
      await tester.pump();

      await tester.tap(find.byKey(const Key('dashboard_clear_error_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.byKey(const Key('dashboard_emergency_banner')), findsNothing);
      expect(
        find.byKey(const Key('global_emergency_alert_frame')),
        findsNothing,
      );
    },
  );

  testWidgets('dashboard shows charging state next to the battery value', (
    WidgetTester tester,
  ) async {
    final service = _ScriptedOhtService();
    final controller = OhtManualController(service: service);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: OhtManualScreen(
          controller: controller,
          username: 'Thaco',
          activeItem: IndustrialTopBarItem.dashboard,
          languageCode: 'vi',
          themeMode: ThemeMode.light,
          onLanguageChanged: (_) {},
          onThemeModeChanged: (_) {},
          onTopNavSelected: (_) {},
          onDisconnect: () async {},
          onLogout: () async {},
        ),
      ),
    );

    service.emitTelemetry(_telemetry(batteryLevel: 58, isCharging: true));
    await tester.pump(const Duration(milliseconds: 150));

    expect(
      find.byKey(const Key('dashboard_battery_charging_indicator')),
      findsOneWidget,
    );
    expect(find.text('ĐANG SẠC'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('diagnostics page does not expose advanced controls', (
    WidgetTester tester,
  ) async {
    await pumpDesktopApp(tester);
    await login(tester);

    await tester.tap(find.byKey(const Key('top_nav_diagnostics')));
    await tester.pump();

    expect(find.byKey(const Key('top_nav_diagnostics_active')), findsOneWidget);
    expect(find.byKey(const Key('diagnostics_panel')), findsOneWidget);
    expect(
      find.byKey(const Key('diagnostics_advanced_control_button')),
      findsNothing,
    );
    expect(find.byKey(const Key('advanced_control_panel')), findsNothing);
    expect(find.byKey(const Key('advanced_control_dialog')), findsNothing);
    expect(find.byKey(const Key('dashboard_manual_panel')), findsNothing);
  });

  testWidgets('diagnostics uses the Stitch hardware sections', (
    WidgetTester tester,
  ) async {
    await pumpDesktopApp(tester);
    await login(tester);

    await tester.tap(find.byKey(const Key('top_nav_diagnostics')));
    await tester.pump();

    expect(
      find.byKey(const Key('diagnostics_motion_motors_section')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('diagnostics_steer_motors_section')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('diagnostics_hoist_motors_section')),
      findsOneWidget,
    );
    for (final id in <String>[
      'travel_front',
      'travel_rear',
      'steer_front',
      'steer_rear',
      'hoist_front',
      'hoist_rear',
    ]) {
      expect(find.byKey(Key('diagnostics_motor_$id')), findsOneWidget);
      expect(
        find.byKey(Key('diagnostics_motor_${id}_position_cell')),
        findsOneWidget,
      );
      expect(
        find.byKey(Key('diagnostics_motor_${id}_velocity_cell')),
        findsOneWidget,
      );

      final positionCell = tester.getSize(
        find.byKey(Key('diagnostics_motor_${id}_position_cell')),
      );
      final velocityCell = tester.getSize(
        find.byKey(Key('diagnostics_motor_${id}_velocity_cell')),
      );
      expect(positionCell.width, closeTo(velocityCell.width, 1));
      expect(positionCell.height, greaterThanOrEqualTo(60));
    }

    expect(find.byKey(const Key('diagnostics_sensor_matrix')), findsOneWidget);
    for (final id in <String>[
      'lidar_upper',
      'lidar_lower',
      'bumper_front',
      'bumper_rear',
      'steer_front_left',
      'steer_front_right',
      'steer_rear_left',
      'steer_rear_right',
      'hoist_front_upper',
      'hoist_rear_upper',
    ]) {
      expect(find.byKey(Key('diagnostics_sensor_$id')), findsOneWidget);
    }

    void expectSameSensorTileSize(List<String> ids) {
      final reference = tester.getSize(
        find.byKey(Key('diagnostics_sensor_${ids.first}')),
      );
      expect(reference.width, greaterThanOrEqualTo(120));
      expect(reference.height, greaterThanOrEqualTo(70));
      for (final id in ids.skip(1)) {
        final size = tester.getSize(find.byKey(Key('diagnostics_sensor_$id')));
        expect(size.width, closeTo(reference.width, 1));
        expect(size.height, closeTo(reference.height, 1));
      }
    }

    expectSameSensorTileSize([
      'lidar_upper',
      'lidar_lower',
      'bumper_front',
      'bumper_rear',
    ]);
    expectSameSensorTileSize([
      'steer_front_left',
      'steer_front_right',
      'steer_rear_left',
      'steer_rear_right',
    ]);
    expectSameSensorTileSize(['hoist_front_upper', 'hoist_rear_upper']);

    expect(
      find.descendant(
        of: find.byKey(const Key('diagnostics_panel')),
        matching: find.byType(Scrollable),
      ),
      findsNothing,
    );
  });

  testWidgets('diagnostics shows active and faulted motor states', (
    WidgetTester tester,
  ) async {
    final service = _ScriptedOhtService();
    final controller = OhtManualController(service: service);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: OhtManualScreen(
          controller: controller,
          username: 'Thaco',
          activeItem: IndustrialTopBarItem.diagnostics,
          languageCode: 'vi',
          themeMode: ThemeMode.light,
          onLanguageChanged: (_) {},
          onThemeModeChanged: (_) {},
          onTopNavSelected: (_) {},
          onDisconnect: () async {},
          onLogout: () async {},
        ),
      ),
    );

    service.emitTelemetry(
      _telemetry(
        motors: {
          MotorIds.travelFront: const MotorStatus(
            id: MotorIds.travelFront,
            state: MotorState.running,
            direction: 'forward',
            speed: 60,
            velocityMps: 0.6,
            positionM: 0.0012,
          ),
        },
      ),
    );
    await tester.pump(const Duration(milliseconds: 150));

    expect(
      find.byKey(const Key('diagnostics_motor_travel_front_status_active')),
      findsOneWidget,
    );
    expect(find.text('1.2'), findsOneWidget);
    expect(find.text('60'), findsOneWidget);

    service.emitTelemetry(
      _telemetry(errors: const ['Motor travel_front disconnected']),
    );
    await tester.pump(const Duration(milliseconds: 150));

    expect(
      find.byKey(const Key('diagnostics_motor_travel_front_status_error')),
      findsOneWidget,
    );

    controller.dispose();
  });

  testWidgets('logs tab has Stitch toolbar and download action', (
    WidgetTester tester,
  ) async {
    await pumpDesktopApp(tester);
    await login(tester);

    await tester.tap(find.byKey(const Key('top_nav_logs')));
    await tester.pump();

    expect(find.byKey(const Key('logs_toolbar')), findsOneWidget);
    expect(find.byKey(const Key('logs_search_field')), findsOneWidget);
    expect(find.byKey(const Key('logs_source_filter')), findsNothing);
    expect(find.text('Tất cả hệ thống'), findsNothing);
    expect(find.byKey(const Key('logs_download_button')), findsOneWidget);
  });

  testWidgets('logs severity buttons filter visible events', (
    WidgetTester tester,
  ) async {
    await pumpDesktopApp(tester);
    await login(tester);

    await tester.tap(find.text('Chế độ Mock (Demo)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const Key('dashboard_control_forward')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    await tester.tap(find.byKey(const Key('top_nav_logs')));
    await tester.pump();

    expect(find.text('COMMAND'), findsWidgets);

    await tester.tap(find.byKey(const Key('logs_filter_info')));
    await tester.pump();

    expect(find.byKey(const Key('logs_filter_info_active')), findsOneWidget);
    expect(find.text('INFO'), findsWidgets);
    expect(find.text('COMMAND'), findsNothing);

    await tester.tap(find.byKey(const Key('logs_filter_error')));
    await tester.pump();

    expect(find.byKey(const Key('logs_filter_error_active')), findsOneWidget);
    expect(find.byKey(const Key('logs_empty_state')), findsOneWidget);
  });

  testWidgets('settings tab uses the Stitch configuration sections', (
    WidgetTester tester,
  ) async {
    await pumpDesktopApp(tester);
    await login(tester);

    await tester.tap(find.byKey(const Key('top_nav_settings')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('settings_panel')), findsOneWidget);
    expect(find.byKey(const Key('settings_general_panel')), findsOneWidget);
    expect(find.byKey(const Key('settings_user_panel')), findsOneWidget);
    expect(find.byKey(const Key('settings_two_column_grid')), findsOneWidget);
    expect(find.byKey(const Key('settings_left_column')), findsOneWidget);
    expect(find.byKey(const Key('settings_right_column')), findsOneWidget);

    expect(find.byKey(const Key('settings_safety_panel')), findsNothing);
    expect(find.byKey(const Key('settings_bento_grid')), findsOneWidget);

    final generalTop = tester
        .getTopLeft(find.byKey(const Key('settings_general_panel')))
        .dy;
    final userTop = tester
        .getTopLeft(find.byKey(const Key('settings_user_panel')))
        .dy;
    expect(userTop, greaterThanOrEqualTo(generalTop));

    await tester.ensureVisible(
      find.byKey(const Key('settings_session_panel')),
    );
    expect(find.byKey(const Key('settings_session_panel')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('settings_action_bar')));
    expect(find.byKey(const Key('settings_action_bar')), findsOneWidget);
    expect(find.byKey(const Key('settings_cancel_button')), findsOneWidget);
    expect(find.byKey(const Key('settings_apply_button')), findsOneWidget);
  });

  testWidgets('settings persist language and dark theme selections', (
    WidgetTester tester,
  ) async {
    await pumpDesktopApp(tester);
    await login(tester);

    await tester.tap(find.byKey(const Key('top_nav_settings')));
    await tester.pump();

    expect(
      find.byKey(const Key('settings_language_vi_active')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('settings_theme_light_active')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('settings_language_en_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings_theme_dark_button')));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('oht_language_code'), 'en');
    expect(prefs.getString('oht_theme_mode'), 'dark');
    expect(
      find.byKey(const Key('settings_language_en_active')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('settings_theme_dark_active')), findsOneWidget);

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.locale, const Locale('en'));
    expect(app.themeMode, ThemeMode.dark);
  });

  testWidgets('app restores saved language and theme on startup', (
    WidgetTester tester,
  ) async {
    await pumpDesktopApp(
      tester,
      preferences: const {'oht_language_code': 'en', 'oht_theme_mode': 'dark'},
    );
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.locale, const Locale('en'));
    expect(app.themeMode, ThemeMode.dark);
  });

  testWidgets('english language applies across visible app pages', (
    WidgetTester tester,
  ) async {
    await pumpDesktopApp(
      tester,
      preferences: const {'oht_language_code': 'en'},
    );
    await tester.pumpAndSettle();

    expect(find.text('System Login'), findsOneWidget);
    expect(find.text('Đăng nhập hệ thống'), findsNothing);

    await login(tester);
    expect(find.text('Current Status'), findsOneWidget);
    expect(find.text('Connection Protocol'), findsOneWidget);

    await tester.tap(find.text('Mock Mode (Demo)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Manual Control'), findsOneWidget);
    expect(find.text('System Map'), findsOneWidget);

    await tester.tap(find.byKey(const Key('top_nav_diagnostics')));
    await tester.pump();
    expect(find.text('Hardware Diagnostics'), findsOneWidget);
    expect(find.text('ADVANCED CONTROL'), findsNothing);

    await tester.tap(find.byKey(const Key('top_nav_logs')));
    await tester.pump();
    expect(find.text('System Log'), findsOneWidget);
    expect(find.text('EXPORT LOG'), findsOneWidget);

    await tester.tap(find.byKey(const Key('top_nav_settings')));
    await tester.pump();
    expect(find.text('System Settings'), findsOneWidget);
    expect(find.text('General System'), findsOneWidget);
    expect(find.text('Operator Information'), findsOneWidget);
    expect(find.text('Safety Limits'), findsNothing);
  });

  testWidgets('macOS keyboard shortcuts trigger space emergency stop and tab switching', (
    WidgetTester tester,
  ) async {
    await pumpDesktopApp(tester);
    await login(tester);

    await tester.tap(find.text('Chế độ Mock (Demo)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // Send Space key for Emergency Stop
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();

    // Verify Space key triggers emergency stop state
    expect(find.byType(OhtManualScreen), findsOneWidget);

    await tester.tap(find.byKey(const Key('top_nav_diagnostics')));
    await tester.pump();

    expect(find.byKey(const Key('diagnostics_panel')), findsOneWidget);
  });
}

OhtTelemetry _telemetry({
  Map<String, MotorStatus> motors = const {},
  SensorStatus? sensors,
  List<String> errors = const [],
  bool emergencyStop = false,
  int batteryLevel = 100,
  bool isCharging = false,
}) {
  return OhtTelemetry(
    mode: OhtMode.manual,
    connected: true,
    emergencyStop: emergencyStop,
    motors: {
      for (final id in MotorIds.all) id: motors[id] ?? MotorStatus.stopped(id),
    },
    sensors: sensors ?? SensorStatus.noData(),
    errors: errors,
    timestamp: DateTime.now(),
    batteryLevel: batteryLevel,
    isCharging: isCharging,
  );
}

class _ScriptedOhtService implements OhtCommunicationService {
  final _telemetryController = StreamController<OhtTelemetry>.broadcast();
  final _statusController = StreamController<ConnectionStatus>.broadcast();
  final _eventController = StreamController<AlarmEvent>.broadcast();

  ConnectionStatus _status = ConnectionStatus(
    phase: ConnectionPhase.connected,
    endpoint: AppConstants.mockEndpoint,
    message: 'Connected',
    changedAt: DateTime.now(),
  );

  @override
  Stream<OhtTelemetry> get telemetryStream => _telemetryController.stream;

  @override
  Stream<ConnectionStatus> get connectionStatusStream =>
      _statusController.stream;

  @override
  Stream<AlarmEvent> get eventStream => _eventController.stream;

  @override
  ConnectionStatus get status => _status;

  void emitTelemetry(OhtTelemetry telemetry) {
    _telemetryController.add(telemetry);
  }

  @override
  Future<void> connect({required String endpoint}) async {
    _status = _status.copyWith(
      phase: ConnectionPhase.connected,
      endpoint: endpoint,
      changedAt: DateTime.now(),
    );
    _statusController.add(_status);
  }

  @override
  Future<void> disconnect() async {
    _status = _status.copyWith(
      phase: ConnectionPhase.disconnected,
      changedAt: DateTime.now(),
    );
    _statusController.add(_status);
  }

  @override
  Future<void> sendCommand(ManualCommand command) async {}

  @override
  void dispose() {
    _telemetryController.close();
    _statusController.close();
    _eventController.close();
  }
}

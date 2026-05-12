import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/app.dart';

void main() {
  testWidgets('OHT manual dashboard smoke test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1180, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const OhtManualApp());

    expect(find.text('Đăng nhập hệ thống'), findsOneWidget);
    expect(find.text('OHT Manual Control & Monitoring'), findsOneWidget);

    await tester.tap(find.text('Đăng nhập'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('Chế độ Mock (Demo)'), findsOneWidget);

    await tester.ensureVisible(find.text('Chế độ Mock (Demo)'));
    await tester.pump();
    await tester.tap(find.text('Chế độ Mock (Demo)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(find.text('OHT Control System'), findsOneWidget);
    expect(find.text('EMERGENCY STOP'), findsOneWidget);
    expect(find.text('Dừng'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

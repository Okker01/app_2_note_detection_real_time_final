// This is a basic Flutter widget test for the Guitar Tuner app.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_2_note_detection_real_time_final/main.dart';

void main() {
  testWidgets('Guitar Tuner app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const GuitarTunerApp());

    // Verify that the app starts with the correct title
    expect(find.text('Guitar Tuner Pro'), findsOneWidget);

    // Verify that the microphone button is present
    expect(find.byIcon(Icons.mic), findsOneWidget);

    // Verify that settings button is present
    expect(find.byIcon(Icons.settings), findsOneWidget);

    // Verify that the initial note display shows A4
    expect(find.text('A4'), findsOneWidget);

    // Verify that frequency display is present (shows 0.00 Hz initially)
    expect(find.text('0.00 Hz'), findsOneWidget);

    // Verify that Standard tuning is shown initially
    expect(find.text('Standard Tuning'), findsOneWidget);
  });

  testWidgets('Settings dialog opens and closes correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const GuitarTunerApp());

    // Tap the settings button
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();

    // Verify that the settings dialog appears
    expect(find.text('Tuner Settings'), findsOneWidget);
    expect(find.text('Tuning Tolerance'), findsOneWidget);
    expect(find.text('Reference Pitch'), findsOneWidget);
    expect(find.text('Advanced Filtering'), findsOneWidget);

    // Close the dialog
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Verify the dialog is closed
    expect(find.text('Tuner Settings'), findsNothing);
  });

  testWidgets('Tuning selector works correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const GuitarTunerApp());

    // Tap the tuning change button
    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();

    // Verify that the tuning selector appears
    expect(find.text('Select Tuning'), findsOneWidget);
    expect(find.text('Standard'), findsOneWidget);
    expect(find.text('Drop D'), findsOneWidget);
    expect(find.text('Open G'), findsOneWidget);
    expect(find.text('DADGAD'), findsOneWidget);

    // Select Drop D tuning
    await tester.tap(find.text('Drop D'));
    await tester.pumpAndSettle();

    // Verify Drop D is now selected
    expect(find.text('Drop D Tuning'), findsOneWidget);
  });

  testWidgets('Advanced mode toggle works', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const GuitarTunerApp());

    // Find the advanced mode button (should show "Advanced" initially)
    expect(find.text('Advanced'), findsOneWidget);

    // Tap the advanced mode button
    await tester.tap(find.text('Advanced'));
    await tester.pumpAndSettle();

    // Verify that it toggles to "Basic" and shows snackbar
    expect(find.text('Basic'), findsOneWidget);
    expect(find.text('Basic mode - faster response'), findsOneWidget);

    // Wait for snackbar to disappear
    await tester.pump(const Duration(seconds: 3));

    // Toggle back to Advanced
    await tester.tap(find.text('Basic'));
    await tester.pumpAndSettle();

    // Verify it's back to Advanced
    expect(find.text('Advanced'), findsOneWidget);
    expect(find.text('Advanced filtering enabled - better accuracy'), findsOneWidget);
  });

  testWidgets('String buttons are present and interactive', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const GuitarTunerApp());

    // Find string buttons (should show note names without octave numbers)
    expect(find.text('E'), findsAtLeastNWidgets(2)); // Low E and High E
    expect(find.text('A'), findsOneWidget);
    expect(find.text('D'), findsOneWidget);
    expect(find.text('G'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);

    // Tap on a string button (A string)
    await tester.tap(find.text('A').first);
    await tester.pumpAndSettle();

    // Verify snackbar appears with target frequency info
    expect(find.text('Target note: 110.00 Hz'), findsOneWidget);
  });

  testWidgets('Microphone button toggles correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const GuitarTunerApp());

    // Initially should show microphone icon (not listening)
    expect(find.byIcon(Icons.mic), findsOneWidget);
    expect(find.byIcon(Icons.stop), findsNothing);

    // Note: We can't actually test microphone functionality in widget tests
    // due to platform dependencies, but we can test the UI changes

    // The microphone button should be present and tappable
    final micButton = find.byIcon(Icons.mic);
    expect(micButton, findsOneWidget);

    // Verify the button is in a circular container
    final circularContainer = find.ancestor(
      of: micButton,
      matching: find.byType(Container),
    );
    expect(circularContainer, findsWidgets);
  });

  testWidgets('Tuning meter is present', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const GuitarTunerApp());

    // Verify cents display is present (should show "0 cents" initially)
    expect(find.textContaining('cents'), findsOneWidget);

    // Verify the custom paint widget (tuning meter) is present
    expect(find.byType(CustomPaint), findsOneWidget);
  });
}
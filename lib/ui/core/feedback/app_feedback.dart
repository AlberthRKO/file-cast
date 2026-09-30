import 'package:file_cast/ui/core/widgets/app_feedback_sheet.dart';
import 'package:flutter/material.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

/// Presents short-lived, global feedback for a completed application action.
///
/// ViewModels expose the result without depending on Flutter. Views call these
/// helpers in response to that result, keeping navigation and presentation at
/// the UI boundary.
Future<void> showAppErrorBottomSheet(
  BuildContext context,
  String message, {
  String? title,
  Duration duration = const Duration(seconds: 3),
}) {
  return _showAppFeedbackBottomSheet(
    context,
    type: AppFeedbackType.error,
    message: message,
    title: title,
    duration: duration,
  );
}

Future<void> showAppSuccessBottomSheet(
  BuildContext context,
  String message, {
  String? title,
  Duration duration = const Duration(seconds: 3),
}) {
  return _showAppFeedbackBottomSheet(
    context,
    type: AppFeedbackType.success,
    message: message,
    title: title,
    duration: duration,
  );
}

Future<void> _showAppFeedbackBottomSheet(
  BuildContext context, {
  required AppFeedbackType type,
  required String message,
  required Duration duration,
  String? title,
}) {
  if (!context.mounted) return Future<void>.value();

  return showMaterialModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (_) => AppFeedbackSheet(
      type: type,
      message: message,
      title: title,
      duration: duration,
    ),
  );
}

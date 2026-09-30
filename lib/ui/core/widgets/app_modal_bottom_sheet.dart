import 'package:flutter/material.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

/// Shared wrapper for interactive sheets.
///
/// Keeping this entry point in `ui/core` makes all sheets use the same route
/// implementation while preserving each feature's content and callbacks.
Future<T?> showAppModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool expand = false,
  bool useSafeArea = false,
  bool isDismissible = true,
  bool enableDrag = true,
  Color? backgroundColor = Colors.transparent,
}) {
  return showMaterialModalBottomSheet<T>(
    context: context,
    expand: expand,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    backgroundColor: backgroundColor,
    builder: useSafeArea
        ? (sheetContext) => SafeArea(child: builder(sheetContext))
        : builder,
  );
}

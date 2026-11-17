import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

typedef MirrorTouchCallback =
    void Function(
      int action,
      int pointerId,
      int x,
      int y,
    );

typedef MirrorScrollCallback = void Function(int x, int y, int deltaY);

/// Shared scrcpy texture used by both the individual and multi-mirror flows.
///
/// It owns only rendering and pointer-coordinate translation. Session state,
/// native IO and evidence operations remain in their ViewModels/repositories.
class InteractiveMirrorTexture extends StatelessWidget {
  const InteractiveMirrorTexture({
    required this.textureId,
    required this.videoSize,
    required this.onTouch,
    required this.onScroll,
    this.interactionEnabled = true,
    super.key,
  });

  final int textureId;
  final Size videoSize;
  final MirrorTouchCallback onTouch;
  final MirrorScrollCallback onScroll;
  final bool interactionEnabled;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth <= 0 ||
          constraints.maxHeight <= 0 ||
          videoSize.width <= 0 ||
          videoSize.height <= 0) {
        return const SizedBox.shrink();
      }

      final available = Size(
        constraints.maxWidth,
        constraints.maxHeight,
      );
      final deviceAspect = videoSize.aspectRatio;
      final renderWidth = deviceAspect > available.aspectRatio
          ? available.width
          : available.height * deviceAspect;
      final renderHeight = deviceAspect > available.aspectRatio
          ? available.width / deviceAspect
          : available.height;

      (int, int) translatedPosition(PointerEvent event) {
        final maxX = math.max(0, videoSize.width.round() - 1);
        final maxY = math.max(0, videoSize.height.round() - 1);
        final x = (event.localPosition.dx * videoSize.width / renderWidth)
            .clamp(0, maxX)
            .round();
        final y = (event.localPosition.dy * videoSize.height / renderHeight)
            .clamp(0, maxY)
            .round();
        return (x, y);
      }

      void sendTouch(int action, PointerEvent event) {
        final (x, y) = translatedPosition(event);
        onTouch(action, event.pointer, x, y);
      }

      void sendScroll(PointerScrollEvent event) {
        final (x, y) = translatedPosition(event);
        onScroll(x, y, event.scrollDelta.dy.round());
      }

      return Center(
        child: SizedBox(
          width: renderWidth,
          height: renderHeight,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: interactionEnabled
                ? (event) => sendTouch(0, event)
                : null,
            onPointerMove: interactionEnabled
                ? (event) => sendTouch(2, event)
                : null,
            onPointerUp: interactionEnabled
                ? (event) => sendTouch(1, event)
                : null,
            onPointerCancel: interactionEnabled
                ? (event) => sendTouch(1, event)
                : null,
            onPointerSignal: interactionEnabled
                ? (event) {
                    if (event is PointerScrollEvent) sendScroll(event);
                  }
                : null,
            child: Texture(textureId: textureId),
          ),
        ),
      );
    },
  );
}

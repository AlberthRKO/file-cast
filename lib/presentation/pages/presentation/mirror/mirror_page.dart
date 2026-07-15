import 'dart:async';

import 'package:file_cast/core/adb/adb_client.dart';
import 'package:flutter/material.dart';

class MirrorPage extends StatefulWidget {
  const MirrorPage({
    required this.textureId,
    required this.videoWidth,
    required this.videoHeight,
    required this.controlLocalId,
    required this.deviceName,
    super.key,
  });
  final int textureId;
  final int videoWidth;
  final int videoHeight;
  final int controlLocalId;
  final String deviceName;

  @override
  State<MirrorPage> createState() => _MirrorPageState();
}

class _MirrorPageState extends State<MirrorPage> {
  final AdbClient _adbClient = AdbClient();
  String _mirrorLog = '';
  Timer? _mirrorLogTimer;

  bool _showControls = false;
  bool _showLogs = false;

  @override
  void initState() {
    super.initState();
    _mirrorLogTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted) return;
      final log = await _adbClient.getMirrorLog();
      if (mounted) setState(() => _mirrorLog = log);
    });
  }

  @override
  void dispose() {
    _mirrorLogTimer?.cancel();
    super.dispose();
  }

  Offset _widgetToDevice(Offset widgetPos, Size widgetSize, double offsetX, double offsetY) {
    final scaleX = widget.videoWidth / widgetSize.width;
    final scaleY = widget.videoHeight / widgetSize.height;
    return Offset(
      (widgetPos.dx * scaleX).clamp(0, widget.videoWidth.toDouble()),
      (widgetPos.dy * scaleY).clamp(0, widget.videoHeight.toDouble()),
    );
  }

  void _handlePointerDown(PointerDownEvent event, Size layoutSize, double offsetX, double offsetY) {
    final device = _widgetToDevice(event.localPosition, layoutSize, offsetX, offsetY);
    _sendTouchSafe(0, device.dx.toInt(), device.dy.toInt());
  }

  void _handlePointerMove(PointerMoveEvent event, Size layoutSize, double offsetX, double offsetY) {
    final device = _widgetToDevice(event.localPosition, layoutSize, offsetX, offsetY);
    _sendTouchSafe(2, device.dx.toInt(), device.dy.toInt());
  }

  void _handlePointerUp(PointerEvent event, Size layoutSize, double offsetX, double offsetY) {
    final device = _widgetToDevice(event.localPosition, layoutSize, offsetX, offsetY);
    _sendTouchSafe(1, device.dx.toInt(), device.dy.toInt());
  }

  void _sendTouchSafe(int action, int x, int y) {
    _adbClient.sendTouch(
      action, x, y,
      widget.videoWidth, widget.videoHeight,
    );
  }

  void _sendKeySafe(String label, Future<void> Function() sender) async {
    try {
      await sender();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$label error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        title: Text(
          widget.deviceName,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showControls ? Icons.gamepad : Icons.touch_app,
              color: _showControls ? Colors.blue : Colors.white,
            ),
            onPressed: () => setState(() => _showControls = !_showControls),
            tooltip: _showControls ? 'Ocultar controles' : 'Mostrar controles',
          ),
          IconButton(
            icon: Icon(
              _showLogs ? Icons.bug_report : Icons.terminal,
              color: _showLogs ? Colors.orange : Colors.white,
            ),
            onPressed: () => setState(() => _showLogs = !_showLogs),
            tooltip: _showLogs ? 'Ocultar logs' : 'Mostrar logs',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Mirror display (full screen behind everything)
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final available = Size(
                  constraints.maxWidth,
                  constraints.maxHeight,
                );
                final deviceAspect = widget.videoWidth / widget.videoHeight;
                final availAspect = available.width / available.height;

                double renderW, renderH;
                if (deviceAspect > availAspect) {
                  renderW = available.width;
                  renderH = available.width / deviceAspect;
                } else {
                  renderH = available.height;
                  renderW = available.height * deviceAspect;
                }
                final renderSize = Size(renderW, renderH);

                final offsetX = (available.width - renderW) / 2;
                final offsetY = (available.height - renderH) / 2;

                return Stack(
                  children: [
                    Positioned(
                      left: offsetX,
                      top: offsetY,
                      width: renderW,
                      height: renderH,
                      child: Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: (e) => _handlePointerDown(e, renderSize, offsetX, offsetY),
                        onPointerMove: (e) => _handlePointerMove(e, renderSize, offsetX, offsetY),
                        onPointerUp: (e) => _handlePointerUp(e, renderSize, offsetX, offsetY),
                        onPointerCancel: (e) => _handlePointerUp(e, renderSize, offsetX, offsetY),
                        child: Texture(textureId: widget.textureId),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Floating controls panel
          if (_showControls)
            Positioned(
              left: 16,
              bottom: 16,
              child: _DraggablePanel(
                initialOffset: const Offset(16, 0),
                child: _buildControlsPanel(),
              ),
            ),

          // Floating logs panel
          if (_showLogs)
            Positioned(
              right: 16,
              top: 16,
              child: _DraggablePanel(
                initialOffset: const Offset(0, 80),
                child: _buildLogsPanel(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControlsPanel() {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Controles',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ControlButton(
                icon: Icons.arrow_back,
                label: 'Back',
                onTap: () => _sendKeySafe('Back', _adbClient.sendBack),
              ),
              _ControlButton(
                icon: Icons.home,
                label: 'Home',
                onTap: () => _sendKeySafe('Home', _adbClient.sendHome),
              ),
              _ControlButton(
                icon: Icons.crop_square,
                label: 'Recents',
                onTap: () => _sendKeySafe('Recents', _adbClient.sendAppSwitch),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ControlButton(
                icon: Icons.volume_up,
                label: 'Vol+',
                onTap: () => _sendKeySafe('VolUp', _adbClient.sendVolumeUp),
              ),
              _ControlButton(
                icon: Icons.volume_down,
                label: 'Vol-',
                onTap: () => _sendKeySafe('VolDown', _adbClient.sendVolumeDown),
              ),
              _ControlButton(
                icon: Icons.power_settings_new,
                label: 'Power',
                onTap: () => _sendKeySafe('Power', _adbClient.sendPower),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogsPanel() {
    return Container(
      width: 280,
      height: 200,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Logs',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(4),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  _mirrorLog.isEmpty ? 'Waiting for data...' : _mirrorLog,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    color: Colors.green.shade300,
                    height: 1.3,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DraggablePanel extends StatefulWidget {
  const _DraggablePanel({
    required this.child,
    this.initialOffset = Offset.zero,
  });
  final Widget child;
  final Offset initialOffset;

  @override
  State<_DraggablePanel> createState() => _DraggablePanelState();
}

class _DraggablePanelState extends State<_DraggablePanel> {
  late Offset _offset;

  @override
  void initState() {
    super.initState();
    _offset = widget.initialOffset;
  }

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: _offset,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _offset += details.delta;
          });
        },
        child: widget.child,
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

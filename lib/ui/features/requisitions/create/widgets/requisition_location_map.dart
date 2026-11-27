import 'package:file_cast/domain/models/requisition_creation.dart';
import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class RequisitionLocationMap extends StatefulWidget {
  const RequisitionLocationMap({
    required this.location,
    required this.currentUserLocation,
    required this.isLocating,
    required this.onLocationChanged,
    required this.onRequestCurrentLocation,
    super.key,
  });

  final GeoPoint location;
  final GeoPoint? currentUserLocation;
  final bool isLocating;
  final ValueChanged<GeoPoint> onLocationChanged;
  final Future<void> Function() onRequestCurrentLocation;

  @override
  State<RequisitionLocationMap> createState() => _RequisitionLocationMapState();
}

class _RequisitionLocationMapState extends State<RequisitionLocationMap>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  late final AnimationController _pulseController;
  AnimationController? _cameraAnimation;
  LatLng? _lastGestureCenter;
  bool _isMapReady = false;
  bool _showSatellite = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant RequisitionLocationMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final locationChanged =
        oldWidget.location.latitude != widget.location.latitude ||
        oldWidget.location.longitude != widget.location.longitude;
    if (!locationChanged || !_isMapReady) return;

    final nextCenter = LatLng(
      widget.location.latitude,
      widget.location.longitude,
    );
    if (_lastGestureCenter != null &&
        _samePoint(nextCenter, _lastGestureCenter!)) {
      _lastGestureCenter = null;
      return;
    }
    _animateTo(nextCenter, _mapController.camera.zoom);
  }

  @override
  void dispose() {
    _cameraAnimation?.dispose();
    _pulseController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  bool _samePoint(LatLng first, LatLng second) =>
      (first.latitude - second.latitude).abs() < 0.0000001 &&
      (first.longitude - second.longitude).abs() < 0.0000001;

  bool _userLocationOverlapsCenter(GeoPoint? userPosition) =>
      userPosition != null &&
      (userPosition.latitude - widget.location.latitude).abs() < 0.000001 &&
      (userPosition.longitude - widget.location.longitude).abs() < 0.000001;

  Widget _pulsingLocationIndicator(ThemeData theme) {
    return SizedBox.square(
      dimension: 52,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, _) {
          final progress = _pulseController.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: (1 - progress) * .58,
                child: Transform.scale(
                  scale: .65 + (progress * 1.1),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.primary,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.colorScheme.surface,
                    width: 2,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _animateTo(LatLng point, double zoom) {
    if (!_isMapReady) return;
    final previousAnimation = _cameraAnimation;
    _cameraAnimation = null;
    previousAnimation?.dispose();

    final camera = _mapController.camera;
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _cameraAnimation = controller;
    final animation = CurvedAnimation(
      parent: controller,
      curve: Curves.easeOutCubic,
    );
    final latitude = Tween<double>(
      begin: camera.center.latitude,
      end: point.latitude,
    ).animate(animation);
    final longitude = Tween<double>(
      begin: camera.center.longitude,
      end: point.longitude,
    ).animate(animation);
    final targetZoom = Tween<double>(begin: camera.zoom, end: zoom).animate(
      animation,
    );

    controller.addListener(() {
      if (!_isMapReady) return;
      _mapController.move(
        LatLng(latitude.value, longitude.value),
        targetZoom.value,
      );
    });
    controller.addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      if (identical(_cameraAnimation, controller)) _cameraAnimation = null;
      controller.dispose();
    });
    controller.forward();
  }

  void _zoomBy(double amount) {
    if (!_isMapReady) return;
    _animateTo(
      _mapController.camera.center,
      (_mapController.camera.zoom + amount).clamp(2.0, 19.0).toDouble(),
    );
  }

  Future<void> _locateOrFocus() async {
    final currentLocation = widget.currentUserLocation;
    if (currentLocation == null) {
      await widget.onRequestCurrentLocation();
      return;
    }
    widget.onLocationChanged(
      GeoPoint(
        latitude: currentLocation.latitude,
        longitude: currentLocation.longitude,
        label: widget.location.label,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userPosition = widget.currentUserLocation;
    final userLocationOverlapsCenter = _userLocationOverlapsCenter(
      userPosition,
    );
    final compactHeight = MediaQuery.sizeOf(context).height < 480;
    final mapHeight = compactHeight
        ? 210.0
        : MediaQuery.sizeOf(context).width < 380
        ? 230.0
        : 280.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final effectiveHeight = constraints.maxWidth < 330 && !compactHeight
            ? 210.0
            : mapHeight;
        return SizedBox(
          height: effectiveHeight,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.m),
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: LatLng(
                      widget.location.latitude,
                      widget.location.longitude,
                    ),
                    initialZoom: 15,
                    onMapReady: () {
                      if (mounted) setState(() => _isMapReady = true);
                    },
                    onPositionChanged: (camera, hasGesture) {
                      if (!hasGesture) return;
                      final center = camera.center;
                      _lastGestureCenter = center;
                      widget.onLocationChanged(
                        GeoPoint(
                          latitude: center.latitude,
                          longitude: center.longitude,
                          label: widget.location.label,
                        ),
                      );
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: _showSatellite
                          ? 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}'
                          : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'bo.fiscalia.file_cast',
                    ),
                    if (userPosition != null && !userLocationOverlapsCenter)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(
                              userPosition.latitude,
                              userPosition.longitude,
                            ),
                            width: 52,
                            height: 52,
                            child: _pulsingLocationIndicator(theme),
                          ),
                        ],
                      ),
                  ],
                ),
                const IgnorePointer(
                  child: Center(
                    child: Icon(
                      Icons.location_pin,
                      color: Colors.red,
                      size: 48,
                    ),
                  ),
                ),
                if (userLocationOverlapsCenter)
                  IgnorePointer(
                    child: Center(
                      child: _pulsingLocationIndicator(theme),
                    ),
                  ),
                Positioned(
                  top: AppSpace.s,
                  right: AppSpace.s,
                  child: Column(
                    children: [
                      _MapControlButton(
                        tooltip: 'Acercar',
                        icon: Icons.add_rounded,
                        onPressed: _isMapReady ? () => _zoomBy(1) : null,
                      ),
                      const SizedBox(height: AppSpace.xs),
                      _MapControlButton(
                        tooltip: 'Alejar',
                        icon: Icons.remove_rounded,
                        onPressed: _isMapReady ? () => _zoomBy(-1) : null,
                      ),
                      const SizedBox(height: AppSpace.xs),
                      _MapControlButton(
                        tooltip: _showSatellite
                            ? 'Mostrar mapa normal'
                            : 'Mostrar mapa satelital',
                        icon: _showSatellite
                            ? Icons.map_outlined
                            : Icons.satellite_alt_rounded,
                        onPressed: () => setState(
                          () => _showSatellite = !_showSatellite,
                        ),
                      ),
                      const SizedBox(height: AppSpace.xs),
                      _MapControlButton(
                        tooltip: widget.currentUserLocation == null
                            ? 'Usar mi ubicación'
                            : 'Enfocar mi ubicación',
                        icon: widget.isLocating
                            ? null
                            : widget.currentUserLocation == null
                            ? Icons.my_location_rounded
                            : Icons.gps_fixed_rounded,
                        onPressed: widget.isLocating || !_isMapReady
                            ? null
                            : _locateOrFocus,
                        isLoading: widget.isLocating,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MapControlButton extends StatelessWidget {
  const _MapControlButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.isLoading = false,
  });

  final String tooltip;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.cardColor,
      elevation: 3,
      borderRadius: BorderRadius.circular(AppRadius.s),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        constraints: const BoxConstraints.tightFor(
          width: AppSize.minTouchTarget,
          height: AppSize.minTouchTarget,
        ),
        icon: isLoading
            ? const SizedBox.square(
                dimension: AppSize.iconS,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon, color: theme.colorScheme.primary),
      ),
    );
  }
}

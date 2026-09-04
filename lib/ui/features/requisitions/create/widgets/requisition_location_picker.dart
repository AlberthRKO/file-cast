import 'package:file_cast/domain/models/requisition_creation.dart';
import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:file_cast/ui/core/widgets/app_form_input_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class RequisitionLocationPicker extends StatefulWidget {
  const RequisitionLocationPicker({
    required this.initialPoint,
    super.key,
  });

  final GeoPoint? initialPoint;

  @override
  State<RequisitionLocationPicker> createState() =>
      _RequisitionLocationPickerState();
}

class _RequisitionLocationPickerState extends State<RequisitionLocationPicker> {
  late double _latitude;
  late double _longitude;
  late final TextEditingController _labelController;

  @override
  void initState() {
    super.initState();
    _latitude = widget.initialPoint?.latitude ?? -19.0478;
    _longitude = widget.initialPoint?.longitude ?? -65.2592;
    _labelController = TextEditingController(text: widget.initialPoint?.label);
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.cardColor,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadius.l),
      ),
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 560,
            maxHeight: MediaQuery.sizeOf(context).height * .9,
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              AppSpace.m,
              AppSpace.s,
              AppSpace.m,
              AppSpace.m + MediaQuery.paddingOf(context).bottom,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.m),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Capturar ubicacion',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.s),
                  _MapView(
                    latitude: _latitude,
                    longitude: _longitude,
                    onChanged: (point) => setState(() {
                      _latitude = point.latitude;
                      _longitude = point.longitude;
                    }),
                  ),
                  const SizedBox(height: AppSpace.m),
                  Row(
                    children: [
                      Expanded(
                        child: _CoordinateField(
                          label: 'Latitud',
                          value: _latitude,
                          onChanged: (value) =>
                              setState(() => _latitude = value),
                        ),
                      ),
                      const SizedBox(width: AppSpace.s),
                      Expanded(
                        child: _CoordinateField(
                          label: 'Longitud',
                          value: _longitude,
                          onChanged: (value) =>
                              setState(() => _longitude = value),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.s),
                  TextField(
                    controller: _labelController,
                    style: theme.textTheme.bodyLarge,
                    cursorColor: theme.textTheme.bodyLarge?.color,
                    decoration: const InputDecoration(
                      labelText: 'Referencia o direccion',
                      prefixIcon: AppFormInputIcon(
                        asset: 'assets/images/icons/punto.svg',
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpace.m),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(
                      GeoPoint(
                        latitude: _latitude,
                        longitude: _longitude,
                        label: _labelController.text.trim().isEmpty
                            ? null
                            : _labelController.text.trim(),
                      ),
                    ),
                    icon: const Icon(Icons.check_circle_rounded),
                    label: const Text('Usar ubicacion'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CoordinateField extends StatefulWidget {
  const _CoordinateField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  State<_CoordinateField> createState() => _CoordinateFieldState();
}

class _MapView extends StatelessWidget {
  const _MapView({
    required this.latitude,
    required this.longitude,
    required this.onChanged,
  });
  final double latitude;
  final double longitude;
  final ValueChanged<LatLng> onChanged;

  @override
  Widget build(BuildContext context) {
    final center = LatLng(latitude, longitude);
    return SizedBox(
      height: 270,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.m),
        child: Stack(
          alignment: Alignment.center,
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: center,
                initialZoom: 15,
                onPositionChanged: (camera, hasGesture) {
                  if (hasGesture) onChanged(camera.center);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'bo.fiscalia.file_cast',
                ),
              ],
            ),
            const Icon(Icons.location_pin, color: Colors.red, size: 48),
          ],
        ),
      ),
    );
  }
}

class _CoordinateFieldState extends State<_CoordinateField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.toStringAsFixed(6));
  }

  @override
  void didUpdateWidget(covariant _CoordinateField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextText = widget.value.toStringAsFixed(6);
    if (_controller.text != nextText) {
      _controller.value = TextEditingValue(
        text: nextText,
        selection: TextSelection.collapsed(offset: nextText.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      keyboardType: const TextInputType.numberWithOptions(
        signed: true,
        decimal: true,
      ),
      style: Theme.of(context).textTheme.bodyLarge,
      cursorColor: Theme.of(context).textTheme.bodyLarge?.color,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: const AppFormInputIcon(
          asset: 'assets/images/icons/coordenadas.svg',
        ),
      ),
      onChanged: (text) {
        final parsed = double.tryParse(text);
        if (parsed != null) widget.onChanged(parsed);
      },
    );
  }
}

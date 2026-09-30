import 'package:file_cast/domain/models/requisition.dart';
import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:file_cast/ui/core/widgets/app_form_input_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Visor de solo lectura para las coordenadas persistidas en una requisa.
class RequisitionLocationViewer extends StatelessWidget {
  const RequisitionLocationViewer({
    required this.location,
    required this.onClose,
    super.key,
  });

  final RequisitionLocation location;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final center = LatLng(location.latitude, location.longitude);

    return Material(
      color: theme.cardColor,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadius.l),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.m,
            AppSpace.s,
            AppSpace.m,
            AppSpace.m,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Lugar del hecho',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar',
                      onPressed: onClose,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.s),
                SizedBox(
                  height: 280,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.m),
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: center,
                        initialZoom: 15,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'bo.fiscalia.file_cast',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: center,
                              width: 48,
                              height: 48,
                              child: const Icon(
                                Icons.location_pin,
                                color: Colors.red,
                                size: 48,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.m),
                Row(
                  children: [
                    Expanded(
                      child: _CoordinateValue(
                        label: 'Latitud',
                        value: location.latitude,
                      ),
                    ),
                    const SizedBox(width: AppSpace.s),
                    Expanded(
                      child: _CoordinateValue(
                        label: 'Longitud',
                        value: location.longitude,
                      ),
                    ),
                  ],
                ),
                if (location.label?.isNotEmpty == true) ...[
                  const SizedBox(height: AppSpace.s),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Referencia o dirección',
                      prefixIcon: AppFormInputIcon(
                        asset: 'assets/images/icons/punto.svg',
                      ),
                    ),
                    child: Text(location.label!),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CoordinateValue extends StatelessWidget {
  const _CoordinateValue({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const AppFormInputIcon(
          asset: 'assets/images/icons/coordenadas.svg',
        ),
      ),
      child: Text(value.toStringAsFixed(6)),
    );
  }
}

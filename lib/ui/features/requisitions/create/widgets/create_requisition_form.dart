import 'package:file_cast/domain/models/requisition_creation.dart';
import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:file_cast/ui/core/widgets/app_form_input_icon.dart';
import 'package:file_cast/ui/core/widgets/app_modal_bottom_sheet.dart';
import 'package:file_cast/ui/features/requisitions/create/view_models/create_requisition_state.dart';
import 'package:file_cast/ui/features/requisitions/create/view_models/create_requisition_view_model.dart';
import 'package:file_cast/ui/features/requisitions/create/widgets/requisition_location_map.dart';
import 'package:file_cast/ui/features/requisitions/widgets/case_subjects_sheet.dart';
import 'package:file_cast/ui/features/requisitions/widgets/requisition_case_card.dart';
import 'package:file_cast/ui/features/requisitions/widgets/requisition_person_selection_card.dart';
import 'package:file_cast/ui/features/requisitions/widgets/requisition_section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

class CreateRequisitionForm extends StatefulWidget {
  const CreateRequisitionForm({
    required this.viewModel,
    required this.compact,
    required this.onCancel,
    super.key,
  });

  final CreateRequisitionViewModel viewModel;
  final bool compact;
  final VoidCallback onCancel;

  @override
  State<CreateRequisitionForm> createState() => _CreateRequisitionFormState();
}

class _CreateRequisitionFormState extends State<CreateRequisitionForm> {
  late final FocusNode _cudFocusNode;
  late final FocusNode _personFocusNode;
  late final TextEditingController _cudController;
  late final TextEditingController _personController;

  @override
  void initState() {
    super.initState();
    _cudFocusNode = FocusNode(debugLabel: 'requisition-cud-search');
    _personFocusNode = FocusNode(debugLabel: 'requisition-person-search');
    _cudController = TextEditingController();
    _personController = TextEditingController();
  }

  @override
  void dispose() {
    _cudFocusNode.dispose();
    _personFocusNode.dispose();
    _cudController.dispose();
    _personController.dispose();
    super.dispose();
  }

  void _changeMode(RequisitionRegistrationMode mode) {
    // Cierra el teclado antes de reemplazar el formulario de cada modo.
    _cudFocusNode.unfocus();
    _personFocusNode.unfocus();
    _cudController.clear();
    _personController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.viewModel.setMode(mode);
    });
  }

  Future<void> _searchCud() async {
    if (!_cudFocusNode.hasFocus) {
      _cudFocusNode.requestFocus();
      await Future<void>.delayed(Duration.zero);
    }
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    await widget.viewModel.searchCases();
    if (mounted) {
      await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.viewModel.state;

    return Column(
      children: [
        _Header(onClose: widget.onCancel),
        Expanded(
          child: ListView(
            padding: EdgeInsets.all(
              widget.compact ? AppSpace.m : AppSpace.l,
            ),
            children: [
              _ModeSelector(
                mode: state.mode,
                onChanged: _changeMode,
              ),
              const SizedBox(height: AppSpace.m),
              if (state.mode == RequisitionRegistrationMode.existingCud)
                _ExistingCudSection(
                  state: state,
                  focusNode: _cudFocusNode,
                  controller: _cudController,
                  onQueryChanged: widget.viewModel.updateCudQuery,
                  onSearch: _searchCud,
                  onSelected: widget.viewModel.selectCase,
                )
              else
                _PersonLookupSection(
                  state: state,
                  focusNode: _personFocusNode,
                  controller: _personController,
                  onQueryChanged: widget.viewModel.updatePersonQuery,
                  onSearch: widget.viewModel.searchPerson,
                ),
              const SizedBox(height: AppSpace.m),
              _ProcedureSection(
                state: state,
                onDateChanged: widget.viewModel.updateProcedureAt,
                onLocationChanged: widget.viewModel.updateLocation,
                onLocationLabelChanged: widget.viewModel.updateLocationLabel,
                onCaptureLocation: _captureCurrentLocation,
              ),
            ],
          ),
        ),
        _Footer(
          isSubmitting: state.isSubmitting,
          canSubmit: state.canSubmit,
          onSubmit: widget.viewModel.submit,
        ),
      ],
    );
  }

  Future<void> _captureCurrentLocation() async {
    await widget.viewModel.captureCurrentLocation();
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.m,
        AppSpace.m,
        AppSpace.m,
        AppSpace.s,
      ),
      child: Row(
        children: [
          Container(
            width: AppSize.minTouchTarget,
            height: AppSize.minTouchTarget,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.m),
            ),
            child: SvgPicture.asset(
              'assets/images/icons/file.svg',
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(
                theme.colorScheme.primary,
                BlendMode.srcIn,
              ),
            ),
          ),
          const SizedBox(width: AppSpace.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Registrar nueva requisa',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  'Completa los datos para iniciar el procedimiento.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withValues(
                      alpha: 0.65,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Cerrar',
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({
    required this.mode,
    required this.onChanged,
  });

  final RequisitionRegistrationMode mode;
  final ValueChanged<RequisitionRegistrationMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = <bool>[
      mode == RequisitionRegistrationMode.existingCud,
      mode == RequisitionRegistrationMode.withoutCud,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(label: 'Modalidad de registro'),
        const SizedBox(height: AppSpace.s),
        LayoutBuilder(
          builder: (context, constraints) {
            final vertical = constraints.maxWidth < 460;
            if (vertical) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ModeButton(
                    selected: selected[0],
                    icon: Icons.link_rounded,
                    label: 'Vincular a CUD existente',
                    onPressed: () => onChanged(
                      RequisitionRegistrationMode.existingCud,
                    ),
                  ),
                  const SizedBox(height: AppSpace.s),
                  _ModeButton(
                    selected: selected[1],
                    icon: Icons.person_add_alt_1_rounded,
                    label: 'Sin CUD - Registrar persona',
                    onPressed: () => onChanged(
                      RequisitionRegistrationMode.withoutCud,
                    ),
                  ),
                ],
              );
            }
            return ToggleButtons(
              isSelected: selected,
              onPressed: (index) => onChanged(
                index == 0
                    ? RequisitionRegistrationMode.existingCud
                    : RequisitionRegistrationMode.withoutCud,
              ),
              borderRadius: BorderRadius.circular(AppRadius.s),
              constraints: const BoxConstraints(
                minHeight: AppSize.minTouchTarget,
              ),
              children: [
                _ModeItem(
                  icon: Icons.link_rounded,
                  label: 'Vincular a CUD existente',
                  expanded: !vertical,
                  selected: selected[0],
                ),
                _ModeItem(
                  icon: Icons.person_add_alt_1_rounded,
                  label: 'Sin CUD - Registrar persona',
                  expanded: !vertical,
                  selected: selected[1],
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (selected) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(selected ? Icons.check_circle_rounded : icon),
        label: Text(label),
      );
    }

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

class _ModeItem extends StatelessWidget {
  const _ModeItem({
    required this.icon,
    required this.label,
    required this.expanded,
    required this.selected,
  });

  final IconData icon;
  final String label;
  final bool expanded;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: expanded ? 278 : double.infinity,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            selected ? Icons.check_circle_rounded : icon,
            size: AppSize.iconS,
          ),
          const SizedBox(width: AppSpace.s),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _CaseSuggestionCard extends StatelessWidget {
  const _CaseSuggestionCard({
    required this.caseSummary,
    required this.onTap,
  });

  final EcosystemCaseSummary caseSummary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return RequisitionCaseCard(
      cud: caseSummary.cud,
      caseType: caseSummary.type,
      division: caseSummary.division,
      statusLabel: caseSummary.status,
      flatStyle: true,
      stageLabel: caseSummary.stage,
      locationLabel: caseSummary.location,
      crimes: caseSummary.crimes,
      score: caseSummary.score,
      timerLabel: caseSummary.timerLabel,
      timerEndsAt: caseSummary.timerEndsAt,
      timerPaused: caseSummary.timerPaused,
      onTap: onTap,
    );
  }
}

class _ExistingCudSection extends StatelessWidget {
  const _ExistingCudSection({
    required this.state,
    required this.focusNode,
    required this.controller,
    required this.onQueryChanged,
    required this.onSearch,
    required this.onSelected,
  });

  final CreateRequisitionState state;
  final FocusNode focusNode;
  final TextEditingController controller;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onSearch;
  final ValueChanged<EcosystemCaseSummary> onSelected;

  @override
  Widget build(BuildContext context) {
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final maxSuggestionsHeight = viewportHeight < 480
        ? 200.0
        : viewportHeight < 680
        ? 300.0
        : 420.0;
    return RequisitionSectionCard(
      icon: Icons.folder_rounded,
      title: 'Casos del ecosistema',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _RequiredLabel(label: 'Numero de CUD'),
          const SizedBox(height: AppSpace.s),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 420;
              final canSearch =
                  state.selectedCase == null &&
                  state.cudQuery.trim().length >= 4 &&
                  state.caseSearchPhase != AsyncPhase.loading;
              final field = Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onChanged: onQueryChanged,
                  textInputAction: TextInputAction.search,
                  style: Theme.of(context).textTheme.bodyLarge,
                  onSubmitted: (_) {
                    if (canSearch) onSearch();
                  },
                  decoration: InputDecoration(
                    labelText: 'Buscar por Nro de caso, caratula o imputado...',
                    labelStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: .5),
                      height: 1,
                    ),
                    prefixIcon: const AppFormInputIcon(
                      asset: 'assets/images/icons/search.svg',
                    ),
                    errorText: state.cudError,
                  ),
                ),
              );
              final searchButton = compact
                  ? IconButton.filledTonal(
                      tooltip: 'Buscar CUD',
                      onPressed: canSearch ? onSearch : null,
                      icon: const Icon(Icons.search_rounded),
                    )
                  : FilledButton.icon(
                      onPressed: canSearch ? onSearch : null,
                      icon: const Icon(Icons.search_rounded),
                      label: const Text('Buscar'),
                    );
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  field,
                  const SizedBox(width: AppSpace.s),
                  searchButton,
                ],
              );
            },
          ),
          ListenableBuilder(
            listenable: focusNode,
            builder: (context, _) {
              if (!focusNode.hasFocus ||
                  state.selectedCase != null ||
                  state.caseResults.isEmpty) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: AppSpace.xs),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxSuggestionsHeight),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: state.caseResults.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpace.xs),
                    itemBuilder: (context, index) {
                      final item = state.caseResults[index];
                      return _CaseSuggestionCard(
                        caseSummary: item,
                        onTap: () {
                          focusNode.unfocus();
                          onSelected(item);
                        },
                      );
                    },
                  ),
                ),
              );
            },
          ),
          if (state.selectedCase == null &&
              state.caseSearchPhase == AsyncPhase.loading)
            const LinearProgressIndicator(),
          if (state.selectedCase != null) ...[
            const SizedBox(height: AppSpace.m),
            _SelectedCaseCard(
              caseSummary: state.selectedCase!,
              onChange: () {
                controller.clear();
                onQueryChanged('');
              },
            ),
          ],
          const SizedBox(height: AppSpace.s),
          const _MutedHelp(
            text:
                'Ingresa el CUD y presiona Buscar. Luego selecciona el caso para continuar.',
          ),
        ],
      ),
    );
  }
}

class _PersonLookupSection extends StatelessWidget {
  const _PersonLookupSection({
    required this.state,
    required this.focusNode,
    required this.controller,
    required this.onQueryChanged,
    required this.onSearch,
  });

  final CreateRequisitionState state;
  final FocusNode focusNode;
  final TextEditingController controller;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return RequisitionSectionCard(
      icon: Icons.person_search_rounded,
      title: 'Persona sin CUD',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _RequiredLabel(label: 'Carnet de identidad'),
          const SizedBox(height: AppSpace.s),
          if (state.selectedPerson == null)
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 420;
                final canSearch =
                    state.personQuery.trim().length >= 4 &&
                    state.personSearchPhase != AsyncPhase.loading;
                final field = Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.search,
                    onChanged: onQueryChanged,
                    onSubmitted: (_) {
                      if (canSearch) onSearch();
                    },
                    style: Theme.of(context).textTheme.bodyLarge,
                    decoration: InputDecoration(
                      labelText: 'Buscar por CI',
                      labelStyle: Theme.of(context).textTheme.bodyLarge
                          ?.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: .5),
                            height: 1,
                          ),
                      prefixIcon: const AppFormInputIcon(
                        asset: 'assets/images/icons/cardEmployee.svg',
                      ),
                      errorText: state.personError,
                    ),
                  ),
                );
                final searchButton = compact
                    ? IconButton.filledTonal(
                        tooltip: 'Buscar persona',
                        onPressed: canSearch ? onSearch : null,
                        icon: const Icon(Icons.search_rounded),
                      )
                    : FilledButton.icon(
                        onPressed: canSearch ? onSearch : null,
                        icon: const Icon(Icons.search_rounded),
                        label: const Text('Buscar'),
                      );
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    field,
                    const SizedBox(width: AppSpace.s),
                    searchButton,
                  ],
                );
              },
            ),
          if (state.personSearchPhase == AsyncPhase.loading)
            const Padding(
              padding: EdgeInsets.only(top: AppSpace.s),
              child: LinearProgressIndicator(),
            ),
          if (state.personSearchPhase == AsyncPhase.empty)
            const Padding(
              padding: EdgeInsets.only(top: AppSpace.s),
              child: _MutedHelp(text: 'No encontramos una persona con ese CI.'),
            ),
          if (state.selectedPerson != null) ...[
            const SizedBox(height: AppSpace.m),
            _SelectedPersonCard(
              person: state.selectedPerson!,
              onChange: () {
                controller.clear();
                onQueryChanged('');
              },
            ),
          ],
          const SizedBox(height: AppSpace.s),
          const _MutedHelp(
            text:
                'Ingresa el CI y presiona Buscar. Puedes reemplazar la persona con la X antes de guardar.',
          ),
        ],
      ),
    );
  }
}

class _ProcedureSection extends StatelessWidget {
  const _ProcedureSection({
    required this.state,
    required this.onDateChanged,
    required this.onLocationChanged,
    required this.onLocationLabelChanged,
    required this.onCaptureLocation,
  });

  final CreateRequisitionState state;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<GeoPoint> onLocationChanged;
  final ValueChanged<String> onLocationLabelChanged;
  final Future<void> Function() onCaptureLocation;

  @override
  Widget build(BuildContext context) {
    final date = state.procedureAt;
    final location = state.location;
    return RequisitionSectionCard(
      icon: Icons.history_toggle_off_rounded,
      title: 'Datos del procedimiento',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _RequiredLabel(label: 'Fecha y hora'),
          const SizedBox(height: AppSpace.s),
          _DateTimeField(
            value: date,
            errorText: state.dateError,
            onChanged: onDateChanged,
          ),
          const SizedBox(height: AppSpace.m),
          const _SectionLabel(label: 'Referencia o dirección'),
          const SizedBox(height: AppSpace.s),
          TextField(
            key: const ValueKey('requisition-location-reference'),
            onChanged: onLocationLabelChanged,
            style: Theme.of(context).textTheme.bodyLarge,
            decoration: const InputDecoration(
              labelText: 'Ingresar referencia o dirección',
              prefixIcon: AppFormInputIcon(
                asset: 'assets/images/icons/address.svg',
              ),
            ),
          ),
          const SizedBox(height: AppSpace.m),
          const _SectionLabel(label: 'Ubicación GPS'),
          const SizedBox(height: AppSpace.s),
          if (location != null)
            RequisitionLocationMap(
              location: location,
              currentUserLocation: state.currentUserLocation,
              isLocating: state.isCapturingLocation,
              onLocationChanged: onLocationChanged,
              onRequestCurrentLocation: onCaptureLocation,
            ),
          if (state.locationError != null) ...[
            const SizedBox(height: AppSpace.xs),
            Text(
              state.locationError!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: AppSpace.s),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 420;
              final latitudeField = _CoordinateField(
                label: 'Latitud',
                value: location!.latitude,
                minimum: -90,
                maximum: 90,
                onChanged: (latitude) => onLocationChanged(
                  GeoPoint(
                    latitude: latitude,
                    longitude: location.longitude,
                    label: location.label,
                  ),
                ),
              );
              final longitudeField = _CoordinateField(
                label: 'Longitud',
                value: location.longitude,
                minimum: -180,
                maximum: 180,
                onChanged: (longitude) => onLocationChanged(
                  GeoPoint(
                    latitude: location.latitude,
                    longitude: longitude,
                    label: location.label,
                  ),
                ),
              );
              if (compact) {
                return Column(
                  children: [
                    latitudeField,
                    const SizedBox(height: AppSpace.s),
                    longitudeField,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: latitudeField),
                  const SizedBox(width: AppSpace.s),
                  Expanded(child: longitudeField),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DateTimeField extends StatelessWidget {
  const _DateTimeField({
    required this.value,
    required this.errorText,
    required this.onChanged,
  });

  final DateTime? value;
  final String? errorText;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = value == null
        ? ''
        : DateFormat('dd/MM/yyyy, HH:mm').format(value!);
    return TextField(
      readOnly: true,
      controller: TextEditingController(text: text),
      style: Theme.of(context).textTheme.bodyLarge,
      cursorColor: Theme.of(context).textTheme.bodyLarge?.color,
      onTap: () async {
        final now = value ?? DateTime.now();
        final date = await showDatePicker(
          context: context,
          initialDate: now,
          firstDate: DateTime(2020),
          lastDate: DateTime(2035),
        );
        if (date == null || !context.mounted) return;
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(now),
        );
        if (time == null) return;
        onChanged(
          DateTime(date.year, date.month, date.day, time.hour, time.minute),
        );
      },
      decoration: InputDecoration(
        labelText: 'Seleccionar fecha y hora',
        labelStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: .5),
          height: 1,
        ),
        prefixIcon: const AppFormInputIcon(
          asset: 'assets/images/icons/clock.svg',
        ),
        suffixIcon: const AppFormInputIcon(
          asset: 'assets/images/icons/calendar.svg',
          muted: true,
        ),
        errorText: errorText,
      ),
    );
  }
}

class _CoordinateField extends StatefulWidget {
  const _CoordinateField({
    required this.label,
    required this.value,
    required this.minimum,
    required this.maximum,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double minimum;
  final double maximum;
  final ValueChanged<double> onChanged;

  @override
  State<_CoordinateField> createState() => _CoordinateFieldState();
}

class _CoordinateFieldState extends State<_CoordinateField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _format(widget.value));
    _focusNode = FocusNode()..addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant _CoordinateField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus && oldWidget.value != widget.value) {
      _syncController();
    }
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (_focusNode.hasFocus) return;
    final parsed = double.tryParse(_controller.text.trim());
    if (parsed == null ||
        !parsed.isFinite ||
        parsed < widget.minimum ||
        parsed > widget.maximum) {
      _syncController();
    } else {
      widget.onChanged(parsed);
    }
  }

  void _syncController() {
    final text = _format(widget.value);
    if (_controller.text == text) return;
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  String _format(double value) => value.toStringAsFixed(6);

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      keyboardType: const TextInputType.numberWithOptions(
        signed: true,
        decimal: true,
      ),
      textInputAction: TextInputAction.done,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: const AppFormInputIcon(
          asset: 'assets/images/icons/coordenadas.svg',
        ),
      ),
      onSubmitted: (_) => _focusNode.unfocus(),
      onTapOutside: (_) => _focusNode.unfocus(),
    );
  }
}

class _SelectedCaseCard extends StatelessWidget {
  const _SelectedCaseCard({required this.caseSummary, required this.onChange});

  final EcosystemCaseSummary caseSummary;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    return _CasePenalCard(caseSummary: caseSummary, onRemove: onChange);
  }
}

/// Traducción responsive de CardCasoPenal para el caso seleccionado.
class _CasePenalCard extends StatelessWidget {
  const _CasePenalCard({required this.caseSummary, required this.onRemove});
  final EcosystemCaseSummary caseSummary;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return RequisitionCaseCard(
      cud: caseSummary.cud,
      caseType: caseSummary.type,
      division: caseSummary.division,
      statusLabel: caseSummary.status,
      selectionStyle: true,
      flatStyle: true,
      stageLabel: caseSummary.stage,
      locationLabel: caseSummary.location,
      crimes: caseSummary.crimes,
      score: caseSummary.score,
      timerLabel: caseSummary.timerLabel,
      timerEndsAt: caseSummary.timerEndsAt,
      timerPaused: caseSummary.timerPaused,
      onViewSubjects: () => showAppModalBottomSheet<void>(
        context: context,
        maxWidth: 560,
        builder: (_) => CaseSubjectsSheet.fromEcosystem(
          subjects: caseSummary.caseSubjects,
          fallbackNames: caseSummary.subjects,
        ),
      ),
      onRemove: onRemove,
    );
  }
}

class _SelectedPersonCard extends StatelessWidget {
  const _SelectedPersonCard({required this.person, required this.onChange});

  final PersonSummary person;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    return RequisitionPersonSelectionCard(
      name: person.name,
      ci: person.ci,
      address: person.address,
      phone: person.phone,
      selectionStyle: true,
      uppercaseName: true,
      onRemove: onChange,
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.isSubmitting,
    required this.canSubmit,
    required this.onSubmit,
  });

  final bool isSubmitting;
  final bool canSubmit;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final action = FilledButton.icon(
      onPressed: canSubmit ? onSubmit : null,
      icon: isSubmitting
          ? const SizedBox.square(
              dimension: AppSize.iconS,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.play_circle_fill_rounded),
      label: const Text('Iniciar requisa'),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.16),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.m),
        child: SizedBox(width: double.infinity, child: action),
      ),
    );
  }
}

class _RequiredLabel extends StatelessWidget {
  const _RequiredLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SectionLabel(label: label),
        Text(
          ' *',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _MutedHelp extends StatelessWidget {
  const _MutedHelp({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).textTheme.bodySmall?.color?.withValues(
          alpha: 0.65,
        ),
      ),
    );
  }
}

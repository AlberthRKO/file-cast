import 'package:file_cast/domain/models/requisition_creation.dart';
import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:file_cast/ui/core/widgets/app_form_input_icon.dart';
import 'package:file_cast/ui/features/requisitions/create/view_models/create_requisition_state.dart';
import 'package:file_cast/ui/features/requisitions/create/view_models/create_requisition_view_model.dart';
import 'package:file_cast/ui/features/requisitions/create/widgets/requisition_location_picker.dart';
import 'package:file_cast/ui/features/requisitions/widgets/requisition_case_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:searchfield/searchfield.dart';

class CreateRequisitionForm extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final state = viewModel.state;

    return Column(
      children: [
        _Header(onClose: onCancel),
        Expanded(
          child: ListView(
            padding: EdgeInsets.all(compact ? AppSpace.m : AppSpace.l),
            children: [
              _ModeSelector(
                mode: state.mode,
                onChanged: viewModel.setMode,
              ),
              const SizedBox(height: AppSpace.m),
              if (state.mode == RequisitionRegistrationMode.existingCud)
                _ExistingCudSection(
                  state: state,
                  onQueryChanged: viewModel.updateCudQuery,
                  onSelected: viewModel.selectCase,
                )
              else
                _PersonLookupSection(
                  state: state,
                  onQueryChanged: viewModel.updatePersonQuery,
                  onSelected: viewModel.selectPerson,
                ),
              const SizedBox(height: AppSpace.m),
              _ProcedureSection(
                state: state,
                onDateChanged: viewModel.updateProcedureAt,
                onLocationChanged: viewModel.updateLocation,
              ),
              const SizedBox(height: AppSpace.m),
              _OfflineNotice(),
              if (state.errorMessage != null) ...[
                const SizedBox(height: AppSpace.m),
                Text(
                  state.errorMessage!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
        _Footer(
          isSubmitting: state.isSubmitting,
          canSubmit: state.canSubmit,
          onSubmit: viewModel.submit,
        ),
      ],
    );
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

class _ExistingCudSection extends StatelessWidget {
  const _ExistingCudSection({
    required this.state,
    required this.onQueryChanged,
    required this.onSelected,
  });

  final CreateRequisitionState state;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<EcosystemCaseSummary> onSelected;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.folder_rounded,
      title: 'Casos del ecosistema',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _RequiredLabel(label: 'Numero de CUD'),
          const SizedBox(height: AppSpace.s),
          if (state.selectedCase == null)
            SearchField<EcosystemCaseSummary>(
              searchStyle: Theme.of(context).textTheme.bodyLarge,
              suggestionStyle: Theme.of(context).textTheme.bodyMedium,
              itemHeight: 76,
              suggestionsDecoration: SuggestionDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(AppRadius.s),
              ),
              onSearchTextChanged: (query) {
                onQueryChanged(query);
                return state.caseResults
                    .map(
                      (item) => SearchFieldListItem<EcosystemCaseSummary>(
                        item.cud,
                        item: item,
                        child: ListTile(
                          dense: true,
                          title: Text(item.cud),
                          subtitle: Text('${item.type} - ${item.division}'),
                        ),
                      ),
                    )
                    .toList();
              },
              suggestions: state.caseResults
                  .map(
                    (item) => SearchFieldListItem<EcosystemCaseSummary>(
                      item.cud,
                      item: item,
                      child: ListTile(
                        dense: true,
                        title: Text(item.cud),
                        subtitle: Text('${item.type} - ${item.division}'),
                      ),
                    ),
                  )
                  .toList(),
              onSuggestionTap: (suggestion) {
                final item = suggestion.item;
                if (item != null) onSelected(item);
              },
              searchInputDecoration: InputDecoration(
                labelText: 'Buscar por Nro de caso, caratula o imputado...',
                labelStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary.withValues(
                    alpha: .5,
                  ),
                  height: 1,
                ),
                prefixIcon: const AppFormInputIcon(
                  asset: 'assets/images/icons/search.svg',
                ),
                errorText: state.cudError,
              ),
            ),
          if (state.selectedCase == null &&
              state.caseSearchPhase == AsyncPhase.loading)
            const LinearProgressIndicator(),
          if (state.selectedCase != null) ...[
            const SizedBox(height: AppSpace.m),
            _SelectedCaseCard(
              caseSummary: state.selectedCase!,
              onChange: () => onQueryChanged(''),
            ),
          ],
          const SizedBox(height: AppSpace.s),
          const _MutedHelp(
            text:
                'Los datos de la persona ya estan vinculados al expediente CUD seleccionado.',
          ),
        ],
      ),
    );
  }
}

class _PersonLookupSection extends StatelessWidget {
  const _PersonLookupSection({
    required this.state,
    required this.onQueryChanged,
    required this.onSelected,
  });

  final CreateRequisitionState state;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<PersonSummary> onSelected;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.person_search_rounded,
      title: 'Persona sin CUD',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _RequiredLabel(label: 'Carnet de identidad'),
          const SizedBox(height: AppSpace.s),
          if (state.selectedPerson == null)
            SearchField<PersonSummary>(
              searchStyle: Theme.of(context).textTheme.bodyLarge,
              suggestionStyle: Theme.of(context).textTheme.bodyMedium,
              itemHeight: 80,
              maxSuggestionsInViewPort: 3,
              suggestionsDecoration: SuggestionDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(AppRadius.s),
              ),
              onSearchTextChanged: (query) {
                onQueryChanged(query);
                return _personSuggestions(state.personResults);
              },
              suggestions: _personSuggestions(state.personResults),
              onSuggestionTap: (suggestion) {
                final person = suggestion.item;
                if (person != null) onSelected(person);
              },
              searchInputDecoration: InputDecoration(
                labelText: 'Buscar por CI',
                labelStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary.withValues(
                    alpha: .5,
                  ),
                  height: 1,
                ),
                prefixIcon: const AppFormInputIcon(
                  asset: 'assets/images/icons/cardEmployee.svg',
                ),
                errorText: state.personError,
              ),
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
              onChange: () => onQueryChanged(''),
            ),
          ],
          const SizedBox(height: AppSpace.s),
          const _MutedHelp(
            text:
                'El endpoint disponible permite busqueda por CI. La busqueda por nombre queda pendiente hasta contar con el servicio.',
          ),
        ],
      ),
    );
  }

  List<SearchFieldListItem<PersonSummary>> _personSuggestions(
    List<PersonSummary> people,
  ) => people
      .map(
        (person) => SearchFieldListItem<PersonSummary>(
          person.ci,
          item: person,
          child: _PersonSuggestionCard(person: person),
        ),
      )
      .toList();
}

class _ProcedureSection extends StatelessWidget {
  const _ProcedureSection({
    required this.state,
    required this.onDateChanged,
    required this.onLocationChanged,
  });

  final CreateRequisitionState state;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<GeoPoint> onLocationChanged;

  @override
  Widget build(BuildContext context) {
    final date = state.procedureAt;
    final location = state.location;
    return _SectionCard(
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
          const _SectionLabel(label: 'Ubicacion GPS'),
          const SizedBox(height: AppSpace.s),
          LayoutBuilder(
            builder: (context, constraints) {
              final vertical = constraints.maxWidth < 520;
              final field = location == null
                  ? _LocationPending(errorText: state.locationError)
                  : _LocationSelectedCard(location: location);
              return Flex(
                direction: vertical ? Axis.vertical : Axis.horizontal,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (vertical) field else Expanded(child: field),
                  SizedBox(
                    width: vertical ? 0 : AppSpace.s,
                    height: vertical ? AppSpace.s : 0,
                  ),
                  SizedBox(
                    width: vertical ? double.infinity : 136,
                    child: FilledButton.tonalIcon(
                      onPressed: () async {
                        final point = await showModalBottomSheet<GeoPoint>(
                          context: context,
                          isScrollControlled: true,
                          useSafeArea: true,
                          builder: (_) => RequisitionLocationPicker(
                            initialPoint: location,
                          ),
                        );
                        if (point != null) onLocationChanged(point);
                      },
                      icon: SvgPicture.asset(
                        'assets/images/icons/gps.svg',
                        width: AppSize.iconS,
                        height: AppSize.iconS,
                        colorFilter: ColorFilter.mode(
                          Theme.of(context).colorScheme.onSecondaryContainer,
                          BlendMode.srcIn,
                        ),
                      ),
                      label: Text(
                        location == null ? 'Capturar' : 'Editar ubicación',
                      ),
                    ),
                  ),
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

class _LocationPending extends StatelessWidget {
  const _LocationPending({this.errorText});
  final String? errorText;

  @override
  Widget build(BuildContext context) => InputDecorator(
    decoration: InputDecoration(
      errorText: errorText,
      prefixIcon: const AppFormInputIcon(
        asset: 'assets/images/icons/punto.svg',
      ),
    ),
    child: Text(
      'Captura la ubicación para continuar',
      style: Theme.of(context).inputDecorationTheme.hintStyle,
    ),
  );
}

class _LocationSelectedCard extends StatelessWidget {
  const _LocationSelectedCard({required this.location});
  final GeoPoint location;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(AppRadius.s),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: .2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s),
        child: Row(
          children: [
            const AppFormInputIcon(asset: 'assets/images/icons/punto.svg'),
            const SizedBox(width: AppSpace.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    location.label?.isNotEmpty ?? false
                        ? location.label!
                        : 'Ubicación capturada',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary),
          ],
        ),
      ),
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
      subjectCount: caseSummary.subjects.length,
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
    return _PersonSelectionCard(person: person, onRemove: onChange);
  }
}

class _PersonSuggestionCard extends StatelessWidget {
  const _PersonSuggestionCard({required this.person});
  final PersonSummary person;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpace.s,
      vertical: AppSpace.xs,
    ),
    child: _PersonCardContent(person: person),
  );
}

class _PersonSelectionCard extends StatelessWidget {
  const _PersonSelectionCard({required this.person, required this.onRemove});
  final PersonSummary person;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpace.m),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(AppRadius.s),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .05),
                blurRadius: 15,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.only(right: AppSpace.m),
            child: _PersonCardContent(person: person),
          ),
        ),
        Positioned(
          right: -AppSpace.xs,
          top: -AppSpace.xs,
          child: InkWell(
            onTap: onRemove,
            customBorder: const CircleBorder(),
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.error.withValues(alpha: .9),
              ),
              child: SvgPicture.asset(
                'assets/images/icons/x.svg',
                width: 14,
                colorFilter: ColorFilter.mode(
                  theme.colorScheme.onError,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PersonCardContent extends StatelessWidget {
  const _PersonCardContent({required this.person});
  final PersonSummary person;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          person.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpace.xs),
        _PersonDetail(
          asset: 'assets/images/icons/cardEmployee.svg',
          label: 'CI:',
          value: person.ci,
        ),
        if (person.address?.isNotEmpty == true) ...[
          const SizedBox(height: AppSpace.xs),
          _PersonDetail(
            asset: 'assets/images/icons/address.svg',
            label: 'Dirección:',
            value: person.address!,
          ),
        ],
        if (person.phone?.isNotEmpty == true) ...[
          const SizedBox(height: AppSpace.xs),
          _PersonDetail(
            asset: 'assets/images/icons/phone.svg',
            label: 'Celular:',
            value: person.phone!,
          ),
        ],
      ],
    );
  }
}

class _PersonDetail extends StatelessWidget {
  const _PersonDetail({
    required this.asset,
    required this.label,
    required this.value,
  });
  final String asset;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SvgPicture.asset(
          asset,
          width: AppSize.iconS,
          height: AppSize.iconS,
          colorFilter: ColorFilter.mode(
            theme.colorScheme.primary,
            BlendMode.srcIn,
          ),
        ),
        const SizedBox(width: AppSpace.xs),
        Expanded(
          child: RichText(
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              style: theme.textTheme.bodySmall,
              children: [
                TextSpan(
                  text: '$label ',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.m),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.18),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: AppSize.iconM,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: AppSpace.xs),
                Text(
                  title.toUpperCase(),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.m),
            child,
          ],
        ),
      ),
    );
  }
}

class _OfflineNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.m),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.18),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.m),
        child: Row(
          children: [
            Icon(Icons.lock_outline_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpace.s),
            Expanded(
              child: Text(
                'Registro local de laboratorio. El cifrado offline real queda pendiente para la capa de evidencias.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
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

import 'package:file_cast/domain/models/requisition_detail.dart';
import 'package:file_cast/ui/core/widgets/app_form_input_icon.dart';
import 'package:flutter/material.dart';

class ParticipantRoleDropdown extends StatelessWidget {
  const ParticipantRoleDropdown({
    required this.role,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final RequisitionParticipantRole role;
  final ValueChanged<RequisitionParticipantRole> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DropdownButtonFormField<RequisitionParticipantRole>(
      key: ValueKey(role),
      initialValue: role,
      isExpanded: true,
      style: theme.textTheme.bodyLarge,
      dropdownColor: theme.cardColor,
      iconEnabledColor: theme.colorScheme.primary,
      decoration: InputDecoration(
        labelText: 'Nivel de acceso',
        labelStyle: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.primary.withValues(alpha: .55),
        ),
        prefixIcon: const AppFormInputIcon(
          asset: 'assets/images/icons/key.svg',
        ),
      ),
      items: RequisitionParticipantRole.values
          .map(
            (item) => DropdownMenuItem(
              value: item,
              child: Text(item.label, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(growable: false),
      selectedItemBuilder: (context) => RequisitionParticipantRole.values
          .map(
            (item) => Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(item.label, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(growable: false),
      onChanged: enabled
          ? (value) {
              if (value != null && value != role) onChanged(value);
            }
          : null,
    );
  }
}

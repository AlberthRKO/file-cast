import 'package:file_cast/domain/models/requisition_detail.dart';
import 'package:file_cast/ui/core/widgets/app_modal_bottom_sheet.dart';
import 'package:file_cast/ui/features/requisitions/widgets/case_subjects_sheet.dart';
import 'package:flutter/material.dart';

Future<void> showAcquisitionSubjectPicker({
  required BuildContext context,
  required List<RequisitionSubjectSummary> subjects,
  required int? selectedPersonId,
  required ValueChanged<int?> onSelected,
  required String deviceName,
}) {
  return showAppModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    maxWidth: 560,
    builder: (_) => CaseSubjectsSheet.fromRequisition(
      subjects: subjects,
      title: selectedPersonId == null
          ? 'Asignar sujeto al dispositivo'
          : 'Cambiar sujeto del dispositivo',
      subtitle: deviceName,
      selectionEnabled: true,
      singleSelection: true,
      initialSelectedPersonIds: {
        if (selectedPersonId != null) selectedPersonId,
      },
      confirmLabel: selectedPersonId == null
          ? 'Asignar sujeto'
          : 'Guardar cambio',
      onConfirm: (personIds) async {
        onSelected(personIds.single);
        return null;
      },
    ),
  );
}

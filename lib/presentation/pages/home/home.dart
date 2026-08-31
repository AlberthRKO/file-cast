import 'package:file_cast/ui/features/requisitions/list/views/requisition_list_view.dart';
import 'package:flutter/widgets.dart';

/// Compatibility entry point for callers that have not migrated their import.
@Deprecated('Use RequisitionListRoute from lib/ui/features/requisitions/list.')
class HomePage extends StatelessWidget {
  @Deprecated(
    'Use RequisitionListRoute from lib/ui/features/requisitions/list.',
  )
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) => const RequisitionListRoute();
}

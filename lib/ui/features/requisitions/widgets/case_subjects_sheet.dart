import 'package:file_cast/domain/models/requisition_creation.dart';
import 'package:file_cast/domain/models/requisition_detail.dart';
import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CaseSubjectsSheet extends StatefulWidget {
  CaseSubjectsSheet.fromEcosystem({
    required List<EcosystemSubjectSummary> subjects,
    List<String> fallbackNames = const [],
    String title = 'Sujetos del caso',
    String? subtitle,
    super.key,
  }) : title = title,
       subtitle = subtitle,
       selectionEnabled = false,
       confirmLabel = 'Aceptar',
       initialSelectedPersonIds = const {},
       onConfirm = null,
       _subjects = subjects.isNotEmpty
           ? subjects
                 .map(
                   (subject) => _CaseSubjectItem(
                     name: subject.name,
                     documentNumber: subject.documentNumber,
                     role: subject.role,
                     roleColorHex: subject.subjectTypeColorHex,
                     personId: subject.personId,
                   ),
                 )
                 .toList(growable: false)
           : fallbackNames
                 .map((name) => _CaseSubjectItem(name: name))
                 .toList(growable: false);

  CaseSubjectsSheet.fromRequisition({
    required List<RequisitionSubjectSummary> subjects,
    List<String> fallbackNames = const [],
    String title = 'Sujetos del caso',
    String? subtitle,
    bool selectionEnabled = false,
    Set<int> initialSelectedPersonIds = const {},
    String confirmLabel = 'Anclar',
    Future<String?> Function(List<int> personIds)? onConfirm,
    super.key,
  }) : title = title,
       subtitle = subtitle,
       selectionEnabled = selectionEnabled,
       confirmLabel = confirmLabel,
       initialSelectedPersonIds = initialSelectedPersonIds,
       onConfirm = onConfirm,
       _subjects = subjects.isNotEmpty
           ? subjects
                 .map(
                   (subject) => _CaseSubjectItem(
                     name: subject.name,
                     documentNumber: subject.documentNumber,
                     role: subject.role,
                     roleColorHex: subject.subjectTypeColorHex,
                     personId: subject.personId,
                   ),
                 )
                 .toList(growable: false)
           : fallbackNames
                 .map((name) => _CaseSubjectItem(name: name))
                 .toList(growable: false);

  final String title;
  final String? subtitle;
  final List<_CaseSubjectItem> _subjects;
  final bool selectionEnabled;
  final Set<int> initialSelectedPersonIds;
  final String confirmLabel;
  final Future<String?> Function(List<int> personIds)? onConfirm;

  @override
  State<CaseSubjectsSheet> createState() => _CaseSubjectsSheetState();
}

class _CaseSubjectsSheetState extends State<CaseSubjectsSheet> {
  late final TextEditingController _searchController;
  late final Set<int> _selectedPersonIds;
  String _query = '';
  bool _isConfirming = false;

  List<_CaseSubjectItem> get _filteredSubjects {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return widget._subjects;
    return widget._subjects
        .where((subject) {
          return subject.name.toLowerCase().contains(query) ||
              (subject.documentNumber?.toLowerCase().contains(query) ??
                  false) ||
              (subject.role?.toLowerCase().contains(query) ?? false);
        })
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    final availablePersonIds = widget._subjects
        .map((subject) => subject.personId)
        .whereType<int>()
        .toSet();
    _selectedPersonIds = widget.initialSelectedPersonIds
        .where(availablePersonIds.contains)
        .toSet();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredSubjects = _filteredSubjects;
    return Material(
      color: theme.cardColor,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadius.l),
      ),
      clipBehavior: Clip.antiAlias,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final availableHeight = constraints.maxHeight.isFinite
                  ? constraints.maxHeight
                  : MediaQuery.sizeOf(context).height;
              final sheetHeight = availableHeight > 620
                  ? 620.0
                  : availableHeight;
              return SizedBox(
                height: sheetHeight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.m,
                    AppSpace.s,
                    AppSpace.m,
                    AppSpace.m,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SheetHeader(
                        title: widget.title,
                        subtitle:
                            widget.subtitle ??
                            '${widget._subjects.length} ${widget._subjects.length == 1 ? 'sujeto procesal' : 'sujetos procesales'}',
                        onClose: _isConfirming
                            ? null
                            : () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(height: AppSpace.s),
                      TextField(
                        controller: _searchController,
                        enabled: !_isConfirming,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          labelText: 'Buscar sujeto',
                          prefixIcon: const Icon(Icons.person_search_outlined),
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Limpiar búsqueda',
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _query = '');
                                  },
                                  icon: const Icon(Icons.close_rounded),
                                ),
                        ),
                        onChanged: (value) => setState(() => _query = value),
                      ),
                      const SizedBox(height: AppSpace.s),
                      Expanded(
                        child: filteredSubjects.isEmpty
                            ? _EmptySubjectsState(hasQuery: _query.isNotEmpty)
                            : ListView.separated(
                                keyboardDismissBehavior:
                                    ScrollViewKeyboardDismissBehavior.onDrag,
                                itemCount: filteredSubjects.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: AppSpace.s),
                                itemBuilder: (context, index) {
                                  final subject = filteredSubjects[index];
                                  final personId = subject.personId;
                                  final selected =
                                      personId != null &&
                                      _selectedPersonIds.contains(personId);
                                  return _SubjectCard(
                                    subject: subject,
                                    selectable: widget.selectionEnabled,
                                    selected: selected,
                                    onPressed:
                                        _isConfirming ||
                                            !widget.selectionEnabled ||
                                            personId == null
                                        ? null
                                        : () => _toggle(personId),
                                  );
                                },
                              ),
                      ),
                      if (widget.selectionEnabled) ...[
                        const SizedBox(height: AppSpace.s),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: _isConfirming
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              child: const Text('Cancelar'),
                            ),
                            const SizedBox(width: AppSpace.s),
                            FilledButton.icon(
                              onPressed: _isConfirming ? null : _confirm,
                              icon: _isConfirming
                                  ? const SizedBox.square(
                                      dimension: AppSize.iconS,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.link_rounded),
                              label: Text(
                                _isConfirming
                                    ? 'Guardando…'
                                    : widget.confirmLabel,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _toggle(int personId) {
    setState(() {
      if (!_selectedPersonIds.add(personId)) {
        _selectedPersonIds.remove(personId);
      }
    });
  }

  Future<void> _confirm() async {
    final selected = _selectedPersonIds.toList(growable: false);
    final onConfirm = widget.onConfirm;
    if (onConfirm == null) {
      Navigator.of(context).pop(selected);
      return;
    }

    setState(() {
      _isConfirming = true;
    });
    final error = await onConfirm(selected);
    if (!mounted) return;
    if (error != null) {
      Navigator.of(context).pop(error);
      return;
    }
    Navigator.of(context).pop(true);
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.title,
    required this.subtitle,
    required this.onClose,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: AppSize.minTouchTarget,
          height: AppSize.minTouchTarget,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(AppRadius.m),
          ),
          child: Icon(
            Icons.groups_2_outlined,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: AppSpace.s),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
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
    );
  }
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({
    required this.subject,
    required this.selectable,
    required this.selected,
    this.onPressed,
  });

  final _CaseSubjectItem subject;
  final bool selectable;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roleColor = _parseHexColor(subject.roleColorHex);
    final badgeColor = roleColor ?? theme.colorScheme.primary;
    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(AppRadius.m),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.m),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(AppSpace.m),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.m),
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline.withValues(alpha: .16),
              width: selected ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .04),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: AppSize.minTouchTarget,
                height: AppSize.minTouchTarget,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: .08),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: SvgPicture.asset(
                  'assets/images/icons/cardEmployee.svg',
                  width: AppSize.iconL,
                  height: AppSize.iconL,
                  colorFilter: ColorFilter.mode(
                    theme.colorScheme.primary,
                    BlendMode.srcIn,
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (subject.documentNumber?.isNotEmpty == true) ...[
                      Text(
                        'C.I. ${subject.documentNumber}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpace.xs),
                    ],
                    Text(
                      subject.name.toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpace.s),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: .2),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpace.s,
                            vertical: AppSpace.xs,
                          ),
                          child: Text(
                            subject.role?.trim().isNotEmpty == true
                                ? subject.role!
                                : 'Sujeto procesal',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (selectable) ...[
                const SizedBox(width: AppSpace.s),
                Checkbox(
                  value: selected,
                  onChanged: onPressed == null ? null : (_) => onPressed!(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptySubjectsState extends StatelessWidget {
  const _EmptySubjectsState({required this.hasQuery});

  final bool hasQuery;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.l),
        child: Text(
          hasQuery
              ? 'No se encontraron sujetos con ese criterio.'
              : 'El caso no tiene sujetos procesales registrados.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _CaseSubjectItem {
  const _CaseSubjectItem({
    required this.name,
    this.documentNumber,
    this.role,
    this.roleColorHex,
    this.personId,
  });

  final String name;
  final String? documentNumber;
  final String? role;
  final String? roleColorHex;
  final int? personId;
}

Color? _parseHexColor(String? value) {
  if (value == null) return null;
  final normalized = value.trim().replaceFirst('#', '');
  final hex = normalized.length == 6 ? 'FF$normalized' : normalized;
  final parsed = int.tryParse(hex, radix: 16);
  return parsed == null ? null : Color(parsed);
}

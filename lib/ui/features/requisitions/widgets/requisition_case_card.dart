import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Adaptación responsive del CardCasoPenal usado por el ecosistema Justicia Libre.
class RequisitionCaseCard extends StatelessWidget {
  const RequisitionCaseCard({
    required this.cud,
    required this.caseType,
    required this.division,
    required this.statusLabel,
    this.identifierLabel = 'CUD',
    this.selectionStyle = false,
    this.flatStyle = false,
    this.stageLabel,
    this.locationLabel,
    this.crimes = const [],
    this.score,
    this.timerLabel,
    this.timerEndsAt,
    this.timerPaused = false,
    this.onTap,
    this.onViewSubjects,
    this.onRemove,
    super.key,
  });

  final String cud;
  final String caseType;
  final String division;
  final String statusLabel;
  final String identifierLabel;
  final bool selectionStyle;
  final bool flatStyle;
  final String? stageLabel;
  final String? locationLabel;
  final List<String> crimes;
  final int? score;
  final String? timerLabel;
  final DateTime? timerEndsAt;
  final bool timerPaused;
  final VoidCallback? onTap;
  final VoidCallback? onViewSubjects;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.s),
    );
    final content = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.m),
      decoration: BoxDecoration(
        color: selectionStyle ? theme.scaffoldBackgroundColor : theme.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.s),
        border: selectionStyle
            ? null
            : flatStyle
            ? null
            : Border.all(
                color: theme.colorScheme.outline.withValues(alpha: .14),
              ),
        boxShadow: flatStyle || selectionStyle
            ? const []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .05),
                  blurRadius: 15,
                  offset: const Offset(0, 7),
                ),
              ],
      ),
      child: Padding(
        padding: EdgeInsets.only(right: onRemove == null ? 0 : AppSpace.m),
        child: flatStyle
            ? _FlatCaseDetails(
                identifierLabel: identifierLabel,
                cud: cud,
                statusLabel: statusLabel,
                caseType: caseType,
                division: division,
                stageLabel: stageLabel,
                locationLabel: locationLabel,
                crimes: crimes,
                score: score,
                timerLabel: timerLabel,
                timerEndsAt: timerEndsAt,
                timerPaused: timerPaused,
                onViewSubjects: onViewSubjects,
              )
            : _StandardCaseDetails(
                identifierLabel: identifierLabel,
                cud: cud,
                statusLabel: statusLabel,
                caseType: caseType,
                division: division,
                stageLabel: stageLabel,
                locationLabel: locationLabel,
                crimes: crimes,
                onViewSubjects: onViewSubjects,
              ),
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.transparent,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: onTap == null
              ? content
              : InkWell(
                  onTap: onTap,
                  customBorder: shape,
                  child: content,
                ),
        ),
        if (onRemove != null)
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
                  color: theme.colorScheme.error.withValues(alpha: .9),
                  shape: BoxShape.circle,
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

class _FlatCaseDetails extends StatelessWidget {
  const _FlatCaseDetails({
    required this.identifierLabel,
    required this.cud,
    required this.statusLabel,
    required this.caseType,
    required this.division,
    required this.crimes,
    required this.timerPaused,
    this.stageLabel,
    this.locationLabel,
    this.score,
    this.timerLabel,
    this.timerEndsAt,
    this.onViewSubjects,
  });

  final String identifierLabel;
  final String cud;
  final String statusLabel;
  final String caseType;
  final String division;
  final String? stageLabel;
  final String? locationLabel;
  final List<String> crimes;
  final int? score;
  final String? timerLabel;
  final DateTime? timerEndsAt;
  final bool timerPaused;
  final VoidCallback? onViewSubjects;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timer = _timerText(timerEndsAt, timerLabel, timerPaused);
    final timerExpired =
        timerEndsAt != null &&
        timerEndsAt!.isBefore(DateTime.now()) &&
        !timerPaused;
    final metadata = <_CaseMetadata>[
      _CaseMetadata(Icons.category_outlined, 'Tipo', caseType),
      if (stageLabel?.trim().isNotEmpty == true)
        _CaseMetadata(Icons.account_tree_outlined, 'Etapa', stageLabel!),
      _CaseMetadata(Icons.apartment_rounded, 'División', division),
      if (locationLabel?.trim().isNotEmpty == true)
        _CaseMetadata(Icons.place_outlined, 'Ubicación', locationLabel!),
      _CaseMetadata(
        Icons.gavel_rounded,
        'Delito',
        crimes.isEmpty ? 'Sin registro' : crimes.join(', '),
      ),
      if (timer != null)
        _CaseMetadata(
          Icons.timer_outlined,
          'Plazo',
          timer,
          color: timerExpired
              ? theme.colorScheme.error
              : theme.colorScheme.tertiary,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$identifierLabel $cud',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: AppSpace.s),
            _StatusBadge(label: statusLabel),
          ],
        ),
        if (score != null || onViewSubjects != null) ...[
          const SizedBox(height: AppSpace.xxs),
          Row(
            children: [
              if (score != null) _ScoreStars(score: score!),
              if (score != null && onViewSubjects != null) const Spacer(),
              if (onViewSubjects != null)
                _CaseSubjectsButton(onPressed: onViewSubjects!),
            ],
          ),
        ],
        const SizedBox(height: AppSpace.s),
        LayoutBuilder(
          builder: (context, constraints) {
            final gap = AppSpace.xs;
            final itemWidth = (constraints.maxWidth - gap) / 2;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: metadata
                  .map(
                    (item) => SizedBox(
                      width: itemWidth,
                      child: _MetadataTile(metadata: item),
                    ),
                  )
                  .toList(growable: false),
            );
          },
        ),
      ],
    );
  }
}

class _CaseMetadata {
  const _CaseMetadata(this.icon, this.label, this.value, {this.color});

  final IconData icon;
  final String label;
  final String value;
  final Color? color;
}

class _MetadataTile extends StatelessWidget {
  const _MetadataTile({required this.metadata});

  final _CaseMetadata metadata;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = metadata.color ?? theme.colorScheme.primary;
    return Container(
      constraints: const BoxConstraints(minHeight: 46),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s,
        vertical: AppSpace.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(AppRadius.s),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(metadata.icon, size: AppSize.iconS, color: color),
          const SizedBox(width: AppSpace.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metadata.label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  metadata.value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreStars extends StatelessWidget {
  const _ScoreStars({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filledStars = (score.clamp(0, 100) / 20).round();
    return Tooltip(
      message: 'Puntaje $score/100',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List<Widget>.generate(
          5,
          (index) => Icon(
            index < filledStars
                ? Icons.star_rounded
                : Icons.star_border_rounded,
            size: AppSize.iconS,
            color: theme.colorScheme.tertiary,
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s,
          vertical: AppSpace.xxs,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

String? _timerText(DateTime? endsAt, String? fallback, bool paused) {
  if (paused) return 'Plazo suspendido';
  if (endsAt == null) return fallback;

  final now = DateTime.now();
  final end = endsAt.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final endDate = DateTime(end.year, end.month, end.day);
  final days = endDate.difference(today).inDays;
  if (days < 0) {
    final elapsedDays = days.abs();
    return elapsedDays == 0
        ? 'Expirado hoy'
        : 'Expirado hace $elapsedDays ${elapsedDays == 1 ? 'día' : 'días'}';
  }
  if (days == 0) return end.isBefore(now) ? 'Expirado hoy' : 'Vence hoy';
  return 'Vence en $days ${days == 1 ? 'día' : 'días'}';
}

class _StandardCaseDetails extends StatelessWidget {
  const _StandardCaseDetails({
    required this.identifierLabel,
    required this.cud,
    required this.statusLabel,
    required this.caseType,
    required this.division,
    required this.crimes,
    this.stageLabel,
    this.locationLabel,
    this.onViewSubjects,
  });

  final String identifierLabel;
  final String cud;
  final String statusLabel;
  final String caseType;
  final String division;
  final String? stageLabel;
  final String? locationLabel;
  final List<String> crimes;
  final VoidCallback? onViewSubjects;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$identifierLabel: $cud',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: AppSpace.s),
            _StatusBadge(label: statusLabel),
            if (onViewSubjects != null) ...[
              const SizedBox(width: AppSpace.xs),
              _CaseSubjectsButton(onPressed: onViewSubjects!),
            ],
          ],
        ),
        const SizedBox(height: AppSpace.s),
        _DetailLine(
          asset: 'assets/images/icons/contrato.svg',
          label: 'Tipo:',
          value: caseType,
        ),
        const SizedBox(height: AppSpace.xs),
        _DetailLine(
          asset: 'assets/images/icons/marca.svg',
          label: 'División:',
          value: division,
        ),
        if (stageLabel?.trim().isNotEmpty == true) ...[
          const SizedBox(height: AppSpace.xs),
          _DetailLine(
            asset: 'assets/images/icons/sync.svg',
            label: 'Etapa:',
            value: stageLabel!,
          ),
        ],
        if (locationLabel?.trim().isNotEmpty == true) ...[
          const SizedBox(height: AppSpace.xs),
          _DetailLine(
            asset: 'assets/images/icons/punto.svg',
            label: 'Ubicación:',
            value: locationLabel!,
          ),
        ],
        if (crimes.isNotEmpty) ...[
          const SizedBox(height: AppSpace.xs),
          _DetailLine(
            asset: 'assets/images/icons/contrato.svg',
            label: 'Delito:',
            value: crimes.join(', '),
          ),
        ],
      ],
    );
  }
}

class _CaseSubjectsButton extends StatelessWidget {
  const _CaseSubjectsButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return IconButton(
      tooltip: 'Ver sujetos del caso',
      onPressed: onPressed,
      style: IconButton.styleFrom(
        minimumSize: const Size.square(AppSize.minTouchTarget),
        maximumSize: const Size.square(AppSize.minTouchTarget),
        padding: EdgeInsets.zero,
        shape: const CircleBorder(),
        side: BorderSide.none,
      ),
      constraints: const BoxConstraints(
        minWidth: AppSize.minTouchTarget,
        minHeight: AppSize.minTouchTarget,
      ),
      icon: Container(
        width: AppSize.iconL + AppSpace.s,
        height: AppSize.iconL + AppSpace.s,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: primary.withValues(alpha: .1),
        ),
        alignment: Alignment.center,
        child: SvgPicture.asset(
          'assets/images/icons/users.svg',
          width: AppSize.iconS,
          height: AppSize.iconS,
          colorFilter: ColorFilter.mode(primary, BlendMode.srcIn),
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
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

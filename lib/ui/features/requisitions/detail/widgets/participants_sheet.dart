import 'dart:async';

import 'package:file_cast/domain/models/requisition_detail.dart';
import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:file_cast/ui/features/requisitions/detail/widgets/participant_role_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ParticipantsSheet extends StatelessWidget {
  const ParticipantsSheet({
    required this.participants,
    required this.participantName,
    required this.currentActorId,
    required this.canManageRoles,
    required this.changingActorIds,
    required this.roleErrors,
    required this.onChangeRole,
    super.key,
  });

  final List<RequisitionParticipantSummary> participants;
  final String Function(RequisitionParticipantSummary participant)
  participantName;
  final String? currentActorId;
  final bool canManageRoles;
  final Set<String> changingActorIds;
  final Map<String, String> roleErrors;
  final Future<void> Function(
    RequisitionParticipantSummary participant,
    RequisitionParticipantRole role,
  )
  onChangeRole;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.cardColor,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.m,
            AppSpace.s,
            AppSpace.m,
            AppSpace.m,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ParticipantsSheetHeader(
                title: 'Fiscales investigadores',
                subtitle:
                    '${participants.length} ${participants.length == 1 ? 'fiscal investigador' : 'fiscales investigadores'}',
              ),
              const SizedBox(height: AppSpace.s),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  itemCount: participants.isEmpty ? 1 : participants.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpace.s),
                  itemBuilder: (context, index) {
                    if (participants.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(AppSpace.l),
                        child: Text(
                          'No hay fiscales investigadores registrados en la requisa.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    }

                    final participant = participants[index];
                    return _ParticipantRoleCard(
                      participant: participant,
                      name: participantName(participant),
                      currentActorId: currentActorId,
                      canManageRoles: canManageRoles,
                      isChanging: changingActorIds.contains(
                        participant.actorId,
                      ),
                      errorMessage: roleErrors[participant.actorId],
                      onChangeRole: onChangeRole,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParticipantsSheetHeader extends StatelessWidget {
  const _ParticipantsSheetHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

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
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Cerrar',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
          constraints: const BoxConstraints.tightFor(
            width: AppSize.minTouchTarget,
            height: AppSize.minTouchTarget,
          ),
        ),
      ],
    );
  }
}

class _ParticipantRoleCard extends StatelessWidget {
  const _ParticipantRoleCard({
    required this.participant,
    required this.name,
    required this.currentActorId,
    required this.canManageRoles,
    required this.isChanging,
    required this.errorMessage,
    required this.onChangeRole,
  });

  final RequisitionParticipantSummary participant;
  final String name;
  final String? currentActorId;
  final bool canManageRoles;
  final bool isChanging;
  final String? errorMessage;
  final Future<void> Function(
    RequisitionParticipantSummary participant,
    RequisitionParticipantRole role,
  )
  onChangeRole;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentRole = _roleFromApi(participant.role);
    final canEdit =
        canManageRoles &&
        participant.actorId != currentActorId &&
        currentRole != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.m),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.m),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: .16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final largeText =
                  MediaQuery.textScalerOf(context).scale(14.0) > 18.0;
              final identity = _ParticipantIdentity(
                name: name,
                documentNumber: participant.documentNumber,
              );
              final roleControl = _RoleControl(
                role: currentRole,
                rawRole: participant.role,
                canEdit: canEdit,
                isChanging: isChanging,
                onChanged: (role) => unawaited(
                  onChangeRole(participant, role),
                ),
              );

              if (constraints.maxWidth < 440 || largeText) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    identity,
                    const SizedBox(height: AppSpace.s),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: roleControl,
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: identity),
                  const SizedBox(width: AppSpace.s),
                  roleControl,
                ],
              );
            },
          ),
          if (errorMessage != null && errorMessage!.isNotEmpty) ...[
            const SizedBox(height: AppSpace.s),
            Text(
              errorMessage!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
              softWrap: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _ParticipantIdentity extends StatelessWidget {
  const _ParticipantIdentity({required this.name, this.documentNumber});

  final String name;
  final String? documentNumber;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
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
              if (documentNumber?.trim().isNotEmpty == true) ...[
                Text(
                  'C.I. ${documentNumber!.trim()}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpace.xs),
              ],
              Text(
                name.toUpperCase(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoleControl extends StatelessWidget {
  const _RoleControl({
    required this.role,
    required this.rawRole,
    required this.canEdit,
    required this.isChanging,
    required this.onChanged,
  });

  final RequisitionParticipantRole? role;
  final String rawRole;
  final bool canEdit;
  final bool isChanging;
  final ValueChanged<RequisitionParticipantRole> onChanged;

  @override
  Widget build(BuildContext context) {
    final selectedRole = role;
    final label = switch (rawRole.toUpperCase()) {
      'OWNER' => 'Propietario',
      'EDITOR' => 'Editor',
      'VIEWER' => 'Lector',
      _ => rawRole,
    };

    if (isChanging) {
      return const SizedBox.square(
        dimension: AppSize.minTouchTarget,
        child: Center(
          child: SizedBox.square(
            dimension: AppSize.iconM,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (!canEdit || selectedRole == null) {
      return _RoleBadge(label: label);
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: AppSize.minTouchTarget,
        maxWidth: 232,
      ),
      child: ParticipantRoleDropdown(
        role: selectedRole,
        onChanged: onChanged,
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: AppSize.minTouchTarget),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

RequisitionParticipantRole? _roleFromApi(String role) =>
    switch (role.toUpperCase()) {
      'EDITOR' => RequisitionParticipantRole.editor,
      'VIEWER' => RequisitionParticipantRole.viewer,
      _ => null,
    };

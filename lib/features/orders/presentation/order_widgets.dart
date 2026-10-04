import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/settings.dart';
import '../../../core/theme/app_colors.dart';
import '../application/orders_logic.dart';

/// A coloured status pill: tone from `orders_logic`, text already translated.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.tone});

  final String label;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final (background, foreground) = switch (tone) {
      Tone.accent => (colors.accent.withValues(alpha: 0.15), colors.accent),
      Tone.success => (colors.success.withValues(alpha: 0.15), colors.success),
      Tone.warning => (
        colors.warning.withValues(alpha: 0.18),
        colors.foreground,
      ),
      Tone.destructive => (
        colors.destructive.withValues(alpha: 0.15),
        colors.destructive,
      ),
      Tone.neutral => (colors.secondary, colors.secondaryForeground),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: foreground, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// The six delivery steps of a shipment (confirmed ... collected) with [progress] done.
/// Each step reads as "Confirmed, done" to a screen reader.
class DeliveryTracker extends ConsumerWidget {
  const DeliveryTracker({super.key, required this.progress});

  final int progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final colors = AppColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < groupSteps.length; i++)
          Expanded(
            child: Builder(
              builder: (context) {
                final state = trackerStep(i, progress);
                final label = t(groupSteps[i]);
                final stateLabel = t(switch (state) {
                  TrackerStep.done => 'order.stepDone',
                  TrackerStep.current => 'order.stepCurrent',
                  TrackerStep.upcoming => 'order.stepUpcoming',
                });
                final active = state != TrackerStep.upcoming;
                return Semantics(
                  label: '$label, $stateLabel',
                  excludeSemantics: true,
                  child: Column(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: state == TrackerStep.done
                              ? colors.accent
                              : Colors.transparent,
                          border: Border.all(
                            color: active ? colors.accent : colors.border,
                            width: 2,
                          ),
                        ),
                        child: state == TrackerStep.done
                            ? Icon(
                                Icons.check,
                                size: 14,
                                color: colors.accentForeground,
                              )
                            : state == TrackerStep.current
                            ? Center(
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: colors.accent,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: active
                              ? colors.foreground
                              : colors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

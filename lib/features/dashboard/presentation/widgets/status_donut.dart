import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_radii.dart';
import '../../../../shared/theme/app_text_styles.dart';

/// Member status breakdown as a donut with a centered total and a labelled
/// legend. Three semantic slices only (active / pending / rejected) — within
/// the "≤5 slices, use labels" guidance for readable pie charts.
class StatusDonut extends StatelessWidget {
  final int active;
  final int pending;
  final int rejected;

  const StatusDonut({
    super.key,
    required this.active,
    required this.pending,
    required this.rejected,
  });

  @override
  Widget build(BuildContext context) {
    final total = active + pending + rejected;
    final slices = <_Seg>[
      _Seg('Active', active, AppColors.success),
      _Seg('Pending', pending, AppColors.inkMuted),
      _Seg('Rejected', rejected, AppColors.danger),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.borderMd,
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                  width: 3, height: 16, margin: const EdgeInsets.only(right: 9),
                  decoration: BoxDecoration(
                      color: AppColors.brand,
                      borderRadius: BorderRadius.circular(2))),
              Text('Status breakdown', style: AppTextStyles.h3()),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Donut
              SizedBox(
                width: 128,
                height: 128,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: total == 0 ? 0 : 3,
                        centerSpaceRadius: 40,
                        startDegreeOffset: -90,
                        sections: total == 0
                            ? [
                                PieChartSectionData(
                                    value: 1,
                                    color: AppColors.fillMuted,
                                    radius: 20,
                                    showTitle: false),
                              ]
                            : [
                                for (final s in slices)
                                  if (s.value > 0)
                                    PieChartSectionData(
                                      value: s.value.toDouble(),
                                      color: s.color,
                                      radius: 20,
                                      showTitle: false,
                                    ),
                              ],
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$total', style: AppTextStyles.h1()),
                        Text('members',
                            style: AppTextStyles.caption()),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              // Legend
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final s in slices) ...[
                      _LegendRow(
                          color: s.color,
                          label: s.label,
                          value: s.value,
                          pct: total == 0 ? 0 : s.value / total),
                      if (s != slices.last) const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Seg {
  final String label;
  final int value;
  final Color color;
  const _Seg(this.label, this.value, this.color);
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;
  final int value;
  final double pct;
  const _LegendRow({
    required this.color,
    required this.label,
    required this.value,
    required this.pct,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
            width: 10, height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: AppTextStyles.body())),
        Text('$value', style: AppTextStyles.bodyMedium()),
        const SizedBox(width: 6),
        SizedBox(
          width: 38,
          child: Text('${(pct * 100).round()}%',
              textAlign: TextAlign.right,
              style: AppTextStyles.caption()),
        ),
      ],
    );
  }
}

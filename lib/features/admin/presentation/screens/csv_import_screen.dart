import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/errors/app_error_mapper.dart';
import '../../data/lookup_admin_repository.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_radii.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_text_styles.dart';
import '../../../../shared/widgets/canopy_arc.dart';
import '../../../../shared/widgets/ndc_button.dart';

class CsvImportScreen extends StatefulWidget {
  const CsvImportScreen({super.key});

  @override
  State<CsvImportScreen> createState() => _CsvImportScreenState();
}

class _CsvImportScreenState extends State<CsvImportScreen> {
  final _csvCtrl = TextEditingController();
  bool _importing = false;
  _ImportResult? _result;
  String? _parseError;

  static const _sampleCsv =
      'region,district,constituency,electoral_area,station_name\n'
      'Greater Accra,Tema Metro,Tema West,EA1,Ashaiman Polling Station 1\n'
      'Greater Accra,Tema Metro,Tema West,EA1,Ashaiman Polling Station 2\n'
      'Greater Accra,Tema Metro,Tema West,EA2,Community 5 PS\n';

  @override
  void dispose() {
    _csvCtrl.dispose();
    super.dispose();
  }

  List<Map<String, String>>? _parseCsv(String raw) {
    final lines = raw
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) {
      setState(() => _parseError = 'No data found.');
      return null;
    }

    final headers = lines.first
        .split(',')
        .map((h) => h.trim().toLowerCase().replaceAll(' ', '_'))
        .toList();

    const required = ['region', 'district', 'constituency', 'station_name'];
    for (final h in required) {
      if (!headers.contains(h)) {
        setState(() => _parseError = 'Missing required column: $h');
        return null;
      }
    }

    final rows = <Map<String, String>>[];
    for (var i = 1; i < lines.length; i++) {
      final cells = _splitCsvLine(lines[i]);
      if (cells.length != headers.length) continue;
      rows.add({for (var j = 0; j < headers.length; j++) headers[j]: cells[j]});
    }

    if (rows.isEmpty) {
      setState(() => _parseError = 'No data rows found (only header).');
      return null;
    }
    return rows;
  }

  // Handles simple CSV without quoted fields containing commas.
  List<String> _splitCsvLine(String line) =>
      line.split(',').map((c) => c.trim()).toList();

  Future<void> _import() async {
    setState(() { _parseError = null; _result = null; });
    final raw = _csvCtrl.text.trim();
    if (raw.isEmpty) {
      setState(() => _parseError = 'Please paste CSV data first.');
      return;
    }

    final rows = _parseCsv(raw);
    if (rows == null) return;

    setState(() => _importing = true);
    try {
      final res = await LookupAdminRepository().bulkImportRows(rows);
      if (mounted) {
        setState(() {
          _result = _ImportResult(
            upserted: res.upserted,
            skipped: res.skipped,
            failed: res.failed,
            total: rows.length,
          );
          _importing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _parseError = AppErrorMapper.friendly(e);
          _importing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.deepCanopy,
        elevation: 0,
        leading: IconButton(
          icon: const PhosphorIcon(PhosphorIconsRegular.arrowLeft, color: AppColors.surface, size: 22),
          onPressed: () => context.pop(),
        ),
        title: Text('CSV Bulk Import', style: AppTextStyles.appBarTitle()),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(4),
          child: CanopyStripe(height: 4),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenH),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Format guide
            Container(
              padding: const EdgeInsets.all(AppSpacing.base),
              decoration: BoxDecoration(
                color: AppColors.greenTint,
                borderRadius: AppRadii.borderMd,
                border: Border.all(color: AppColors.canopyGreen.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const PhosphorIcon(PhosphorIconsRegular.info, size: 16, color: AppColors.canopyGreen),
                      const SizedBox(width: 8),
                      Text('Required CSV columns:', style: AppTextStyles.label(color: AppColors.canopyGreen)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'region, district, constituency, station_name\n'
                    '+ optional: electoral_area',
                    style: AppTextStyles.small(color: AppColors.canopyGreen),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => setState(() => _csvCtrl.text = _sampleCsv),
                    child: Text(
                      'Tap to load sample →',
                      style: AppTextStyles.small(color: AppColors.canopyGreen).copyWith(
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.base),

            Text('Paste CSV data', style: AppTextStyles.h3()),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadii.borderMd,
                border: Border.all(color: AppColors.hairline),
              ),
              child: TextField(
                controller: _csvCtrl,
                maxLines: 14,
                style: AppTextStyles.timestamp(color: AppColors.ink),
                decoration: InputDecoration(
                  hintText: 'region,district,constituency,electoral_area,station_name\n...',
                  hintStyle: AppTextStyles.timestamp(color: AppColors.textMuted),
                  contentPadding: const EdgeInsets.all(AppSpacing.base),
                  border: InputBorder.none,
                ),
                onChanged: (_) {
                  if (_parseError != null || _result != null) {
                    setState(() { _parseError = null; _result = null; });
                  }
                },
              ),
            ),

            if (_parseError != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.redTint,
                  borderRadius: AppRadii.borderSm,
                ),
                child: Row(
                  children: [
                    const PhosphorIcon(PhosphorIconsRegular.warning, size: 16, color: AppColors.umbrellaRed),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_parseError!, style: AppTextStyles.small(color: AppColors.umbrellaRed))),
                  ],
                ),
              ),
            ],

            if (_result != null) ...[
              const SizedBox(height: AppSpacing.base),
              _ResultCard(result: _result!),
            ],

            const SizedBox(height: AppSpacing.xl),
            NdcButton(
              label: 'Import',
              loading: _importing,
              onPressed: _importing ? null : _import,
              icon: const PhosphorIcon(PhosphorIconsFill.uploadSimple, size: 18, color: AppColors.surface),
            ),
            const SizedBox(height: AppSpacing.base),
            Text(
              'Import is idempotent — re-running with the same data will not create duplicates.',
              style: AppTextStyles.caption(),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ImportResult {
  final int upserted;
  final int skipped;
  final int failed;
  final int total;
  const _ImportResult({
    required this.upserted,
    required this.skipped,
    required this.failed,
    required this.total,
  });
}

class _ResultCard extends StatelessWidget {
  final _ImportResult result;
  const _ResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final allGood = result.failed == 0;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: allGood ? AppColors.greenTint : AppColors.amberTint,
        borderRadius: AppRadii.borderMd,
        border: Border.all(
          color: allGood ? AppColors.canopyGreen.withValues(alpha: 0.4) : AppColors.statusPending.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PhosphorIcon(
                allGood ? PhosphorIconsFill.checkCircle : PhosphorIconsFill.warning,
                size: 18,
                color: allGood ? AppColors.canopyGreen : AppColors.statusPending,
              ),
              const SizedBox(width: 8),
              Text(
                allGood ? 'Import complete' : 'Import complete with errors',
                style: AppTextStyles.label(
                  color: allGood ? AppColors.canopyGreen : AppColors.statusPending,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _Stat('Total rows processed', result.total),
          _Stat('Upserted (new or updated)', result.upserted, color: AppColors.canopyGreen),
          if (result.skipped > 0) _Stat('Skipped (missing fields)', result.skipped, color: AppColors.mist),
          if (result.failed > 0) _Stat('Failed (DB error)', result.failed, color: AppColors.umbrellaRed),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;
  final Color? color;
  const _Stat(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTextStyles.small())),
          Text(
            value.toString(),
            style: AppTextStyles.bodyMedium(color: color ?? AppColors.ink),
          ),
        ],
      ),
    );
  }
}

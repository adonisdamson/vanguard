import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/app_error_mapper.dart';
import '../../data/review_repository.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_radii.dart';
import '../../../../shared/theme/app_shadows.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_text_styles.dart';
import '../../../../shared/widgets/filter_chip_bar.dart';
import '../../../../shared/widgets/load_more_button.dart';
import '../../../../shared/widgets/canopy_arc.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/skeleton_loader.dart';
import '../../../../shared/widgets/status_pill.dart';

class MemberDirectoryScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const MemberDirectoryScreen({super.key, this.showAppBar = true});

  @override
  ConsumerState<MemberDirectoryScreen> createState() => _MemberDirectoryScreenState();
}

class _MemberDirectoryScreenState extends ConsumerState<MemberDirectoryScreen> {
  static const _pageSize = 20;
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  final List<MemberDetail> _items = [];
  int _page = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  String? _error;
  String _activeFilter = 'all';
  String _activeSearch = '';
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _loadPage(0);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _activeSearch = value.trim();
      _loadPage(0);
    });
  }

  Future<void> _loadPage(int page) async {
    if (!mounted) return;
    setState(() {
      if (page == 0) { _loading = true; _error = null; }
      else { _loadingMore = true; }
    });
    try {
      final items = await ReviewRepository().searchMembers(
        page: page,
        query: _activeSearch.isEmpty ? null : _activeSearch,
        statusFilter: _activeFilter,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        if (page == 0) _items.clear();
        _items.addAll(items);
        _page = page;
        _hasMore = items.length == _pageSize;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = AppErrorMapper.forDataLoad(e); _loading = false; _loadingMore = false; });
    }
  }

  Future<void> _triggerExport() async {
    // Let user pick format
    final format = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.hairline, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text('Export format', style: AppTextStyles.h2()),
            const SizedBox(height: 8),
            ListTile(
              leading: const PhosphorIcon(PhosphorIconsRegular.fileCsv, color: AppColors.canopyGreen),
              title: const Text('CSV spreadsheet'),
              subtitle: const Text('Open in Excel or Google Sheets'),
              onTap: () => Navigator.pop(ctx, 'csv'),
            ),
            ListTile(
              leading: const PhosphorIcon(PhosphorIconsRegular.filePdf, color: AppColors.umbrellaRed),
              title: const Text('PDF register'),
              subtitle: const Text('Printable formatted report'),
              onTap: () => Navigator.pop(ctx, 'pdf'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (format == null) return;

    setState(() => _exporting = true);
    try {
      final token = Supabase.instance.client.auth.currentSession?.accessToken;
      if (token == null) throw Exception('Not authenticated');

      final baseUrl = dotenv.env['RAILWAY_API_URL'] ?? '';
      final uri = Uri.parse('$baseUrl/api/exports/members');
      final client = HttpClient();
      final request = await client.postUrl(uri);
      request.headers.set('Authorization', 'Bearer $token');
      request.headers.set('Content-Type', 'application/json');
      request.write(jsonEncode({
        'format': format,
        if (_activeFilter != 'all') 'status': _activeFilter,
        if (_activeSearch.isNotEmpty) 'search': _activeSearch,
      }));

      final response = await request.close().timeout(const Duration(seconds: 120));
      if (response.statusCode != 200) {
        throw Exception('Server error ${response.statusCode}');
      }
      final chunks = <List<int>>[];
      await for (final chunk in response) {
        chunks.add(chunk);
      }
      final bytes = chunks.expand((c) => c).toList();
      client.close();

      final dir = await getApplicationDocumentsDirectory();
      final ts = DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 19);
      final ext = format == 'pdf' ? 'pdf' : 'csv';
      final file = File('${dir.path}/members_$ts.$ext');
      await file.writeAsBytes(bytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AppColors.canopyGreen,
          content: Text(
            '${format.toUpperCase()} saved — ${(bytes.length / 1024).toStringAsFixed(1)} KB',
            style: AppTextStyles.body(color: AppColors.surface),
          ),
          duration: const Duration(seconds: 5),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.umbrellaRed,
            content: Text(AppErrorMapper.friendly(e), style: AppTextStyles.body(color: AppColors.surface)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: AppColors.deepCanopy,
              elevation: 0,
              leading: IconButton(
                tooltip: 'Back',
                icon: const PhosphorIcon(PhosphorIconsRegular.arrowLeft, color: AppColors.surface, size: 22),
                onPressed: () => context.pop(),
              ),
              title: Text('Member directory', style: AppTextStyles.appBarTitle()),
              actions: [
                IconButton(
                  icon: _exporting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.surface))
                      : const PhosphorIcon(PhosphorIconsRegular.export, color: AppColors.surface, size: 22),
                  onPressed: _exporting ? null : _triggerExport,
                  tooltip: 'Export (CSV / PDF)',
                ),
              ],
              bottom: const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: CanopyStripe(height: 4),
              ),
            )
          : null,
      floatingActionButton: !widget.showAppBar
          ? FloatingActionButton.small(
              backgroundColor: AppColors.canopyGreen,
              tooltip: 'Export (CSV / PDF)',
              onPressed: _exporting ? null : _triggerExport,
              child: _exporting
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.surface))
                  : const PhosphorIcon(PhosphorIconsRegular.export, color: AppColors.surface, size: 18),
            )
          : null,
      body: Column(
        children: [
          _SearchBar(
            controller: _searchCtrl,
            onChanged: _onSearchChanged,
            selectedFilter: _activeFilter,
            onFilterChanged: (f) {
              _activeFilter = f;
              _loadPage(0);
            },
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.canopyGreen,
              onRefresh: () => _loadPage(0),
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 8,
        itemBuilder: (_, _) => const Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.sm),
          child: MemberTileSkeleton(),
        ),
      );
    }
    if (_error != null && _items.isEmpty) {
      return EmptyState.offline(onRetry: () => _loadPage(0));
    }
    if (_items.isEmpty) {
      return _searchCtrl.text.isNotEmpty
          ? const EmptyState.noSearchResults()
          : const EmptyState.noMembers();
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _items.length + (_hasMore ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == _items.length) {
          return LoadMoreButton(loading: _loadingMore, onPressed: () => _loadPage(_page + 1));
        }
        return _DirectoryTile(member: _items[i]);
      },
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final void Function(String) onChanged;
  final String selectedFilter;
  final void Function(String) onFilterChanged;

  const _SearchBar({required this.controller, required this.onChanged, required this.selectedFilter, required this.onFilterChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH, AppSpacing.sm,
        AppSpacing.screenH, AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: 'Search by name, phone, or member ID',
              hintStyle: AppTextStyles.body(color: AppColors.mist),
              prefixIcon: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: PhosphorIcon(PhosphorIconsRegular.magnifyingGlass, size: 20, color: AppColors.mist),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 48),
              suffixIcon: controller.text.isNotEmpty
                  ? IconButton(
                      icon: const PhosphorIcon(PhosphorIconsRegular.x, size: 18, color: AppColors.mist),
                      onPressed: () { controller.clear(); onChanged(''); },
                    )
                  : null,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              filled: true,
              fillColor: AppColors.fillMuted,
              border: OutlineInputBorder(borderRadius: AppRadii.borderSm, borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: AppRadii.borderSm, borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadii.borderSm,
                borderSide: const BorderSide(color: AppColors.canopyGreen, width: 2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilterChipBar<String>(
            chips: const [
              (value: 'all',      label: 'All'),
              (value: 'pending',  label: 'Pending'),
              (value: 'active',   label: 'Active'),
              (value: 'rejected', label: 'Rejected'),
            ],
            selected: selectedFilter,
            onSelected: onFilterChanged,
          ),
        ],
      ),
    );
  }
}

class _DirectoryTile extends StatelessWidget {
  final MemberDetail member;
  const _DirectoryTile({required this.member});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/member/${member.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadii.borderMd,
          boxShadow: AppShadows.e1,
          border: Border.all(color: AppColors.hairline, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: AppColors.greenTint,
                borderRadius: AppRadii.borderSm,
              ),
              child: const PhosphorIcon(PhosphorIconsRegular.person, size: 22, color: AppColors.canopyGreen),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.fullName,
                    style: AppTextStyles.title(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (member.memberNumber != null)
                    Text(member.memberNumber!, style: AppTextStyles.memberNumber())
                  else
                    Text(member.phone ?? '—', style: AppTextStyles.small()),
                  if (member.constituencyName != null)
                    Text(
                      member.constituencyName!,
                      style: AppTextStyles.caption(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            StatusPill.fromString(member.status),
          ],
        ),
      ),
    );
  }
}

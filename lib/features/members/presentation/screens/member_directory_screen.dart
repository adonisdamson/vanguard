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
import '../../application/review_providers.dart';
import '../../data/review_repository.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_text_styles.dart';
import '../../../../shared/widgets/ndc_flag_stripe.dart';
import '../../../../shared/widgets/skeleton_loader.dart';
import '../widgets/member_list_tile.dart';
import '../widgets/member_status_badge.dart';

class MemberDirectoryScreen extends ConsumerStatefulWidget {
  const MemberDirectoryScreen({super.key});

  @override
  ConsumerState<MemberDirectoryScreen> createState() => _MemberDirectoryScreenState();
}

class _MemberDirectoryScreenState extends ConsumerState<MemberDirectoryScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  bool _exporting = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(directorySearchProvider.notifier).state = value.trim();
      ref.read(directoryPageProvider.notifier).state = 0;
      ref.invalidate(memberDirectoryProvider);
    });
  }

  Future<void> _triggerExport() async {
    setState(() => _exporting = true);
    try {
      final token = Supabase.instance.client.auth.currentSession?.accessToken;
      if (token == null) throw Exception('Not authenticated');

      final filter = ref.read(directoryFilterProvider);
      final search = ref.read(directorySearchProvider);
      final baseUrl = dotenv.env['RAILWAY_API_URL'] ?? '';
      final uri = Uri.parse('$baseUrl/api/exports/members');

      final client = HttpClient();
      final request = await client.postUrl(uri);
      request.headers.set('Authorization', 'Bearer $token');
      request.headers.set('Content-Type', 'application/json');
      request.write(jsonEncode({
        'filter': {
          if (filter != 'all') 'status': filter,
          if (search.isNotEmpty) 'search': search,
        },
      }));

      final response = await request.close().timeout(const Duration(seconds: 60));
      final chunks = <List<int>>[];
      await for (final chunk in response) {
        chunks.add(chunk);
      }
      final bytes = chunks.expand((c) => c).toList();
      client.close();

      final dir = await getApplicationDocumentsDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/members_export_$ts.csv');
      await file.writeAsBytes(bytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.ndcGreen,
            content: Text(
              'Export saved to Documents (${(bytes.length / 1024).toStringAsFixed(1)} KB)',
              style: AppTextStyles.body(color: AppColors.ndcWhite),
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(directoryFilterProvider);
    final membersAsync = ref.watch(memberDirectoryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.ndcGreen,
        elevation: 0,
        leading: IconButton(
          icon: const PhosphorIcon(PhosphorIconsRegular.arrowLeft, color: AppColors.ndcWhite, size: 22),
          onPressed: () => context.pop(),
        ),
        title: Text('Member Directory', style: AppTextStyles.appBarTitle()),
        actions: [
          IconButton(
            icon: _exporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ndcWhite),
                  )
                : const PhosphorIcon(PhosphorIconsRegular.export, color: AppColors.ndcWhite, size: 22),
            onPressed: _exporting ? null : _triggerExport,
            tooltip: 'Export CSV',
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(4),
          child: NdcFlagStripe(height: 4),
        ),
      ),
      body: Column(
        children: [
          // Search + filter bar
          _SearchBar(
            controller: _searchCtrl,
            onChanged: _onSearchChanged,
            selectedFilter: filter,
            onFilterChanged: (f) {
              ref.read(directoryFilterProvider.notifier).state = f;
              ref.read(directoryPageProvider.notifier).state = 0;
              ref.invalidate(memberDirectoryProvider);
            },
          ),

          // Member list
          Expanded(
            child: RefreshIndicator(
              color: AppColors.ndcGreen,
              onRefresh: () async => ref.invalidate(memberDirectoryProvider),
              child: membersAsync.when(
                data: (members) => members.isEmpty
                    ? _EmptyDirectory(hasSearch: _searchCtrl.text.isNotEmpty)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: members.length,
                        itemBuilder: (_, i) => _DirectoryTile(member: members[i]),
                      ),
                loading: () => ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: 8,
                  itemBuilder: (_, __) => const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: MemberTileSkeleton(),
                  ),
                ),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const PhosphorIcon(PhosphorIconsFill.warningCircle, size: 40, color: AppColors.ndcRed),
                      const SizedBox(height: 12),
                      Text('Failed to load members', style: AppTextStyles.h3()),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => ref.invalidate(memberDirectoryProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final void Function(String) onChanged;
  final String selectedFilter;
  final void Function(String) onFilterChanged;

  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final filters = [('all', 'All'), ('pending', 'Pending'), ('active', 'Active'), ('rejected', 'Rejected')];

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          // Search field
          TextField(
            controller: controller,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: 'Search by name, phone, or member no.',
              hintStyle: AppTextStyles.body(color: AppColors.textMuted),
              prefixIcon: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: PhosphorIcon(PhosphorIconsRegular.magnifyingGlass, size: 20, color: AppColors.textMuted),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 48),
              suffixIcon: controller.text.isNotEmpty
                  ? IconButton(
                      icon: const PhosphorIcon(PhosphorIconsFill.x, size: 18, color: AppColors.textMuted),
                      onPressed: () {
                        controller.clear();
                        onChanged('');
                      },
                    )
                  : null,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            ),
          ),
          const SizedBox(height: 10),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: filters.map(((String value, String label) f) {
                final selected = selectedFilter == f.$1;
                return Padding(
                  padding: const EdgeInsets.only(right: 8, bottom: 12),
                  child: GestureDetector(
                    onTap: () => onFilterChanged(f.$1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.ndcGreen : AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        f.$2,
                        style: AppTextStyles.small(color: selected ? AppColors.ndcWhite : AppColors.textSecondary),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
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
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: const BoxDecoration(color: AppColors.greenLight, shape: BoxShape.circle),
              child: const PhosphorIcon(PhosphorIconsFill.person, size: 22, color: AppColors.ndcGreen),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(member.fullName, style: AppTextStyles.bodyMedium()),
                  if (member.memberNumber != null)
                    Text(member.memberNumber!, style: AppTextStyles.memberNumber())
                  else
                    Text(member.phone ?? '—', style: AppTextStyles.small()),
                  if (member.constituencyName != null)
                    Text(member.constituencyName!, style: AppTextStyles.caption()),
                ],
              ),
            ),
            MemberStatusBadge(status: member.status),
          ],
        ),
      ),
    );
  }
}

class _EmptyDirectory extends StatelessWidget {
  final bool hasSearch;
  const _EmptyDirectory({required this.hasSearch});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PhosphorIcon(PhosphorIconsRegular.magnifyingGlass, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(
              hasSearch ? 'No members match your search' : 'No members found',
              style: AppTextStyles.h3(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              hasSearch ? 'Try a different name, phone, or member number.' : 'Members will appear here once registered.',
              style: AppTextStyles.body(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

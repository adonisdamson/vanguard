import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/router.dart';
import 'core/update/update_gate.dart';
import 'core/web/web_frame.dart';
import 'features/members/application/offline_queue.dart';
import 'shared/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    publishableKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  await Hive.initFlutter();
  await OfflineQueue.init();
  runApp(const ProviderScope(child: VanguardApp()));
}

class VanguardApp extends ConsumerWidget {
  const VanguardApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'TemaWest',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
      // Global in-app update prompt, overlaid above whatever route is active.
      // On wide web screens, center the app in a phone-width frame.
      builder: (context, child) {
        final content = UpdateGate(child: child ?? const SizedBox());
        return kIsWeb ? WebFrame(child: content) : content;
      },
    );
  }
}

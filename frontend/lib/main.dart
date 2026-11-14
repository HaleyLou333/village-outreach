import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'features/auth/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  if (supabaseUrl.isEmpty || supabasePublishableKey.isEmpty) {
    throw StateError(
      'Missing SUPABASE_URL or SUPABASE_PUBLISHABLE_KEY. '
      'Provide both using --dart-define.',
    );
  }

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      detectSessionInUriPredicate: isAppAuthCallback,
    ),
  );

  runApp(const VillageOutreachApp());
}

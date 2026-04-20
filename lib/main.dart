import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/app_theme.dart';
import 'pages/login_page.dart';
import 'pages/main_page.dart';
import 'services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');
  await initializeDateFormatting('id_ID', null);

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kasir Barokah',
      theme: AppTheme.theme,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate>
    with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.detached) {
      await Supabase.instance.client.auth.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final session = snapshot.data?.session;

        if (session != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _handleLogin(session);
          });

          return const MainPage();
        }

        return const LoginPage();
      },
    );
  }

  Future<void> _handleLogin(Session session) async {
    try {
      await _syncProfil(session);
      await SupabaseService.absenMasuk();
    } catch (e) {
      debugPrint('Auto login gagal: $e');
    }
  }

  Future<void> _syncProfil(Session session) async {
    try {
      final meta = session.user.userMetadata;

      if (meta == null || meta.isEmpty) return;

      final existing = await SupabaseService.getProfil();

      if (existing == null ||
          existing['nama'] == null ||
          existing['nama'].toString().isEmpty) {
        await SupabaseService.updateProfil({
          'nama': meta['nama'] ?? '',
          'is_admin': meta['is_admin'] ?? false,
        });
      }
    } catch (_) {}
  }
}
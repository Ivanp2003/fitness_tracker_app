import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/supabase_config.dart';
import 'core/di/service_locator.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/datasources/biometric_datasource.dart';
import 'features/auth/domain/usecases/authenticate_user.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/dashboard/presentation/pages/dashboard_page.dart';
import 'features/steps/presentation/widgets/step_counter_widget.dart';
import 'features/tracking/presentation/widgets/route_map_widget.dart';
import 'features/history/presentation/bloc/history_bloc.dart';
import 'features/history/presentation/pages/history_list_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    publishableKey: SupabaseConfig.supabaseAnonKey,
  );

  runApp(const FitnessApp());
}

class FitnessApp extends StatelessWidget {
  const FitnessApp({super.key});

  @override
  Widget build(BuildContext context) {
    final biometricDataSource = BiometricDataSourceImpl();
    final authenticateUser = AuthenticateUser(biometricDataSource);

    return ListenableBuilder(
      listenable: themeModeNotifier,
      builder: (context, _) {
        return MaterialApp(
          title: 'Fitness Tracker',
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeModeNotifier.value,
          home: BlocProvider(
            create: (_) => AuthBloc(authenticateUser),
            child: const AuthWrapper(),
          ),
        );
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isAuthenticated = false;
  bool _isSupabaseReady = false;
  String? _supabaseError;

  @override
  void initState() {
    super.initState();
    _initSupabaseAuth();
  }

  Future<void> _initSupabaseAuth() async {
    String? errorMsg;
    if (Supabase.instance.client.auth.currentSession == null) {
      try {
        await Supabase.instance.client.auth.signInAnonymously();
      } catch (e) {
        final s = e.toString();
        debugPrint('Error Supabase: $s');
        if (s.contains('Failed host lookup') || s.contains('SocketException')) {
          errorMsg = 'No hay conexión a internet. Verifica tu red.';
        } else if (s.contains('disabled') || s.contains('Anonymous')) {
          errorMsg = 'Inicio anónimo deshabilitado en Supabase.';
        } else {
          errorMsg = 'Error: $s';
        }
      }
    }
    if (mounted) {
      setState(() {
        _isSupabaseReady = true;
        _supabaseError = errorMsg;
      });
    }
  }

  void _onAuthSuccess() {
    setState(() {
      _isAuthenticated = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isSupabaseReady) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_supabaseError != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Error de conexión',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _supabaseError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _supabaseError = null;
                      _isSupabaseReady = false;
                    });
                    _initSupabaseAuth();
                  },
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_isAuthenticated) {
      return const HomePage();
    }
    return LoginPage(onAuthSuccess: _onAuthSuccess);
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fitness Tracker'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Dashboard',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DashboardPage(
                    getActivityHistory: ServiceLocator.getActivityHistory,
                  ),
                ),
              );
            },
          ),
          ListenableBuilder(
            listenable: themeModeNotifier,
            builder: (context, _) => IconButton(
              icon: Icon(
                themeModeNotifier.value == ThemeMode.dark
                    ? Icons.light_mode
                    : Icons.dark_mode,
              ),
              tooltip: 'Modo oscuro',
              onPressed: () {
                themeModeNotifier.value =
                    themeModeNotifier.value == ThemeMode.dark
                        ? ThemeMode.light
                        : ThemeMode.dark;
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Historial',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BlocProvider(
                    create: (context) => HistoryBloc(
                      getActivityHistory: ServiceLocator.getActivityHistory,
                      createActivityRecord: ServiceLocator.createActivityRecord,
                      updateActivityRecord: ServiceLocator.updateActivityRecord,
                      deleteActivityRecord: ServiceLocator.deleteActivityRecord,
                    ),
                    child: const HistoryListPage(),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            StepCounterWidget(),
            SizedBox(height: 16),
            RouteMapWidget(),
          ],
        ),
      ),
    );
  }
}

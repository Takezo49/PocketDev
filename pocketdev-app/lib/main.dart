import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'services/connection.dart';
import 'services/session_state.dart';
import 'screens/auth_screen.dart';
import 'screens/connect_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/session_screen.dart';
import 'theme/colors.dart';

/// Check for ?preview= param on web for design iteration
String? _getPreviewMode() {
  if (!kIsWeb) return null;
  final uri = Uri.base;
  return uri.queryParameters['preview'];
}

void main() {
  runApp(const DevBoxApp());
}

class DevBoxApp extends StatelessWidget {
  const DevBoxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()..init()),
        ChangeNotifierProvider(create: (_) => DevBoxConnection()),
      ],
      child: MaterialApp(
        title: 'PocketDev',
        theme: darkTheme,
        debugShowCheckedModeBanner: false,
        home: const AppRouter(),
      ),
    );
  }
}

/// Flow:
/// Not logged in → AuthScreen
/// Logged in, no device → ConnectScreen
/// Logged in + device → DashboardScreen (tool picker)
/// Select tool → SessionScreen
class AppRouter extends StatefulWidget {
  const AppRouter({super.key});

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  String? _activeTool; // null = show dashboard, 'claude' = show session
  bool _autoConnected = false;

  void _tryAutoConnect() {
    if (_autoConnected) return;
    final auth = context.read<AuthService>();
    final conn = context.read<DevBoxConnection>();

    if (auth.hasDevice && conn.status == ConnectionStatus.disconnected) {
      if (auth.hasDirectConnection) {
        conn.connect(auth.directHost!, auth.directPort!, auth.directSecret!);
      } else {
        conn.autoConnect();
      }
      _autoConnected = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Web preview mode for design iteration
    final preview = _getPreviewMode();
    if (preview != null) {
      return _previewScreen(preview);
    }

    final auth = context.watch<AuthService>();

    // Wait for SharedPreferences to load
    if (!auth.ready) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: SizedBox(width: 24, height: 24,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textMuted)),
        ),
      );
    }

    // Not logged in — but allow direct LAN connect without auth
    if (!auth.isLoggedIn && !auth.hasDirectConnection) {
      return AuthScreen(
        onAuth: () => setState(() {}),
        onSkip: () => setState(() {}),
      );
    }

    // No device paired
    if (!auth.hasDevice) {
      return ConnectScreen(onConnected: () => setState(() {}));
    }

    // Auto-connect on startup
    _tryAutoConnect();

    // Tool selected → show session screen
    if (_activeTool != null) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: ChangeNotifierProxyProvider<DevBoxConnection, SessionState>(
            create: (ctx) => SessionState(ctx.read<DevBoxConnection>()),
            update: (_, conn, prev) => prev ?? SessionState(conn),
            child: SessionScreen(
              onNeedsPairing: () {
                auth.unpairDevice();
                setState(() { _activeTool = null; _autoConnected = false; });
              },
              onBack: () => setState(() => _activeTool = null),
            ),
          ),
        ),
      );
    }

    // Dashboard: pick an AI tool
    return DashboardScreen(
      onSelectTool: (toolId) => setState(() => _activeTool = toolId),
      onDisconnect: () {
        auth.unpairDevice();
        setState(() { _autoConnected = false; });
      },
    );
  }

  /// Preview screens without auth for design iteration
  Widget _previewScreen(String screen) {
    switch (screen) {
      case 'dashboard':
        // Mock as paired for full visual
        WidgetsBinding.instance.addPostFrameCallback((_) {
          context.read<DevBoxConnection>().mockStatus(ConnectionStatus.paired);
        });
        return DashboardScreen(
          onSelectTool: (_) {},
          onDisconnect: () {},
        );
      case 'connect':
        return ConnectScreen(onConnected: () {});
      case 'session':
        // Mock as paired so we see the full empty state
        WidgetsBinding.instance.addPostFrameCallback((_) {
          context.read<DevBoxConnection>().mockStatus(ConnectionStatus.paired);
        });
        return Scaffold(
          backgroundColor: AppColors.bg,
          body: SafeArea(
            child: ChangeNotifierProxyProvider<DevBoxConnection, SessionState>(
              create: (ctx) => SessionState(ctx.read<DevBoxConnection>()),
              update: (_, conn, prev) => prev ?? SessionState(conn),
              child: SessionScreen(
                onNeedsPairing: () {},
                onBack: () {},
              ),
            ),
          ),
        );
      default:
        return AuthScreen(onAuth: () {}, onSkip: () {});
    }
  }
}

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
        title: 'DevBox',
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
      conn.autoConnect();
      _autoConnected = true;
    }
  }

  @override
  Widget build(BuildContext context) {
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

    // Not logged in
    if (!auth.isLoggedIn) {
      return AuthScreen(onAuth: () => setState(() {}));
    }

    // Logged in but no device paired
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
}

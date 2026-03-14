import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'services/connection.dart';
import 'services/session_state.dart';
import 'services/workspace_state.dart';
import 'screens/auth_screen.dart';
import 'screens/connect_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/session_screen.dart';
import 'screens/workspace_picker_screen.dart';
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
        ChangeNotifierProxyProvider<DevBoxConnection, SessionState>(
          create: (ctx) => SessionState(ctx.read<DevBoxConnection>()),
          update: (_, conn, prev) => prev ?? SessionState(conn),
        ),
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
/// Select tool → Workspace Picker (or fast path) → SessionScreen
class AppRouter extends StatefulWidget {
  const AppRouter({super.key});

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  String? _activeTool;
  String? _selectedWorkspace;
  String? _selectedWorkspaceName;
  bool _showWorkspacePicker = false;
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

  /// Select a tool — always show workspace picker
  void _selectTool(String toolId) {
    setState(() {
      _activeTool = toolId;
      _showWorkspacePicker = true;
    });
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

    // Tool selected — decide workspace or session
    if (_activeTool != null) {
      // Workspace selected → show session
      if (_selectedWorkspace != null) {
        return Scaffold(
          backgroundColor: AppColors.bg,
          body: SafeArea(
            child: SessionScreen(
              workspaceName: _selectedWorkspaceName,
              onNeedsPairing: () {
                auth.unpairDevice();
                setState(() {
                  _activeTool = null;
                  _selectedWorkspace = null;
                  _selectedWorkspaceName = null;
                  _showWorkspacePicker = false;
                  _autoConnected = false;
                });
              },
              onBack: () => setState(() {
                _activeTool = null;
                _selectedWorkspace = null;
                _selectedWorkspaceName = null;
                _showWorkspacePicker = false;
              }),
              onChangeWorkspace: () => setState(() {
                _selectedWorkspace = null;
                _selectedWorkspaceName = null;
                _showWorkspacePicker = true;
              }),
            ),
          ),
        );
      }

      // Show workspace picker
      return ChangeNotifierProxyProvider<DevBoxConnection, WorkspaceState>(
        create: (ctx) => WorkspaceState(ctx.read<DevBoxConnection>()),
        update: (_, conn, prev) => prev ?? WorkspaceState(conn),
        child: WorkspacePickerScreen(
          onSelectWorkspace: (path, name) {
            context.read<SessionState>().selectSessionForWorkspace(path);
            setState(() {
              _selectedWorkspace = path;
              _selectedWorkspaceName = name;
              _showWorkspacePicker = false;
            });
          },
          onBack: () => setState(() {
            _activeTool = null;
            _showWorkspacePicker = false;
          }),
        ),
      );
    }

    // Dashboard: pick an AI tool
    return ChangeNotifierProxyProvider<DevBoxConnection, WorkspaceState>(
      create: (ctx) => WorkspaceState(ctx.read<DevBoxConnection>()),
      update: (_, conn, prev) => prev ?? WorkspaceState(conn),
      child: DashboardScreen(
        onSelectTool: _selectTool,
        onSelectToolWithWorkspace: (toolId, path, name) {
          context.read<SessionState>().selectSessionForWorkspace(path);
          setState(() {
            _activeTool = toolId;
            _selectedWorkspace = path;
            _selectedWorkspaceName = name;
          });
        },
        onDisconnect: () {
          auth.unpairDevice();
          setState(() { _autoConnected = false; });
        },
      ),
    );
  }

  /// Preview screens without auth for design iteration
  Widget _previewScreen(String screen) {
    switch (screen) {
      case 'dashboard':
        WidgetsBinding.instance.addPostFrameCallback((_) {
          context.read<DevBoxConnection>().mockStatus(ConnectionStatus.paired);
        });
        return ChangeNotifierProxyProvider<DevBoxConnection, WorkspaceState>(
          create: (ctx) => WorkspaceState(ctx.read<DevBoxConnection>()),
          update: (_, conn, prev) => prev ?? WorkspaceState(conn),
          child: DashboardScreen(
            onSelectTool: (_) {},
            onSelectToolWithWorkspace: (a, b, c) {},
            onDisconnect: () {},
          ),
        );
      case 'connect':
        return ConnectScreen(onConnected: () {});
      case 'workspace':
        WidgetsBinding.instance.addPostFrameCallback((_) {
          context.read<DevBoxConnection>().mockStatus(ConnectionStatus.paired);
        });
        return ChangeNotifierProxyProvider<DevBoxConnection, WorkspaceState>(
          create: (ctx) => WorkspaceState(ctx.read<DevBoxConnection>()),
          update: (_, conn, prev) => prev ?? WorkspaceState(conn),
          child: WorkspacePickerScreen(
            onSelectWorkspace: (a, b) {},
            onBack: () {},
          ),
        );
      case 'session':
        WidgetsBinding.instance.addPostFrameCallback((_) {
          context.read<DevBoxConnection>().mockStatus(ConnectionStatus.paired);
        });
        return Scaffold(
          backgroundColor: AppColors.bg,
          body: SafeArea(
            child: SessionScreen(
              onNeedsPairing: () {},
              onBack: () {},
            ),
          ),
        );
      default:
        return AuthScreen(onAuth: () {}, onSkip: () {});
    }
  }
}

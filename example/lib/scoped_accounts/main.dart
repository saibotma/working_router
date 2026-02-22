import 'package:flutter/material.dart';
import 'package:working_router/working_router.dart';

void main() {
  runApp(const ScopedAccountsExampleApp());
}

class ScopedAccountsExampleApp extends StatefulWidget {
  const ScopedAccountsExampleApp({super.key});

  @override
  State<ScopedAccountsExampleApp> createState() =>
      _ScopedAccountsExampleAppState();
}

class _ScopedAccountsExampleAppState extends State<ScopedAccountsExampleApp> {
  static const _globalScope = GlobalScope();

  final List<AccountScope> _accounts = <AccountScope>[
    const AccountScope('alpha'),
    const AccountScope('beta'),
    const AccountScope('gamma'),
  ];

  late final WorkingRouterV2<AppScope, AppRouteId> _router =
      WorkingRouterV2<AppScope, AppRouteId>(
    initialScope: _globalScope,
    root: ScopeRootLocationV2<AppScope, AppRouteId>(
      children: <LocationV2<AppScope, AppRouteId>>[
        StaticScopeLocationV2<AppScope, GlobalScope, AppRouteId>(
          path: '',
          scope: _globalScope,
          buildScopeRouter: (_, subtree, initialScopedUri) {
            return WorkingRouter.fromLocationSubtreeV2(
              subtree: subtree,
              initialUri: initialScopedUri,
              noContentWidget: const _NoRouteScreen(),
              buildRootPages: _buildGlobalPages,
            );
          },
          children: const <LocationV2<AppScope, AppRouteId>>[
            RouteLocationV2<AppScope, AppRouteId>(
              path: 'login',
              id: AppRouteId.login,
            ),
            RouteLocationV2<AppScope, AppRouteId>(
              path: 'forgot-password',
              id: AppRouteId.forgotPassword,
            ),
            RouteLocationV2<AppScope, AppRouteId>(
              path: 'accounts/add',
              id: AppRouteId.addAccount,
            ),
          ],
        ),
        ScopeLocationV2<AppScope, AccountScope, AppRouteId>(
          path: 'accounts/:accountId',
          resolveScope: _resolveAccountScope,
          serializeScopeParams: _serializeAccountScope,
          buildScopeRouter: (scope, subtree, initialScopedUri) {
            return WorkingRouter.fromLocationSubtreeV2(
              subtree: subtree,
              initialUri: initialScopedUri ?? Uri(path: '/inbox'),
              noContentWidget: const _NoRouteScreen(),
              buildRootPages: (router, location, data) {
                return _buildAccountPages(
                  scope: scope,
                  location: location,
                  data: data,
                );
              },
            );
          },
          children: const <LocationV2<AppScope, AppRouteId>>[
            RouteLocationV2<AppScope, AppRouteId>(
              path: 'inbox',
              id: AppRouteId.inbox,
            ),
            RouteLocationV2<AppScope, AppRouteId>(
              path: 'thread/:threadId',
              id: AppRouteId.thread,
            ),
            RouteLocationV2<AppScope, AppRouteId>(
              path: 'settings',
              id: AppRouteId.settings,
            ),
          ],
        ),
      ],
    ),
    buildShell: (context, host, activeRouter) {
      if (host.activeScope is GlobalScope) {
        return activeRouter;
      }
      return _AccountScopesShell(
        host: host,
        accounts: _accounts,
        onAddAccount: () => host.routeToUri(Uri(path: '/accounts/add')),
      );
    },
  );

  @override
  void initState() {
    super.initState();
    _router.addListener(_syncAccountsWithActiveScope);
  }

  @override
  void dispose() {
    _router.removeListener(_syncAccountsWithActiveScope);
    _router.dispose();
    super.dispose();
  }

  void _syncAccountsWithActiveScope() {
    final scope = _router.activeScope;
    if (scope is! AccountScope) {
      return;
    }
    if (_accounts.contains(scope)) {
      return;
    }
    setState(() {
      _accounts.add(scope);
    });
  }

  List<LocationPageSkeleton<AppRouteId>> _buildGlobalPages(
    WorkingRouter<AppRouteId> router,
    Location<AppRouteId> location,
    WorkingRouterData<AppRouteId> data,
  ) {
    if (location.id == AppRouteId.login) {
      return <LocationPageSkeleton<AppRouteId>>[
        ChildLocationPageSkeleton<AppRouteId>(
          child: _LoginScreen(
            accounts: _accounts,
            onOpenAccount: (accountId) {
              _openAccountById(accountId);
            },
            onAddAccount: () => _router.routeToUri(Uri(path: '/accounts/add')),
            onForgotPassword: () {
              _router.routeToUri(Uri(path: '/forgot-password'));
            },
          ),
        ),
      ];
    }
    if (location.id == AppRouteId.forgotPassword) {
      return <LocationPageSkeleton<AppRouteId>>[
        ChildLocationPageSkeleton<AppRouteId>(
          child: _ForgotPasswordScreen(
            onBackToLogin: () => _router.routeToUri(Uri(path: '/login')),
          ),
        ),
      ];
    }
    if (location.id == AppRouteId.addAccount) {
      return <LocationPageSkeleton<AppRouteId>>[
        ChildLocationPageSkeleton<AppRouteId>(
          child: _AddAccountScreen(
            onCreate: (accountId) {
              _addAndOpenAccount(accountId);
            },
            onCancel: () => _router.routeToUri(Uri(path: '/login')),
          ),
        ),
      ];
    }
    return const <LocationPageSkeleton<AppRouteId>>[];
  }

  List<LocationPageSkeleton<AppRouteId>> _buildAccountPages({
    required AccountScope scope,
    required Location<AppRouteId> location,
    required WorkingRouterData<AppRouteId> data,
  }) {
    if (location.id == AppRouteId.inbox) {
      return <LocationPageSkeleton<AppRouteId>>[
        ChildLocationPageSkeleton<AppRouteId>(
          child: _InboxScreen(
            scope: scope,
            onOpenThread: (threadId) {
              _router.scopeRouterOrNull(scope)?.routeToId(
                AppRouteId.thread,
                pathParameters: <String, String>{
                  'threadId': threadId,
                },
              );
            },
            onOpenSettings: () {
              _router.scopeRouterOrNull(scope)?.routeToId(AppRouteId.settings);
            },
            onLogout: () => _router.routeToUri(Uri(path: '/login')),
          ),
        ),
      ];
    }
    if (location.id == AppRouteId.thread) {
      final threadId = data.pathParameters['threadId'] ?? 'unknown';
      return <LocationPageSkeleton<AppRouteId>>[
        ChildLocationPageSkeleton<AppRouteId>(
          child: _ThreadScreen(
            scope: scope,
            threadId: threadId,
          ),
        ),
      ];
    }
    if (location.id == AppRouteId.settings) {
      return <LocationPageSkeleton<AppRouteId>>[
        ChildLocationPageSkeleton<AppRouteId>(
          child: _SettingsScreen(scope: scope),
        ),
      ];
    }
    return const <LocationPageSkeleton<AppRouteId>>[];
  }

  void _openAccountById(String accountId) {
    final scope = AccountScope(accountId.trim());
    if (scope.id.isEmpty) {
      return;
    }
    if (!_accounts.contains(scope)) {
      setState(() {
        _accounts.add(scope);
      });
    }
    _router.activateScope(scope, initialScopedUri: Uri(path: '/inbox'));
  }

  void _addAndOpenAccount(String accountId) {
    final normalized = accountId.trim();
    if (normalized.isEmpty) {
      return;
    }
    final scope = AccountScope(normalized);
    if (!_accounts.contains(scope)) {
      setState(() {
        _accounts.add(scope);
      });
    }
    _router.routeToUri(Uri(path: '/accounts/${scope.id}/inbox'));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(routerConfig: _router);
  }
}

sealed class AppScope {
  const AppScope();
}

class GlobalScope extends AppScope {
  const GlobalScope();

  @override
  bool operator ==(Object other) => other is GlobalScope;

  @override
  int get hashCode => 1;
}

class AccountScope extends AppScope {
  final String id;

  const AccountScope(this.id);

  @override
  bool operator ==(Object other) {
    return other is AccountScope && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'AccountScope($id)';
}

enum AppRouteId {
  login,
  forgotPassword,
  addAccount,
  inbox,
  thread,
  settings,
}

AccountScope _resolveAccountScope(Map<String, String> params) {
  return AccountScope(params['accountId']!);
}

Map<String, String> _serializeAccountScope(AccountScope scope) {
  return <String, String>{'accountId': scope.id};
}

class _AccountScopesShell extends StatefulWidget {
  final WorkingRouterV2<AppScope, AppRouteId> host;
  final List<AccountScope> accounts;
  final VoidCallback onAddAccount;

  const _AccountScopesShell({
    required this.host,
    required this.accounts,
    required this.onAddAccount,
  });

  @override
  State<_AccountScopesShell> createState() => _AccountScopesShellState();
}

class _AccountScopesShellState extends State<_AccountScopesShell> {
  late PageController _headerController;

  @override
  void initState() {
    super.initState();
    _headerController = PageController(
      viewportFraction: 0.82,
      initialPage: _activeIndex(),
    );
  }

  @override
  void didUpdateWidget(covariant _AccountScopesShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final activeIndex = _activeIndex();
    if (activeIndex >= 0 &&
        _headerController.hasClients &&
        (_headerController.page?.round() ?? _headerController.initialPage) !=
            activeIndex) {
      _headerController.animateToPage(
        activeIndex,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  int _activeIndex() {
    final activeScope = widget.host.activeScope;
    if (activeScope is! AccountScope) {
      return 0;
    }
    final index = widget.accounts.indexOf(activeScope);
    if (index == -1) {
      return 0;
    }
    return index;
  }

  @override
  void dispose() {
    _headerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeIndex = _activeIndex();
    final accountPages = widget.accounts
        .map(
          (scope) => widget.host.buildScopeRouterWidget(
            context,
            scope,
            initialScopedUri: Uri(path: '/inbox'),
          ),
        )
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: SizedBox(
          height: 40,
          child: PageView.builder(
            controller: _headerController,
            onPageChanged: (index) {
              final scope = widget.accounts[index];
              widget.host.activateScope(
                scope,
                initialScopedUri: Uri(path: '/inbox'),
              );
            },
            itemCount: widget.accounts.length,
            itemBuilder: (context, index) {
              final scope = widget.accounts[index];
              final isActive = index == activeIndex;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.blue.shade700
                        : Colors.blueGrey.shade200,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Center(
                    child: Text(
                      scope.id,
                      style: TextStyle(
                        color: isActive ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Add account',
            onPressed: widget.onAddAccount,
            icon: const Icon(Icons.person_add),
          ),
          IconButton(
            tooltip: 'Login screen',
            onPressed: () => widget.host.routeToUri(Uri(path: '/login')),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: IndexedStack(
        index: activeIndex,
        children: accountPages,
      ),
    );
  }
}

class _NoRouteScreen extends StatelessWidget {
  const _NoRouteScreen();

  @override
  Widget build(BuildContext context) {
    final data = WorkingRouterData.of<AppRouteId>(context);
    return Scaffold(
      body: Center(
        child: Text(
          'No route for ${data.uri.path}',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _LoginScreen extends StatelessWidget {
  final List<AccountScope> accounts;
  final ValueChanged<String> onOpenAccount;
  final VoidCallback onAddAccount;
  final VoidCallback onForgotPassword;

  const _LoginScreen({
    required this.accounts,
    required this.onOpenAccount,
    required this.onAddAccount,
    required this.onForgotPassword,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          const Text(
            'Global routes are outside account scopes. '
            'Pick an account to enter a scoped router.',
          ),
          const SizedBox(height: 20),
          ...accounts.map(
            (scope) => ListTile(
              title: Text('Open ${scope.id}'),
              subtitle: Text('/accounts/${scope.id}/inbox'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => onOpenAccount(scope.id),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: onAddAccount,
            child: const Text('Add account'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onForgotPassword,
            child: const Text('Forgot password'),
          ),
        ],
      ),
    );
  }
}

class _ForgotPasswordScreen extends StatelessWidget {
  final VoidCallback onBackToLogin;

  const _ForgotPasswordScreen({
    required this.onBackToLogin,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot password')),
      body: Center(
        child: FilledButton(
          onPressed: onBackToLogin,
          child: const Text('Back to login'),
        ),
      ),
    );
  }
}

class _AddAccountScreen extends StatefulWidget {
  final ValueChanged<String> onCreate;
  final VoidCallback onCancel;

  const _AddAccountScreen({
    required this.onCreate,
    required this.onCancel,
  });

  @override
  State<_AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends State<_AddAccountScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add account')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: <Widget>[
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Account id',
                hintText: 'e.g. delta',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                FilledButton(
                  onPressed: () => widget.onCreate(_controller.text),
                  child: const Text('Create and open'),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: widget.onCancel,
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InboxScreen extends StatelessWidget {
  final AccountScope scope;
  final ValueChanged<String> onOpenThread;
  final VoidCallback onOpenSettings;
  final VoidCallback onLogout;

  const _InboxScreen({
    required this.scope,
    required this.onOpenThread,
    required this.onOpenSettings,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          Text(
            'Account ${scope.id} • Inbox',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 20),
          ...List<Widget>.generate(
            4,
            (index) {
              final threadId = '${scope.id}-thread-$index';
              return ListTile(
                title: Text('Open $threadId'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => onOpenThread(threadId),
              );
            },
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: onOpenSettings,
            child: const Text('Settings'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onLogout,
            child: const Text('Go to /login'),
          ),
        ],
      ),
    );
  }
}

class _ThreadScreen extends StatelessWidget {
  final AccountScope scope;
  final String threadId;

  const _ThreadScreen({
    required this.scope,
    required this.threadId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Thread $threadId'),
        leading: BackButton(
          onPressed: () => WorkingRouter.of<AppRouteId>(context).routeBack(),
        ),
      ),
      body: Center(
        child: Text('Account ${scope.id}\n$threadId'),
      ),
    );
  }
}

class _SettingsScreen extends StatelessWidget {
  final AccountScope scope;

  const _SettingsScreen({
    required this.scope,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${scope.id} settings'),
        leading: BackButton(
          onPressed: () => WorkingRouter.of<AppRouteId>(context).routeBack(),
        ),
      ),
      body: const Center(
        child: Text('Scoped settings'),
      ),
    );
  }
}

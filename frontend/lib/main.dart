import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/api_client.dart';
import 'core/router.dart';
import 'core/theme.dart';

void main() {
  runApp(const HelmApp());
}

/// Root widget. One [ApiClient] is provided app-wide; features build their
/// own repositories and Blocs from it. Navigation is go_router-only.
class HelmApp extends StatelessWidget {
  const HelmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider(
      create: (_) => ApiClient(),
      child: MaterialApp.router(
        title: 'Helm',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        routerConfig: AppRouter.create(),
      ),
    );
  }
}

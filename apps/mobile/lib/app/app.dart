import 'package:flutter/material.dart';

import 'router/app_router.dart';
import 'theme/app_theme.dart';
import '../shared/widgets/app_update_gate.dart';

class MasjidManagerApp extends StatelessWidget {
  const MasjidManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Masjid Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: appRouter,
      builder: (context, child) {
        return AppUpdateGate(child: child ?? const SizedBox.shrink());
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/update/app_update_service.dart';

class AppUpdateGate extends StatefulWidget {
  const AppUpdateGate({
    required this.child,
    super.key,
    this.service = const AppUpdateService(),
  });

  final Widget child;
  final AppUpdateService service;

  @override
  State<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends State<AppUpdateGate>
    with WidgetsBindingObserver {
  var _checking = false;
  var _dialogShowing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _check();
    }
  }

  Future<void> _check() async {
    if (_checking || _dialogShowing || !mounted) return;
    _checking = true;
    try {
      final update = await widget.service.checkForUpdate();
      if (!mounted || update == null || update.manifest.apkUrl.isEmpty) return;

      _dialogShowing = true;
      await showDialog<void>(
        context: context,
        barrierDismissible: !update.isRequired,
        builder: (context) => _UpdateDialog(update: update),
      );
    } catch (_) {
      // Update checks should never block normal app use.
    } finally {
      _checking = false;
      _dialogShowing = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _UpdateDialog extends StatelessWidget {
  const _UpdateDialog({required this.update});

  final AppUpdateInfo update;

  Future<void> _openUpdate() async {
    final url = Uri.parse(update.manifest.apkUrl);
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final notes = update.manifest.releaseNotes.take(4).toList();

    return PopScope(
      canPop: !update.isRequired,
      child: Dialog(
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                color: const Color(0xFF12322B),
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                child: Column(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF6F1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.system_update_alt,
                        color: Color(0xFF13896F),
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      update.manifest.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Version ${update.manifest.latestVersionName}',
                      style: const TextStyle(
                        color: Color(0xFFD7BD72),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      update.manifest.body,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        height: 1.45,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7FAF8),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFDCE8E1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'What is new',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 8),
                          if (notes.isEmpty)
                            const Text(
                              'Performance, stability, and mosque management improvements.',
                            )
                          else
                            for (final note in notes)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.check_circle,
                                      color: Color(0xFF13896F),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(note)),
                                  ],
                                ),
                              ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _openUpdate,
                      icon: const Icon(Icons.download),
                      label: const Text('Update now'),
                    ),
                    if (!update.isRequired) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Later'),
                      ),
                    ] else ...[
                      const SizedBox(height: 10),
                      const Text(
                        'This update is required to continue safely.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFB42318),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

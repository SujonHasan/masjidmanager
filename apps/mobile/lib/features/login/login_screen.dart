import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mosqueNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  var _mode = _AuthMode.login;
  var _country = 'Bangladesh';
  var _currency = 'BDT';
  var _loading = false;
  var _verificationPending = false;
  String? _notice;
  String? _error;
  String? _pendingEmail;

  bool get _firebaseReady => Firebase.apps.isNotEmpty;
  bool get _showVerification => _firebaseReady && _verificationPending;

  @override
  void dispose() {
    _mosqueNameController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_firebaseReady) {
      setState(() {
        _error =
            'Firebase configuration is missing. Run FlutterFire setup first.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _notice = null;
    });

    try {
      if (_mode == _AuthMode.register) {
        await _register();
      } else {
        await _login();
      }
    } catch (error) {
      setState(() {
        _error = _authErrorMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _register() async {
    final auth = FirebaseAuth.instance;
    final firestore = FirebaseFirestore.instance;
    final email = _emailController.text.trim();
    final credential = await auth.createUserWithEmailAndPassword(
      email: email,
      password: _passwordController.text,
    );

    await credential.user!.sendEmailVerification();

    final uid = credential.user!.uid;
    final mosqueRef = firestore.collection('mosques').doc();
    final appUser = <String, dynamic>{
      'uid': uid,
      'email': credential.user!.email,
      'displayName': _mosqueNameController.text.trim(),
      'mosqueId': mosqueRef.id,
      'role': 'owner',
    };
    final mosqueRecord = <String, dynamic>{
      'id': mosqueRef.id,
      'name': _mosqueNameController.text.trim(),
      'address': _addressController.text.trim(),
      'country': _country,
      'currency': _currency,
      'ownerId': uid,
      'status': 'trial',
    };

    final batch = firestore.batch();
    batch.set(mosqueRef, {
      ...mosqueRecord,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(firestore.collection('users').doc(uid), {
      ...appUser,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(mosqueRef.collection('users').doc(uid), {
      ...appUser,
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();

    setState(() {
      _pendingEmail = credential.user!.email;
      _verificationPending = true;
      _notice = 'Verification email sent. Check inbox and spam folder.';
      _error = null;
    });
  }

  Future<void> _login() async {
    final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    await credential.user!.reload();
    final refreshedUser = FirebaseAuth.instance.currentUser;
    final verified = refreshedUser?.emailVerified == true;

    if (verified) {
      await refreshedUser!.getIdToken(true);
      if (mounted) context.go('/dashboard');
      return;
    }

    setState(() {
      _pendingEmail = refreshedUser?.email ?? _emailController.text.trim();
      _verificationPending = true;
      _notice = 'Please verify your email before entering the dashboard.';
      _error = null;
    });
  }

  Future<void> _resendVerificationEmail() async {
    setState(() {
      _loading = true;
      _error = null;
      _notice = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(
          () => _error =
              'Please login again before resending verification email.',
        );
        return;
      }
      await user.sendEmailVerification();
      setState(() {
        _pendingEmail = user.email;
        _notice = 'Verification email sent again.';
      });
    } catch (error) {
      setState(() => _error = _authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _checkVerification() async {
    setState(() {
      _loading = true;
      _error = null;
      _notice = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(
          () => _error = 'Please login again after verifying your email.',
        );
        return;
      }

      await user.reload();
      final refreshedUser = FirebaseAuth.instance.currentUser;
      if (refreshedUser?.emailVerified == true) {
        await refreshedUser!.getIdToken(true);
        if (mounted) context.go('/dashboard');
      } else {
        setState(() {
          _pendingEmail = refreshedUser?.email ?? _pendingEmail;
          _notice =
              'Still not verified. Open the email link first, then check again.';
        });
      }
    } catch (error) {
      setState(() => _error = _authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logoutOrChangeEmail() async {
    await FirebaseAuth.instance.signOut();
    setState(() {
      _verificationPending = false;
      _pendingEmail = null;
      _notice = null;
      _error = null;
    });
  }

  String _authErrorMessage(Object error) {
    final message = error.toString();
    if (message.contains('configuration-not-found') ||
        message.contains('CONFIGURATION_NOT_FOUND')) {
      return 'Firebase Authentication is not initialized. Enable Email/Password in Firebase Console.';
    }
    if (message.contains('operation-not-allowed')) {
      return 'Email/Password sign-in is disabled in Firebase Console.';
    }
    if (message.contains('invalid-credential') ||
        message.contains('wrong-password')) {
      return 'Email or password is not correct.';
    }
    if (message.contains('email-already-in-use')) {
      return 'This email already has an account. Try login instead.';
    }
    if (message.contains('network-request-failed')) {
      return 'Network error. Check internet connection and try again.';
    }
    return message.replaceFirst('Exception: ', '');
  }

  void _switchMode(_AuthMode mode) {
    setState(() {
      _mode = mode;
      _notice = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 8),
            const _BrandHeader(),
            const SizedBox(height: 22),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: _showVerification ? _verificationPanel() : _authForm(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _authForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _mode == _AuthMode.register
                ? 'Create mosque workspace'
                : 'Login to dashboard',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            _mode == _AuthMode.register
                ? 'Register the first owner account for your mosque.'
                : 'Use the same verified admin account from the web dashboard.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.black54),
          ),
          if (!_firebaseReady) ...[
            const SizedBox(height: 14),
            const _MessageBox(
              message:
                  'Firebase is not initialized in this build. Check firebase_options.dart.',
              isError: true,
            ),
          ],
          const SizedBox(height: 18),
          SegmentedButton<_AuthMode>(
            segments: const [
              ButtonSegment(value: _AuthMode.login, label: Text('Login')),
              ButtonSegment(value: _AuthMode.register, label: Text('Register')),
            ],
            selected: {_mode},
            onSelectionChanged: _loading
                ? null
                : (value) => _switchMode(value.first),
          ),
          const SizedBox(height: 18),
          if (_mode == _AuthMode.register) ...[
            TextFormField(
              controller: _mosqueNameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Mosque name'),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Address'),
              validator: _required,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _country,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Country'),
                    onChanged: (value) => _country = value.trim().isEmpty
                        ? 'Bangladesh'
                        : value.trim(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _currency,
                    decoration: const InputDecoration(labelText: 'Currency'),
                    items: const [
                      DropdownMenuItem(value: 'BDT', child: Text('BDT')),
                      DropdownMenuItem(value: 'INR', child: Text('INR')),
                      DropdownMenuItem(value: 'USD', child: Text('USD')),
                      DropdownMenuItem(value: 'GBP', child: Text('GBP')),
                    ],
                    onChanged: _loading
                        ? null
                        : (value) => setState(() => _currency = value ?? 'BDT'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Email'),
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.isEmpty) return 'Email is required';
              if (!text.contains('@')) return 'Enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
            validator: (value) {
              if ((value ?? '').length < 6) return 'Minimum 6 characters';
              return null;
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            _MessageBox(message: _error!, isError: true),
          ],
          if (_notice != null) ...[
            const SizedBox(height: 14),
            _MessageBox(message: _notice!),
          ],
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _loading ? null : _submit,
            child: Text(
              _loading
                  ? 'Please wait...'
                  : (_mode == _AuthMode.register
                        ? 'Create workspace'
                        : 'Login'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _verificationPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(
          Icons.mark_email_unread_outlined,
          size: 48,
          color: Color(0xFF13896F),
        ),
        const SizedBox(height: 14),
        Text(
          'Check your inbox',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          'We sent a verification link to ${_pendingEmail ?? _emailController.text.trim()}. Verify the email, then come back here.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.black54),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          _MessageBox(message: _error!, isError: true),
        ],
        if (_notice != null) ...[
          const SizedBox(height: 14),
          _MessageBox(message: _notice!),
        ],
        const SizedBox(height: 18),
        FilledButton(
          onPressed: _loading ? null : _checkVerification,
          child: Text(_loading ? 'Checking...' : 'I verified, check again'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: _loading ? null : _resendVerificationEmail,
          child: const Text('Resend email'),
        ),
        TextButton(
          onPressed: _loading ? null : _logoutOrChangeEmail,
          child: const Text('Logout or change email'),
        ),
      ],
    );
  }

  String? _required(String? value) {
    if ((value ?? '').trim().isEmpty) return 'Required';
    return null;
  }
}

enum _AuthMode { login, register }

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF6F1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.mosque, size: 36, color: Color(0xFF13896F)),
        ),
        const SizedBox(height: 14),
        const Text(
          'Masjid Manager',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        const Text('Firebase synced admin access for mosque operations.'),
      ],
    );
  }
}

class _MessageBox extends StatelessWidget {
  const _MessageBox({required this.message, this.isError = false});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFFF0F0) : const Color(0xFFEAF6F1),
        border: Border.all(
          color: isError ? const Color(0xFFFFB4B4) : const Color(0xFFCBEBDD),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: isError ? const Color(0xFFB42318) : const Color(0xFF116A56),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

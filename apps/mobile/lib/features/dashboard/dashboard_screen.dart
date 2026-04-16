import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../shared/models/transaction_record.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final Future<_DashboardSession> _sessionFuture = _loadSession();

  Future<_DashboardSession> _loadSession() async {
    if (Firebase.apps.isEmpty) {
      throw const _DashboardException('Firebase is not initialized.');
    }

    final auth = FirebaseAuth.instance;
    final user = auth.currentUser;
    if (user == null) {
      throw const _DashboardException('Please login first.');
    }

    await user.reload();
    final refreshedUser = auth.currentUser;
    if (refreshedUser?.emailVerified != true) {
      throw const _DashboardException(
        'Please verify your email before opening dashboard.',
      );
    }
    await refreshedUser!.getIdToken(true);

    final firestore = FirebaseFirestore.instance;
    final profileSnap = await firestore
        .collection('users')
        .doc(refreshedUser.uid)
        .get();
    if (!profileSnap.exists) {
      throw const _DashboardException('User profile was not found.');
    }

    final profile = profileSnap.data()!;
    final mosqueId = profile['mosqueId'] as String?;
    if (mosqueId == null || mosqueId.isEmpty) {
      throw const _DashboardException(
        'No mosque workspace is connected to this account.',
      );
    }

    final mosqueSnap = await firestore
        .collection('mosques')
        .doc(mosqueId)
        .get();
    if (!mosqueSnap.exists) {
      throw const _DashboardException('Mosque workspace was not found.');
    }

    return _DashboardSession(
      uid: refreshedUser.uid,
      email: refreshedUser.email ?? '',
      mosqueId: mosqueId,
      displayName: profile['displayName'] as String? ?? 'Admin',
      mosqueName: mosqueSnap.data()?['name'] as String? ?? 'Masjid Manager',
      currency: mosqueSnap.data()?['currency'] as String? ?? 'BDT',
    );
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DashboardSession>(
      future: _sessionFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return _DashboardError(
            message: snapshot.error is _DashboardException
                ? (snapshot.error! as _DashboardException).message
                : 'Could not load dashboard. Please login again.',
          );
        }

        return _DashboardContent(session: snapshot.data!, onLogout: _logout);
      },
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.session, required this.onLogout});

  final _DashboardSession session;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;
    final transactionsStream = firestore
        .collection('mosques')
        .doc(session.mosqueId)
        .collection('transactions')
        .snapshots();
    final membersStream = firestore
        .collection('mosques')
        .doc(session.mosqueId)
        .collection('members')
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: Text(session.mosqueName),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: onLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: transactionsStream,
        builder: (context, transactionSnapshot) {
          final transactions =
              transactionSnapshot.data?.docs
                  .map((doc) => TransactionRecord.fromMap(doc.id, doc.data()))
                  .toList() ??
              const <TransactionRecord>[];
          final income = transactions
              .where((transaction) => transaction.type == 'income')
              .fold<num>(0, (total, transaction) => total + transaction.amount);
          final expense = transactions
              .where((transaction) => transaction.type == 'expense')
              .fold<num>(0, (total, transaction) => total + transaction.amount);

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: membersStream,
            builder: (context, memberSnapshot) {
              final memberCount = memberSnapshot.data?.docs.length ?? 0;
              return RefreshIndicator(
                onRefresh: () async {
                  await FirebaseAuth.instance.currentUser?.reload();
                },
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'Realtime dashboard',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Signed in as ${session.email}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                    ),
                    if (transactionSnapshot.hasError ||
                        memberSnapshot.hasError) ...[
                      const SizedBox(height: 14),
                      const _MessageBox(
                        message:
                            'Firestore read failed. Make sure the email is verified and rules are deployed.',
                        isError: true,
                      ),
                    ],
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _StatCard(
                          label: 'Income',
                          value: _formatMoney(income, session.currency),
                          icon: Icons.trending_up,
                        ),
                        _StatCard(
                          label: 'Expense',
                          value: _formatMoney(expense, session.currency),
                          icon: Icons.trending_down,
                        ),
                        _StatCard(
                          label: 'Balance',
                          value: _formatMoney(
                            income - expense,
                            session.currency,
                          ),
                          icon: Icons.account_balance_wallet,
                        ),
                        _StatCard(
                          label: 'Members',
                          value: memberCount.toString(),
                          icon: Icons.groups_2_outlined,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const _ActionGrid(),
                    const SizedBox(height: 20),
                    const _SectionHeader(title: 'Recent activity'),
                    if (transactionSnapshot.connectionState ==
                        ConnectionState.waiting)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (transactions.isEmpty)
                      const _EmptyState()
                    else
                      ...transactions
                          .take(8)
                          .map(
                            (transaction) => _ActivityTile(
                              transaction: transaction,
                              currency: session.currency,
                            ),
                          ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatMoney(num amount, String currency) {
    final symbol = currency == 'BDT' ? '৳' : '$currency ';
    return NumberFormat.currency(
      locale: 'en_BD',
      symbol: symbol,
      decimalDigits: 0,
    ).format(amount);
  }
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.lock_outline,
                      size: 48,
                      color: Color(0xFF13896F),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Dashboard locked',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Text(message),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('Go to login'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: (MediaQuery.sizeOf(context).width - 44) / 2,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: const Color(0xFF13896F)),
              const SizedBox(height: 12),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid();

  @override
  Widget build(BuildContext context) {
    final actions = [
      ('Add Income', Icons.add_card),
      ('Add Expense', Icons.receipt_long),
      ('Members', Icons.groups),
      ('Prayer Times', Icons.schedule),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.6,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (context, index) {
        final action = actions[index];
        return OutlinedButton.icon(
          onPressed: () {},
          icon: Icon(action.$2),
          label: Text(action.$1),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.transaction, required this.currency});

  final TransactionRecord transaction;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == 'income';
    final symbol = currency == 'BDT' ? '৳' : '$currency ';
    final amount = NumberFormat.currency(
      locale: 'en_BD',
      symbol: symbol,
      decimalDigits: 0,
    ).format(transaction.amount);

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isIncome
              ? const Color(0xFFEAF6F1)
              : const Color(0xFFFFF0F0),
          foregroundColor: isIncome
              ? const Color(0xFF13896F)
              : const Color(0xFFB42318),
          child: Icon(isIncome ? Icons.south_west : Icons.north_east),
        ),
        title: Text(
          transaction.categoryNameSnapshot,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          transaction.notes.isEmpty
              ? transaction.paymentMethod
              : transaction.notes,
        ),
        trailing: Text(
          '${isIncome ? '+' : '-'}$amount',
          style: TextStyle(
            color: isIncome ? const Color(0xFF13896F) : const Color(0xFFB42318),
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 42,
              color: Color(0xFF13896F),
            ),
            SizedBox(height: 10),
            Text(
              'No transactions yet',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 4),
            Text(
              'Add income or expense from the web dashboard and it will appear here.',
            ),
          ],
        ),
      ),
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

class _DashboardSession {
  const _DashboardSession({
    required this.uid,
    required this.email,
    required this.mosqueId,
    required this.displayName,
    required this.mosqueName,
    required this.currency,
  });

  final String uid;
  final String email;
  final String mosqueId;
  final String displayName;
  final String mosqueName;
  final String currency;
}

class _DashboardException implements Exception {
  const _DashboardException(this.message);

  final String message;
}

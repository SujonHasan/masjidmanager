import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../shared/models/category.dart';
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
      address: mosqueSnap.data()?['address'] as String? ?? '',
      role: profile['role'] as String? ?? 'owner',
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

class _DashboardContent extends StatefulWidget {
  const _DashboardContent({required this.session, required this.onLogout});

  final _DashboardSession session;
  final Future<void> Function() onLogout;

  @override
  State<_DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<_DashboardContent> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  var _section = _DashboardSection.overview;
  var _seededDefaults = false;

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _collection(String name) {
    return _firestore
        .collection('mosques')
        .doc(widget.session.mosqueId)
        .collection(name);
  }

  Future<void> _seedDefaultCategoriesIfNeeded() async {
    if (_seededDefaults) return;
    _seededDefaults = true;

    final categories = await _collection('categories').limit(1).get();
    if (categories.docs.isNotEmpty) return;

    final batch = _firestore.batch();
    for (final category in _defaultCategories(
      widget.session.mosqueId,
      widget.session.uid,
    )) {
      batch.set(_collection('categories').doc(category['id'] as String), {
        ...category,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  void _openSection(_DashboardSection section) {
    setState(() => _section = section);
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final title = _section.label;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _collection('categories').snapshots(),
      builder: (context, categorySnapshot) {
        if (categorySnapshot.hasData && categorySnapshot.data!.docs.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _seedDefaultCategoriesIfNeeded().catchError((_) {});
          });
        }

        final categories =
            categorySnapshot.data?.docs
                .map((doc) => CategoryModel.fromMap(doc.id, doc.data()))
                .toList() ??
            const <CategoryModel>[];

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _collection('transactions').snapshots(),
          builder: (context, transactionSnapshot) {
            final transactions =
                transactionSnapshot.data?.docs
                    .map((doc) => TransactionRecord.fromMap(doc.id, doc.data()))
                    .toList() ??
                const <TransactionRecord>[];

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _collection('members').snapshots(),
              builder: (context, memberSnapshot) {
                final members = memberSnapshot.data?.docs ?? const [];
                final readError =
                    categorySnapshot.hasError ||
                    transactionSnapshot.hasError ||
                    memberSnapshot.hasError;

                return Scaffold(
                  key: _scaffoldKey,
                  appBar: AppBar(
                    title: Text(title),
                    leading: IconButton(
                      tooltip: 'Menu',
                      icon: const Icon(Icons.menu),
                      onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                    ),
                    actions: [
                      IconButton(
                        tooltip: 'Logout',
                        onPressed: widget.onLogout,
                        icon: const Icon(Icons.logout),
                      ),
                    ],
                  ),
                  drawer: _DashboardDrawer(
                    session: widget.session,
                    activeSection: _section,
                    onSelect: _openSection,
                    onLogout: widget.onLogout,
                  ),
                  bottomNavigationBar: NavigationBar(
                    selectedIndex: _bottomIndex(_section),
                    onDestinationSelected: (index) {
                      final section = switch (index) {
                        0 => _DashboardSection.overview,
                        1 => _DashboardSection.income,
                        2 => _DashboardSection.expenses,
                        _ => _DashboardSection.categories,
                      };
                      _openSection(section);
                    },
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.dashboard_outlined),
                        label: 'Overview',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.add_card),
                        label: 'Income',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.receipt_long),
                        label: 'Expense',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.category_outlined),
                        label: 'More',
                      ),
                    ],
                  ),
                  body: readError
                      ? const _ErrorPanel(
                          message:
                              'Firestore read failed. Make sure the email is verified and rules are deployed.',
                        )
                      : _DashboardBody(
                          section: _section,
                          session: widget.session,
                          categories: categories,
                          transactions: transactions,
                          members: members,
                          collection: _collection,
                          onOpenSection: _openSection,
                        ),
                );
              },
            );
          },
        );
      },
    );
  }

  int _bottomIndex(_DashboardSection section) {
    return switch (section) {
      _DashboardSection.overview => 0,
      _DashboardSection.income => 1,
      _DashboardSection.expenses => 2,
      _ => 3,
    };
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.section,
    required this.session,
    required this.categories,
    required this.transactions,
    required this.members,
    required this.collection,
    required this.onOpenSection,
  });

  final _DashboardSection section;
  final _DashboardSession session;
  final List<CategoryModel> categories;
  final List<TransactionRecord> transactions;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> members;
  final CollectionReference<Map<String, dynamic>> Function(String name)
  collection;
  final void Function(_DashboardSection section) onOpenSection;

  @override
  Widget build(BuildContext context) {
    return switch (section) {
      _DashboardSection.overview => _OverviewPanel(
        session: session,
        categories: categories,
        transactions: transactions,
        members: members,
        onOpenSection: onOpenSection,
      ),
      _DashboardSection.income => _TransactionPanel(
        type: 'income',
        session: session,
        categories: categories,
        transactions: transactions,
        collection: collection,
      ),
      _DashboardSection.expenses => _TransactionPanel(
        type: 'expense',
        session: session,
        categories: categories,
        transactions: transactions,
        collection: collection,
      ),
      _DashboardSection.categories => _CategoryPanel(
        session: session,
        categories: categories,
        collection: collection,
      ),
      _DashboardSection.members => _MemberPanel(
        session: session,
        members: members,
        collection: collection,
      ),
      _DashboardSection.announcements => _SimpleCollectionPanel(
        title: 'Announcements',
        description: 'Publish mosque updates for web and mobile users.',
        collectionName: 'announcements',
        collection: collection,
        fields: const [
          _FormFieldSpec('title', 'Title'),
          _FormFieldSpec('body', 'Message', multiline: true),
          _FormFieldSpec('audience', 'Audience', initialValue: 'public'),
        ],
        itemTitleKey: 'title',
        itemSubtitleKey: 'body',
      ),
      _DashboardSection.prayer => _SimpleCollectionPanel(
        title: 'Prayer Times',
        description: 'Maintain Salah and Jummah schedule.',
        collectionName: 'prayerTimes',
        collection: collection,
        fields: const [
          _FormFieldSpec(
            'label',
            'Schedule label',
            initialValue: 'Regular Schedule',
          ),
          _FormFieldSpec('fajr', 'Fajr'),
          _FormFieldSpec('dhuhr', 'Dhuhr'),
          _FormFieldSpec('asr', 'Asr'),
          _FormFieldSpec('maghrib', 'Maghrib'),
          _FormFieldSpec('isha', 'Isha'),
          _FormFieldSpec('jummah', 'Jummah'),
        ],
        itemTitleKey: 'label',
        itemSubtitleKey: 'fajr',
        subtitleBuilder: (data) =>
            'Fajr ${data['fajr'] ?? '-'} · Dhuhr ${data['dhuhr'] ?? '-'} · Asr ${data['asr'] ?? '-'} · Maghrib ${data['maghrib'] ?? '-'} · Isha ${data['isha'] ?? '-'}',
      ),
      _DashboardSection.reports => _ReportsPanel(
        session: session,
        transactions: transactions,
        members: members,
      ),
      _DashboardSection.settings => _SettingsPanel(session: session),
    };
  }
}

class _OverviewPanel extends StatelessWidget {
  const _OverviewPanel({
    required this.session,
    required this.categories,
    required this.transactions,
    required this.members,
    required this.onOpenSection,
  });

  final _DashboardSession session;
  final List<CategoryModel> categories;
  final List<TransactionRecord> transactions;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> members;
  final void Function(_DashboardSection section) onOpenSection;

  @override
  Widget build(BuildContext context) {
    final income = _sumTransactions(transactions, 'income');
    final expense = _sumTransactions(transactions, 'expense');

    return RefreshIndicator(
      onRefresh: () async => FirebaseAuth.instance.currentUser?.reload(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            session.mosqueName,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            session.address.isEmpty
                ? 'Signed in as ${session.email}'
                : session.address,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.black54),
          ),
          const SizedBox(height: 16),
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
                value: _formatMoney(income - expense, session.currency),
                icon: Icons.account_balance_wallet,
              ),
              _StatCard(
                label: 'Members',
                value: members.length.toString(),
                icon: Icons.groups_2_outlined,
              ),
            ],
          ),
          const SizedBox(height: 18),
          GridView.count(
            crossAxisCount: 2,
            childAspectRatio: 2.6,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _QuickAction(
                'Add Income',
                Icons.add_card,
                () => onOpenSection(_DashboardSection.income),
              ),
              _QuickAction(
                'Add Expense',
                Icons.receipt_long,
                () => onOpenSection(_DashboardSection.expenses),
              ),
              _QuickAction(
                'Categories',
                Icons.category_outlined,
                () => onOpenSection(_DashboardSection.categories),
              ),
              _QuickAction(
                'Members',
                Icons.groups,
                () => onOpenSection(_DashboardSection.members),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const _SectionHeader(title: 'Recent activity'),
          if (transactions.isEmpty)
            const _EmptyState(
              title: 'No transactions yet',
              body: 'Use Add Income or Add Expense from the mobile menu.',
            )
          else
            ...transactions
                .take(8)
                .map(
                  (transaction) => _ActivityTile(
                    transaction: transaction,
                    currency: session.currency,
                  ),
                ),
          const SizedBox(height: 12),
          Text(
            '${categories.length} categories synced from Firebase',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _TransactionPanel extends StatefulWidget {
  const _TransactionPanel({
    required this.type,
    required this.session,
    required this.categories,
    required this.transactions,
    required this.collection,
  });

  final String type;
  final _DashboardSession session;
  final List<CategoryModel> categories;
  final List<TransactionRecord> transactions;
  final CollectionReference<Map<String, dynamic>> Function(String name)
  collection;

  @override
  State<_TransactionPanel> createState() => _TransactionPanelState();
}

class _TransactionPanelState extends State<_TransactionPanel> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  var _paymentMethod = 'Cash';
  var _date = DateFormat('yyyy-MM-dd').format(DateTime.now());
  String? _categoryId;
  var _saving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final categories = _activeCategories;
    final categoryId =
        _categoryId ?? (categories.isNotEmpty ? categories.first.id : null);
    if (categoryId == null) return;

    final category = categories.firstWhere((item) => item.id == categoryId);
    setState(() => _saving = true);
    try {
      await widget.collection('transactions').add({
        'mosqueId': widget.session.mosqueId,
        'type': widget.type,
        'categoryId': category.id,
        'categoryNameSnapshot': category.name,
        'amount': num.parse(_amountController.text.trim()),
        'date': _date,
        'paymentMethod': _paymentMethod,
        'notes': _notesController.text.trim(),
        'createdBy': widget.session.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _amountController.clear();
      _notesController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${widget.type == 'income' ? 'Income' : 'Expense'} saved',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<CategoryModel> get _activeCategories {
    return widget.categories
        .where((category) => category.type == widget.type && category.isActive)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final categories = _activeCategories;
    final records = widget.transactions
        .where((item) => item.type == widget.type)
        .toList();
    final title = widget.type == 'income' ? 'Add Income' : 'Add Expense';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _PanelHeader(
          title: title,
          description: widget.type == 'income'
              ? 'Record Zakat, Sadaqah, Jummah collection, monthly collection, and other income.'
              : 'Record salary, utility bills, maintenance, construction, and other expenses.',
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (categories.isEmpty)
                    const _MessageBox(
                      message:
                          'No active category found. Open Categories and add one first.',
                      isError: true,
                    )
                  else
                    DropdownButtonFormField<String>(
                      initialValue: _categoryId ?? categories.first.id,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: categories
                          .map(
                            (category) => DropdownMenuItem(
                              value: category.id,
                              child: Text(category.name),
                            ),
                          )
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _categoryId = value),
                    ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Amount'),
                    validator: (value) {
                      final amount = num.tryParse(value?.trim() ?? '');
                      if (amount == null || amount <= 0) {
                        return 'Enter a valid amount';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: _date,
                    decoration: const InputDecoration(labelText: 'Date'),
                    onChanged: (value) =>
                        _date = value.trim().isEmpty ? _date : value.trim(),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _paymentMethod,
                    decoration: const InputDecoration(
                      labelText: 'Payment method',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                      DropdownMenuItem(value: 'Bank', child: Text('Bank')),
                      DropdownMenuItem(value: 'bKash', child: Text('bKash')),
                      DropdownMenuItem(value: 'Nagad', child: Text('Nagad')),
                      DropdownMenuItem(value: 'Other', child: Text('Other')),
                    ],
                    onChanged: _saving
                        ? null
                        : (value) =>
                              setState(() => _paymentMethod = value ?? 'Cash'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notesController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Notes'),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _saving || categories.isEmpty ? null : _save,
                    child: Text(_saving ? 'Saving...' : 'Save'),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        const _SectionHeader(title: 'Saved records'),
        if (records.isEmpty)
          _EmptyState(
            title: 'No ${widget.type} records yet',
            body: 'Saved records will appear here.',
          )
        else
          ...records.map(
            (transaction) => _ActivityTile(
              transaction: transaction,
              currency: widget.session.currency,
            ),
          ),
      ],
    );
  }
}

class _CategoryPanel extends StatefulWidget {
  const _CategoryPanel({
    required this.session,
    required this.categories,
    required this.collection,
  });

  final _DashboardSession session;
  final List<CategoryModel> categories;
  final CollectionReference<Map<String, dynamic>> Function(String name)
  collection;

  @override
  State<_CategoryPanel> createState() => _CategoryPanelState();
}

class _CategoryPanelState extends State<_CategoryPanel> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  var _type = 'income';
  var _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final name = _nameController.text.trim();
    final id =
        '$_type-${_slugify(name)}-${DateTime.now().millisecondsSinceEpoch}';
    setState(() => _saving = true);
    try {
      await widget.collection('categories').doc(id).set({
        'id': id,
        'mosqueId': widget.session.mosqueId,
        'type': _type,
        'name': name,
        'slug': _slugify(name),
        'color': _type == 'income' ? '#13896f' : '#b42318',
        'icon': 'receipt',
        'isDefault': false,
        'isActive': true,
        'sortOrder': widget.categories.length + 1,
        'createdBy': widget.session.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _nameController.clear();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _PanelHeader(
          title: 'Categories',
          description:
              'Add dynamic income and expense categories. They sync with the web dashboard.',
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'income', label: Text('Income')),
                      ButtonSegment(value: 'expense', label: Text('Expense')),
                    ],
                    selected: {_type},
                    onSelectionChanged: _saving
                        ? null
                        : (value) => setState(() => _type = value.first),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Category name',
                    ),
                    validator: (value) =>
                        (value ?? '').trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Saving...' : 'Add category'),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        if (widget.categories.isEmpty)
          const _EmptyState(
            title: 'No categories yet',
            body: 'Default categories are being prepared.',
          )
        else
          ...widget.categories.map(
            (category) => _CategoryTile(category: category),
          ),
      ],
    );
  }
}

class _MemberPanel extends StatefulWidget {
  const _MemberPanel({
    required this.session,
    required this.members,
    required this.collection,
  });

  final _DashboardSession session;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> members;
  final CollectionReference<Map<String, dynamic>> Function(String name)
  collection;

  @override
  State<_MemberPanel> createState() => _MemberPanelState();
}

class _MemberPanelState extends State<_MemberPanel> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _monthlyAmountController = TextEditingController();
  var _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _monthlyAmountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.collection('members').add({
        'mosqueId': widget.session.mosqueId,
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'monthlyAmount':
            num.tryParse(_monthlyAmountController.text.trim()) ?? 0,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      });
      _nameController.clear();
      _phoneController.clear();
      _addressController.clear();
      _monthlyAmountController.clear();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _PanelHeader(
          title: 'Members',
          description:
              'Track member contact details and expected monthly collection.',
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (value) =>
                        (value ?? '').trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(labelText: 'Phone'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(labelText: 'Address'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _monthlyAmountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Monthly amount',
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Saving...' : 'Add member'),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        if (widget.members.isEmpty)
          const _EmptyState(
            title: 'No members yet',
            body: 'Added members will appear here.',
          )
        else
          ...widget.members.map((member) {
            final data = member.data();
            return Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text(data['name'] as String? ?? 'Member'),
                subtitle: Text(
                  '${data['phone'] ?? 'No phone'} · ${data['address'] ?? 'No address'}',
                ),
                trailing: Text(
                  _formatMoney(
                    data['monthlyAmount'] as num? ?? 0,
                    widget.session.currency,
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _SimpleCollectionPanel extends StatefulWidget {
  const _SimpleCollectionPanel({
    required this.title,
    required this.description,
    required this.collectionName,
    required this.collection,
    required this.fields,
    required this.itemTitleKey,
    required this.itemSubtitleKey,
    this.subtitleBuilder,
  });

  final String title;
  final String description;
  final String collectionName;
  final CollectionReference<Map<String, dynamic>> Function(String name)
  collection;
  final List<_FormFieldSpec> fields;
  final String itemTitleKey;
  final String itemSubtitleKey;
  final String Function(Map<String, dynamic> data)? subtitleBuilder;

  @override
  State<_SimpleCollectionPanel> createState() => _SimpleCollectionPanelState();
}

class _SimpleCollectionPanelState extends State<_SimpleCollectionPanel> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers = {
    for (final field in widget.fields)
      field.key: TextEditingController(text: field.initialValue),
  };
  var _saving = false;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.collection(widget.collectionName).add({
        for (final entry in _controllers.entries)
          entry.key: entry.value.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      for (final field in widget.fields) {
        _controllers[field.key]!.text = field.initialValue;
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: widget.collection(widget.collectionName).snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const [];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _PanelHeader(title: widget.title, description: widget.description),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final field in widget.fields) ...[
                        TextFormField(
                          controller: _controllers[field.key],
                          minLines: field.multiline ? 3 : 1,
                          maxLines: field.multiline ? 5 : 1,
                          decoration: InputDecoration(labelText: field.label),
                          validator: (value) =>
                              (value ?? '').trim().isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                      ],
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        child: Text(_saving ? 'Saving...' : 'Save'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (docs.isEmpty)
              _EmptyState(
                title: 'No ${widget.title.toLowerCase()} yet',
                body: 'Saved records will appear here.',
              )
            else
              ...docs.map((doc) {
                final data = doc.data();
                return Card(
                  child: ListTile(
                    title: Text(
                      data[widget.itemTitleKey] as String? ?? widget.title,
                    ),
                    subtitle: Text(
                      widget.subtitleBuilder?.call(data) ??
                          (data[widget.itemSubtitleKey] as String? ?? ''),
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}

class _ReportsPanel extends StatelessWidget {
  const _ReportsPanel({
    required this.session,
    required this.transactions,
    required this.members,
  });

  final _DashboardSession session;
  final List<TransactionRecord> transactions;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> members;

  @override
  Widget build(BuildContext context) {
    final income = _sumTransactions(transactions, 'income');
    final expense = _sumTransactions(transactions, 'expense');
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _PanelHeader(
          title: 'Reports',
          description:
              'Live summary from Firebase records. PDF export can be added later.',
        ),
        const SizedBox(height: 16),
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
              value: _formatMoney(income - expense, session.currency),
              icon: Icons.wallet,
            ),
            _StatCard(
              label: 'Entries',
              value: transactions.length.toString(),
              icon: Icons.list_alt,
            ),
          ],
        ),
      ],
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({required this.session});

  final _DashboardSession session;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _PanelHeader(
          title: 'Settings',
          description: 'Current Firebase workspace details.',
        ),
        const SizedBox(height: 14),
        Card(
          child: Column(
            children: [
              _SettingTile(label: 'Mosque', value: session.mosqueName),
              _SettingTile(
                label: 'Address',
                value: session.address.isEmpty ? '-' : session.address,
              ),
              _SettingTile(label: 'User', value: session.email),
              _SettingTile(label: 'Role', value: session.role),
              _SettingTile(label: 'Currency', value: session.currency),
              _SettingTile(label: 'Mosque ID', value: session.mosqueId),
            ],
          ),
        ),
      ],
    );
  }
}

class _DashboardDrawer extends StatelessWidget {
  const _DashboardDrawer({
    required this.session,
    required this.activeSection,
    required this.onSelect,
    required this.onLogout,
  });

  final _DashboardSession session;
  final _DashboardSection activeSection;
  final void Function(_DashboardSection section) onSelect;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF6F1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.mosque, color: Color(0xFF13896F)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.mosqueName,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          session.role,
                          style: const TextStyle(
                            color: Colors.black54,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                children: [
                  for (final section in _DashboardSection.values)
                    ListTile(
                      selected: activeSection == section,
                      leading: Icon(section.icon),
                      title: Text(section.label),
                      onTap: () => onSelect(section),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: onLogout,
            ),
          ],
        ),
      ),
    );
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

class _QuickAction extends StatelessWidget {
  const _QuickAction(this.label, this.icon, this.onPressed);

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category});

  final CategoryModel category;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Container(
          width: 12,
          height: 36,
          decoration: BoxDecoration(
            color: _parseColor(category.color),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        title: Text(
          category.name,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${category.type} · ${category.isDefault ? 'Default' : 'Custom'}',
        ),
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
    final amount = _formatMoney(transaction.amount, currency);

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
              ? '${transaction.date} · ${transaction.paymentMethod}'
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

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(
          description,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.black54),
        ),
      ],
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const Icon(
              Icons.inbox_outlined,
              size: 42,
              color: Color(0xFF13896F),
            ),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(body, textAlign: TextAlign.center),
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

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _MessageBox(message: message, isError: true),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(value),
    );
  }
}

class _FormFieldSpec {
  const _FormFieldSpec(
    this.key,
    this.label, {
    this.initialValue = '',
    this.multiline = false,
  });

  final String key;
  final String label;
  final String initialValue;
  final bool multiline;
}

class _DashboardSession {
  const _DashboardSession({
    required this.uid,
    required this.email,
    required this.mosqueId,
    required this.displayName,
    required this.mosqueName,
    required this.address,
    required this.role,
    required this.currency,
  });

  final String uid;
  final String email;
  final String mosqueId;
  final String displayName;
  final String mosqueName;
  final String address;
  final String role;
  final String currency;
}

class _DashboardException implements Exception {
  const _DashboardException(this.message);

  final String message;
}

enum _DashboardSection {
  overview('Overview', Icons.dashboard_outlined),
  income('Income', Icons.add_card),
  expenses('Expenses', Icons.receipt_long),
  categories('Categories', Icons.category_outlined),
  members('Members', Icons.groups_outlined),
  announcements('Announcements', Icons.campaign_outlined),
  prayer('Prayer Times', Icons.schedule),
  reports('Reports', Icons.bar_chart),
  settings('Settings', Icons.settings_outlined);

  const _DashboardSection(this.label, this.icon);

  final String label;
  final IconData icon;
}

String _formatMoney(num amount, String currency) {
  final symbol = currency == 'BDT' ? '৳' : '$currency ';
  return NumberFormat.currency(
    locale: 'en_BD',
    symbol: symbol,
    decimalDigits: 0,
  ).format(amount);
}

num _sumTransactions(List<TransactionRecord> transactions, String type) {
  return transactions
      .where((transaction) => transaction.type == type)
      .fold<num>(0, (total, transaction) => total + transaction.amount);
}

String _slugify(String value) {
  final slug = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return slug.isEmpty ? 'category' : slug;
}

Color _parseColor(String hex) {
  final normalized = hex.replaceFirst('#', '');
  final value = int.tryParse('ff$normalized', radix: 16);
  return Color(value ?? 0xff13896f);
}

List<Map<String, Object>> _defaultCategories(String mosqueId, String uid) {
  final income = [
    'Zakat',
    'Sadaqah',
    'Fitra',
    'Jummah Collection',
    'Monthly Collection',
    'Building Fund',
    'Madrasa Fee',
    'Other',
  ];
  final expense = [
    'Imam Salary',
    'Muazzin Salary',
    'Electricity Bill',
    'Water Bill',
    'Cleaning',
    'Maintenance',
    'Construction',
    'Madrasa Expense',
    'Other',
  ];

  Map<String, Object> item(String type, String name, int index) {
    final id = '$type-${_slugify(name)}';
    return {
      'id': id,
      'mosqueId': mosqueId,
      'type': type,
      'name': name,
      'slug': _slugify(name),
      'color': type == 'income' ? '#13896f' : '#b42318',
      'icon': 'receipt',
      'isDefault': true,
      'isActive': true,
      'sortOrder': index,
      'createdBy': uid,
    };
  }

  return [
    for (var index = 0; index < income.length; index++)
      item('income', income[index], index + 1),
    for (var index = 0; index < expense.length; index++)
      item('expense', expense[index], index + 1),
  ];
}

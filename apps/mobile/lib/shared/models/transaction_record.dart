class TransactionRecord {
  const TransactionRecord({
    required this.id,
    required this.type,
    required this.categoryNameSnapshot,
    required this.amount,
    required this.date,
    required this.paymentMethod,
    required this.notes,
  });

  final String id;
  final String type;
  final String categoryNameSnapshot;
  final num amount;
  final String date;
  final String paymentMethod;
  final String notes;

  factory TransactionRecord.fromMap(String id, Map<String, dynamic> data) {
    return TransactionRecord(
      id: id,
      type: data['type'] as String? ?? 'income',
      categoryNameSnapshot:
          data['categoryNameSnapshot'] as String? ?? 'Uncategorized',
      amount: data['amount'] as num? ?? 0,
      date: data['date'] as String? ?? '',
      paymentMethod: data['paymentMethod'] as String? ?? 'Cash',
      notes: data['notes'] as String? ?? '',
    );
  }
}

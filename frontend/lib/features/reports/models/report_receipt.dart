class ReportReceipt {
  final String id;
  final String status;

  const ReportReceipt({required this.id, required this.status});

  factory ReportReceipt.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final status = json['status'];

    if (id is! String || id.isEmpty || status != 'pending') {
      throw const FormatException('Invalid report receipt.');
    }

    return ReportReceipt(id: id, status: status as String);
  }
}

enum ReportTargetType { request, user }

enum ReportReason {
  spam('spam', 'Spam'),
  harassment('harassment', 'Harassment'),
  unsafeContent('unsafe_content', 'Unsafe content'),
  fraud('fraud', 'Fraud'),
  other('other', 'Other');

  final String apiValue;
  final String label;

  const ReportReason(this.apiValue, this.label);
}

class SafetyReport {
  final ReportTargetType targetType;
  final String targetId;
  final ReportReason reason;
  final String? description;

  const SafetyReport({
    required this.targetType,
    required this.targetId,
    required this.reason,
    this.description,
  });

  Map<String, dynamic> toJson() {
    final normalizedDescription = description?.trim();

    return {
      'target_type': targetType.name,
      'target_id': targetId,
      'reason': reason.apiValue,
      if (normalizedDescription != null && normalizedDescription.isNotEmpty)
        'description': normalizedDescription,
    };
  }
}

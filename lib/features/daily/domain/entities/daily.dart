class Daily {
  const Daily({
    required this.id,
    required this.userId,
    required this.storagePath,
    required this.dateKey,
    required this.status,
  });

  final String id;
  final String userId;
  final String storagePath;
  final String dateKey;
  final DailyStatus status;

  bool get isActive => status == DailyStatus.active;
}

enum DailyStatus { draft, active, expired }

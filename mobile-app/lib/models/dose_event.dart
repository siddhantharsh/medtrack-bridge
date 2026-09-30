enum DoseStatus { pending, dispensed, collected, missed }

DoseStatus doseStatusFromString(String value) {
  return DoseStatus.values.firstWhere(
    (s) => s.name == value,
    orElse: () => DoseStatus.pending,
  );
}

class DoseEvent {
  const DoseEvent({
    required this.id,
    required this.compartmentId,
    required this.date,
    required this.status,
    required this.updatedAt,
  });

  final int id;
  final int compartmentId;
  final String date; // "YYYY-MM-DD"
  final DoseStatus status;
  final DateTime updatedAt;

  factory DoseEvent.fromJson(Map<String, dynamic> json) => DoseEvent(
        id: json['id'] as int,
        compartmentId: json['compartmentId'] as int,
        date: json['date'] as String,
        status: doseStatusFromString(json['status'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );

  DoseEvent copyWith({DoseStatus? status, DateTime? updatedAt}) => DoseEvent(
        id: id,
        compartmentId: compartmentId,
        date: date,
        status: status ?? this.status,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

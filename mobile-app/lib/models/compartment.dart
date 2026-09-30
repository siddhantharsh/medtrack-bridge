class Compartment {
  const Compartment({
    required this.id,
    required this.label,
    required this.medicineName,
    required this.time,
  });

  final int id;
  final String label;
  final String medicineName;
  final String time; // "HH:mm", 24h

  factory Compartment.fromJson(Map<String, dynamic> json) => Compartment(
        id: json['id'] as int,
        label: json['label'] as String,
        medicineName: json['medicineName'] as String,
        time: json['time'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'medicineName': medicineName,
        'time': time,
      };
}

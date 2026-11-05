class Event {
  final String id;
  String name;
  String location;
  DateTime startDate;
  DateTime endDate;
  String personInCharge;
  String status;
  String notes;

  Event({
    required this.id,
    required this.name,
    required this.location,
    required this.startDate,
    required this.endDate,
    required this.personInCharge,
    required this.status,
    required this.notes,
  });
}

class Movement {
  final String id;
  final String type;

  final String itemId;
  final String itemName;

  final String eventId;
  final String eventName;

  final int quantity;

  final String fromLocation;
  final String toLocation;

  final String handledBy;

  final DateTime dateTime;

  Movement({
    required this.id,
    required this.type,
    required this.itemId,
    required this.itemName,
    required this.eventId,
    required this.eventName,
    required this.quantity,
    required this.fromLocation,
    required this.toLocation,
    required this.handledBy,
    required this.dateTime,
  });
}

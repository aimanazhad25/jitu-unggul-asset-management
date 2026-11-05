class Item {
  final String id;

  String name;
  String category;
  String brand;
  String model;

  int totalQuantity;
  int availableQuantity;
  int outQuantity;
  int damagedQuantity;
  int maintenanceQuantity;
  int missingQuantity;

  String location;
  String condition;
  String description;

  Item({
    required this.id,
    required this.name,
    required this.category,
    required this.brand,
    required this.model,
    required this.totalQuantity,

    // Automatically calculated when a new item is registered
    int? availableQuantity,
    this.outQuantity = 0,
    this.damagedQuantity = 0,
    this.maintenanceQuantity = 0,
    this.missingQuantity = 0,

    required this.location,
    required this.condition,
    required this.description,
  }) : availableQuantity = availableQuantity ?? totalQuantity;
}

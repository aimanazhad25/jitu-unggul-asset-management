import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/event.dart';
import '../models/event_data.dart';

class AddEventPage extends StatefulWidget {
  const AddEventPage({super.key});

  @override
  State<AddEventPage> createState() => _AddEventPageState();
}

class _AddEventPageState extends State<AddEventPage> {
  final formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final locationController = TextEditingController();
  final notesController = TextEditingController();

  DateTime? startDate;
  DateTime? endDate;

  String selectedPIC = 'Ahmad';
  bool isSaving = false;
  final List<String> staff = ['Ahmad', 'Ijam', 'Iwan', 'Udi', 'Aiman'];

  @override
  void dispose() {
    nameController.dispose();
    locationController.dispose();
    notesController.dispose();
    super.dispose();
  }

  String formatDate(DateTime? date) {
    if (date == null) {
      return 'Select date';
    }

    return '${date.day}/${date.month}/${date.year}';
  }

  // Use calendar dates (midnight), so today's date remains selectable.
  DateTime get today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> selectStartDate() async {
    final minimum = today;
    final initial = startDate != null && !startDate!.isBefore(minimum)
        ? startDate!
        : minimum;

    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: minimum,
      lastDate: DateTime(2035, 12, 31),
    );

    if (selected != null) {
      setState(() {
        startDate = selected;
        if (endDate != null && endDate!.isBefore(selected)) {
          endDate = null;
        }
      });
    }
  }

  Future<void> selectEndDate() async {
    final minimum = startDate != null && startDate!.isAfter(today)
        ? startDate!
        : today;
    final initial = endDate != null && !endDate!.isBefore(minimum)
        ? endDate!
        : minimum;

    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: minimum,
      lastDate: DateTime(2035, 12, 31),
    );

    if (selected != null) {
      setState(() {
        endDate = selected;
      });
    }
  }

  Future<void> saveEvent() async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    if (startDate == null || endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select the event dates.')),
      );
      return;
    }

    // Always validate again at save time. A date picker restriction alone
    // does not protect against dates selected on an earlier day.
    if (startDate!.isBefore(today)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The event start date cannot be in the past.')),
      );
      return;
    }

    if (endDate!.isBefore(startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The end date cannot be before the start date.')),
      );
      return;
    }

    if (isSaving) {
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final firestore = FirebaseFirestore.instance;

      final eventRef = firestore.collection('events').doc();

      final newEvent = Event(
        id: eventRef.id,
        name: nameController.text.trim(),
        location: locationController.text.trim(),
        startDate: startDate!,
        endDate: endDate!,
        personInCharge: selectedPIC,
        status: 'Upcoming',
        notes: notesController.text.trim(),
      );

      await eventRef.set({
        'name': newEvent.name,
        'location': newEvent.location,
        'startDate': Timestamp.fromDate(newEvent.startDate),
        'endDate': Timestamp.fromDate(newEvent.endDate),
        'personInCharge': newEvent.personInCharge,
        'status': newEvent.status,
        'notes': newEvent.notes,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      eventList.add(newEvent);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${newEvent.name} created successfully.')),
      );

      Navigator.pop(context, true);
    } on FirebaseException catch (e) {
      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to create event: ${e.message ?? e.code}'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Unable to create event: $e')));
    }
  }

  InputDecoration inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),

      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'Add Event',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),

        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 700),
            padding: const EdgeInsets.all(28),

            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),

            child: Form(
              key: formKey,

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Create New Event',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 30),

                  TextFormField(
                    controller: nameController,
                    decoration: inputDecoration(
                      'Event Name',
                      Icons.event_outlined,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter the event name.';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 18),

                  TextFormField(
                    controller: locationController,
                    decoration: inputDecoration(
                      'Event Location',
                      Icons.location_on_outlined,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter the event location.';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 18),

                  DropdownButtonFormField<String>(
                    initialValue: selectedPIC,
                    decoration: inputDecoration(
                      'Person In Charge',
                      Icons.person_outline,
                    ),
                    items: staff.map((name) {
                      return DropdownMenuItem(value: name, child: Text(name));
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          selectedPIC = value;
                        });
                      }
                    },
                  ),

                  const SizedBox(height: 25),

                  const Text(
                    'Event Dates',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: selectStartDate,
                          icon: const Icon(Icons.calendar_month),
                          label: Text('Start: ${formatDate(startDate)}'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.all(17),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: selectEndDate,
                          icon: const Icon(Icons.calendar_month),
                          label: Text('End: ${formatDate(endDate)}'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.all(17),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  TextFormField(
                    controller: notesController,
                    maxLines: 4,
                    decoration: inputDecoration('Notes', Icons.notes),
                  ),

                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: isSaving ? null : saveEvent,

                      icon: isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),

                      label: Text(
                        isSaving ? 'CREATING EVENT...' : 'CREATE EVENT',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),

                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A5F),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

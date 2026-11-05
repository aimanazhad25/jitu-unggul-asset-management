import 'package:flutter/material.dart';

import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'screens/items_page.dart';

import 'screens/events_page.dart';

import 'screens/item_out_page.dart';

import 'screens/item_in_page.dart';

import 'screens/maintenance_page.dart';

import 'screens/missing_items_page.dart';

import 'screens/damaged_items_page.dart';

import 'screens/movement_history_page.dart';

import 'screens/reports_page.dart';

import 'models/item.dart';
import 'models/item_data.dart';
import 'models/event.dart';
import 'models/event_data.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const JituUnggulApp());
}

class JituUnggulApp extends StatelessWidget {
  const JituUnggulApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      title: 'Jitu Unggul Assets',

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E3A5F)),

        useMaterial3: true,
      ),

      home: const LoginPage(),
    );
  }
}

// =====================================================

// JITU UNGGUL USERS

// =====================================================

class AppUser {
  final String username;

  final String password;

  final String name;

  final String role;

  const AppUser({
    required this.username,

    required this.password,

    required this.name,

    required this.role,
  });
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();

  final passwordController = TextEditingController();

  bool hidePassword = true;

  String? errorMessage;

  Future<void> login() async {
    final email = emailController.text.trim();

    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        errorMessage = 'Please enter your email and password.';
      });

      return;
    }

    setState(() {
      errorMessage = null;
    });

    try {
      // 1. LOGIN USING FIREBASE AUTHENTICATION

      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,

        password: password,
      );

      final firebaseUser = credential.user;

      if (firebaseUser == null) {
        setState(() {
          errorMessage = 'Unable to sign in.';
        });

        return;
      }

      // 2. GET USER PROFILE FROM FIRESTORE

      final userDocument = await FirebaseFirestore.instance
          .collection('users')
          .doc(firebaseUser.uid)
          .get();

      if (!userDocument.exists) {
        await FirebaseAuth.instance.signOut();

        setState(() {
          errorMessage = 'User profile was not found.';
        });

        return;
      }

      final data = userDocument.data()!;

      // 3. CHECK WHETHER ACCOUNT IS ACTIVE

      final bool active = data['active'] ?? false;

      if (!active) {
        await FirebaseAuth.instance.signOut();

        setState(() {
          errorMessage = 'This account has been disabled.';
        });

        return;
      }

      // 4. CREATE APP USER USING FIRESTORE DATA

      final appUser = AppUser(
        username: email,

        password: '',

        name: data['name'] ?? 'User',

        role: data['role'] ?? 'staff',
      );

      if (!mounted) return;

      // 5. OPEN DASHBOARD

      Navigator.pushReplacement(
        context,

        MaterialPageRoute(builder: (context) => DashboardPage(user: appUser)),
      );
    } on FirebaseAuthException catch (e) {
      String message = 'Unable to login. Please try again.';

      if (e.code == 'invalid-credential' ||
          e.code == 'wrong-password' ||
          e.code == 'user-not-found') {
        message = 'Invalid email or password.';
      } else if (e.code == 'invalid-email') {
        message = 'Please enter a valid email address.';
      } else if (e.code == 'too-many-requests') {
        message = 'Too many login attempts. Please try again later.';
      }

      if (!mounted) return;

      setState(() {
        errorMessage = message;
      });
    } catch (e) {
      print('LOGIN ERROR: $e');

      if (!mounted) return;

      setState(() {
        errorMessage = 'Something went wrong. Please try again.';
      });
    }
  }

  @override
  void dispose() {
    emailController.dispose();

    passwordController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),

      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),

            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),

              padding: const EdgeInsets.all(32),

              decoration: BoxDecoration(
                color: Colors.white,

                borderRadius: BorderRadius.circular(20),

                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),

                    blurRadius: 20,

                    offset: const Offset(0, 8),
                  ),
                ],
              ),

              child: Column(
                mainAxisSize: MainAxisSize.min,

                children: [
                  // LOGO

                  Container(
                    width: 85,

                    height: 85,

                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A5F),

                      borderRadius: BorderRadius.circular(20),
                    ),

                    child: const Icon(
                      Icons.inventory_2_rounded,

                      size: 45,

                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // COMPANY NAME
                  const Text(
                    'JITU UNGGUL',

                    style: TextStyle(
                      fontSize: 28,

                      fontWeight: FontWeight.bold,

                      letterSpacing: 1,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    'Asset Management System',

                    style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                  ),

                  const SizedBox(height: 35),

                  // EMAIL
                  TextField(
                    controller: emailController,

                    keyboardType: TextInputType.emailAddress,

                    decoration: InputDecoration(
                      labelText: 'Email',

                      hintText: 'Enter your email',

                      prefixIcon: const Icon(Icons.email_outlined),

                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // PASSWORD
                  TextField(
                    controller: passwordController,

                    obscureText: hidePassword,

                    onSubmitted: (_) => login(),

                    decoration: InputDecoration(
                      labelText: 'Password',

                      hintText: 'Enter your password',

                      prefixIcon: const Icon(Icons.lock_outline),

                      suffixIcon: IconButton(
                        icon: Icon(
                          hidePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),

                        onPressed: () {
                          setState(() {
                            hidePassword = !hidePassword;
                          });
                        },
                      ),

                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

                  if (errorMessage != null) ...[
                    const SizedBox(height: 10),

                    Align(
                      alignment: Alignment.centerLeft,

                      child: Text(
                        errorMessage!,

                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                  ],

                  const SizedBox(height: 25),

                  // LOGIN BUTTON
                  SizedBox(
                    width: double.infinity,

                    height: 52,

                    child: FilledButton(
                      onPressed: login,

                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A5F),

                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),

                      child: const Text(
                        'LOGIN',

                        style: TextStyle(
                          fontSize: 16,

                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 25),

                  Text(
                    'Jitu Unggul Asset Management',

                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
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

// =====================================================

// DASHBOARD

// =====================================================

class DashboardPage extends StatefulWidget {
  final AppUser user;

  const DashboardPage({super.key, required this.user});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  static const navy = Color(0xFF17324D);

  static const pageBg = Color(0xFFF5F7FA);

  bool get isAdmin => widget.user.role.toLowerCase() == 'admin';

  int totalItems = 0;

  int availableItems = 0;

  int itemsOut = 0;

  int maintenanceItems = 0;

  int damagedItems = 0;

  int missingItems = 0;

  bool isLoadingDashboard = true;

  bool isLoadingSharedData = true;
  String? sharedDataError;
  int _sharedDataRequest = 0;

  List<Map<String, dynamic>> recentMovements = [];

  String selectedSection = 'dashboard';
  String inventoryFilter = 'ALL';

  void selectSection(
    String section, {
    String filter = 'ALL',
    bool closeDrawer = false,
  }) {
    if (closeDrawer) Navigator.pop(context);
    setState(() {
      selectedSection = section;
      inventoryFilter = filter;
    });
    if (section == 'dashboard') loadDashboard();
    if (section == 'itemOut' || section == 'itemIn') {
      loadSharedData();
    }
  }

  @override
  void initState() {
    super.initState();

    loadDashboard();
    loadSharedData();
  }

  // Load the shared lists used by Item Out and Item In directly from Firestore.
  // Refresh on entry so users never need to open Inventory or Events first.
  Future<void> loadSharedData() async {
    final requestId = ++_sharedDataRequest;
    if (!mounted) return;
    setState(() {
      isLoadingSharedData = true;
      sharedDataError = null;
    });

    try {
      final firestore = FirebaseFirestore.instance;
      final results = await Future.wait([
        firestore.collection('items').get(),
        firestore.collection('events').get(),
      ]);

      final loadedItems = results[0].docs.map((doc) {
        final data = doc.data();
        return Item(
          id: doc.id,
          name: data['name']?.toString() ?? '',
          category: data['category']?.toString() ?? 'Other',
          brand: data['brand']?.toString() ?? '',
          model: data['model']?.toString() ?? '',
          totalQuantity: (data['totalQuantity'] as num?)?.toInt() ?? 0,
          availableQuantity: (data['availableQuantity'] as num?)?.toInt() ?? 0,
          outQuantity: (data['outQuantity'] as num?)?.toInt() ?? 0,
          damagedQuantity: (data['damagedQuantity'] as num?)?.toInt() ?? 0,
          maintenanceQuantity:
              (data['maintenanceQuantity'] as num?)?.toInt() ?? 0,
          missingQuantity: (data['missingQuantity'] as num?)?.toInt() ?? 0,
          location: data['location']?.toString() ?? '',
          condition: data['condition']?.toString() ?? 'Good',
          description: data['description']?.toString() ?? '',
        );
      }).toList();

      final loadedEvents = results[1].docs.map((doc) {
        final data = doc.data();
        return Event(
          id: doc.id,
          name: data['name']?.toString() ?? '',
          location: data['location']?.toString() ?? '',
          startDate: data['startDate'] is Timestamp
              ? (data['startDate'] as Timestamp).toDate()
              : DateTime.now(),
          endDate: data['endDate'] is Timestamp
              ? (data['endDate'] as Timestamp).toDate()
              : DateTime.now(),
          personInCharge: data['personInCharge']?.toString() ?? '',
          status: data['status']?.toString() ?? 'Upcoming',
          notes: data['notes']?.toString() ?? '',
        );
      }).toList();

      if (!mounted || requestId != _sharedDataRequest) return;
      setState(() {
        itemList
          ..clear()
          ..addAll(loadedItems);
        eventList
          ..clear()
          ..addAll(loadedEvents);
        isLoadingSharedData = false;
      });
    } catch (e) {
      if (!mounted || requestId != _sharedDataRequest) return;
      setState(() {
        sharedDataError = 'Unable to load inventory and events: $e';
        isLoadingSharedData = false;
      });
    }
  }

  Widget operationLoadingOrError() {
    if (isLoadingSharedData) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(sharedDataError ?? 'Unable to load data.', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: loadSharedData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> loadDashboard() async {
    try {
      final firestore = FirebaseFirestore.instance;

      final itemSnapshot = await firestore.collection('items').get();

      int total = 0,
          available = 0,
          out = 0,
          maintenance = 0,
          damaged = 0,
          missing = 0;

      for (final doc in itemSnapshot.docs) {
        final data = doc.data();

        total += (data['totalQuantity'] as num?)?.toInt() ?? 0;

        available += (data['availableQuantity'] as num?)?.toInt() ?? 0;

        out += (data['outQuantity'] as num?)?.toInt() ?? 0;

        maintenance += (data['maintenanceQuantity'] as num?)?.toInt() ?? 0;

        damaged += (data['damagedQuantity'] as num?)?.toInt() ?? 0;

        missing += (data['missingQuantity'] as num?)?.toInt() ?? 0;
      }

      final movementSnapshot = await firestore
          .collection('movements')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();

      final movements = movementSnapshot.docs
          .map((doc) => <String, dynamic>{'id': doc.id, ...doc.data()})
          .toList();

      if (!mounted) return;

      setState(() {
        totalItems = total;

        availableItems = available;

        itemsOut = out;

        maintenanceItems = maintenance;

        damagedItems = damaged;

        missingItems = missing;

        recentMovements = movements;

        isLoadingDashboard = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => isLoadingDashboard = false);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to load dashboard: $e')));
    }
  }

  Future<void> openPage(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));

    await loadDashboard();
  }

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,

      MaterialPageRoute(builder: (_) => const LoginPage()),

      (_) => false,
    );
  }

  Widget statCard(
    String title,

    int value,

    IconData icon,

    Color accent,

    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.white,

      borderRadius: BorderRadius.circular(18),

      child: InkWell(
        onTap: onTap,

        borderRadius: BorderRadius.circular(18),

        child: Container(
          padding: const EdgeInsets.all(20),

          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),

            border: Border.all(color: const Color(0xFFE6EBF0)),
          ),

          child: Row(
            children: [
              Container(
                width: 48,

                height: 48,

                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .10),

                  borderRadius: BorderRadius.circular(14),
                ),

                child: Icon(icon, color: accent),
              ),

              const SizedBox(width: 15),

              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      '$value',

                      style: const TextStyle(
                        fontSize: 25,

                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      title,

                      style: const TextStyle(
                        color: Color(0xFF6F7B88),

                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(Icons.chevron_right_rounded, color: Color(0xFFABB4BE)),
            ],
          ),
        ),
      ),
    );
  }

  Widget sectionLabel(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 20, 18, 7),

    child: Text(
      text,

      style: const TextStyle(
        color: Color(0xFF8393A5),

        fontSize: 10.5,

        fontWeight: FontWeight.w800,

        letterSpacing: 1.1,
      ),
    ),
  );

  Widget navTile(
    String label,

    IconData icon,

    VoidCallback onTap, {

    bool selected = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),

      child: Material(
        color: selected
            ? Colors.white.withValues(alpha: .12)
            : Colors.transparent,

        borderRadius: BorderRadius.circular(12),

        child: InkWell(
          onTap: onTap,

          borderRadius: BorderRadius.circular(12),

          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),

            child: Row(
              children: [
                Icon(
                  icon,

                  size: 20,

                  color: selected ? Colors.white : const Color(0xFFB7C4D2),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Text(
                    label,

                    style: TextStyle(
                      color: selected ? Colors.white : const Color(0xFFD8E0E8),

                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,

                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget sidebar(bool drawerMode) {
    void choose(String section, {String filter = 'ALL'}) {
      selectSection(section, filter: filter, closeDrawer: drawerMode);
    }

    return Container(
      width: 255,
      color: navy,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 23, 20, 19),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.inventory_2_rounded, color: navy),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'JITU UNGGUL',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Asset Management',
                          style: TextStyle(
                            color: Color(0xFF9FB0C1),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFF29445E)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  navTile(
                    'Dashboard',
                    Icons.dashboard_rounded,
                    () => choose('dashboard'),
                    selected: selectedSection == 'dashboard',
                  ),
                  navTile(
                    'Inventory',
                    Icons.inventory_2_outlined,
                    () => choose('inventory'),
                    selected: selectedSection == 'inventory',
                  ),
                  navTile(
                    'Events',
                    Icons.event_outlined,
                    () => choose('events'),
                    selected: selectedSection == 'events',
                  ),
                  sectionLabel('OPERATIONS'),
                  navTile(
                    'Item Out',
                    Icons.outbox_outlined,
                    () => choose('itemOut'),
                    selected: selectedSection == 'itemOut',
                  ),
                  navTile(
                    'Item In',
                    Icons.move_to_inbox_outlined,
                    () => choose('itemIn'),
                    selected: selectedSection == 'itemIn',
                  ),
                  sectionLabel('ASSET STATUS'),
                  navTile(
                    'Maintenance',
                    Icons.build_outlined,
                    () => choose('maintenance'),
                    selected: selectedSection == 'maintenance',
                  ),
                  navTile(
                    'Damaged',
                    Icons.report_problem_outlined,
                    () => choose('damaged'),
                    selected: selectedSection == 'damaged',
                  ),
                  navTile(
                    'Missing',
                    Icons.search_off_outlined,
                    () => choose('missing'),
                    selected: selectedSection == 'missing',
                  ),
                  sectionLabel('REPORTS'),
                  navTile(
                    'Movement History',
                    Icons.history_rounded,
                    () => choose('movementHistory'),
                    selected: selectedSection == 'movementHistory',
                  ),
                  navTile(
                    'Reports & Analytics',
                    Icons.analytics_outlined,
                    () => choose('reports'),
                    selected: selectedSection == 'reports',
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFF29445E)),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 19,
                    backgroundColor: Colors.white.withValues(alpha: .12),
                    child: Text(
                      widget.user.name.isEmpty
                          ? 'U'
                          : widget.user.name[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.user.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          widget.user.role.toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFF9FB0C1),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Logout',
                    onPressed: logout,
                    icon: const Icon(
                      Icons.logout_rounded,
                      color: Color(0xFFD8E0E8),
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String displayType(String type) {
    if (type == 'MAINTENANCE_COMPLETED') return 'REPAIRED';

    if (type == 'MISSING_FOUND') return 'FOUND';

    if (type == 'DAMAGED_REPAIRED') return 'REPAIRED';

    if (type == 'DAMAGED_TO_MAINTENANCE') return 'TO MAINTENANCE';

    return type;
  }

  Color movementColor(String type) {
    if (type == 'OUT') return Colors.orange.shade700;

    if (type == 'MAINTENANCE_COMPLETED' || type == 'DAMAGED_TO_MAINTENANCE')
      return Colors.blue.shade700;

    if (type == 'MISSING_FOUND') return Colors.teal.shade700;

    return Colors.green.shade700;
  }

  IconData movementIcon(String type) {
    if (type == 'OUT') return Icons.north_east_rounded;

    if (type == 'IN') return Icons.south_west_rounded;

    if (type == 'MAINTENANCE_COMPLETED') return Icons.build_outlined;

    if (type == 'MISSING_FOUND') return Icons.search_outlined;

    if (type == 'DAMAGED_REPAIRED') return Icons.handyman_outlined;

    if (type == 'DAMAGED_TO_MAINTENANCE') return Icons.build_circle_outlined;

    return Icons.history_rounded;
  }

  Widget recentActivity() {
    if (isLoadingDashboard) {
      return const Padding(
        padding: EdgeInsets.all(35),

        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (recentMovements.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(35),

        child: Center(
          child: Text(
            'No recent movement yet.',

            style: TextStyle(color: Color(0xFF7C8794)),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (int i = 0; i < recentMovements.length; i++) ...[
          Builder(
            builder: (_) {
              final movement = recentMovements[i];

              final type = movement['type']?.toString() ?? '';

              final itemName =
                  movement['itemName']?.toString() ?? 'Unknown Item';

              final quantity = (movement['quantity'] as num?)?.toInt() ?? 0;

              final handledBy = movement['handledBy']?.toString() ?? 'Unknown';

              final eventName = movement['eventName']?.toString() ?? '';

              final notes = movement['notes']?.toString() ?? '';

              final label = displayType(type);

              final special =
                  type == 'MAINTENANCE_COMPLETED' ||
                  type == 'MISSING_FOUND' ||
                  type == 'DAMAGED_REPAIRED' ||
                  type == 'DAMAGED_TO_MAINTENANCE';

              final subtitle = special
                  ? '${notes.isEmpty ? label : notes} • $handledBy'
                  : '${eventName.isEmpty ? 'General' : eventName} • $handledBy';

              final color = movementColor(type);

              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,

                  vertical: 11,
                ),

                child: Row(
                  children: [
                    Container(
                      width: 42,

                      height: 42,

                      decoration: BoxDecoration(
                        color: color.withValues(alpha: .09),

                        borderRadius: BorderRadius.circular(12),
                      ),

                      child: Icon(movementIcon(type), color: color, size: 20),
                    ),

                    const SizedBox(width: 13),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          Text(
                            '$itemName × $quantity',

                            maxLines: 1,

                            overflow: TextOverflow.ellipsis,

                            style: const TextStyle(
                              fontWeight: FontWeight.w700,

                              fontSize: 14,
                            ),
                          ),

                          const SizedBox(height: 3),

                          Text(
                            subtitle,

                            maxLines: 1,

                            overflow: TextOverflow.ellipsis,

                            style: const TextStyle(
                              color: Color(0xFF7C8794),

                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 10),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,

                        vertical: 6,
                      ),

                      decoration: BoxDecoration(
                        color: color.withValues(alpha: .08),

                        borderRadius: BorderRadius.circular(20),
                      ),

                      child: Text(
                        label,

                        style: TextStyle(
                          color: color,

                          fontWeight: FontWeight.w800,

                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          if (i != recentMovements.length - 1)
            const Divider(
              height: 1,

              indent: 73,

              endIndent: 18,

              color: Color(0xFFEEF1F4),
            ),
        ],
      ],
    );
  }

  Widget dashboardContent(bool compact) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        compact ? 18 : 30,

        compact ? 18 : 28,

        compact ? 18 : 30,

        36,
      ),

      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1250),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        const Text(
                          'Dashboard',

                          style: TextStyle(
                            fontSize: 28,

                            fontWeight: FontWeight.w800,
                          ),
                        ),

                        const SizedBox(height: 5),

                        Text(
                          'Welcome back, ${widget.user.name}. Here is your asset overview.',

                          style: const TextStyle(
                            color: Color(0xFF74808D),

                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (!compact)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,

                        vertical: 8,
                      ),

                      decoration: BoxDecoration(
                        color: (isAdmin ? Colors.deepPurple : Colors.blue)
                            .withValues(alpha: .08),

                        borderRadius: BorderRadius.circular(20),
                      ),

                      child: Text(
                        widget.user.role.toUpperCase(),

                        style: TextStyle(
                          color: isAdmin
                              ? Colors.deepPurple.shade700
                              : Colors.blue.shade700,

                          fontWeight: FontWeight.w800,

                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 28),

              if (isLoadingDashboard)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 70),

                  child: Center(child: CircularProgressIndicator()),
                )
              else
                LayoutBuilder(
                  builder: (context, c) {
                    final columns = c.maxWidth >= 950
                        ? 3
                        : (c.maxWidth >= 560 ? 2 : 1);

                    return GridView.count(
                      crossAxisCount: columns,

                      shrinkWrap: true,

                      physics: const NeverScrollableScrollPhysics(),

                      crossAxisSpacing: 14,

                      mainAxisSpacing: 14,

                      childAspectRatio: columns == 1 ? 3.2 : 2.55,

                      children: [
                        statCard(
                          'Total Items',

                          totalItems,

                          Icons.inventory_2_outlined,

                          navy,

                          () => selectSection('inventory', filter: 'ALL'),
                        ),

                        statCard(
                          'Available',

                          availableItems,

                          Icons.check_circle_outline,

                          Colors.green.shade700,

                          () => selectSection('inventory', filter: 'AVAILABLE'),
                        ),

                        statCard(
                          'Items Out',

                          itemsOut,

                          Icons.outbox_outlined,

                          Colors.orange.shade700,

                          () => selectSection('inventory', filter: 'OUT'),
                        ),

                        statCard(
                          'Maintenance',

                          maintenanceItems,

                          Icons.build_outlined,

                          Colors.blue.shade700,

                          () => selectSection('maintenance'),
                        ),

                        statCard(
                          'Damaged',

                          damagedItems,

                          Icons.report_problem_outlined,

                          Colors.red.shade700,

                          () => selectSection('damaged'),
                        ),

                        statCard(
                          'Missing',

                          missingItems,

                          Icons.search_off_outlined,

                          Colors.deepOrange.shade700,

                          () => selectSection('missing'),
                        ),
                      ],
                    );
                  },
                ),

              const SizedBox(height: 30),

              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Recent Activity',

                      style: TextStyle(
                        fontSize: 18,

                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),

                  TextButton.icon(
                    onPressed: () => selectSection('movementHistory'),

                    icon: const Icon(Icons.arrow_forward_rounded, size: 17),

                    label: const Text('View all'),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              Container(
                width: double.infinity,

                decoration: BoxDecoration(
                  color: Colors.white,

                  borderRadius: BorderRadius.circular(18),

                  border: Border.all(color: const Color(0xFFE6EBF0)),
                ),

                child: recentActivity(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get mobileSectionTitle {
    switch (selectedSection) {
      case 'inventory':
        return 'Inventory';
      case 'events':
        return 'Events';
      case 'itemOut':
        return 'Item Out';
      case 'itemIn':
        return 'Item In';
      case 'maintenance':
        return 'Maintenance';
      case 'damaged':
        return 'Damaged Items';
      case 'missing':
        return 'Missing Items';
      case 'movementHistory':
        return 'Movement History';
      case 'reports':
        return 'Reports & Analytics';
      default:
        return 'Dashboard';
    }
  }

  Widget shellContent(bool compact) {
    switch (selectedSection) {
      case 'inventory':
        return ItemsPage(
          key: ValueKey('inventory-$inventoryFilter-${widget.user.role}'),
          initialFilter: inventoryFilter,
          userRole: widget.user.role,
          embedded: true,
        );
      case 'events':
        return const EventsPage(embedded: true);
      case 'itemOut':
        if (isLoadingSharedData || sharedDataError != null) {
          return operationLoadingOrError();
        }
        return ItemOutPage(
          handledBy: widget.user.name,
          embedded: true,
          onCompleted: loadDashboard,
        );
      case 'itemIn':
        if (isLoadingSharedData || sharedDataError != null) {
          return operationLoadingOrError();
        }
        return ItemInPage(
          handledBy: widget.user.name,
          embedded: true,
          onCompleted: loadDashboard,
        );
      case 'maintenance':
        return MaintenancePage(handledBy: widget.user.name, embedded: true);
      case 'damaged':
        return DamagedItemsPage(handledBy: widget.user.name, embedded: true);
      case 'missing':
        return MissingItemsPage(handledBy: widget.user.name, embedded: true);
      case 'movementHistory':
        return const MovementHistoryPage(embedded: true);
      case 'reports':
        return ReportsPage(generatedBy: widget.user.name, embedded: true);
      case 'dashboard':
      default:
        return dashboardContent(compact);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 820;

        return Scaffold(
          backgroundColor: pageBg,

          drawer: compact ? Drawer(child: sidebar(true)) : null,
          appBar: compact
              ? AppBar(
                  backgroundColor: Colors.white,
                  foregroundColor: navy,
                  elevation: 1,
                  scrolledUnderElevation: 1,
                  title: Text(mobileSectionTitle),
                  actions: [
                    if (selectedSection != 'dashboard')
                      IconButton(
                        tooltip: 'Go to Dashboard',
                        icon: const Icon(Icons.home_outlined),
                        onPressed: () => selectSection('dashboard'),
                      ),
                  ],
                )
              : null,
          body: Row(
            children: [
              if (!compact) sidebar(false),
              Expanded(child: shellContent(compact)),
            ],
          ),
        );
      },
    );
  }
}

// =====================================================

class DashboardCard extends StatelessWidget {
  final String title;

  final String value;

  final IconData icon;

  const DashboardCard({
    super.key,

    required this.title,

    required this.value,

    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(15),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Icon(icon, color: const Color(0xFF1E3A5F)),

          const SizedBox(height: 15),

          Text(
            value,

            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 3),

          Text(title, style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

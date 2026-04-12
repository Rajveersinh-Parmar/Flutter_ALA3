import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
// Using 'as p' to prevent naming conflicts with Flutter's BuildContext
import 'package:path/path.dart' as p;

void main() {
  runApp(const PasswordVaultApp());
}

class PasswordVaultApp extends StatelessWidget {
  const PasswordVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Secure Vault',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
      ),
      home: const HistoryScreen(),
    );
  }
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final TextEditingController _controller = TextEditingController();
  Database? _database;
  List<Map<String, dynamic>> _historyList = [];
  String _currentStrength = "Waiting for input...";
  Color _strengthColor = Colors.grey;

  @override
  void initState() {
    super.initState();
    _initDatabase();
  }

  // Initialize Local SQLite Database
  Future<void> _initDatabase() async {
    _database = await openDatabase(
      // Updated to use the 'p.' prefix
      p.join(await getDatabasesPath(), 'vault_history.db'),
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE records(id INTEGER PRIMARY KEY AUTOINCREMENT, password TEXT, strength TEXT, timestamp TEXT)',
        );
      },
      version: 1,
    );
    _refreshData();
  }

  // Retrieve Data from SQLite
  Future<void> _refreshData() async {
    if (_database == null) return;
    final List<Map<String, dynamic>> data =
        await _database!.query('records', orderBy: 'id DESC');
    setState(() {
      _historyList = data;
    });
  }

  // Store Data into SQLite
  void _savePasswordCheck() async {
    String pass = _controller.text;
    if (pass.isEmpty) return;

    // Password Strength Logic
    String strength = "Weak";
    Color color = Colors.red;

    if (pass.length >= 10 &&
        pass.contains(RegExp(r'[0-9]')) &&
        pass.contains(RegExp(r'[A-Z]'))) {
      strength = "Strong";
      color = Colors.green;
    } else if (pass.length >= 6) {
      strength = "Medium";
      color = Colors.orange;
    }

    setState(() {
      _currentStrength = "Strength: $strength";
      _strengthColor = color;
    });

    if (_database != null) {
      await _database!.insert(
        'records',
        {
          'password': pass.replaceAll(RegExp(r'.'), '*'), // Masked for privacy
          'strength': strength,
          'timestamp': DateTime.now().toString().substring(0, 16),
        },
      );
    }

    _controller.clear();
    _refreshData();

    if (mounted) {
      ScaffoldMessenger.of(this.context).showSnackBar(
        const SnackBar(content: Text("Analysis Saved to History!")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Password Checker"),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Enter Password",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _controller,
                  obscureText: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: "Enter password...",
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _savePasswordCheck,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text("Check Strength"),
                ),
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    _currentStrength,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _strengthColor),
                  ),
                ),
              ],
            ),
          ),
          const Divider(thickness: 1.2),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text(
              "Persistent History (Stored Locally)",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          Expanded(
            child: _historyList.isEmpty
                ? const Center(
                    child: Text("No history found. Try checking a password!"))
                : ListView.builder(
                    itemCount: _historyList.length,
                    itemBuilder: (context, index) {
                      final item = _historyList[index];
                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                _getStrengthColor(item['strength']),
                            child:
                                const Icon(Icons.history, color: Colors.white),
                          ),
                          title: Text("Masked: ${item['password']}"),
                          subtitle: Text("Result: ${item['strength']}"),
                          trailing: Text(
                            item['timestamp'],
                            style: const TextStyle(
                                fontSize: 10, color: Colors.grey),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Color _getStrengthColor(String strength) {
    if (strength == "Strong") return Colors.green;
    if (strength == "Medium") return Colors.orange;
    return Colors.red;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

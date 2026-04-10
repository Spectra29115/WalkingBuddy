import 'package:flutter/material.dart';
import 'database_helper.dart';

void main() {
  runApp(const WalkingBuddyApp());
}

class WalkingBuddyApp extends StatelessWidget {
  const WalkingBuddyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Walking Buddy',
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
      ),
      home: const WalkingBuddyHome(),
    );
  }
}

class WalkingBuddyHome extends StatefulWidget {
  const WalkingBuddyHome({Key? key}) : super(key: key);

  @override
  State<WalkingBuddyHome> createState() => _WalkingBuddyHomeState();
}

class _WalkingBuddyHomeState extends State<WalkingBuddyHome> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _distanceController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  
  List<Map<String, dynamic>> _entries = [];

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final entries = await _dbHelper.getWalkEntries();
    setState(() {
      _entries = entries;
    });
  }

  Future<void> _addEntry() async {
    if (_nameController.text.isEmpty || 
        _distanceController.text.isEmpty || 
        _durationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')), 
      );
      return;
    }

    try {
      final entry = {
        'name': _nameController.text,
        'distance': double.parse(_distanceController.text),
        'duration': int.parse(_durationController.text),
        'timestamp': DateTime.now().toIso8601String(),
      };

      await _dbHelper.insertWalkEntry(entry);
      _nameController.clear();
      _distanceController.clear();
      _durationController.clear();
      _loadEntries();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Walk logged successfully!')), 
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: \')), 
      );
    }
  }

  Future<void> _deleteEntry(int id) async {
    await _dbHelper.deleteWalkEntry(id);
    _loadEntries();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _distanceController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Walking Buddy'),
        centerTitle: true,
        elevation: 2,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Log a Walk',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Walk Name',
                          hintText: 'e.g., Morning Walk',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(Icons.directions_walk),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _distanceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Distance (km)',
                          hintText: 'e.g., 5.5',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(Icons.map),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _durationController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Duration (minutes)',
                          hintText: 'e.g., 45',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(Icons.schedule),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _addEntry,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Entry'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Your Walks',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _entries.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48.0),
                        child: Column(
                          children: [
                            Icon(
                              Icons.directions_walk,
                              size: 64,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No walks logged yet',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _entries.length,
                      itemBuilder: (context, index) {
                        final entry = _entries[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListTile(
                            leading: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.green[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.directions_walk,
                                color: Colors.green,
                              ),
                            ),
                            title: Text(
                              entry['name'],
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              '\ km • \ min',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _deleteEntry(entry['id']),
                            ),
                          ),
                        );
                      },
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

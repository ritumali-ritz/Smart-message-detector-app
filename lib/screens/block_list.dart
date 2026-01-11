import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/block_list_service.dart';

class BlockListScreen extends StatefulWidget {
  const BlockListScreen({super.key});

  @override
  State<BlockListScreen> createState() => _BlockListScreenState();
}

class _BlockListScreenState extends State<BlockListScreen> {
  final BlockListService _blockListService = BlockListService();
  List<String> _blacklisted = [];
  List<String> _whitelisted = [];

  @override
  void initState() {
    super.initState();
    _loadLists();
  }

  Future<void> _loadLists() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _blacklisted = prefs.getStringList('blacklist_numbers') ?? [];
      _whitelisted = prefs.getStringList('whitelist_numbers') ?? [];
    });
  }

  void _remove(String number) async {
    await _blockListService.removeFromLists(number);
    _loadLists();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text("Sender Management"),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.block), text: "Blocked"),
              Tab(icon: Icon(Icons.verified_user), text: "Trusted"),
            ],
            indicatorColor: Colors.blueAccent,
            labelColor: Colors.blueAccent,
            unselectedLabelColor: Colors.white24,
          ),
        ),
        body: TabBarView(
          children: [
            _buildList(_blacklisted, "No blocked numbers", Colors.redAccent),
            _buildList(_whitelisted, "No trusted numbers", Colors.greenAccent),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<String> items, String emptyMsg, Color color) {
    if (items.isEmpty) {
      return Center(
        child: Text(emptyMsg, style: const TextStyle(color: Colors.white24)),
      );
    }
    return ListView.builder(
      itemCount: items.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        return Card(
          color: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: ListTile(
            leading: Icon(Icons.person_pin, color: color),
            title: Text(items[index], style: const TextStyle(color: Colors.white)),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white24),
              onPressed: () => _remove(items[index]),
            ),
          ),
        );
      },
    );
  }
}

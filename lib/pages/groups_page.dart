import 'package:flutter/material.dart';
import 'package:qr_sorter/services/db_service.dart';
import 'package:qr_sorter/models/item.dart';
import 'package:qr_sorter/widgets/item_icon.dart';

class GroupsPage extends StatefulWidget {
  const GroupsPage({Key? key}) : super(key: key);

  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  final DBService db = DBService();
  Map<String, List<Item>> _groups = {};

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  void _loadGroups() {
    final items = db.getItems();
    final map = <String, List<Item>>{};
    for (final it in items) {
      final key =
          (it.category.trim().isEmpty) ? 'Ungrouped' : it.category.trim();
      map.putIfAbsent(key, () => []).add(it);
    }
    final sorted = Map<String, List<Item>>.fromEntries(
      map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    setState(() => _groups = sorted);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups (by category)'),
      ),
      body: _groups.isEmpty
          ? const Center(child: Text('No groups yet'))
          : ListView.separated(
              itemCount: _groups.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final entry = _groups.entries.elementAt(index);
                final name = entry.key;
                final list = entry.value;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.grey.shade100,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(name),
                  subtitle:
                      Text('${list.length} item${list.length == 1 ? '' : 's'}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            GroupItemsPage(groupName: name, items: list),
                      ),
                    ).then((_) => _loadGroups());
                  },
                );
              },
            ),
    );
  }
}

class GroupItemsPage extends StatefulWidget {
  final String groupName;
  final List<Item> items;
  const GroupItemsPage({Key? key, required this.groupName, required this.items})
      : super(key: key);

  @override
  State<GroupItemsPage> createState() => _GroupItemsPageState();
}

class _GroupItemsPageState extends State<GroupItemsPage> {
  late List<Item> _items;

  @override
  void initState() {
    super.initState();
    _items = List<Item>.from(widget.items);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.groupName),
      ),
      body: _items.isEmpty
          ? const Center(child: Text('No items in this group'))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, idx) {
                final it = _items[idx];
                return Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          it.sorted ? Colors.green[50] : Colors.purple[50],
                      child: ItemIcon(
                          item: it,
                          size: 20,
                          color: it.sorted ? Colors.green : Colors.purple),
                    ),
                    title: Text(it.title,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(it.category.isEmpty
                        ? it.description
                        : '${it.description} • ${it.category}'),
                    trailing: Icon(
                        it.sorted ? Icons.check_circle : Icons.qr_code,
                        color: it.sorted ? Colors.green : Colors.grey),
                    onTap: () async {
                      // Optionally, you can show the existing item dialog here by
                      // calling the same dialog method you use on HomePage/ScanPage.
                      // For now this is a no-op so editing happens via the main view.
                    },
                  ),
                );
              },
            ),
    );
  }
}

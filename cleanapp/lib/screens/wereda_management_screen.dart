import 'package:flutter/material.dart';
import '../models/wereda_model.dart';
import '../theme/app_colors.dart';

class WeredaManagementScreen extends StatefulWidget {
  @override
  _WeredaManagementScreenState createState() => _WeredaManagementScreenState();
}

class _WeredaManagementScreenState extends State<WeredaManagementScreen> {
  List<WeredaModel> _weredas = [];
  List<WeredaModel> _filteredWeredas = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadWeredas();
  }

  void _loadWeredas() {
    // Mock data for UI base implementation
    _weredas = [
      WeredaModel(id: 1, name: 'Wereda 1', description: 'Central District', subcity: 'Arada', isActive: true),
      WeredaModel(id: 2, name: 'Wereda 2', description: 'Business Area', subcity: 'Bole', isActive: true),
      WeredaModel(id: 3, name: 'Wereda 3', description: 'Residential', subcity: 'Yeka', isActive: false),
    ];
    _filterWeredas('');
  }

  void _filterWeredas(String query) {
    setState(() {
      _searchQuery = query;
      _filteredWeredas = _weredas
          .where((w) => w.name.toLowerCase().contains(query.toLowerCase()) || 
                        w.subcity.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  void _addWereda() {
    showDialog(context: context, builder: (context) {
      String name = '';
      String subcity = '';
      String description = '';
      return AlertDialog(
        title: Text('Add Wereda', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(decoration: InputDecoration(labelText: 'Name'), onChanged: (v) => name = v),
            TextField(decoration: InputDecoration(labelText: 'Subcity'), onChanged: (v) => subcity = v),
            TextField(decoration: InputDecoration(labelText: 'Description'), onChanged: (v) => description = v),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              if (name.isNotEmpty) {
                setState(() {
                  _weredas.add(WeredaModel(
                    id: DateTime.now().millisecondsSinceEpoch, 
                    name: name, 
                    description: description, 
                    subcity: subcity, 
                    isActive: true
                  ));
                  _filterWeredas(_searchQuery);
                });
                Navigator.pop(context);
              }
            }, 
            child: Text('Add', style: TextStyle(color: Colors.white))
          ),
        ],
      );
    });
  }

  void _deleteWereda(int id) {
    setState(() {
      _weredas.removeWhere((w) => w.id == id);
      _filterWeredas(_searchQuery);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Wereda Management', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Filter by name or subcity...',
                prefixIcon: Icon(Icons.search, color: AppColors.textHint),
                filled: true,
                fillColor: Colors.white.withOpacity(0.8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
              ),
              onChanged: _filterWeredas,
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filteredWeredas.length,
              itemBuilder: (context, index) {
                final w = _filteredWeredas[index];
                return Card(
                  margin: EdgeInsets.only(bottom: 12),
                  elevation: 4,
                  shadowColor: AppColors.shadow,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: ListTile(
                    contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    title: Text(w.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    subtitle: Text('${w.subcity} - ${w.description}', style: TextStyle(color: AppColors.textSecondary)),
                    trailing: IconButton(
                      icon: Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _deleteWereda(w.id),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addWereda,
        backgroundColor: AppColors.secondary,
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

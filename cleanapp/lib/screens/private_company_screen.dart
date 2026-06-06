import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';

class PrivateCompanyScreen extends StatefulWidget {
  const PrivateCompanyScreen({super.key});
  @override
  State<PrivateCompanyScreen> createState() => _PrivateCompanyScreenState();
}

class _PrivateCompanyScreenState extends State<PrivateCompanyScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _api = ApiService();

  Map<String, dynamic>? _companyInfo;
  List<Map<String, dynamic>> _receipts = [];
  List<Map<String, dynamic>> _weredas  = [];
  List<Map<String, dynamic>> _vehicles = [];

  bool _loadingInfo    = true;
  bool _loadingHistory = true;
  bool _submitting     = false;

  // Form
  final _formKey    = GlobalKey<FormState>();
  int?    _weredaId;
  int?    _vehicleId;
  final _kgCtrl     = TextEditingController();
  final _priceCtrl  = TextEditingController(text: '1.40');
  final _notesCtrl  = TextEditingController();
  DateTime _date    = DateTime.now();
  TimeOfDay _time   = TimeOfDay.now();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _kgCtrl.dispose();
    _priceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final user = Provider.of<AuthService>(context, listen: false).currentUser!;
    final results = await Future.wait([
      _api.getPrivateCompanyInfo(user.id),
      _api.getPrivateReceipts(user.id),
      _api.getWeredas(),
      _api.getVehicles(),
    ]);
    if (!mounted) return;
    setState(() {
      _companyInfo    = results[0] as Map<String, dynamic>?;
      _receipts       = results[1] as List<Map<String, dynamic>>;
      _weredas        = results[2] as List<Map<String, dynamic>>;
      _vehicles       = results[3] as List<Map<String, dynamic>>;
      _loadingInfo    = false;
      _loadingHistory = false;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_weredaId == null) {
      _showSnack('Please select a Wereda', Colors.red);
      return;
    }
    setState(() => _submitting = true);
    final user = Provider.of<AuthService>(context, listen: false).currentUser!;
    final ok = await _api.submitPrivateReceipt(
      userId:   user.id,
      weredaId: _weredaId!,
      vehicleId:_vehicleId,
      kilogram: double.tryParse(_kgCtrl.text) ?? 0,
      price:    double.tryParse(_priceCtrl.text) ?? 1.4,
      date:     DateFormat('yyyy-MM-dd').format(_date),
      time:     '${_time.hour.toString().padLeft(2,'0')}:${_time.minute.toString().padLeft(2,'0')}',
      notes:    _notesCtrl.text,
    );
    setState(() => _submitting = false);
    if (!mounted) return;
    if (ok) {
      _showSnack('Receipt submitted successfully!', Colors.green);
      _kgCtrl.clear(); _notesCtrl.clear();
      _weredaId = null; _vehicleId = null;
      _date = DateTime.now(); _time = TimeOfDay.now();
      _loadAll();
      _tabs.animateTo(1);
    } else {
      _showSnack('Submission failed. Please try again.', Colors.red);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color,
               behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user  = Provider.of<AuthService>(context).currentUser!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Private Company', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          Text(_companyInfo?['company_name'] ?? user.name,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
        ]),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.add_circle_outline), text: 'Submit Receipt'),
            Tab(icon: Icon(Icons.history),             text: 'My Receipts'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAll,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildSubmitTab(isDark),
          _buildHistoryTab(isDark),
        ],
      ),
    );
  }

  // ── SUBMIT TAB ────────────────────────────────────────────────────────────
  Widget _buildSubmitTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Company info card
          if (_companyInfo != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                gradient: AppColors.cardGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(children: [
                const Icon(Icons.business, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_companyInfo!['company_name'] ?? '',
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.w800, fontSize: 15)),
                  if (_companyInfo!['address'] != null)
                    Text(_companyInfo!['address'],
                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ])),
              ]),
            ),

          _sectionTitle('Select Wereda *'),
          _dropdown(
            hint: '— Select Wereda —',
            value: _weredaId,
            items: _weredas.map((w) =>
              DropdownMenuItem(value: w['id'] as int, child: Text(w['name'] ?? ''))).toList(),
            onChanged: (v) => setState(() => _weredaId = v),
          ),
          const SizedBox(height: 14),

          _sectionTitle('Vehicle (optional)'),
          _dropdown(
            hint: '— Select Vehicle —',
            value: _vehicleId,
            items: [
              const DropdownMenuItem(value: null, child: Text('— No vehicle —')),
              ..._vehicles.map((v) =>
                DropdownMenuItem(value: v['id'] as int, child: Text(v['name'] ?? ''))),
            ],
            onChanged: (v) => setState(() => _vehicleId = v),
          ),
          const SizedBox(height: 14),

          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionTitle('Date *'),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2024),
                    lastDate: DateTime.now().add(const Duration(days: 1)),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
                child: _inputDisplay(DateFormat('yyyy-MM-dd').format(_date),
                    Icons.calendar_today),
              ),
            ])),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionTitle('Time *'),
              InkWell(
                onTap: () async {
                  final picked = await showTimePicker(context: context, initialTime: _time);
                  if (picked != null) setState(() => _time = picked);
                },
                child: _inputDisplay(
                    '${_time.hour.toString().padLeft(2,'0')}:${_time.minute.toString().padLeft(2,'0')}',
                    Icons.access_time),
              ),
            ])),
          ]),
          const SizedBox(height: 14),

          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionTitle('Kilogram *'),
              TextFormField(
                controller: _kgCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: _inputDeco('0.00', Icons.scale),
                validator: (v) => (v == null || double.tryParse(v) == null || double.parse(v) <= 0)
                    ? 'Enter valid KG' : null,
                onChanged: (_) => setState(() {}),
              ),
            ])),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionTitle('Price/KG (ETB) *'),
              TextFormField(
                controller: _priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: _inputDeco('1.40', Icons.sell),
                validator: (v) => (v == null || double.tryParse(v) == null || double.parse(v) <= 0)
                    ? 'Enter price' : null,
                onChanged: (_) => setState(() {}),
              ),
            ])),
          ]),
          const SizedBox(height: 14),

          // Total
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Column(children: [
              const Text('Total Amount', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              Text(
                'ETB ${((double.tryParse(_kgCtrl.text) ?? 0) * (double.tryParse(_priceCtrl.text) ?? 0)).toStringAsFixed(2)}',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900,
                    color: AppColors.primary),
              ),
            ]),
          ),
          const SizedBox(height: 14),

          _sectionTitle('Notes (optional)'),
          TextFormField(
            controller: _notesCtrl,
            maxLines: 2,
            decoration: _inputDeco('Any additional notes...', Icons.notes),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded),
              label: Text(_submitting ? 'Submitting…' : 'Submit Receipt',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  // ── HISTORY TAB ───────────────────────────────────────────────────────────
  Widget _buildHistoryTab(bool isDark) {
    if (_loadingHistory) return const Center(child: CircularProgressIndicator());
    if (_receipts.isEmpty)
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.receipt_long, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 12),
          const Text('No receipts yet', style: TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 6),
          const Text('Submit your first receipt using the Submit tab',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
        ]),
      );

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _receipts.length,
        itemBuilder: (ctx, i) {
          final r     = _receipts[i];
          final total = double.tryParse(r['total_amount']?.toString() ?? '0') ?? 0;
          final kg    = double.tryParse(r['kilogram']?.toString() ?? '0') ?? 0;
          final date  = r['receipt_date']?.toString().substring(0, 10) ?? '—';
          final status= r['status']?.toString() ?? 'Registered';
          Color sColor = status == 'Paid' ? Colors.green
              : status == 'Approved' ? Colors.blue : Colors.orange;

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(children: [
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(r['company_name']?.toString() ?? '—',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text('$date  •  ${r['wereda_name'] ?? "—"}',
                        style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: sColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(status,
                        style: TextStyle(color: sColor, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ]),
                const Divider(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  _statChip('KG', '${kg.toStringAsFixed(1)} kg', Icons.scale, Colors.blue),
                  _statChip('Total', 'ETB ${total.toStringAsFixed(2)}', Icons.monetization_on, AppColors.primary),
                  _statChip('Driver', r['driver_name']?.toString() ?? '—', Icons.person, Colors.grey),
                ]),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _statChip(String label, String val, IconData icon, Color color) =>
    Column(children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(height: 3),
      Text(val, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: color)),
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
    ]);

  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(t, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
  );

  Widget _dropdown({
    required String hint,
    required int? value,
    required List<DropdownMenuItem<int?>> items,
    required ValueChanged<int?> onChanged,
  }) => Container(
    decoration: BoxDecoration(
      border: Border.all(color: Colors.grey.shade300),
      borderRadius: BorderRadius.circular(10),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<int?>(
        isExpanded: true,
        value: value,
        hint: Text(hint, style: const TextStyle(color: Colors.grey)),
        items: items,
        onChanged: onChanged,
      ),
    ),
  );

  Widget _inputDisplay(String val, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    decoration: BoxDecoration(
      border: Border.all(color: Colors.grey.shade300),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(children: [
      Icon(icon, size: 16, color: Colors.grey),
      const SizedBox(width: 8),
      Text(val, style: const TextStyle(fontSize: 14)),
    ]),
  );

  InputDecoration _inputDeco(String hint, IconData icon) => InputDecoration(
    hintText: hint,
    prefixIcon: Icon(icon, size: 18),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );
}

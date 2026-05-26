import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../models/submission_model.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
import 'package:geolocator/geolocator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/local_db_service.dart';

class NewSubmissionScreen extends StatefulWidget {
  @override
  _NewSubmissionScreenState createState() => _NewSubmissionScreenState();
}

class _NewSubmissionScreenState extends State<NewSubmissionScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  
  List<Map<String, dynamic>> _weredas = [];
  List<Map<String, dynamic>> _mahberats = [];
  List<Map<String, dynamic>> _companies = [];
  List<Map<String, dynamic>> _vehicles = [];

  String _receiptType = 'Mahberat';
  int? _selectedWereda;
  int? _selectedEntity;
  int? _selectedVehicle;
  
  final _kgController = TextEditingController();
  final _notesController = TextEditingController();
  
  List<XFile> _imageFiles = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDropdownData();
  }

  @override
  void dispose() {
    _kgController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadDropdownData() async {
    setState(() => _isLoading = true);
    final weredas = await _apiService.getWeredas();
    final mahberats = await _apiService.getMahberats();
    final companies = await _apiService.getCompanies();
    final vehicles = await _apiService.getVehicles();
    
    if (mounted) {
      setState(() {
        _weredas = weredas;
        _mahberats = mahberats;
        _companies = companies;
        _vehicles = vehicles;
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage(); 
    
    if (pickedFiles.isNotEmpty) {
      setState(() {
        _imageFiles.addAll(pickedFiles);
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedWereda == null || _selectedEntity == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please select Wereda and ${_receiptType == 'Mahberat' ? 'Mahberat' : 'Company'}')));
      return;
    }

    setState(() => _isLoading = true);

    double? lat;
    double? lng;
    
    // Attempt to get GPS Location
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
          Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
          lat = position.latitude;
          lng = position.longitude;
        }
      }
    } catch (e) {
      print('Could not get location: $e');
    }

    final user = Provider.of<AuthService>(context, listen: false).currentUser!;
    final now = DateTime.now();

    // Upload images to the server first
    List<String> uploadedUrls = [];
    for (var imageFile in _imageFiles) {
      final url = await _apiService.uploadImage(imageFile);
      if (url != null) {
        uploadedUrls.add(url);
      }
    }

    final submission = SubmissionModel(
      userId: user.id,
      role: user.role,
      weredaId: _selectedWereda!,
      mahberatId: _selectedEntity!,
      vehicleId: _selectedVehicle ?? user.vehicleId, 
      kilogram: double.tryParse(_kgController.text) ?? 0.0,
      rate: 0.0, 
      total: 0.0, 
      date: DateFormat('yyyy-MM-dd').format(now),
      time: DateFormat('HH:mm').format(now),
      notes: _notesController.text,
      imageUrl: uploadedUrls.isNotEmpty ? uploadedUrls.join(',') : null, 
      latitude: lat,
      longitude: lng,
      receiptType: _receiptType,
    );

    // Check internet connection
    final connectivityResult = await (Connectivity().checkConnectivity());
    bool hasInternet = connectivityResult.isNotEmpty && connectivityResult.first != ConnectivityResult.none;

    bool success = false;
    bool savedOffline = false;

    if (hasInternet) {
      success = await _apiService.submitWork(submission);
      if (!success) {
        // Fallback to offline if API fails
        await LocalDbService().saveOfflineSubmission(submission);
        savedOffline = true;
      }
    } else {
      await LocalDbService().saveOfflineSubmission(submission);
      savedOffline = true;
    }

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Submission successful! Check your History tab.')));
        context.go('/home');
      } else if (savedOffline) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved offline. Will sync later.')));
        context.go('/home');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Submission failed.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthService>(context).currentUser;
    final isDriver = user?.isDriver ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('New Submission', style: TextStyle(color: AppColors.textPrimary)),
        backgroundColor: AppColors.surface,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        elevation: 1,
      ),
      body: _isLoading && _weredas.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Location & Assignment Card
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Location & Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            const SizedBox(height: 16),
                            // Receipt Type Switcher
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setState(() {
                                        _receiptType = 'Mahberat';
                                        _selectedEntity = null;
                                      }),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        decoration: BoxDecoration(
                                          color: _receiptType == 'Mahberat' ? Colors.white : Colors.transparent,
                                          borderRadius: BorderRadius.circular(8),
                                          boxShadow: _receiptType == 'Mahberat' 
                                              ? [const BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]
                                              : null,
                                        ),
                                        child: Center(
                                          child: Text(
                                            'Mahberat',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: _receiptType == 'Mahberat' ? AppColors.primaryDark : AppColors.textHint,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setState(() {
                                        _receiptType = 'Outsource';
                                        _selectedEntity = null;
                                      }),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        decoration: BoxDecoration(
                                          color: _receiptType == 'Outsource' ? Colors.white : Colors.transparent,
                                          borderRadius: BorderRadius.circular(8),
                                          boxShadow: _receiptType == 'Outsource' 
                                              ? [const BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]
                                              : null,
                                        ),
                                        child: Center(
                                          child: Text(
                                            'Outsource',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: _receiptType == 'Outsource' ? AppColors.primaryDark : AppColors.textHint,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<int>(
                              decoration: _inputDecoration('Wereda', Icons.location_on),
                              value: _selectedWereda,
                              items: _weredas.map((w) => DropdownMenuItem<int>(value: w['id'], child: Text(w['name']))).toList(),
                              onChanged: (val) => setState(() => _selectedWereda = val),
                              validator: (val) => val == null ? 'Required' : null,
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<int>(
                              decoration: _inputDecoration(_receiptType == 'Mahberat' ? 'Mahberat' : 'Company', Icons.business),
                              value: _selectedEntity,
                              items: (_receiptType == 'Mahberat' ? _mahberats : _companies).map((m) => DropdownMenuItem<int>(value: m['id'], child: Text(m['name']))).toList(),
                              onChanged: (val) => setState(() => _selectedEntity = val),
                              validator: (val) => val == null ? 'Required' : null,
                            ),
                            if (isDriver) ...[
                              const SizedBox(height: 16),
                              DropdownButtonFormField<int>(
                                decoration: _inputDecoration('Vehicle (Optional)', Icons.local_shipping),
                                value: _selectedVehicle,
                                items: _vehicles.map((v) => DropdownMenuItem<int>(value: v['id'], child: Text(v['name']))).toList(),
                                onChanged: (val) => setState(() => _selectedVehicle = val),
                              ),
                            ]
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Work Data Card
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Work Data', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _kgController,
                                    keyboardType: TextInputType.number,
                                    decoration: _inputDecoration('Kilograms', Icons.scale),
                                    validator: (val) => val!.isEmpty ? 'Required' : null,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Evidence & Notes
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Evidence & Notes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            const SizedBox(height: 16),
                            InkWell(
                              onTap: _pickImages,
                              child: Container(
                                height: 120,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid),
                                ),
                                child: _imageFiles.isNotEmpty
                                    ? ListView.builder(
                                        scrollDirection: Axis.horizontal,
                                        itemCount: _imageFiles.length,
                                        itemBuilder: (context, index) {
                                          return Padding(
                                            padding: const EdgeInsets.only(right: 8.0),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(12),
                                              child: FutureBuilder<Uint8List>(
                                                future: _imageFiles[index].readAsBytes(),
                                                builder: (context, snapshot) {
                                                  if (snapshot.hasData) {
                                                    return Image.memory(snapshot.data!, fit: BoxFit.cover, width: 120);
                                                  }
                                                  return const SizedBox(width: 120, child: Center(child: CircularProgressIndicator()));
                                                },
                                              ),
                                            ),
                                          );
                                        },
                                      )
                                    : const Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.camera_alt, size: 40, color: AppColors.textHint),
                                          SizedBox(height: 8),
                                          Text('Tap to add photos', style: TextStyle(color: AppColors.textHint)),
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _notesController,
                              maxLines: 3,
                              decoration: _inputDecoration('Additional Notes', Icons.notes),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Submit Button
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('SUBMIT WORK', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.primary),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
      filled: true,
      fillColor: Colors.grey[50],
    );
  }
}

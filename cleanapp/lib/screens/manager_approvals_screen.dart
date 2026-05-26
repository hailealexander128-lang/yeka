import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../models/submission_model.dart';

class ManagerApprovalsScreen extends StatefulWidget {
  @override
  _ManagerApprovalsScreenState createState() => _ManagerApprovalsScreenState();
}

class _ManagerApprovalsScreenState extends State<ManagerApprovalsScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<SubmissionModel>> _pendingSubmissions;

  @override
  void initState() {
    super.initState();
    _loadPending();
  }

  void _loadPending() {
    setState(() {
      _pendingSubmissions = _apiService.getPendingSubmissions();
    });
  }

  Future<void> _updateStatus(int id, String status) async {
    final success = await _apiService.updateSubmissionStatus(id, status);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Submission $status successfully')),
      );
      _loadPending();
    } else if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to update status')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SubmissionModel>>(
      future: _pendingSubmissions,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return const Center(child: Text('Error loading pending submissions'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No pending submissions to approve'));
        }

        final pending = snapshot.data!;

        return ListView.builder(
          padding: const EdgeInsets.all(16.0).copyWith(bottom: 80),
          itemCount: pending.length,
          itemBuilder: (context, index) {
            final item = pending[index];
            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${item.date} • ${item.time}',
                          style: const TextStyle(
                            color: AppColors.textHint,
                            fontSize: 14,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange),
                          ),
                          child: Text(
                            item.status,
                            style: const TextStyle(
                              color: Colors.orange,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.weredaName ?? 'Unknown Wereda',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Driver: ${item.driverName ?? "Unknown"}',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${item.kilogram} KG',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (item.notes.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                const Text(
                                  'Notes:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  item.notes,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              if (item.imageUrl != null &&
                                  item.imageUrl!.isNotEmpty)
                                SizedBox(
                                  height: 100,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: item.imageUrl!.split(',').length,
                                    itemBuilder: (context, imgIndex) {
                                      final path = item.imageUrl!
                                          .split(',')[imgIndex]
                                          .trim();
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          right: 8.0,
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: path.startsWith('http') || path.startsWith('blob:') || kIsWeb
                                              ? Image.network(
                                                  path,
                                                  width: 100,
                                                  height: 100,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 50),
                                                )
                                              : const Icon(Icons.image_not_supported, size: 50),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () => _updateStatus(item.id!, 'Rejected'),
                          icon: const Icon(Icons.close, color: Colors.red),
                          label: const Text(
                            'Reject',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () => _updateStatus(item.id!, 'Approved'),
                          icon: const Icon(Icons.check, color: Colors.white),
                          label: const Text('Approve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

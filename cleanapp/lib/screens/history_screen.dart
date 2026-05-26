import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../models/submission_model.dart';
import '../services/pdf_service.dart';

class HistoryScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthService>(context).currentUser;
    final apiService = ApiService();

    return FutureBuilder<List<SubmissionModel>>(
      future: apiService.getHistory(user!.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return const Center(child: Text('Error loading history'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No submissions found'));
        }

        final history = snapshot.data!;

        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: FloatingActionButton(
            onPressed: () async {
              final pdfService = PdfService();
              await pdfService.generateAndPrintHistoryPdf(history, user.name);
            },
            backgroundColor: AppColors.primaryDark,
            child: const Icon(Icons.picture_as_pdf, color: Colors.white),
            tooltip: 'Export to PDF',
          ),
          body: ListView.builder(
            padding: const EdgeInsets.all(16.0).copyWith(bottom: 80), // extra padding for FAB
            itemCount: history.length,
            itemBuilder: (context, index) {
              final item = history[index];
              return _buildHistoryCard(item);
            },
          ),
        );
      },
    );
  }

  Widget _buildHistoryCard(SubmissionModel item) {
    Color statusColor;
    switch (item.status.toLowerCase()) {
      case 'approved':
        statusColor = Colors.green;
        break;
      case 'rejected':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.orange;
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                  style: const TextStyle(color: AppColors.textHint, fontSize: 14),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    item.status,
                    style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: item.imageUrl != null
                      ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(item.imageUrl!, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.image, color: Colors.grey)))
                      : const Icon(Icons.image, color: Colors.grey),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.weredaName ?? 'Unknown Wereda', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
                      if (item.mahberatName != null)
                        Text(item.mahberatName!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text('${item.kilogram} KG @ \$${item.rate}/KG', style: const TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      Text('Total: \$${item.total}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondaryDark)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../models/FreelanceProjectModel.dart';
import '../../providers/FreelancingHubProvider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class FreelanceProjectModal extends StatelessWidget {
  final FreelanceProjectModel project;

  const FreelanceProjectModal({
    super.key,
    required this.project,
  });

  void _showApplicationModal(BuildContext context) {
    final TextEditingController introController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          final characterCount = introController.text.length;
          final isValid = characterCount >= 50;
          
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 600, maxWidth: 500),
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Apply for Position',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 24),
                          onPressed: () => Navigator.pop(dialogContext),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Project Info
                    Text(
                      project.title,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[800],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      project.companyName,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Instructions
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.blue.shade700, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Write a brief introduction about yourself, your skills, and why you\'re a good fit.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.blue.shade900,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Text Field
                    Expanded(
                      child: TextFormField(
                        controller: introController,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          hintText:
                              'Example: Hi, I\'m a Flutter developer with 3+ years of experience in mobile app development. I specialize in creating beautiful UIs...',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[400],
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Colors.red, width: 2),
                          ),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                        onChanged: (value) {
                          setState(() {}); // Rebuild to update character count
                        },
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please write an introduction';
                          }
                          if (value.trim().length < 50) {
                            return 'Please write at least 50 characters';
                          }
                          return null;
                        },
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Character Counter with visual feedback
                    Row(
                      children: [
                        Icon(
                          isValid ? Icons.check_circle : Icons.error_outline,
                          size: 16,
                          color: isValid ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$characterCount / 50 characters',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isValid ? Colors.green : Colors.orange,
                          ),
                        ),
                        const Spacer(),
                        if (characterCount > 0)
                          Text(
                            characterCount < 50 
                                ? '${50 - characterCount} more needed'
                                : '✓ Minimum reached',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          if (formKey.currentState!.validate()) {
                            // Show loading
                            showDialog(
                              context: dialogContext,
                              barrierDismissible: false,
                              builder: (_) => const Center(
                                child: CircularProgressIndicator(),
                              ),
                            );

                            // Submit application
                            final provider = Provider.of<FreelancingHubProvider>(
                              context,
                              listen: false,
                            );

                            final success = await provider.submitApplication(
                              projectId: project.projectId,
                              introduction: introController.text.trim(),
                            );

                            // Close loading
                            Navigator.pop(dialogContext);
                            // Close application modal
                            Navigator.pop(dialogContext);
                            // Close project details modal
                            Navigator.pop(context);

                            if (success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: const [
                                      Icon(Icons.check_circle, color: Colors.white),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Application submitted successfully!',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: Colors.green,
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 3),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: const [
                                      Icon(Icons.error, color: Colors.white),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Failed to submit. You may have already applied.',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: Colors.red.shade600,
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 3),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.send_rounded, size: 20),
                        label: const Text(
                          'Apply Now',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 650, maxWidth: 500),
        child: Column(
          children: [
            // ========== HEADER ==========
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red.shade400, Colors.red.shade700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              project.companyName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              project.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 26),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ========== CONTENT ==========
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Description
                    const Text(
                      "Description",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      project.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Key Responsibilities
                    const Text(
                      "Key Responsibilities",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      project.keyResponsibilities,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Skills Required
                    const Text(
                      "Skills Required",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: project.skillsNeeded.map((skill) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            skill,
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Project Details
                    _buildDetailRow(
                      Icons.access_time_rounded,
                      "Duration:",
                      project.duration,
                    ),
                    const SizedBox(height: 14),
                    _buildDetailRow(
                      Icons.event_rounded,
                      "Deadline:",
                      DateFormat('dd/MM/yyyy').format(project.deadline),
                    ),
                    const SizedBox(height: 14),
                    if (project.budgetRange != null)
                      _buildDetailRow(
                        Icons.attach_money_rounded,
                        "Budget:",
                        project.budgetRange!,
                      ),

                    // Application Count
                    const SizedBox(height: 14),
                    Consumer<FreelancingHubProvider>(
                      builder: (context, provider, _) {
                        final count =
                            provider.getApplicationCount(project.projectId);
                        return _buildDetailRow(
                          Icons.people_rounded,
                          "Applicants:",
                          count.toString(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // ========== ACTION BUTTONS ==========
            Consumer<FreelancingHubProvider>(
              builder: (context, provider, _) {
                final hasApplied = provider.hasApplied(project.projectId);
                final isSaved = provider.isProjectSaved(project.projectId);
                final application = provider.getApplication(project.projectId);

                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Save for Later Button
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await provider.toggleSaveProject(
                              projectId: project.projectId,
                            );

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    Icon(
                                      isSaved
                                          ? Icons.bookmark_remove
                                          : Icons.bookmark,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      isSaved
                                          ? 'Removed from saved'
                                          : 'Saved for later',
                                      style: const TextStyle(fontSize: 15),
                                    ),
                                  ],
                                ),
                                backgroundColor: Colors.orange.shade600,
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 2),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          },
                          icon: Icon(
                            isSaved ? Icons.bookmark : Icons.bookmark_border,
                            size: 20,
                          ),
                          label: Text(
                            isSaved ? "Saved" : "Save for Later",
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red, width: 2),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Apply Now Button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: hasApplied
                              ? null
                              : () => _showApplicationModal(context),
                          icon: Icon(
                            hasApplied ? Icons.check_circle : Icons.arrow_forward,
                            size: 20,
                          ),
                          label: Text(
                            hasApplied
                                ? application?.status == 'withdrawn'
                                    ? "Withdrawn"
                                    : "Applied"
                                : "Apply Now",
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                hasApplied ? Colors.grey : Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            disabledBackgroundColor: Colors.grey,
                            disabledForegroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 22, color: Colors.red),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
import 'package:flutter/material.dart';
import '../../models/FreelanceProjectModel.dart';
import 'freelance_project_modal.dart';
import '../../providers/FreelancingHubProvider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class FreelanceProjectCard extends StatelessWidget {
  final FreelanceProjectModel project;

  const FreelanceProjectCard({
    super.key,
    required this.project,
  });

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    if (diff.inDays < 7) return "${diff.inDays}d ago";
    return "${(diff.inDays / 7).floor()}w ago";
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FreelancingHubProvider>(
      builder: (context, provider, _) {
        final isSaved = provider.isProjectSaved(project.projectId);
        final hasApplied = provider.hasApplied(project.projectId);
        final applicationCount = provider.getApplicationCount(project.projectId);

        return GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => FreelanceProjectModal(
                project: project,
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ========== COMPANY HEADER ==========
                Row(
                  children: [
                    // Company Logo
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: project.companyLogo != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                project.companyLogo!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(
                                    Icons.business,
                                    color: Colors.red,
                                    size: 24,
                                  );
                                },
                              ),
                            )
                          : const Icon(
                              Icons.business,
                              color: Colors.red,
                              size: 24,
                            ),
                    ),
                    const SizedBox(width: 14),

                    // Company Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            project.companyName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _timeAgo(project.postedAt),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Save Button
                    IconButton(
                      icon: Icon(
                        isSaved ? Icons.bookmark : Icons.bookmark_border,
                        color: isSaved ? Colors.red : Colors.grey,
                        size: 26,
                      ),
                      onPressed: () async {
                        await provider.toggleSaveProject(
                          projectId: project.projectId,
                        );

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isSaved
                                  ? 'Removed from saved'
                                  : 'Saved for later',
                            ),
                            duration: const Duration(seconds: 1),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ========== PROJECT TITLE ==========
                Text(
                  project.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),

                // ========== DESCRIPTION ==========
                Text(
                  project.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),

                // ========== SKILLS ==========
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: project.skillsNeeded.take(4).map((skill) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        skill,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                ),

                // ========== APPLIED BADGE ==========
                if (hasApplied) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.green.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: Colors.green,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Applied',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // ========== FOOTER INFO ==========
                Wrap(
                  spacing: 20,
                  runSpacing: 10,
                  children: [
                    _buildInfoChip(
                      Icons.access_time_rounded,
                      project.duration,
                    ),
                    _buildInfoChip(
                      Icons.event_rounded,
                      DateFormat('dd/MM/yyyy').format(project.deadline),
                    ),
                    if (project.budgetRange != null)
                      _buildInfoChip(
                        Icons.attach_money_rounded,
                        project.budgetRange!,
                      ),
                    if (applicationCount > 0)
                      _buildInfoChip(
                        Icons.people_rounded,
                        "$applicationCount applicants",
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
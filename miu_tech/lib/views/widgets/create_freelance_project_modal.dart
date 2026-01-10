import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/FreelancingHubProvider.dart';

class CreateFreelanceProjectModal extends StatefulWidget {
  const CreateFreelanceProjectModal({super.key});

  @override
  State<CreateFreelanceProjectModal> createState() =>
      _CreateFreelanceProjectModalState();
}

class _CreateFreelanceProjectModalState
    extends State<CreateFreelanceProjectModal> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _companyLogoController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _responsibilitiesController = TextEditingController();
  final _durationController = TextEditingController();
  final _budgetController = TextEditingController();
  
  DateTime? _selectedDeadline;
  final List<String> _selectedSkills = [];
  final TextEditingController _skillController = TextEditingController();
  
  bool _isSubmitting = false;

  // Predefined skills for quick selection
  final List<String> _suggestedSkills = [
    'Flutter',
    'Dart',
    'React',
    'JavaScript',
    'Python',
    'UI/UX',
    'Figma',
    'Mobile Design',
    'Prototyping',
    'Node.js',
    'Firebase',
    'API Integration',
    'Git',
    'Agile',
    'Project Management',
    'TypeScript',
    'Swift',
    'Kotlin',
    'React Native',
    'Vue.js',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _companyNameController.dispose();
    _companyLogoController.dispose();
    _descriptionController.dispose();
    _responsibilitiesController.dispose();
    _durationController.dispose();
    _budgetController.dispose();
    _skillController.dispose();
    super.dispose();
  }

  void _addSkill(String skill) {
    if (skill.isNotEmpty && !_selectedSkills.contains(skill)) {
      setState(() {
        _selectedSkills.add(skill);
      });
    }
  }

  void _removeSkill(String skill) {
    setState(() {
      _selectedSkills.remove(skill);
    });
  }

  Future<void> _selectDeadline() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.red,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDeadline = picked;
      });
    }
  }

  Future<void> _submitProject() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDeadline == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a deadline'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedSkills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one skill'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final provider = Provider.of<FreelancingHubProvider>(
        context,
        listen: false,
      );

      final projectData = {
        'title': _titleController.text.trim(),
        'company_name': _companyNameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'key_responsibilities': _responsibilitiesController.text.trim(),
        'skills_needed': _selectedSkills,
        'duration': _durationController.text.trim(),
        'deadline': DateFormat('yyyy-MM-dd').format(_selectedDeadline!),
      };

      final companyLogo = _companyLogoController.text.trim();
      if (companyLogo.isNotEmpty) {
        projectData['company_logo'] = companyLogo;
      }

      final budgetRange = _budgetController.text.trim();
      if (budgetRange.isNotEmpty) {
        projectData['budget_range'] = budgetRange;
      }

      debugPrint('📤 Submitting project data: $projectData');

      final success = await provider.createProject(projectData);

      if (!mounted) return;

      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Project posted successfully!',
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
                    'Failed to post project. Please try again.',
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
    } catch (e) {
      debugPrint('❌ Error submitting project: $e');
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Widget _buildCharacterCounter(TextEditingController controller, int minLength) {
    final count = controller.text.length;
    final isValid = count >= minLength;
    
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle : Icons.info_outline,
            size: 14,
            color: isValid ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 6),
          Text(
            count >= minLength
                ? '$count characters'
                : '$count / $minLength characters (${minLength - count} more needed)',
            style: TextStyle(
              fontSize: 12,
              color: isValid ? Colors.green : Colors.grey[600],
              fontWeight: isValid ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 700, maxWidth: 550),
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
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.work_outline,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Post a Project',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Find the perfect freelancer for your needs',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
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
            ),

            // ========== FORM CONTENT ==========
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Company Information Section
                      _buildSectionTitle('Company Information'),
                      const SizedBox(height: 12),
                      
                      _buildTextField(
                        controller: _companyNameController,
                        label: 'Company Name',
                        hint: 'e.g., TechStart Inc.',
                        icon: Icons.business,
                        minLength: null,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter company name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      _buildTextField(
                        controller: _companyLogoController,
                        label: 'Company Logo URL (Optional)',
                        hint: 'https://example.com/logo.png',
                        icon: Icons.image,
                        required: false,
                        minLength: null,
                      ),
                      const SizedBox(height: 24),

                      // Project Details Section
                      _buildSectionTitle('Project Details'),
                      const SizedBox(height: 12),
                      
                      _buildTextField(
                        controller: _titleController,
                        label: 'Project Title',
                        hint: 'e.g., Mobile App UI/UX Designer Needed',
                        icon: Icons.title,
                        minLength: 10,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter project title';
                          }
                          if (value.trim().length < 10) {
                            return 'Title must be at least 10 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      _buildTextField(
                        controller: _descriptionController,
                        label: 'Description',
                        hint: 'Describe the project in detail...',
                        icon: Icons.description,
                        maxLines: 4,
                        minLength: 50,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter description';
                          }
                          if (value.trim().length < 50) {
                            return 'Description must be at least 50 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      _buildTextField(
                        controller: _responsibilitiesController,
                        label: 'Key Responsibilities',
                        hint: '• Create wireframes and prototypes\n• Design user interface\n• Conduct user research',
                        icon: Icons.list_alt,
                        maxLines: 5,
                        minLength: 30,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter key responsibilities';
                          }
                          if (value.trim().length < 30) {
                            return 'Responsibilities must be at least 30 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Skills Required Section
                      _buildSectionTitle('Skills Required'),
                      const SizedBox(height: 12),
                      
                      // Custom skill input
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _skillController,
                              decoration: InputDecoration(
                                hintText: 'Add a skill',
                                prefixIcon: const Icon(Icons.label, color: Colors.red),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Colors.red,
                                    width: 2,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                              ),
                              onSubmitted: (value) {
                                _addSkill(value.trim());
                                _skillController.clear();
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              _addSkill(_skillController.text.trim());
                              _skillController.clear();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Add'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // Suggested skills
                      const Text(
                        'Suggested Skills:',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _suggestedSkills.map((skill) {
                          final isSelected = _selectedSkills.contains(skill);
                          return GestureDetector(
                            onTap: () {
                              if (isSelected) {
                                _removeSkill(skill);
                              } else {
                                _addSkill(skill);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.red.withOpacity(0.1)
                                    : Colors.grey.withOpacity(0.1),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.red
                                      : Colors.grey.shade300,
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                skill,
                                style: TextStyle(
                                  color: isSelected ? Colors.red : Colors.grey[700],
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      
                      // Selected skills
                      if (_selectedSkills.isNotEmpty) ...[
                        const Text(
                          'Selected Skills:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _selectedSkills.map((skill) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    skill,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: () => _removeSkill(skill),
                                    child: const Icon(
                                      Icons.close,
                                      size: 16,
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                      const SizedBox(height: 24),

                      // Project Timeline & Budget Section
                      _buildSectionTitle('Timeline & Budget'),
                      const SizedBox(height: 12),
                      
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _durationController,
                              label: 'Duration',
                              hint: 'e.g., 2-3 months',
                              icon: Icons.access_time,
                              minLength: null,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Required';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: _selectDeadline,
                              child: AbsorbPointer(
                                child: _buildTextField(
                                  controller: TextEditingController(
                                    text: _selectedDeadline != null
                                        ? DateFormat('dd/MM/yyyy')
                                            .format(_selectedDeadline!)
                                        : '',
                                  ),
                                  label: 'Deadline',
                                  hint: 'Select date',
                                  icon: Icons.calendar_today,
                                  minLength: null,
                                  validator: (value) {
                                    if (_selectedDeadline == null) {
                                      return 'Required';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      _buildTextField(
                        controller: _budgetController,
                        label: 'Budget Range (Optional)',
                        hint: 'e.g., \$3000-\$5000',
                        icon: Icons.attach_money,
                        required: false,
                        minLength: null,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ========== ACTION BUTTONS ==========
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red, width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submitProject,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(Icons.publish, size: 20),
                      label: Text(
                        _isSubmitting ? 'Posting...' : 'Post Project',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
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
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    bool required = true,
    int? minLength,
    String? Function(String?)? validator,
  }) {
    return StatefulBuilder(
      builder: (context, setState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                if (required) ...[
                  const SizedBox(width: 4),
                  const Text(
                    '*',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: controller,
              maxLines: maxLines,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[400],
                ),
                prefixIcon: Icon(icon, color: Colors.red, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.red, width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.red),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              onChanged: (value) {
                // Trigger rebuild to update character count
                setState(() {});
              },
              validator: validator,
            ),
            if (minLength != null) _buildCharacterCounter(controller, minLength),
          ],
        );
      },
    );
  }
}
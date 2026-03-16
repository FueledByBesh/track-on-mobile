import 'package:flutter/material.dart';

class AddPage extends StatefulWidget {
  const AddPage({super.key});

  @override
  State<AddPage> createState() => _AddPageState();
}

class _AddPageState extends State<AddPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add New')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(
            left: 16.0,
            right: 16.0,
            top: 16.0,
            bottom: 100.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create Something New',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFF1C2A3A),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 32),
              _buildFormField(
                label: 'Title',
                hint: 'Enter title',
                controller: _titleController,
              ),
              const SizedBox(height: 20),
              _buildFormField(
                label: 'Description',
                hint: 'Enter description',
                controller: _descriptionController,
                maxLines: 4,
              ),
              const SizedBox(height: 20),
              Text(
                'Category',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: const Color(0xFF1C2A3A),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildCategoryChip('Work'),
                  const SizedBox(width: 12),
                  _buildCategoryChip('Personal'),
                  const SizedBox(width: 12),
                  _buildCategoryChip('Ideas'),
                ],
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D8E7F),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Item added successfully!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                    _titleController.clear();
                    _descriptionController.clear();
                  },
                  child: const Text(
                    'Create',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required String hint,
    required TextEditingController controller,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1C2A3A),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE8ECEF)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE8ECEF)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2D8E7F), width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChip(String text) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE8ECEF)),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, color: Color(0xFF1C2A3A)),
      ),
    );
  }
}

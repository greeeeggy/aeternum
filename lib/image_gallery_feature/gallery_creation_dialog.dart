import 'package:flutter/material.dart';

class GalleryDesignType {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final int minImages;

  const GalleryDesignType({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.minImages,
  });
}

class GalleryCreationDialog extends StatefulWidget {
  const GalleryCreationDialog({super.key});

  @override
  State<GalleryCreationDialog> createState() => _GalleryCreationDialogState();
}

class _GalleryCreationDialogState extends State<GalleryCreationDialog> {
  final TextEditingController _nameController = TextEditingController();
  GalleryDesignType? _selectedDesign;
  int _currentStep = 0;

  // Available gallery designs
  final List<GalleryDesignType> _designs = const [
    GalleryDesignType(
      id: 'carousel',
      name: 'Carousel',
      description: 'Overlapping cards with auto-scroll',
      icon: Icons.view_carousel,
      minImages: 3,
    ),
    // Add more designs here in the future
    // GalleryDesignType(
    //   id: 'grid',
    //   name: 'Grid',
    //   description: 'Classic grid layout',
    //   icon: Icons.grid_view,
    //   minImages: 1,
    // ),
  ];

  @override
  void initState() {
    super.initState();
    // Listen to text changes to update button state
    _nameController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep == 0 && _selectedDesign != null) {
      setState(() {
        _currentStep = 1;
      });
    } else if (_currentStep == 1 && _nameController.text.trim().isNotEmpty) {
      // Return the result
      Navigator.of(context).pop({
        'name': _nameController.text.trim(),
        'designType': _selectedDesign!.id,
        'minImages': _selectedDesign!.minImages,
      });
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                if (_currentStep > 0)
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: _previousStep,
                  ),
                Expanded(
                  child: Text(
                    _currentStep == 0 ? 'Choose Gallery Design' : 'Name Your Gallery',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: _currentStep > 0 ? TextAlign.center : TextAlign.left,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Content
            if (_currentStep == 0) ...[
              // Step 1: Design Selection
              ..._designs.map((design) => _buildDesignOption(design)),
            ] else ...[
              // Step 2: Gallery Naming
              TextField(
                controller: _nameController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'e.g., Candid, Memories, Vacation',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  filled: true,
                  fillColor: Colors.grey[800],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                onSubmitted: (_) => _nextStep(),
              ),
              const SizedBox(height: 16),
              Text(
                'Selected Design: ${_selectedDesign!.name}',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
              ),
              Text(
                'Minimum ${_selectedDesign!.minImages} images required',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Action Button
            ElevatedButton(
              onPressed: (_currentStep == 0 && _selectedDesign == null) ||
                  (_currentStep == 1 && _nameController.text.trim().isEmpty)
                  ? null
                  : _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                disabledBackgroundColor: Colors.grey[800],
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _currentStep == 0 ? 'Next' : 'Create Gallery',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesignOption(GalleryDesignType design) {
    final isSelected = _selectedDesign?.id == design.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedDesign = design;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue[600]?.withOpacity(0.2) : Colors.grey[800],
            border: Border.all(
              color: isSelected ? Colors.blue[600]! : Colors.transparent,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                design.icon,
                color: isSelected ? Colors.blue[400] : Colors.grey[400],
                size: 32,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      design.name,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      design.description,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Min. ${design.minImages} images',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: Colors.blue[400],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
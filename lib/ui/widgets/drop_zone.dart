import 'package:flutter/material.dart';

/// Empty-state drop zone shown in docx2md mode.
class DropZone extends StatelessWidget {
  const DropZone({super.key, required this.highlighted, required this.onTap});

  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: highlighted ? cs.primaryContainer : cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: highlighted ? cs.primary : cs.outlineVariant,
            width: 2,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.upload_file, size: 56, color: cs.primary),
              const SizedBox(height: 12),
              const Text('Drop a .docx here or click to open'),
            ],
          ),
        ),
      ),
    );
  }
}

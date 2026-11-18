import 'package:flutter/material.dart';

import '../../models/convert_mode.dart';

/// [ from-label ]  [ ⇄ ]  [ to-label ] with animated swap.
class HeaderBar extends StatelessWidget {
  const HeaderBar({
    super.key,
    required this.mode,
    required this.swapCount,
    required this.onSwap,
  });

  final ConvertMode mode;
  final int swapCount;
  final VoidCallback onSwap;

  Widget _label(BuildContext context, String text, Key key) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Text(
        text,
        key: key,
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Center(
              child: _label(context, mode.fromLabel, ValueKey('from-$mode')),
            ),
          ),
          Tooltip(
            message: 'Swap direction',
            child: IconButton.filledTonal(
              key: const Key('swap-button'),
              onPressed: onSwap,
              icon: AnimatedRotation(
                key: const Key('swap-rotation'),
                turns: swapCount * 0.5,
                duration: const Duration(milliseconds: 300),
                child: const Icon(Icons.swap_horiz),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: _label(context, mode.toLabel, ValueKey('to-$mode')),
            ),
          ),
        ],
      ),
    );
  }
}

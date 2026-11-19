import 'package:flutter/material.dart';

import 'flower_template_theme.dart';

class FlowerDockItem {
  const FlowerDockItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Bottom dock: two tabs, a highlighted "+" create button, two tabs.
class FlowerDock extends StatelessWidget {
  const FlowerDock({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    required this.onCreate,
  }) : assert(items.length == 4);

  final List<FlowerDockItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// Null disables the create button (e.g. a past day is selected).
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    Widget tab(int index) => Expanded(
      child: _DockTab(
        item: items[index],
        selected: index == selectedIndex,
        onTap: () => onSelected(index),
      ),
    );
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: palette.line),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: palette.isDark ? 0.45 : 0.12,
                ),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: SizedBox(
              height: 64,
              child: Row(
                children: [
                  const SizedBox(width: 6),
                  tab(0),
                  tab(1),
                  Expanded(
                    child: Center(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 150),
                        opacity: onCreate == null ? 0.4 : 1,
                        child: SizedBox.square(
                          dimension: 54,
                          child: FloatingActionButton(
                            heroTag: null,
                            tooltip: 'Tạo đơn',
                            elevation: 2,
                            highlightElevation: 4,
                            shape: CircleBorder(
                              side: BorderSide(color: palette.blush, width: 4),
                            ),
                            onPressed: onCreate,
                            child: const Icon(Icons.add, size: 28),
                          ),
                        ),
                      ),
                    ),
                  ),
                  tab(2),
                  tab(3),
                  const SizedBox(width: 6),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DockTab extends StatelessWidget {
  const _DockTab({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final FlowerDockItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Tooltip(
      message: item.label,
      child: Semantics(
        button: true,
        selected: selected,
        label: item.label,
        excludeSemantics: true,
        child: InkResponse(
          onTap: onTap,
          radius: 28,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              width: selected ? 52 : 44,
              height: 40,
              decoration: BoxDecoration(
                color: selected ? palette.blush : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                selected ? item.selectedIcon : item.icon,
                size: 24,
                color: selected ? palette.onBlush : palette.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

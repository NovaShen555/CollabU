import 'package:flutter/material.dart';

/// 底部导航项配置
class NavItem {
  final IconData icon;
  final String label;
  final String key;

  const NavItem({
    required this.icon,
    required this.label,
    required this.key,
  });
}

/// 动态底部导航栏
class DynamicBottomNav extends StatelessWidget {
  final List<NavItem> items;
  final int currentIndex;
  final Function(int) onTap;
  final VoidCallback? onMoreTap;
  final bool showMore;

  const DynamicBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.onMoreTap,
    this.showMore = true,
  });

  @override
  Widget build(BuildContext context) {
    final displayItems = items.take(4).toList();

    return BottomNavigationBar(
      currentIndex: currentIndex.clamp(0, displayItems.length + (showMore ? 0 : -1)),
      onTap: (index) {
        if (showMore && index == displayItems.length) {
          onMoreTap?.call();
        } else {
          onTap(index);
        }
      },
      type: BottomNavigationBarType.fixed,
      selectedFontSize: 12,
      unselectedFontSize: 12,
      items: [
        ...displayItems.map((item) => BottomNavigationBarItem(
          icon: Icon(item.icon),
          label: item.label,
        )),
        if (showMore)
          const BottomNavigationBarItem(
            icon: Icon(Icons.more_horiz),
            label: '更多',
          ),
      ],
    );
  }
}

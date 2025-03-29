import 'package:flutter/material.dart';

enum ViewType {
  list, // عمودي
  grid, // شبكي
  horizontal, // أفقي
  masonry, // متدرج
  cardStack // متراكب
}

class ViewOptions {
  final ViewType type;
  final String title;
  final IconData icon;
  final int crossAxisCount;
  final double childAspectRatio;
  final double spacing;
  final EdgeInsets padding;

  const ViewOptions({
    required this.type,
    required this.title,
    required this.icon,
    this.crossAxisCount = 2,
    this.childAspectRatio = 1.0,
    this.spacing = 8.0,
    this.padding = const EdgeInsets.all(16.0),
  });
}

// تعريف القائمة كثابتة
final List<ViewOptions> viewOptions = const [
  ViewOptions(
    type: ViewType.list,
    title: 'قائمة',
    icon: Icons.view_list,
    crossAxisCount: 1,
    childAspectRatio: 2.5,
  ),
  ViewOptions(
    type: ViewType.grid,
    title: 'شبكة',
    icon: Icons.grid_view,
    crossAxisCount: 2, // زيادة عدد الأعمدة
    childAspectRatio: 0.7, // تعديل النسبة
    spacing: 1.0, // تقليل المسافة بين العناصر
    padding: EdgeInsets.all(1.0),
  ),
  ViewOptions(
    type: ViewType.horizontal,
    title: 'أفقي',
    icon: Icons.view_array,
    crossAxisCount: 1,
    childAspectRatio: 1.2,
  ),
  ViewOptions(
    type: ViewType.masonry,
    title: 'متدرج',
    icon: Icons.dashboard,
    crossAxisCount: 2, // زيادة عدد الأعمدة
    childAspectRatio: 0.65, // تعديل النسبة
    spacing: 6.0, // تقليل المسافة بين العناصر
    padding: EdgeInsets.all(1.0),
  ),
  ViewOptions(
    type: ViewType.cardStack,
    title: 'متراكب',
    icon: Icons.layers,
    crossAxisCount: 1,
    childAspectRatio: 1.5,
  ),
];

import 'package:flutter/material.dart';

/// مكون يساعد في تجنب إعادة بناء العناصر الأساسية عند تحديث الحالات المحلية
class LocalKeyProvider extends StatefulWidget {
  final Widget child;

  const LocalKeyProvider({
    super.key,
    required this.child,
  });

  @override
  State<LocalKeyProvider> createState() => _LocalKeyProviderState();
}

class _LocalKeyProviderState extends State<LocalKeyProvider> {
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

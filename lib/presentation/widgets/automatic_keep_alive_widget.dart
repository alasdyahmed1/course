import 'package:flutter/material.dart';

/// مكون يمنع إعادة بناء وإزالة العناصر المهمة عند التمرير
class AutomaticKeepAliveWidget extends StatefulWidget {
  final Widget child;
  
  const AutomaticKeepAliveWidget({
    super.key,
    required this.child,
  });

  @override
  State<AutomaticKeepAliveWidget> createState() => _AutomaticKeepAliveWidgetState();
}

class _AutomaticKeepAliveWidgetState extends State<AutomaticKeepAliveWidget> 
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

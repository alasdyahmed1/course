class NumberFormatter {
  static String format(num number) {
    if (number == 0) return '0';
    return number.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }

  static String formatCurrency(num amount) {
    return '${format(amount)} د.ع';
  }

  static String formatViews(num views) {
    if (views >= 1000000) {
      return '${(views / 1000000).toStringAsFixed(1)}M';
    } else if (views >= 1000) {
      return '${(views / 1000).toStringAsFixed(1)}K';
    }
    return format(views);
  }
}

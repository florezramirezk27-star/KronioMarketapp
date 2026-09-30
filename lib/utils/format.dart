String formatCop(num value) {
  final intPart = value.truncate().toString();
  final buf = StringBuffer();
  for (int i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) {
      buf.write('.');
    }
    buf.write(intPart[i]);
  }
  return '\$ $buf';
}
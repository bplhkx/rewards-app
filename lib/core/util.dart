import 'dart:io';

/// Dart 的 SocketException 会把**本地临时端口**写进消息（port = 46954 之类），
/// 看着像目标端口配错了。连接类失败统一翻成人话，其余异常原样透出。
String errText(Object e) => e is SocketException
    ? '连不上 ${e.address?.address ?? "那个地址"}：端口没在听（服务没起，或 IP/端口填错）'
    : '$e';

/// 面板/Control API 两套后端的字段命名不完全一致（snake/camel），统一在这里兜底取。
dynamic pick(Map? m, List<String> keys) {
  if (m == null) return null;
  for (final k in keys) {
    if (m.containsKey(k) && m[k] != null) return m[k];
  }
  return null;
}

int pickInt(Map? m, List<String> keys, [int d = 0]) {
  final v = pick(m, keys);
  if (v is int) return v;
  if (v is double) return v.round();
  if (v is String) return int.tryParse(v) ?? d;
  return d;
}

String pickStr(Map? m, List<String> keys, [String d = '']) {
  final v = pick(m, keys);
  return v == null ? d : v.toString();
}

String dayLabel(String iso) {
  final dt = DateTime.tryParse(iso)?.toLocal();
  if (dt == null) return '--';
  return '${dt.month}/${dt.day}';
}

String clock(String iso) {
  final dt = DateTime.tryParse(iso)?.toLocal();
  if (dt == null) return '--:--';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(dt.hour)}:${two(dt.minute)}';
}

String maskEmail(String email) {
  final at = email.indexOf('@');
  if (at <= 1) return email;
  return '${email[0]}***${email.substring(at)}';
}

String minutes(num sec) => (sec / 60).toStringAsFixed(1);

/// 把 ISO 时间说成"今天 09:00 / 明天 07:30 / 10/12 09:00"，定时相关的展示都用它。
String whenText(String iso) {
  final dt = DateTime.tryParse(iso)?.toLocal();
  if (dt == null) return '--';
  String two(int n) => n.toString().padLeft(2, '0');
  final hm = '${two(dt.hour)}:${two(dt.minute)}';
  final now = DateTime.now();
  final days = DateTime(dt.year, dt.month, dt.day).difference(DateTime(now.year, now.month, now.day)).inDays;
  if (days == 0) return '今天 $hm';
  if (days == 1) return '明天 $hm';
  return '${dt.month}/${dt.day} $hm';
}

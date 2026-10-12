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

/// 面板把布尔字段原样存成 JSON bool（`streakProtectionEnabled: true`），
/// 用 pickInt 读会一律得到 0 —— 之前"连胜保护明明开着却显示未开启"就是这个。
bool pickBool(Map? m, List<String> keys, [bool d = false]) {
  final v = pick(m, keys);
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.toLowerCase();
    if (s == 'true' || s == '1') return true;
    if (s == 'false' || s == '0') return false;
  }
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
  final hm = '${two(dt.hour)}:${two(dt.minute)}';
  final now = DateTime.now();
  final days = DateTime(dt.year, dt.month, dt.day).difference(DateTime(now.year, now.month, now.day)).inDays;
  if (days == 0) return '今天 $hm';
  if (days == 1) return '明天 $hm';
  return '${dt.month}/${dt.day} $hm';
}

/// bot 的日志时间戳是 `toLocaleString('en-US')` 出来的朴素时间（"10/11/2026, 3:29:07 AM"），不带时区。
/// 手机侧 bot / 面板的进程 TZ 已统一设为 Asia/Shanghai（启动链 + .env 都写了 TZ），
/// 所以这个朴素时间**就是北京时间**，按本地时间解，绝不能再加偏移。
/// 这条约定有副本要一起改：`wait-idle.sh` 之外，服务端 TZ 一改这里就得跟着改。
final RegExp _botTsRe = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4}),?\s+(\d{1,2}):(\d{2}):(\d{2})\s*(AM|PM)$', caseSensitive: false);

DateTime? parseBotTs(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return null;
  final iso = DateTime.tryParse(s);
  if (iso != null) return iso.toUtc(); // 面板自己的字段是带 Z 的真 UTC，照常转本地
  final m = _botTsRe.firstMatch(s);
  if (m == null) return null;
  var hour = int.parse(m.group(4)!);
  final ap = m.group(7)!.toUpperCase();
  if (ap == 'PM' && hour != 12) hour += 12;
  if (ap == 'AM' && hour == 12) hour = 0;
  // 朴素时间 = 服务端本地时区（北京），所以用本地构造函数，不做任何换算
  return DateTime(int.parse(m.group(3)!), int.parse(m.group(1)!), int.parse(m.group(2)!), hour, int.parse(m.group(5)!), int.parse(m.group(6)!));
}

String two(int n) => n.toString().padLeft(2, '0');

/// 本地日期键 "YYYY-MM-DD"，热力图和面板 daily_points 都用这个格式。
String dayKey(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';

/// 日志行用的"月-日 时:分:秒"（本地时区 = 北京）。
String logClock(String raw) {
  final dt = parseBotTs(raw);
  if (dt == null) return raw;
  final l = dt.toLocal();
  return '${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}:${two(l.second)}';
}

/// 只到天 + 时分（详情页时间列）。
String stampText(String raw, {bool withDate = true}) {
  final dt = parseBotTs(raw) ?? DateTime.tryParse(raw)?.toUtc();
  if (dt == null) return raw;
  final l = dt.toLocal();
  final hm = '${two(l.hour)}:${two(l.minute)}';
  return withDate ? '${l.month}/${l.day} $hm' : hm;
}

/// 日期 + 时分，用于"最近运行"这种要跨天的列表。
/// 面板的 runs.startTs 是**真 UTC**（还是带 12 位小数秒的那种怪串，Dart 能解析），
/// 直接截字符串等于把 19:30 的跑显示成 11:30 —— 之前主页就这样早了 8 小时。
String dateTimeText(String raw) {
  final dt = parseBotTs(raw);
  if (dt == null) return raw.isEmpty ? '--' : raw;
  final l = dt.toLocal();
  return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
}

/// 打卡类活动的 kind（面板 checkin_progress 的键）→ 中文。
const Map<String, String> checkinKindLabels = {
  'default-search': '默认搜索引擎',
};

String checkinStatusLabel(String status) => switch (status) {
      'advanced' => '今日已推进',
      'complete' => '已全部完成',
      'stalled' => '今日未计入',
      'started' => '打卡中',
      _ => '进度',
    };

/// bot 的分类积分键（scripts/api/logParser.js 的 pointEventSource）→ 中文。
const Map<String, String> pointSourceLabels = {
  'search': '搜索',
  'searchOnBing': 'Bing 搜索活动',
  'bonus': '搜索奖励',
  'visualSearch': '视觉搜索',
  'read': '阅读',
  'checkIn': '签到',
  'claimBonus': '申领加成',
  'claimReward': '领取奖励',
  'urlReward': '活动奖励',
  'appReward': 'App 推广',
  'punchcard': '打卡卡',
  'dailySet': '每日套装',
  'morePromotions': '更多推广',
  'other': '其它',
};

/// 分类明细按分值从大到小排，未知键原样透出（bot 加了新类型时不至于看不见）。
List<({String key, String label, int value})> pointBreakdown(Map? bySource) {
  if (bySource == null) return const [];
  final out = <({String key, String label, int value})>[];
  bySource.forEach((k, v) {
    final key = '$k';
    final n = v is num ? v.toInt() : int.tryParse('$v') ?? 0;
    if (n == 0) return;
    out.add((key: key, label: pointSourceLabels[key] ?? key, value: n));
  });
  out.sort((a, b) => b.value.compareTo(a.value));
  return out;
}


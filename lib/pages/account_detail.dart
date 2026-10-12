import 'package:flutter/material.dart';

import '../core/tokens.dart';
import '../core/util.dart';
import '../widgets/ui.dart';

/// 账号详情。三块数据来源不同，页面上也分开标：
/// · 今天 —— 面板 daily_points 表里当天的分类合计（跑动过程中持续固化，北京零点自然换天）
/// · 本轮 —— bot 进程内存里的 live.bySource，新一轮或 API 重启就清零
/// · 历史 —— 面板 sqlite 的逐次记录 + 每日分类固化
class AccountDetailPage extends StatelessWidget {
  const AccountDetailPage({
    super.key,
    required this.account,
    required this.live,
    required this.history,
    this.daily = const [],
    this.today = '',
    this.todayTotal = 0,
    this.checkins = const {},
    this.running = false,
  });

  /// /api/accounts 里这条账号的合并数据
  final Map<String, dynamic> account;

  /// /api/summary -> status.bot.run.accounts[] 里同邮箱的那条（含 live），没有就是空 map
  final Map<String, dynamic> live;

  /// histories[email] —— 面板 sqlite 里的逐次记录 [{ts, points, gained, durationSec}]
  final List<dynamic> history;

  /// dailyPoints[email] —— 面板固化的每日分类 [{day, total, sources:{...}}]，天倒序
  final List<dynamic> daily;

  /// 面板给的"今天"（北京日期 YYYY-MM-DD）
  final String today;

  /// 今日合计：面板 account_history 里今天每轮 gained 相加（和主页"今日"同源）
  final int todayTotal;

  /// 面板 /api/accounts 的 checkins[email]：
  /// {today, tasks:{source:{streak,todayDone}}, checkins:{'default-search':{days,daysMax,status,ts}}}
  final Map<String, dynamic> checkins;

  /// bot 当前正在跑的就是这个账号
  final bool running;

  Map<String, dynamic> get _ls => live['live'] is Map ? (live['live'] as Map).cast<String, dynamic>() : const {};

  Map<String, dynamic>? get _todayRow {
    for (final d in daily) {
      if (d is Map && pickStr(d, ['day']) == today) return d.cast<String, dynamic>();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final email = pickStr(account, ['email']);
    final liveRows = pointBreakdown(
        (live['bySource'] is Map && (live['bySource'] as Map).isNotEmpty)
            ? live['bySource'] as Map
            : (_ls['bySource'] as Map?));
    final dayRow = _todayRow;
    final dayRows = pointBreakdown(dayRow?['sources'] as Map?);
    final dayTotal = todayTotal;
    final collected = pickInt(live, ['collectedPoints'], pickInt(_ls, ['gained'], pickInt(account, ['lastGained'])));
    final initial = pickInt(live, ['initialPoints'], pickInt(account, ['lastPoints']) - collected);
    final finalPts = pickInt(live, ['finalPoints'], pickInt(_ls, ['balance'], pickInt(account, ['lastPoints'])));
    final earnable = live['earnable'] is Map ? (live['earnable'] as Map).cast<String, dynamic>() : const <String, dynamic>{};
    final search = live['searchSummary'] is Map ? (live['searchSummary'] as Map).cast<String, dynamic>() : const <String, dynamic>{};
    final streak = live['streakProtection'] is Map
        ? (live['streakProtection'] as Map).cast<String, dynamic>()
        : (_ls['streakProtection'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};

    return Scaffold(
      backgroundColor: T.canvas(context),
      appBar: AppBar(
        title: Row(children: [
          Flexible(
            child: Text(email, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15)),
          ),
          if (running) ...[
            const SizedBox(width: 8),
            const Pill('当前在跑', color: T.green500),
          ],
        ]),
        backgroundColor: T.canvas(context),
      ),
      body: ListView(
        padding: const EdgeInsets.all(T.pagePad),
        children: [
          // ---------- 今天（合计以每轮记录为准，分类明细来自固化表） ----------
          PanelCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const SectionTitle('今天'),
                const SizedBox(width: 8),
                Text(today.isEmpty ? '--' : today, style: TextStyle(fontSize: 11.5, color: T.subText(context))),
                const Spacer(),
                Pill('+${dayTotal > 0 ? dayTotal : pickInt(dayRow, ['total'])}', color: T.green500),
              ]),
              const SizedBox(height: 8),
              if (dayRows.isEmpty)
                Text(dayTotal > 0 ? '今天拿了 $dayTotal 分，但还没有分类明细' : '还没有今天的记录',
                    style: TextStyle(fontSize: 12, height: 1.5, color: T.subText(context)))
              else ...[
                ..._bars(dayRows),
                if (dayTotal > 0 && dayTotal != pickInt(dayRow, ['total']))
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    // 明细按轮固化，账本上线之前的天数会偏少；合计一律用每轮记录，两者
                    // 不一致时把差说出来，别让人以为数字是随便挑的。
                    child: Text(
                      '分类明细合计 ${pickInt(dayRow, ['total'])} 分，与每轮记录合计 $dayTotal 分差 ${dayTotal - pickInt(dayRow, ['total'])} 分',
                      style: TextStyle(fontSize: 10.5, height: 1.5, color: T.amber500),
                    ),
                  ),
              ],
            ]),
          ),
          const SizedBox(height: T.gap),
          // ---------- 打卡情况（面板 checkin_progress + daily_points 连续天数） ----------
          _checkinCard(context),
          const SizedBox(height: T.gap),
          _levelUpCard(context),
          const SizedBox(height: T.gap),
          // ---------- 本轮（bot 内存） ----------
          PanelCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const SectionTitle('本轮'),
                const SizedBox(width: 8),
                Pill(pickStr(live, ['success']).isEmpty ? '没在跑' : (live['success'] == true ? '成功' : '失败'),
                    color: live['success'] == true ? T.green500 : T.slate500),
                const Spacer(),
                Text('#${pickInt(account, ['index'])} · ${pickStr(account, ['geoLocale']).split(RegExp(r'[ |]')).first}',
                    style: TextStyle(fontSize: 11.5, color: T.subText(context))),
              ]),
              const SizedBox(height: 10),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('+$collected', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: T.primary)),
                  Text('$initial → $finalPts 分', style: TextStyle(fontSize: 11.5, color: T.subText(context))),
                ]),
                const Spacer(),
                if (live['durationSeconds'] is num)
                  Text('用时 ${minutes(live['durationSeconds'] as num)} 分钟', style: TextStyle(fontSize: 11.5, color: T.subText(context))),
              ]),
              const SizedBox(height: 12),
              Divider(color: T.hairline(context), height: 1),
              const SizedBox(height: 8),
              if (liveRows.isEmpty)
                Text('本轮还没有分类记录',
                    style: TextStyle(fontSize: 11.5, height: 1.5, color: T.subText(context)))
              else
                ..._bars(liveRows),
            ]),
          ),
          const SizedBox(height: T.gap),
          // ---------- 历史每日（固化表，倒序） ----------
          PanelCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const SectionTitle('每日分类历史'),
                const Spacer(),
                Text('${daily.length} 天', style: TextStyle(fontSize: 11, color: T.subText(context))),
              ]),
              const SizedBox(height: 6),
              if (daily.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text('还没有历史',
                      style: TextStyle(fontSize: 12, color: T.subText(context))),
                )
              else
                ...daily.take(14).map((d) {
                  final m = d is Map ? d.cast<String, dynamic>() : const <String, dynamic>{};
                  final rows = pointBreakdown(m['sources'] as Map?);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text(pickStr(m, ['day']), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Text('+${pickInt(m, ['total'])}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: T.green500)),
                      ]),
                      const SizedBox(height: 3),
                      Text(rows.map((e) => '${e.label} ${e.value}').join(' · '),
                          style: TextStyle(fontSize: 11, height: 1.4, color: T.subText(context))),
                    ]),
                  );
                }),
            ]),
          ),
          if (earnable.isNotEmpty || search.isNotEmpty) ...[
            const SizedBox(height: T.gap),
            PanelCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SectionTitle('还能拿'),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  if (earnable.isNotEmpty) ...[
                    _chip(context, 'App 端', pickInt(earnable, ['mobile'])),
                    _chip(context, '浏览器端', pickInt(earnable, ['browser'])),
                    _chip(context, '全部', pickInt(earnable, ['mobile']) + pickInt(earnable, ['browser'])),
                  ],
                ]),
                if (search.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text('搜索：桌面 ${pickInt(search, ['desktop'])} · 移动 ${pickInt(search, ['mobile'])} · 奖励 ${pickInt(search, ['bonus'])} · 计 ${pickInt(search, ['total'])}',
                      style: TextStyle(fontSize: 12, color: T.subText(context))),
                ],
              ]),
            ),
          ],
          const SizedBox(height: T.gap),
          PanelCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SectionTitle('连胜保护'),
              const SizedBox(height: 8),
              Text(_streakText(streak), style: const TextStyle(fontSize: 13)),
              if (pickStr(streak, ['updatedAt']).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('更新 ${stampText(pickStr(streak, ['updatedAt']))}', style: TextStyle(fontSize: 11, color: T.subText(context))),
                )
              else if (pickStr(account, ['streakProtectionUpdatedAt']).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('更新 ${stampText(pickStr(account, ['streakProtectionUpdatedAt']))}', style: TextStyle(fontSize: 11, color: T.subText(context))),
                ),
            ]),
          ),
          const SizedBox(height: T.gap),
          PanelCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const SectionTitle('历史逐次记录'),
                const Spacer(),
                Text('${history.length} 次', style: TextStyle(fontSize: 11, color: T.subText(context))),
              ]),
              const SizedBox(height: 6),
              if (history.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text('还没有记录', style: TextStyle(fontSize: 12, color: T.subText(context))),
                )
              else
                ...history.reversed.take(14).map((h) {
                  final m = h is Map ? h.cast<String, dynamic>() : const <String, dynamic>{};
                  final gained = pickInt(m, ['gained']);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(children: [
                      Text(stampText(pickStr(m, ['ts'])), style: TextStyle(fontSize: 12, color: T.subText(context))),
                      const SizedBox(width: 10),
                      Expanded(child: Text('${pickInt(m, ['points'])} 分', style: const TextStyle(fontSize: 12.5))),
                      Text(gained >= 0 ? '+$gained' : '$gained',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: gained > 0 ? T.green500 : T.slate500)),
                    ]),
                  );
                }),
            ]),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  /// 面板的 streakProtectionEnabled 是 JSON 布尔，不是 0/1
  String _streakText(Map<String, dynamic> streak) {
    if (streak.isNotEmpty) {
      return '${streak['enabled'] == true ? '已开启' : '未开启'} · 连胜 ${pickInt(streak, ['streakCounter'])} 天 · 剩余 ${pickInt(streak, ['remainingDays'])} 天缓冲';
    }
    if (pickBool(account, ['streakProtectionEnabled'])) {
      return '已开启 · 连胜 ${pickInt(account, ['streakCounter'])} 天 · 剩余 ${pickInt(account, ['streakProtectionRemainingDays'])} 天缓冲';
    }
    return '未开启';
  }

  /// 面板 checkin_progress 里的一类进度（punch / search-today / default-search / …）
  Map<String, dynamic> _kind(String name) {
    final v = (checkins['checkins'] as Map?)?[name];
    return v is Map ? v.cast<String, dynamic>() : const <String, dynamic>{};
  }

  /// 右下角那句小字：什么时候记的、是不是今天的。
  /// 面板存的是"最新一条日志"，昨天的完成态不能显示成今天的，所以必须说清日期。
  String _kindNote(Map<String, dynamic> k) {
    if (k.isEmpty) return '还没有记录 · bot 跑起来才会读进度';
    final when = stampText(pickStr(k, ['ts']));
    if (pickBool(k, ['today'])) return '${checkinStatusLabel(pickStr(k, ['status']))} · $when 记录';
    return '$when 的记录 · 今天还没更新';
  }

  /// 最近 n 天里该分类当天有没有得分（下标 0 = 今天）
  List<bool> _sourceDays(String source, {int n = 7}) {
    final has = <String>{};
    for (final d in daily) {
      if (d is! Map) continue;
      final src = d['sources'];
      final v = src is Map ? num.tryParse('${src[source]}') : null;
      if (v != null && v > 0) has.add('${d['day']}');
    }
    return _dayFlags(n, has);
  }

  /// 最近 n 天里"当天拿到过任何积分"的天
  List<bool> _anyDays({int n = 7}) {
    final has = <String>{
      for (final d in daily.whereType<Map>())
        if (pickInt(d.cast<String, dynamic>(), ['total']) > 0) '${d['day']}',
    };
    return _dayFlags(n, has);
  }

  List<bool> _dayFlags(int n, Set<String> has) {
    // today 是面板给的北京日期；DateTime 不可变，这里必须是普通赋值而不是级联
    final base = DateTime.tryParse(today) ?? DateTime.now();
    return List.generate(n, (i) => has.contains(dayKey(base.subtract(Duration(days: i)))));
  }

  int _overallStreak() {
    // 和面板同一套口径：今天还没跑不算断，从昨天往前数
    final has = _anyDays(n: 90);
    var n = 0;
    var i = has[0] ? 0 : 1;
    while (i < has.length && has[i]) {
      n++;
      i++;
    }
    return n;
  }

  /// x/y 的进度画成 y 个格子（前 x 个填色）。手机上条状进度没有刻度，
  /// "14 天里的第 3 天"数格子比看色带快；格子数封顶 31，避免 60/60 那种撑满一屏。
  List<bool> _cells(int done, int total) {
    if (total <= 0) return const [];
    final n = total > 31 ? 31 : total;
    return List.generate(n, (i) => i < done);
  }

  /// 打卡情况：印章收集 / 必应搜索 / 每日打卡 / 必应 App
  Widget _checkinCard(BuildContext context) {
    final tasks = (checkins['tasks'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    int streakOf(String source) => pickInt((tasks[source] as Map?)?.cast<String, dynamic>(), ['streak']);
    bool doneToday(String source) => pickBool((tasks[source] as Map?)?.cast<String, dynamic>(), ['todayDone']);

    final punch = _kind('punch');
    final search = _kind('search-today');
    final app = _kind('app-checkin-today');

    return PanelCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionTitle('打卡情况'),
        const SizedBox(height: 2),
        ProgressRow(
          label: '印章收集',
          // 单位不写死：面板给的可能是"3/12 个印章"，也可能是退回的"几张卡完成几张"，
          // 数字本身配格子就够了，标错单位比不标更糟
          value: punch.isEmpty ? null : '${pickInt(punch, ['days'])}/${pickInt(punch, ['daysMax'])}',
          dots: punch.isEmpty ? const [] : _cells(pickInt(punch, ['days']), pickInt(punch, ['daysMax'])),
          dotCell: 16,
          note: _kindNote(punch),
        ),
        ProgressRow(
          label: '必应搜索',
          value: '连续 ${streakOf('search')} 天',
          dots: _sourceDays('search'),
          note: search.isEmpty
              ? '今日 ${doneToday('search') ? '已打卡' : '未打卡'} · 方格=最近 7 天'
              // 机器人那行 "Desktop: 60/60" 是 pointProgress/pointProgressMax，
              // 也就是积分额度，不是搜索次数（SearchProgress.summarize 里加的就是分数）
              : '今日 ${pickInt(search, ['days'])}/${pickInt(search, ['daysMax'])} 分 · ${doneToday('search') ? '已拿满' : '未拿满'}',
        ),
        ProgressRow(
          label: '每日打卡',
          // 必须是 ${_overallStreak()} —— 写 $_overallStreak() 只会插值函数本身，
          // 屏幕上就冒出 "Closure: () => int from Function '_overallStreak'"
          value: '连续 ${_overallStreak()} 天',
          dots: _anyDays(),
          note: '拿到过积分就算一天 · 实心格=有分',
          color: T.amber500,
        ),
        ProgressRow(
          label: '必应 App',
          value: '连续 ${streakOf('checkIn')} 天',
          dots: _sourceDays('checkIn'),
          note: app.isEmpty ? _kindNote(const {}) : _kindNote(app),
          color: T.purple500,
        ),
      ]),
    );
  }

  /// 升级活动打卡进度：默认搜索引擎 / 每日活动 / 必应 App 签到。
  /// 优先用 bot 从 level_info 读到的"x/y 天"（level-* 那几种），
  /// 那一行还没出现过时退回日志完成态（*-today），两者都没有就明说没记录。
  Widget _levelUpCard(BuildContext context) {
    Widget row(String label, String daysKind, String todayKind, Color color, List<bool> dots) {
      final d = _kind(daysKind);
      final t = _kind(todayKind);
      if (d.isNotEmpty) {
        final days = pickInt(d, ['days']);
        final max = pickInt(d, ['daysMax'], 1);
        return ProgressRow(
          label: label,
          value: '$days/$max 天',
          // 天数型进度一律用格子：一格一天，一眼能数出还差几天
          dots: _cells(days, max),
          dotCell: max > 16 ? 11 : 15,
          note: _kindNote(d),
          color: color,
        );
      }
      return ProgressRow(
        label: label,
        value: t.isEmpty
            ? '未记录'
            : (pickStr(t, ['status']) == 'complete' && pickBool(t, ['today']) ? '今日已完成' : '今日未完成'),
        dots: dots,
        note: t.isEmpty ? '还没有记录 · bot 跑起来才会读进度' : _kindNote(t),
        color: color,
      );
    }

    return PanelCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const SectionTitle('升级活动打卡进度'),
          const Spacer(),
          Text('奖励在下一个日历月初发放', style: TextStyle(fontSize: 10, color: T.subText(context))),
        ]),
        const SizedBox(height: 2),
        row('默认搜索引擎', 'default-search', '', T.primary, const []),
        row('每日活动', 'level-dailyset', 'daily-set-today', T.green500, _sourceDays('urlReward')),
        row('必应 App 签到', 'level-dailystreaks_mobile', 'app-checkin-today', T.purple500, _sourceDays('checkIn')),
      ]),
    );
  }

  List<Widget> _bars(List<({String key, String label, int value})> rows) {
    if (rows.isEmpty) return const [];
    final top = rows.first.value == 0 ? 1 : rows.first.value;
    return [
      for (final e in rows)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            SizedBox(width: 104, child: Text(e.label, style: const TextStyle(fontSize: 13))),
            Expanded(
              child: LayoutBuilder(builder: (context, box) {
                final w = (e.value / top).clamp(0.04, 1.0);
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    height: 8,
                    width: box.maxWidth * w,
                    decoration: BoxDecoration(color: T.primary.withValues(alpha: 0.75), borderRadius: T.sm),
                  ),
                );
              }),
            ),
            Text('+${e.value}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: T.green500)),
          ]),
        ),
    ];
  }

  Widget _chip(BuildContext context, String label, int value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: T.surface(context), borderRadius: T.sm, border: Border.all(color: T.hairline(context))),
        child: Text('$label 还有 $value', style: const TextStyle(fontSize: 12)),
      );
}

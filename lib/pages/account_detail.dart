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
          // ---------- 今天（面板固化，跑完会留住） ----------
          PanelCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const SectionTitle('今天'),
                const SizedBox(width: 8),
                Text(today.isEmpty ? '--' : today, style: TextStyle(fontSize: 11.5, color: T.subText(context))),
                const Spacer(),
                if (dayRows.isNotEmpty)
                  Pill('+${pickInt(dayRow, ['total'])}', color: T.green500),
              ]),
              const SizedBox(height: 8),
              if (dayRows.isEmpty)
                Text('还没有今天的记录',
                    style: TextStyle(fontSize: 12, height: 1.5, color: T.subText(context)))
              else
                ..._bars(dayRows),
            ]),
          ),
          const SizedBox(height: T.gap),
          // ---------- 打卡情况（面板 checkinSummary：连续天数 + 跨天活动进度） ----------
          _checkinCard(context),
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

  /// 打卡情况：跨天连续型活动（默认搜索引擎 x/14 天）+ 各分类的连续得分天数。
  /// 连续天数由面板从 daily_points 倒推，今天还没跑不算断，只标"今日未打卡"。
  Widget _checkinCard(BuildContext context) {
    final dse = (checkins['checkins'] as Map?)?['default-search'];
    final tasks = (checkins['tasks'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    // 已知分类按 labels 的顺序排，bot 将来加了新键也照样显示（原样透出键名）
    final order = <String>[
      for (final k in pointSourceLabels.keys)
        if (tasks.containsKey(k)) k,
      for (final k in tasks.keys)
        if (!pointSourceLabels.containsKey(k)) k,
    ];

    return PanelCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const SectionTitle('打卡情况'),
          const Spacer(),
          Text('连续天数 · 近 90 天', style: TextStyle(fontSize: 10.5, color: T.subText(context))),
        ]),
        const SizedBox(height: 10),
        if (dse is Map)
          _dseRow(context, dse.cast<String, dynamic>())
        else
          Text('默认搜索引擎：还没有打卡进度记录（bot 每天跑的时候才会读进度）',
              style: TextStyle(fontSize: 11.5, height: 1.5, color: T.subText(context))),
        const SizedBox(height: 12),
        Divider(color: T.hairline(context), height: 1),
        const SizedBox(height: 8),
        if (order.isEmpty)
          Text('还没有分类打卡记录 —— 面板从今天起才把每日分类积分固化下来',
              style: TextStyle(fontSize: 11.5, height: 1.5, color: T.subText(context)))
        else
          for (final k in order) _taskRow(context, k, tasks[k] as Map?),
      ]),
    );
  }

  Widget _dseRow(BuildContext context, Map<String, dynamic> d) {
    final days = pickInt(d, ['days']);
    final max = pickInt(d, ['daysMax'], 14);
    final ratio = max <= 0 ? 0.0 : (days / max).clamp(0.0, 1.0);
    final done = days >= max && max > 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('默认搜索引擎', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const Spacer(),
        Text('$days/$max 天',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: done ? T.green500 : T.primary)),
      ]),
      const SizedBox(height: 6),
      // 14 天要一格一格数，画成进度条比看数字直观
      Container(
        height: 7,
        decoration: BoxDecoration(color: T.slate500.withValues(alpha: 0.18), borderRadius: T.sm),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: ratio,
            child: Container(decoration: BoxDecoration(color: done ? T.green500 : T.primary, borderRadius: T.sm)),
          ),
        ),
      ),
      const SizedBox(height: 5),
      Text(
        '${checkinStatusLabel(pickStr(d, ['status']))}${pickStr(d, ['ts']).isEmpty ? '' : ' · ${stampText(pickStr(d, ['ts']))} 记录'}',
        style: TextStyle(fontSize: 10.5, color: T.subText(context)),
      ),
    ]);
  }

  Widget _taskRow(BuildContext context, String key, Map? raw) {
    final m = raw?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final streak = pickInt(m, ['streak']);
    final todayDone = pickBool(m, ['todayDone']);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(width: 96, child: Text(pointSourceLabels[key] ?? key, style: const TextStyle(fontSize: 12.5))),
        Icon(todayDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 15, color: todayDone ? T.green500 : T.slate400),
        const SizedBox(width: 5),
        Text(todayDone ? '今日已打卡' : '今日未打卡',
            style: TextStyle(fontSize: 11.5, color: todayDone ? T.green500 : T.subText(context))),
        const Spacer(),
        Text('连续 $streak 天', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
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

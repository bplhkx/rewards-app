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
      appBar: AppBar(title: Text(email, style: const TextStyle(fontSize: 15)), backgroundColor: T.canvas(context)),
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
                Text('面板里还没有今天的固化记录 —— 这个表是跑动过程中每次状态更新时写的，跑完一轮就一定有。',
                    style: TextStyle(fontSize: 12, height: 1.5, color: T.subText(context)))
              else
                ..._bars(dayRows),
            ]),
          ),
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
                Text('本轮还没有分类记录。bot 内存里的 bySource 在新一轮开始或 Control API 重启时清零 —— 想留住就看上面"今天"那块。',
                    style: TextStyle(fontSize: 11.5, height: 1.5, color: T.subText(context)))
              else ...[
                ..._bars(liveRows),
                const SizedBox(height: 6),
                Text('键名 ${liveRows.map((e) => e.key).join(" / ")}', style: TextStyle(fontSize: 10, color: T.slate400)),
              ],
            ]),
          ),
          const SizedBox(height: T.gap),
          // ---------- 历史每日（固化表，倒序） ----------
          PanelCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const SectionTitle('每日分类历史'),
                const Spacer(),
                Text('面板 daily_points · ${daily.length} 天', style: TextStyle(fontSize: 11, color: T.subText(context))),
              ]),
              const SizedBox(height: 6),
              if (daily.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text('还没有历史（这张表是刚加的，从今天这一轮开始往后攒）。',
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
                Text('面板 sqlite · ${history.length} 次', style: TextStyle(fontSize: 11, color: T.subText(context))),
              ]),
              const SizedBox(height: 6),
              if (history.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text('面板里还没有这个账号的历史（跑完一轮才会落库）', style: TextStyle(fontSize: 12, color: T.subText(context))),
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

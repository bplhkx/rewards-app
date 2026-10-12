import 'package:flutter/material.dart';

import '../core/panel.dart';
import '../core/tokens.dart';
import '../core/util.dart';
import '../widgets/ui.dart';

/// 参数设置：读 GET /api/config（面板转发 bot 的 /config），改动攒着，
/// 保存时只把改过的路径拼成嵌套对象 PATCH 回去（服务端 deepMerge + zod 校验，
/// 所以漏字段/写错值会被拒，不会写坏 config.json）。token 在面板那边，App 不碰。
class ConfigPage extends StatefulWidget {
  const ConfigPage({super.key, required this.panel});
  final Panel panel;

  @override
  State<ConfigPage> createState() => _ConfigPageState();
}

class _ConfigPageState extends State<ConfigPage> {
  Map<String, dynamic>? _c;
  final Map<String, dynamic> _dirty = {};
  bool _busy = false;
  String? _err;
  String? _ok;

  static const _boolLabels = {
    'headless': '无头模式',
    'debugLogs': '输出 debug 日志',
    'ensureStreakProtection': '自动开连胜保护',
    'skipNonPointTasks': '跳过不给分的任务',
    'contintueOnBotWarning': '有 bot 警告也继续',
    'autoClaimPunchcardRewards': '自动领打卡卡奖励',
    'prewarmDesktopLogin': '预热桌面登录',
    'doDailySet': '每日套装',
    'doMorePromotions': '更多推广',
    'doClaimBonusPoints': '领取奖励积分',
    'doPunchCards': '打卡卡（punch cards）',
    'doAppPromotions': 'App 推广',
    'doDesktopSearch': '桌面端搜索',
    'doMobileSearch': '移动端搜索',
    'doVisualSearch': '视觉搜索',
    'doDefaultSearchEngine': '默认搜索引擎打卡',
    'doActivateSearchPerk': '激活搜索特权',
    'doDailyCheckIn': '每日签到',
    'doReadToEarn': '阅读赚分',
    'parallelSearching': '两端并行搜索',
    'runOnZeroPoints': '没分了也跑搜索',
    'clusterSearch': '热搜做聚类扩展',
    'scrollRandomResults': '结果页随机滚动',
    'clickRandomResults': '结果页随机点进',
    'searchOnBingLocalQueries': '用本地搜索词',
  };

  static const _durLabels = {
    'accountDelay': '账号之间等待',
    'workerGap': '大任务之间等待',
    'searchDelay': '每次搜索之间',
    'readDelay': '每篇文章之间',
    'searchResultVisitTime': '结果页停留',
    'globalTimeout': '全局超时',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _busy = true; _err = null; });
    try {
      final r = await widget.panel.get('/api/config');
      final cfg = (r is Map && r['config'] is Map<String, dynamic>) ? r['config'] as Map<String, dynamic> : (r as Map<String, dynamic>);
      if (!mounted) return;
      setState(() {
        _c = Map<String, dynamic>.from(cfg);
        _dirty.clear();
        _busy = false;
      });
    } catch (e) {
      if (mounted) setState(() { _err = errText(e); _busy = false; });
    }
  }

  Future<void> _save() async {
    if (_dirty.isEmpty) return;
    setState(() { _busy = true; _err = null; });
    try {
      final body = <String, dynamic>{};
      _dirty.forEach((path, value) => setDeep(body, path, value));
      await widget.panel.patch('/api/config', body);
      if (!mounted) return;
      setState(() {
        _dirty.forEach((k, v) => setDeep(_c!, k, v));
        _dirty.clear();
        _ok = '已写入，下一轮生效';
        _busy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('参数已保存，下一轮生效')));
    } catch (e) {
      if (mounted) setState(() { _err = '保存失败：${errText(e)}'; _busy = false; });
    }
  }

  static dynamic getDeep(Map m, String path) {
    dynamic cur = m;
    for (final k in path.split('.')) {
      if (cur is Map && cur.containsKey(k)) {
        cur = cur[k];
      } else {
        return null;
      }
    }
    return cur;
  }

  static void setDeep(Map<String, dynamic> root, String path, dynamic value) {
    final parts = path.split('.');
    var cur = root;
    for (var i = 0; i < parts.length - 1; i++) {
      cur.putIfAbsent(parts[i], () => <String, dynamic>{});
      if (cur[parts[i]] is! Map) cur[parts[i]] = <String, dynamic>{};
      cur = cur[parts[i]] as Map<String, dynamic>;
    }
    cur[parts.last] = value;
  }

  void _set(String path, dynamic value) => setState(() {
        setDeep(_c!, path, value);
        _dirty[path] = value;
      });

  String labelOf(String key) => _boolLabels[key] ?? key.replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m[1]!.toLowerCase()}');

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (c == null) {
      return Scaffold(
        backgroundColor: T.canvas(context),
        appBar: AppBar(title: const Text('参数设置'), backgroundColor: T.canvas(context)),
        body: Center(child: _err != null
            ? Padding(padding: const EdgeInsets.all(T.pagePad), child: ErrorBanner(_err!, onRetry: _load))
            : const LoadingBox()),
      );
    }

    final switches = <String, List<String>>{
      '总开关': ['headless', 'debugLogs', 'ensureStreakProtection', 'skipNonPointTasks', 'contintueOnBotWarning', 'autoClaimPunchcardRewards', 'prewarmDesktopLogin'],
      '执行内容': (getDeep(c, 'workers') as Map?)?.keys.map((k) => 'workers.$k').toList() ?? [],
      '搜索策略': [
        'searchSettings.parallelSearching',
        'searchSettings.runOnZeroPoints',
        'searchSettings.clusterSearch',
        'searchSettings.scrollRandomResults',
        'searchSettings.clickRandomResults',
        'searchOnBingLocalQueries',
      ],
    };

    final delays = <String>[
      'accountDelay',
      'workerGap',
      'searchSettings.searchDelay',
      'searchSettings.readDelay',
    ];

    return Scaffold(
      backgroundColor: T.canvas(context),
      appBar: AppBar(
        title: Text(_dirty.isEmpty ? '参数设置' : '参数设置 · ${_dirty.length} 项改动'),
        backgroundColor: T.canvas(context),
        actions: [
          IconButton(onPressed: _busy ? null : _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      bottomNavigationBar: _dirty.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(T.pagePad),
                child: Row(children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _save,
                      style: FilledButton.styleFrom(backgroundColor: T.primary, shape: RoundedRectangleBorder(borderRadius: T.md), padding: const EdgeInsets.symmetric(vertical: 13)),
                      icon: const Icon(Icons.upload_rounded, size: 18),
                      label: Text('保存 ${_dirty.length} 项'),
                    ),
                  ),
                  const SizedBox(width: T.gap),
                  TextButton(onPressed: () => setState(_dirty.clear), child: const Text('放弃改动')),
                ]),
              ),
            ),
      body: ListView(
        padding: const EdgeInsets.all(T.pagePad),
        children: [
          if (_err != null) ...[ErrorBanner(_err!, onRetry: _load), const SizedBox(height: T.gap)],
          if (_ok != null && _dirty.isEmpty)
            Padding(padding: const EdgeInsets.only(bottom: T.gap), child: Text(_ok!, style: const TextStyle(fontSize: 12, color: T.green500))),
          for (final entry in switches.entries)
            if (entry.value.where((p) => getDeep(c, p) is bool).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: T.gap),
                child: PanelCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SectionTitle(entry.key),
                    ...entry.value.where((p) => getDeep(c, p) is bool).map((p) {
                      final key = p.split('.').last;
                      final on = getDeep(c, p) == true;
                      final changed = _dirty.containsKey(p);
                      return SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(
                          labelOf(key),
                          style: TextStyle(fontSize: 13, fontWeight: changed ? FontWeight.w700 : FontWeight.w400, color: changed ? T.primary : null),
                        ),
                        subtitle: Text(p, style: TextStyle(fontSize: 10, color: T.subText(context))),
                        value: on,
                        activeColor: T.primary,
                        onChanged: (v) => _set(p, v),
                      );
                    }),
                  ]),
                ),
              ),
          PanelCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SectionTitle('节奏与等待'),
              const SizedBox(height: 6),
              for (final d in delays)
                if (getDeep(c, d) is Map) _delayRow(d, getDeep(c, d) as Map),
              const SizedBox(height: 6),
              Text('格式支持 30sec / 2min / 1min30sec，也可以直接填毫秒数',
                  style: TextStyle(fontSize: 11, color: T.subText(context))),
            ]),
          ),
          const SizedBox(height: T.gap),
          PanelCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SectionTitle('搜索词来源'),
              const SizedBox(height: 8),
              Wrap(spacing: 6, children: [
                for (final e in const ['china', 'local', 'global'])
                  ChoiceChip(
                    label: Text(e, style: const TextStyle(fontSize: 11)),
                    selected: ((getDeep(c, 'searchSettings.queryEngines') as List?) ?? []).contains(e),
                    selectedColor: T.primaryLight,
                    shape: RoundedRectangleBorder(borderRadius: T.pill),
                    onSelected: (v) {
                      final cur = List<String>.from((getDeep(c, 'searchSettings.queryEngines') as List?) ?? []).toSet();
                      v ? cur.add(e) : cur.remove(e);
                      _set('searchSettings.queryEngines', cur.toList());
                    },
                  ),
              ]),
              const SizedBox(height: 10),
              _numRow('clusters', '并发账号组', c),
              const SizedBox(height: 8),
              _durRow('globalTimeout', '全局超时', c),
              const SizedBox(height: 8),
              _textRow('searchSettings.chinaApi.appkey', '国内热搜 appkey', c, secret: true),
            ]),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _delayRow(String path, Map m) {
    final name = _durLabels[path.split('.').last] ?? _durLabels[path] ?? path;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        SizedBox(width: 108, child: Text(name, style: const TextStyle(fontSize: 12))),
        Expanded(child: _miniField('$path.min', m['min'], 'min')),
        const SizedBox(width: 6),
        Expanded(child: _miniField('$path.max', m['max'], 'max')),
      ]),
    );
  }

  Widget _miniField(String path, dynamic cur, String hint) => TextField(
        key: ValueKey('$path-${_dirty.containsKey(path) ? "d" : "o"}'),
        controller: TextEditingController(text: (cur ?? '').toString()),
        onSubmitted: (v) => _set(path, v.trim()),
        onChanged: (v) {
          if ((cur ?? '').toString() != v.trim() && v.trim().isNotEmpty) {
            _dirty[path] = v.trim();
          } else {
            _dirty.remove(path);
          }
        },
        style: const TextStyle(fontSize: 12),
        decoration: InputDecoration(
          isDense: true,
          hintText: hint,
          filled: true,
          fillColor: T.surface(context),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          border: OutlineInputBorder(borderRadius: T.sm, borderSide: BorderSide(color: T.hairline(context))),
        ),
      );

  Widget _durRow(String path, String label, Map c) => Row(children: [
        SizedBox(width: 108, child: Text(label, style: const TextStyle(fontSize: 12))),
        Expanded(child: _miniField(path, getDeep(c, path), '30sec')),
      ]);

  Widget _numRow(String key, String label, Map c) => Row(children: [
        SizedBox(width: 108, child: Text(label, style: const TextStyle(fontSize: 12))),
        Expanded(
          child: TextField(
            controller: TextEditingController(text: (c[key] ?? 0).toString()),
            keyboardType: TextInputType.number,
            onSubmitted: (v) => _set(key, int.tryParse(v.trim()) ?? 0),
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: T.surface(context),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              border: OutlineInputBorder(borderRadius: T.sm, borderSide: BorderSide(color: T.hairline(context))),
            ),
          ),
        ),
      ]);

  Widget _textRow(String path, String label, Map c, {bool secret = false}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 4),
          TextField(
            controller: TextEditingController(text: (getDeep(c, path) ?? '').toString()),
            obscureText: secret,
            onSubmitted: (v) => _set(path, v.trim()),
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: T.surface(context),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              border: OutlineInputBorder(borderRadius: T.sm, borderSide: BorderSide(color: T.hairline(context))),
            ),
          ),
        ],
      );
}

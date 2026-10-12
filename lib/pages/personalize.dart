import 'package:flutter/material.dart';

import '../core/style.dart';
import '../core/tokens.dart';
import '../widgets/glass_dock.dart';
import '../widgets/ui.dart';

/// 个性化：主题色 + 底栏样式 + 动效。全部即时生效并落盘。
/// 顶部放一个真底栏当预览，改一个滑条就能在下面看到结果，不用来回切页面。
class PersonalizePage extends StatefulWidget {
  const PersonalizePage({super.key});

  @override
  State<PersonalizePage> createState() => _PersonalizePageState();
}

class _PersonalizePageState extends State<PersonalizePage> {
  int _demo = 0;

  static const _demoItems = [
    DockItem(icon: Icons.space_dashboard_outlined, activeIcon: Icons.space_dashboard_rounded, label: '主页'),
    DockItem(icon: Icons.people_outline, activeIcon: Icons.people_rounded, label: '账号'),
    DockItem(icon: Icons.terminal_outlined, activeIcon: Icons.terminal_rounded, label: '日志'),
    DockItem(icon: Icons.menu_outlined, activeIcon: Icons.menu_rounded, label: '更多'),
  ];

  StyleStore get _st => StyleStore.I;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ListenableBuilder(
      listenable: _st,
      builder: (context, _) {
        final s = _st.dock;
        return Scaffold(
          backgroundColor: T.canvas(context),
          appBar: AppBar(
            title: const Text('个性化', style: TextStyle(fontSize: 16)),
            backgroundColor: T.canvas(context),
            elevation: 0,
            scrolledUnderElevation: 0,
            actions: [
              TextButton(onPressed: () => _st.reset(), child: const Text('恢复默认')),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(T.pagePad),
            children: [
              _preview(context, dark),
              if (s.material == 0 && !Lens.ready)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('这台设备没拿到折射滤镜（Impeller 未启用或着色器加载失败），已自动退回磨砂。',
                      style: TextStyle(fontSize: 10.5, color: T.amber500)),
                ),
              const SizedBox(height: T.gap),
              _accentCard(context),
              const SizedBox(height: T.gap),
              _materialCard(context, s),
              const SizedBox(height: T.gap),
              _shapeCard(context, s),
              const SizedBox(height: T.gap),
              _motionCard(context, s),
              const SizedBox(height: T.gap + 40),
            ],
          ),
        );
      },
    );
  }

  /// 预览：底下铺一张花一点的图，模糊/折射才有东西可糊
  Widget _preview(BuildContext context, bool dark) {
    final s = _st.dock;
    return PanelCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionTitle('实时预览'),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: T.md,
          child: SizedBox(
            height: s.barHeight + 116,
            child: Stack(children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        T.primary.withValues(alpha: dark ? 0.55 : 0.35),
                        T.purple500.withValues(alpha: dark ? 0.45 : 0.28),
                        T.green500.withValues(alpha: dark ? 0.35 : 0.22),
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('把胶囊拖到右边',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                              color: dark ? Colors.white : T.slate900)),
                      const SizedBox(height: 2),
                      Text('模糊、折射、色散、按下放大都会跟着滑条变',
                          style: TextStyle(fontSize: 11,
                              color: (dark ? Colors.white : T.slate900).withValues(alpha: 0.75))),
                    ]),
                  ),
                ),
              ),
              Positioned(left: 0, right: 0, bottom: 0,
                  child: GlassDock(
                    items: _demoItems,
                    index: _demo,
                    onSelect: (i) => setState(() => _demo = i),
                  )),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _accentCard(BuildContext context) {
    final hsl = HSLColor.fromColor(_st.accent);
    return PanelCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const SectionTitle('主题色'),
          const Spacer(),
          Pill('#${_hex(_st.accent)}', color: _st.accent),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 10, runSpacing: 10, children: [
          for (final c in StyleStore.presets)
            GestureDetector(
              onTap: () => _st.setAccent(c),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: _st.accent.toARGB32() == c.toARGB32()
                          ? T.primary
                          : T.hairline(context),
                      width: _st.accent.toARGB32() == c.toARGB32() ? 3 : 1),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 4),
        _slider(context, '色相', hsl.hue / 360, (v) => _setHsv(hue: v * 360), '0° – 360°'),
        _slider(context, '饱和度', hsl.saturation, (v) => _setHsv(sat: v), ''),
        _slider(context, '明度', hsl.lightness, (v) => _setHsv(light: v), ''),
      ]),
    );
  }

  void _setHsv({double? hue, double? sat, double? light}) {
    final hsl = HSLColor.fromColor(_st.accent);
    final next = hsl
        .withHue(hue ?? hsl.hue)
        .withSaturation((sat ?? hsl.saturation).clamp(0.05, 1.0))
        .withLightness((light ?? hsl.lightness).clamp(0.25, 0.8));
    _st.setAccent(next.toColor());
  }

  String _hex(Color c) =>
      c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();

  Widget _materialCard(BuildContext context, DockStyle s) {
    return PanelCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionTitle('底栏材质'),
        const SizedBox(height: 8),
        _segment(context, ['玻璃（折射）', '磨砂', '扁平'], s.material,
            (i) => _st.tune(material: i)),
        const SizedBox(height: 4),
        Text(s.material == 0
            ? '对应 KernelSU 的 blur(4dp) + lens(24dp, 24dp)：内容被糊住的同时在边缘一圈被弯折。'
            : (s.material == 1 ? '只模糊，不折射，低端机更省。' : '不透明纯色，最省电。'),
            style: TextStyle(fontSize: 10.5, height: 1.5, color: T.subText(context))),
        _slider(context, '模糊', s.blur, (v) => _st.tune(blur: v), '0 – 40'),
        _slider(context, '折射范围', s.lensHeight, (v) => _st.tune(lensHeight: v), '0 – 60dp'),
        _slider(context, '折射强度', (s.lensAmount + 40) / 80, (v) => _st.tune(lensAmount: v * 80 - 40),
            '负数是反向弯'),
        _slider(context, '色散', s.chroma, (v) => _st.tune(chroma: v), '0 – 1'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('立体感（depthEffect）', style: TextStyle(fontSize: 13.5)),
          subtitle: Text('中心做一点微放大，读起来像厚玻璃',
              style: TextStyle(fontSize: 10.5, color: T.subText(context))),
          value: s.depth,
          activeColor: T.primary,
          onChanged: (v) => _st.tune(depth: v),
        ),
        _slider(context, '底色浓度', s.tint, (v) => _st.tune(tint: v), '0 – 1'),
      ]),
    );
  }

  Widget _shapeCard(BuildContext context, DockStyle s) {
    return PanelCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionTitle('胶囊与尺寸'),
        const SizedBox(height: 8),
        _segment(context, ['正圆', '胶囊', '圆角方'], s.pillShape, (i) => _st.tune(pillShape: i)),
        const SizedBox(height: 4),
        _slider(context, '栏高', s.barHeight, (v) => _st.tune(barHeight: v), '52 – 80dp'),
        _slider(context, '图标大小', s.iconSize, (v) => _st.tune(iconSize: v), '16 – 30'),
        _slider(context, '左右留白', s.margin, (v) => _st.tune(margin: v), '0 – 60dp'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('显示文字标签', style: TextStyle(fontSize: 13.5)),
          value: s.labels,
          activeColor: T.primary,
          onChanged: (v) => _st.tune(labels: v),
        ),
      ]),
    );
  }

  Widget _motionCard(BuildContext context, DockStyle s) {
    return PanelCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionTitle('动效'),
        const SizedBox(height: 8),
        _segment(context, ['直接切', '淡入淡出', '跟随滑动'], s.transition,
            (i) => _st.tune(transition: i)),
        const SizedBox(height: 4),
        _slider(context, '速度', (s.speed - 0.4) / 1.2, (v) => _st.tune(speed: 0.4 + v * 1.2),
            '慢 – 快（弹簧刚度跟着变）'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('切页触感', style: TextStyle(fontSize: 13.5)),
          value: s.haptics,
          activeColor: T.primary,
          onChanged: (v) => _st.tune(haptics: v),
        ),
      ]),
    );
  }

  Widget _segment(BuildContext context, List<String> labels, int cur, ValueChanged<int> onTap) {
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: GestureDetector(
              onTap: () => onTap(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: i == cur ? T.primary.withValues(alpha: 0.14) : Colors.transparent,
                  borderRadius: T.sm,
                  border: Border.all(
                      color: i == cur ? T.primary : T.hairline(context),
                      width: i == cur ? 1.4 : 1),
                ),
                child: Text(labels[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: i == cur ? FontWeight.w700 : FontWeight.w500,
                        color: i == cur ? T.primary : T.subText(context))),
              ),
            ),
          ),
      ],
    );
  }

  Widget _slider(BuildContext context, String label, double value, ValueChanged<double> onChanged,
      String hint) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(children: [
        SizedBox(
            width: 74,
            child: Text(label, style: TextStyle(fontSize: 12.5, color: T.subText(context)))),
        Expanded(
          child: Slider(
            value: value.clamp(0.0, 1.0),
            activeColor: T.primary,
            inactiveColor: T.primary.withValues(alpha: 0.18),
            onChanged: onChanged,
          ),
        ),
        if (hint.isNotEmpty)
          SizedBox(
              width: 108,
              child: Text(hint,
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 9.5, color: T.subText(context)))),
      ]),
    );
  }
}

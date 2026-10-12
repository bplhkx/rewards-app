import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../core/style.dart';
import '../core/tokens.dart';

/// 底部 dock 的一个入口。
class DockItem {
  const DockItem({required this.icon, required this.activeIcon, required this.label});
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// 折射滤镜。KernelSU 那条玻璃栏的"液体"感来自 Miuix 的 lens()，
/// Flutter 里唯一能等价做到的通道是 BackdropFilter + ImageFilter.shader（Impeller 专属）。
/// 程序全局只加载一次；加载失败或后端不支持时，上层自动退回"只模糊"的磨砂。
class Lens {
  Lens._();

  static ui.FragmentProgram? _prog;
  static bool _loading = false;

  static bool get shaderSupported => ui.ImageFilter.isShaderFilterSupported;
  static bool get ready => _prog != null && shaderSupported;

  static Future<void> warm() async {
    if (_loading || _prog != null || !shaderSupported) return;
    _loading = true;
    try {
      _prog = await ui.FragmentProgram.fromAsset('shaders/lens.frag');
    } catch (_) {
      _prog = null; // 拿不到就安静地退回磨砂
    }
  }

  /// uniform 声明顺序：u_tex(0,1 引擎写)、u_rect(2..5)、u_radius(6)、u_height(7)、
  /// u_amount(8)、u_depth(9)、u_chroma(10)、u_press(11)。
  static ui.ImageFilter? filter({
    required Rect rectPx,
    required double radiusPx,
    required double heightPx,
    required double amountPx,
    required double chroma,
    required bool depth,
    required double press,
  }) {
    final p = _prog;
    if (p == null || !shaderSupported) return null;
    final s = p.fragmentShader()
      ..setFloat(2, rectPx.left)
      ..setFloat(3, rectPx.top)
      ..setFloat(4, rectPx.width)
      ..setFloat(5, rectPx.height)
      ..setFloat(6, radiusPx)
      ..setFloat(7, heightPx)
      ..setFloat(8, amountPx)
      ..setFloat(9, depth ? 1 : 0)
      ..setFloat(10, chroma)
      ..setFloat(11, press);
    return ui.ImageFilter.shader(s);
  }
}

/// 类 KernelSU/Miuix 的悬浮玻璃底栏。参数逐条照 `FloatingBottomBar.kt` 抄：
/// · 外层 Row：height 64 / padding 4 / CircleShape / dropShadow(radius 10, 黑 .1 深色 .2)
///   drawBackdrop{ vibrancy; blur(4dp); lens(24dp, 24dp) } + BloomStroke 高光(alpha .75)
///   + surfaceContainer(0.4) + 按下按 1 + 16dp/width 整体鼓起
/// · 指示胶囊：width = tabWidth / height 56，位置 = 浮点序号 * tabWidth
///   lens(10dp*press, 14dp*press, depthEffect, chromaticAberration .5)
///   + innerShadow(8dp*press, 黑 .15) + specular(alpha = press)
///   + 底色黑 .1（深色白 .1，alpha 1-press）再叠黑 .03*press
///   按下放大 78/56，速度压扁 scaleX /= 1-clamp(v*.75)、scaleY *= 1-clamp(v*.25)
/// · 拖过两端整条面板橡皮筋最多 4dp（EaseOut），松手 spring(1, 300, .5)
/// · 条目内容 scale 到 1.2，颜色按胶囊靠近程度插值到主色
///
/// 与 KSU 的两处必要差异：
/// 1) 图标画在胶囊**上面**。KSU 把条目内容再摄进一层 layerBackdrop 让胶囊去折射，
///    Flutter 的 BackdropFilter 取不到另一层 backdrop 滤镜之下的兄弟节点，只能置顶。
/// 2) BloomStroke 的双光源高光要重力传感器，这里改成跟随拖动方向的静态双峰。
class GlassDock extends StatefulWidget {
  const GlassDock({
    super.key,
    required this.items,
    required this.index,
    required this.onSelect,
  });

  final List<DockItem> items;
  final int index;
  final ValueChanged<int> onSelect;

  /// 页面给底部留白的参考值：胶囊 + 悬浮间距 + 系统手势条。
  static double reserve(BuildContext context) {
    final inset = MediaQuery.of(context).padding.bottom;
    return StyleStore.I.dock.barHeight + 14 + (inset > 0 ? inset : 20);
  }

  @override
  State<GlassDock> createState() => _GlassDockState();
}

class _GlassDockState extends State<GlassDock> with TickerProviderStateMixin {
  static const double _stiffness = 300; // KSU: spring(dampingRatio = 1f, stiffness = 300f)
  static const double _barPad = 4; // KSU 的 padding(4.dp)

  late final AnimationController _pos; // 浮点 tab 序号
  late final AnimationController _rubber; // 面板横向位移（逻辑像素）
  late final AnimationController _press; // 0..1 按压进度
  double _tabWidth = 0;
  double _barWidth = 0;
  double _raw = 0;
  bool _dragging = false;

  DockStyle get _s => StyleStore.I.dock;
  int get _count => widget.items.length;

  @override
  void initState() {
    super.initState();
    Lens.warm().then((_) {
      if (mounted) setState(() {});
    });
    _pos = AnimationController.unbounded(vsync: this, value: widget.index.toDouble());
    _rubber = AnimationController.unbounded(vsync: this, value: 0);
    _press = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (130 / _s.speed).round()),
      reverseDuration: Duration(milliseconds: (220 / _s.speed).round()),
    );
    _raw = widget.index.toDouble();
  }

  @override
  void dispose() {
    _pos.dispose();
    _rubber.dispose();
    _press.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(GlassDock old) {
    super.didUpdateWidget(old);
    _press.duration = Duration(milliseconds: (130 / _s.speed).round());
    _press.reverseDuration = Duration(milliseconds: (220 / _s.speed).round());
    if (old.index != widget.index && (_pos.value - widget.index).abs() > 0.001) {
      _settle(widget.index.toDouble());
    }
  }

  /// damping = 2*sqrt(k*m)，速度倍率同时抬刚度与阻尼，比例不变（临界阻尼）。
  SpringDescription get _spring {
    final k = _stiffness * _s.speed;
    return SpringDescription(mass: 1, stiffness: k, damping: 2 * math.sqrt(k));
  }

  void _settle(double to) {
    _raw = to;
    _pos.animateWith(SpringSimulation(_spring, _pos.value, to, _pos.velocity));
    // 橡皮筋那根 KSU 用 spring(1f, 300f, 0.5f)（欠阻尼，会晃两下）
    _rubber.animateWith(SpringSimulation(
        SpringDescription(mass: 1, stiffness: _stiffness * _s.speed, damping: 21.21),
        _rubber.value, 0, _rubber.velocity));
  }

  void _tapAt(double x) {
    if (_tabWidth <= 0) return;
    final i = indexAt(x);
    if (i != widget.index) _select(i);
    _settle(i.toDouble());
  }

  int indexAt(double x) => (((x - _barPad) / _tabWidth).floor()).clamp(0, _count - 1);

  void _select(int i) {
    if (_s.haptics) HapticFeedback.selectionClick();
    widget.onSelect(i);
  }

  void _dragStart(double x) {
    if (_tabWidth <= 0) return;
    _dragging = true;
    _press.forward();
    final i = indexAt(x).toDouble();
    _pos.stop();
    _raw = i;
    _pos.value = i;
  }

  void _dragUpdate(double dx) {
    if (_tabWidth <= 0 || !_dragging) return;
    final next = _raw + dx / _tabWidth;
    final clamped = next.clamp(0.0, (_count - 1).toDouble());
    // 拖过两端：胶囊停住，整条面板按 EaseOut 最多挪 4dp（KSU 的 rubberBand）
    final over = next - clamped;
    _rubber.value = 4.0 * _easeOut(over.clamp(-1.0, 1.0).abs()) * over.sign;
    _raw = clamped;
    _pos.value = clamped;
  }

  void _dragEnd() {
    _press.reverse();
    if (!_dragging) return; // 点按附带的那一次"拖拽"不能改选中项
    _dragging = false;
    final target = _pos.value.round().clamp(0, _count - 1);
    if (target != widget.index) _select(target);
    _settle(target.toDouble());
  }

  /// 拖到一半被打断：弹回当前选中的那一格，不切页面
  void _dragCancel() {
    _dragging = false;
    _press.reverse();
    _settle(widget.index.toDouble());
  }

  double _easeOut(double t) => 1 - math.pow(1 - t, 3).toDouble();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final s = _s;
    final mq = MediaQuery.of(context);
    final inset = mq.padding.bottom;
    final bottom = inset > 0 ? 8.0 + inset : 28.0;
    final dpr = mq.devicePixelRatio;
    final screenH = mq.size.height;

    return Padding(
      padding: EdgeInsets.fromLTRB(s.margin, 0, s.margin, bottom),
      child: AnimatedBuilder(
        animation: Listenable.merge([_pos, _rubber, _press]),
        builder: (context, _) {
          final value = _pos.value;
          final p = _press.value;
          // KSU: pressedScale = 78/56；速度压扁 scaleX /= 1-clamp(v*.75)、scaleY *= 1-clamp(v*.25)
          final pillScale = 1 + (78 / 56 - 1) * p;
          final velocity = (_pos.velocity / 10).clamp(-0.27, 0.27).toDouble();
          final barScale = 1 + (_barWidth > 0 ? (16.0 / math.max(1, _barWidth)) * p : 0.0);
          final shift = _rubber.value;
          final geo = _geometry(screenH, bottom, barScale, shift, pillScale, value);

          return Transform.translate(
            offset: Offset(shift, 0),
            child: Transform.scale(
              scale: barScale,
              alignment: Alignment.center,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) => _tapAt(d.localPosition.dx),
                onHorizontalDragStart: (d) => _dragStart(d.localPosition.dx),
                onHorizontalDragUpdate: (d) => _dragUpdate(d.delta.dx),
                onHorizontalDragEnd: (_) => _dragEnd(),
                onHorizontalDragCancel: _dragCancel,
                child: SizedBox(
                  height: s.barHeight,
                  child: LayoutBuilder(builder: (context, box) {
                    _barWidth = box.maxWidth;
                    _tabWidth = (box.maxWidth - _barPad * 2) / _count;
                    return Stack(children: [
                      Positioned.fill(child: _bar(context, dark, geo.bar, dpr)),
                      Positioned(
                        left: _barPad + value * _tabWidth,
                        top: _barPad,
                        width: _tabWidth,
                        height: s.barHeight - _barPad * 2,
                        child: Transform.scale(
                          scale: pillScale,
                          child: Transform(
                            transform: Matrix4.identity()
                              ..scaleByDouble(
                                  1 / (1 - velocity * 0.75), 1 - velocity * 0.25, 1, 1),
                            alignment: Alignment.center,
                            child: _pill(context, dark, geo.pill, dpr, p),
                          ),
                        ),
                      ),
                      // 图标压在胶囊上面：Flutter 的 BackdropFilter 只会取到
                      // 同一层里在它之前画的内容，而胶囊自己就是一层 backdrop 滤镜，
                      // 图标画在它下面会被"滤"掉看不见。KSU 用 layerBackdrop 把那
                      // 一层再摄一遍，这里改成图标置顶 —— 视觉上仍是"图标浮在玻璃上"。
                      Positioned(
                        left: _barPad,
                        right: _barPad,
                        top: 0,
                        bottom: 0,
                        child: Row(children: [
                          for (var i = 0; i < _count; i++)
                            Expanded(child: _item(context, i, value, p, dark)),
                        ]),
                      ),
                    ]);
                  }),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 折射要按"形状在屏幕里的哪一块"来算，所以这里把两层各自的矩形反推出来：
  /// 外层 Padding(margin/bottom) + 橡皮筋位移 + 整体鼓起 + 胶囊自身放大，
  /// 全部作用在同一个中心点上。速度压扁是瞬时的，不参与（误差肉眼看不出）。
  _Geo _geometry(double screenH, double bottom, double barScale, double shift,
      double pillScale, double value) {
    final s = _s;
    final barLeft = s.margin + shift;
    final barTop = screenH - bottom - s.barHeight;
    final barCx = barLeft + _barWidth / 2;
    final barCy = barTop + s.barHeight / 2;
    final bar = Rect.fromCenter(
      center: Offset(barCx, barCy),
      width: _barWidth * barScale,
      height: s.barHeight * barScale,
    );
    final pillCx = barCx + ((barLeft + _barPad + (value + 0.5) * _tabWidth) - barCx) * barScale;
    final pillCy = barCy; // 胶囊在栏里垂直居中，鼓起后仍在中心

    final pill = Rect.fromCenter(
      center: Offset(pillCx, pillCy),
      width: _tabWidth * pillScale * barScale,
      height: (s.barHeight - _barPad * 2) * pillScale * barScale,
    );
    return _Geo(bar: bar, pill: pill);
  }

  BorderRadius get _barRadius => BorderRadius.circular(_s.barHeight / 2);

  /// 胶囊圆角半径（逻辑像素）。折射 SDF 和裁剪必须用同一个值，否则白边会错位。
  double _pillRadiusValue(double h) {
    switch (_s.pillShape) {
      case 0: // 正圆（格子比高窄时会被拉成椭圆，所以取小的那个当直径）
        return math.min(h, _tabWidth) / 2;
      case 2:
        return 16;
      default:
        return h / 2;
    }
  }

  BorderRadius _pillRadius(double h) => BorderRadius.circular(_pillRadiusValue(h));

  /// 外层玻璃：先模糊再折射 + surfaceContainer(0.4) + 双峰高光 + 外阴影
  Widget _bar(BuildContext context, bool dark, Rect rect, double dpr) {
    final s = _s;
    final glass = ClipRRect(
      borderRadius: _barRadius,
      child: _Backdrop(
        sigma: s.material == 2 ? 0 : s.blur,
        lens: s.material == 0
            ? _LensSpec(
                rect: rect,
                radius: s.barHeight / 2,
                height: s.lensHeight,
                amount: s.lensAmount,
                chroma: s.chroma,
                depth: s.depth,
                press: 1)
            : null,
        dpr: dpr,
        child: SizedBox.expand(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: _barRadius,
              // KSU: surfaceContainer.copy(0.4f)
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: dark
                    ? [
                        T.slate800.withValues(alpha: s.tint),
                        T.slate800.withValues(alpha: s.tint * 0.85),
                      ]
                    : [
                        Colors.white.withValues(alpha: s.tint),
                        Colors.white.withValues(alpha: s.tint * 0.85),
                      ],
              ),
            ),
            child: CustomPaint(painter: _RimPainter(_barRadius, alpha: 0.75)),
          ),
        ),
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: _barRadius,
        boxShadow: [
          // KSU: dropShadow(Shadow(radius = 10.dp, color = Black, alpha = .1 / .2))
          BoxShadow(
              color: Colors.black.withValues(alpha: dark ? 0.20 : 0.10),
              blurRadius: 10),
        ],
      ),
      child: glass,
    );
  }

  /// 指示胶囊：按下才开始折射（lens 10dp*press / 14dp*press + depth + 色散），
  /// 同时长出内阴影和高光；静止时只是一层薄 tint。
  Widget _pill(BuildContext context, bool dark, Rect rect, double dpr, double press) {
    final s = _s;
    final h = s.barHeight - _barPad * 2;
    final r = _pillRadius(h);
    return ClipRRect(
      borderRadius: r,
      child: _Backdrop(
        sigma: 0,
        lens: s.material == 0
            ? _LensSpec(
                rect: rect,
                radius: _pillRadiusValue(h),
                height: 10 * press, // KSU: refractionHeight = 10.dp * progress
                amount: 14 * press, // KSU: refractionAmount = 14.dp * progress
                chroma: s.chroma,
                depth: s.depth,
                press: press)
            : null,
        dpr: dpr,
        child: Stack(children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(borderRadius: r, gradient: _tint(dark, press)),
              child: CustomPaint(painter: _RimPainter(r, alpha: press)),
            ),
          ),
          // KSU: innerShadow(radius = 8.dp * press, 黑 .15, alpha = press)
          Positioned.fill(
              child: CustomPaint(painter: _InnerShadow(r, radiusPx: 8 * press))),
        ]),
      ),
    );
  }

  /// onDrawSurface：静止 = 黑 .1（深色白 .1）；按下 = 黑 .03*press
  Gradient _tint(bool dark, double press) {
    final a = 0.10 * (1 - press) + 0.03 * press;
    final base = dark ? Colors.white.withValues(alpha: a) : Colors.black.withValues(alpha: a);
    return LinearGradient(
      begin: Alignment(-press, -1),
      end: Alignment(0, 1),
      colors: [base, Color.lerp(base, Colors.white.withValues(alpha: 0.18 * press), 0.5)!],
    );
  }

  /// 条目：胶囊压过来的时候放大并染成主色（连续插值，所以拖动时颜色是"流"过去的）
  Widget _item(BuildContext context, int i, double value, double press, bool dark) {
    final s = _s;
    final proximity = (1 - (value - i).abs()).clamp(0.0, 1.0).toDouble();
    final base = dark ? Colors.white70 : T.slate500;
    final tint = Color.lerp(base, T.primary, proximity)!;
    final it = widget.items[i];
    final scale = 1 + 0.2 * proximity * math.max(press, proximity * 0.35);
    final icon = Icon(proximity > 0.5 ? it.activeIcon : it.icon, size: s.iconSize, color: tint);
    if (!s.labels) return Center(child: Transform.scale(scale: scale, child: icon));
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Transform.scale(scale: scale, child: icon),
        const SizedBox(height: 1),
        Text(
          it.label,
          maxLines: 1,
          overflow: TextOverflow.visible,
          style: TextStyle(
            fontSize: 11,
            height: 14 / 11,
            color: tint,
            fontWeight: proximity > 0.5 ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _Geo {
  const _Geo({required this.bar, required this.pill});
  final Rect bar;
  final Rect pill;
}

class _LensSpec {
  const _LensSpec({
    required this.rect,
    required this.radius,
    required this.height,
    required this.amount,
    required this.chroma,
    required this.depth,
    required this.press,
  });
  final Rect rect;
  final double radius;
  final double height;
  final double amount;
  final double chroma;
  final bool depth;
  final double press;
}

/// 一层"先模糊、再折射"的 backdrop 处理。两层 BackdropFilter 叠着写：
/// 外层负责模糊（它会把纹理区域撑开），折射放在内层并显式告诉着色器形状在
/// 屏幕里的矩形，这样折射带一定落在可见轮廓上。
class _Backdrop extends StatelessWidget {
  const _Backdrop({
    required this.sigma,
    required this.lens,
    required this.dpr,
    required this.child,
  });

  final double sigma;
  final _LensSpec? lens;
  final double dpr;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    Widget out = child;
    // 顺序很关键：模糊放里层、折射放外层。最外层那个 BackdropFilter 拿到的
    // backdrop 才是整块屏幕，u_rect（屏幕坐标）才对得上；反过来套的话，折射
    // 那层拿到的是模糊层自己带 padding 的小纹理，坐标整体错位 —— 现象就是
    // 胶囊变成一块死白。
    if (sigma > 0.05) {
      out = BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: out,
      );
    }
    final l = lens;
    if (l != null) {
      final r = l.rect;
      final f = Lens.filter(
        rectPx: Rect.fromLTWH(r.left * dpr, r.top * dpr, r.width * dpr, r.height * dpr),
        radiusPx: l.radius * dpr,
        heightPx: l.height * dpr,
        amountPx: l.amount * dpr,
        chroma: l.chroma,
        depth: l.depth,
        press: l.press,
      );
      if (f != null) out = BackdropFilter(filter: f, child: out);
    }
    return out;
  }
}

/// BloomStroke 的近似：1dp 描边 + 上下两个光斑（dualPeak）。
class _RimPainter extends CustomPainter {
  _RimPainter(this.radius, {required this.alpha});
  final BorderRadius radius;
  final double alpha;

  @override
  void paint(Canvas canvas, Size size) {
    if (alpha <= 0.001) return;
    final rrect = radius.toRRect(Offset.zero & size);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = LinearGradient(
        begin: const Alignment(0, -1),
        end: const Alignment(0, 1),
        colors: [
          Colors.white.withValues(alpha: 0.34 * alpha), // primaryLight intensity 1
          Colors.white.withValues(alpha: 0.08 * alpha),
          Colors.white.withValues(alpha: 0.20 * alpha), // secondaryLight intensity .4
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_RimPainter old) => old.alpha != alpha || old.radius != radius;
}

/// 按下时长出来的内阴影（KSU 的 innerShadow Modifier）。
class _InnerShadow extends CustomPainter {
  _InnerShadow(this.radius, {required this.radiusPx});
  final BorderRadius radius;
  final double radiusPx;

  @override
  void paint(Canvas canvas, Size size) {
    if (radiusPx <= 0.05) return;
    final rrect = radius.toRRect(Offset.zero & size);
    canvas.clipRRect(rrect);
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radiusPx * 2
        ..color = Colors.black.withValues(alpha: 0.15)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6),
    );
  }

  @override
  bool shouldRepaint(_InnerShadow old) => old.radiusPx != radiusPx || old.radius != radius;
}

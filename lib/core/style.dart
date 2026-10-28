import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 底栏与整体外观的可调参数。默认值就是 KernelSU 那套的实测值：
/// bar 高 64、内边距 4、胶囊 56、按下放大 78/56、模糊 4dp、折射 24dp。
@immutable
class DockStyle {
  const DockStyle({
    this.material = 0,
    this.blur = 16,
    this.lensHeight = 24,
    this.lensAmount = 24,
    this.chroma = 0.35,
    this.depth = true,
    this.pillShape = 1,
    this.labels = true,
    this.iconSize = 21,
    this.barHeight = 64,
    this.margin = 28,
    this.haptics = true,
    this.speed = 1,
    this.transition = 2,
    this.tint = 0.4,
  });

  /// 0 玻璃（模糊 + 折射，需要 Impeller）1 磨砂（只模糊）2 扁平（纯色不透明）
  final int material;

  /// 外层面板的模糊 sigma（逻辑像素）
  final double blur;

  /// 折射带宽度 / 位移量，单位 dp，直接对应 Miuix 的 refractionHeight / refractionAmount
  final double lensHeight;
  final double lensAmount;

  /// 色散 0..1（Miuix 胶囊那层是 0.5）
  final double chroma;

  /// 弱凸透镜：中心做一点微放大（Miuix 的 depthEffect）
  final bool depth;

  /// 0 正圆 1 胶囊（跟随格子宽）2 圆角方
  final int pillShape;

  final bool labels;
  final double iconSize;
  final double barHeight;
  final double margin;

  /// 切页时的触感反馈
  final bool haptics;

  /// 动效速度倍率：0.6 慢 → 1.6 快
  final double speed;

  /// 0 直接切 1 淡入淡出 2 跟随胶囊方向滑动
  final int transition;

  /// 玻璃底色不透明度（KSU 用 surfaceContainer 的 0.4）
  final double tint;

  DockStyle copyWith({
    int? material,
    double? blur,
    double? lensHeight,
    double? lensAmount,
    double? chroma,
    bool? depth,
    int? pillShape,
    bool? labels,
    double? iconSize,
    double? barHeight,
    double? margin,
    bool? haptics,
    double? speed,
    int? transition,
    double? tint,
  }) {
    return DockStyle(
      material: material ?? this.material,
      blur: blur ?? this.blur,
      lensHeight: lensHeight ?? this.lensHeight,
      lensAmount: lensAmount ?? this.lensAmount,
      chroma: chroma ?? this.chroma,
      depth: depth ?? this.depth,
      pillShape: pillShape ?? this.pillShape,
      labels: labels ?? this.labels,
      iconSize: iconSize ?? this.iconSize,
      barHeight: barHeight ?? this.barHeight,
      margin: margin ?? this.margin,
      haptics: haptics ?? this.haptics,
      speed: speed ?? this.speed,
      transition: transition ?? this.transition,
      tint: tint ?? this.tint,
    );
  }
}

/// 全局外观状态：主题色 + 底栏样式。改一处，底栏/图表/按钮立刻跟着变，
/// 并且落到 shared_preferences，下次冷启动还是那个样子。
class StyleStore extends ChangeNotifier {
  StyleStore._();

  static final StyleStore I = StyleStore._();

  static const List<Color> presets = [
    Color(0xFF409EFF), // 面板蓝（默认）
    Color(0xFF2563EB), // 靛蓝
    Color(0xFF0EA5E9), // 天蓝
    Color(0xFF14B8A6), // 青绿
    Color(0xFF22C55E), // 森绿
    Color(0xFFF59E0B), // 琥珀
    Color(0xFFEF4444), // 珊瑚
    Color(0xFF8B5CF6), // 紫罗兰
    Color(0xFFEC4899), // 桃红
    Color(0xFF64748B), // 石板灰
  ];

  SharedPreferences? _p;
  Color _accent = const Color(0xFF409EFF);
  DockStyle _dock = const DockStyle();

  Color get accent => _accent;
  DockStyle get dock => _dock;

  /// 主色的浅/深两档，给"选中底色""按下描边"用
  Color get accentLight => Color.lerp(_accent, Colors.white, 0.88)!;
  Color get accentDark => Color.lerp(_accent, Colors.black, 0.22)!;

  Future<void> load() async {
    _p ??= await SharedPreferences.getInstance();
    final a = _p!.getInt('st.accent');
    if (a != null) _accent = Color(a);
    double? d(String k) => _p!.containsKey(k) ? _p!.getDouble(k) : null;
    int? i(String k) => _p!.containsKey(k) ? _p!.getInt(k) : null;
    bool? b(String k) => _p!.containsKey(k) ? _p!.getBool(k) : null;
    _dock = DockStyle(
      material: i('st.material') ?? 0,
      blur: d('st.blur') ?? 16,
      lensHeight: d('st.lensHeight') ?? 24,
      lensAmount: d('st.lensAmount') ?? 24,
      chroma: d('st.chroma') ?? 0.35,
      depth: b('st.depth') ?? true,
      pillShape: i('st.pillShape') ?? 1,
      labels: b('st.labels') ?? true,
      iconSize: d('st.iconSize') ?? 21,
      barHeight: d('st.barHeight') ?? 64,
      margin: d('st.margin') ?? 28,
      haptics: b('st.haptics') ?? true,
      speed: d('st.speed') ?? 1,
      transition: i('st.transition') ?? 2,
      tint: d('st.tint') ?? 0.4,
    );
  }

  void setAccent(Color c) {
    _accent = c;
    _p?.setInt('st.accent', c.toARGB32());
    notifyListeners();
  }

  void setDock(DockStyle s) {
    _dock = s;
    final p = _p;
    if (p == null) {
      notifyListeners();
      return;
    }
    p.setInt('st.material', s.material);
    p.setDouble('st.blur', s.blur);
    p.setDouble('st.lensHeight', s.lensHeight);
    p.setDouble('st.lensAmount', s.lensAmount);
    p.setDouble('st.chroma', s.chroma);
    p.setBool('st.depth', s.depth);
    p.setInt('st.pillShape', s.pillShape);
    p.setBool('st.labels', s.labels);
    p.setDouble('st.iconSize', s.iconSize);
    p.setDouble('st.barHeight', s.barHeight);
    p.setDouble('st.margin', s.margin);
    p.setBool('st.haptics', s.haptics);
    p.setDouble('st.speed', s.speed);
    p.setInt('st.transition', s.transition);
    p.setDouble('st.tint', s.tint);
    notifyListeners();
  }

  /// 只把某个字段换掉
  void tune({
    int? material,
    double? blur,
    double? lensHeight,
    double? lensAmount,
    double? chroma,
    bool? depth,
    int? pillShape,
    bool? labels,
    double? iconSize,
    double? barHeight,
    double? margin,
    bool? haptics,
    double? speed,
    int? transition,
    double? tint,
  }) {
    setDock(_dock.copyWith(
      material: material,
      blur: blur,
      lensHeight: lensHeight,
      lensAmount: lensAmount,
      chroma: chroma,
      depth: depth,
      pillShape: pillShape,
      labels: labels,
      iconSize: iconSize,
      barHeight: barHeight,
      margin: margin,
      haptics: haptics,
      speed: speed,
      transition: transition,
      tint: tint,
    ));
  }

  void reset() {
    setAccent(const Color(0xFF409EFF));
    setDock(const DockStyle());
  }
}

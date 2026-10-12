import 'package:shared_preferences/shared_preferences.dart';

/// 只存"用户亲手填过的东西"，全部默认空 —— 不往 APK 里编 IP，也不编 token。
/// 填一个面板地址就够：其余参数都是运行时从面板拿的（面板自己持有 Control API 地址与 token）。
class Settings {
  static SharedPreferences? _p;

  static Future<void> init() async {
    _p ??= await SharedPreferences.getInstance();
  }

  /// 面板（rewards-dashboard）地址，唯一必填项。历史、状态、参数、定时、启停都从这一个入口走。
  static String get panelBase => _s('panelBase');
  static set panelBase(String v) => _p?.setString('panelBase', v.trim());

  /// 面板开了 Basic auth 才要填；手机那台按用户要求把密码关了，所以留空。
  static String get panelUser => _s('panelUser');
  static set panelUser(String v) => _p?.setString('panelUser', v.trim());

  static String get panelPass => _s('panelPass');
  static set panelPass(String v) => _p?.setString('panelPass', v);

  /// 接管视图（8891）不在面板背后，面板不知道它的存在，所以这一项只能手填；不填就没有"视图"页。
  static String get viewToken => _s('viewToken');
  static set viewToken(String v) => _p?.setString('viewToken', v.trim());

  static bool get dark => _p?.getBool('dark') ?? false;
  static set dark(bool v) => _p?.setBool('dark', v);

  /// 账号页的展示形态：0=详细·柱状图，1=详细·热力图，2=双列紧凑（一屏看四个）
  /// 旧版本存的是布尔 chartHeatmap，这里顺带迁移一次。
  static int get viewMode {
    final stored = _p?.getInt('viewMode');
    if (stored != null) return stored.clamp(0, 2);
    return (_p?.getBool('chartHeatmap') ?? false) ? 1 : 0;
  }

  static set viewMode(int v) => _p?.setInt('viewMode', v.clamp(0, 2));

  static String _s(String k) => _p?.getString(k)?.trim() ?? '';

  /// 面板地址的主机部分，视图地址就跟着它走。
  static String get host => Uri.tryParse(panelBase)?.host ?? '';

  /// 视图端口固定 8891（接管服务的默认值），主机跟随面板地址 —— 填一个 IP 不会两边跑偏。
  static String get viewBase => host.isEmpty ? '' : 'http://$host:8891';

  static bool get hasPanel => panelBase.isNotEmpty;
  static bool get hasView => viewBase.isNotEmpty && viewToken.isNotEmpty;
}

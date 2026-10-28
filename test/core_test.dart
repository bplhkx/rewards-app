// 面板字段解析与时间格式化的回归。
//
// 这里只测**与时区无关**的分支：CI runner 的本地时区是 UTC，我的手机/电脑是
// Asia/Shanghai，任何依赖 toLocal() 具体数值的断言都会在另一边假掉。
// 需要跨时区稳定的做法是：喂朴素时间串（bot 的日志格式，服务端就是北京时间、
// 不带偏移），然后要求输出等于原样解释的结果。
import 'package:flutter_test/flutter_test.dart';
import 'package:rewards_app/core/util.dart';

void main() {
  group('pick* 兜底取字段', () {
    test('pickBool 认 JSON 布尔，也认字符串和数字', () {
      // 面板把 streakProtectionEnabled 原样存成 JSON bool；早先用 pickInt 读
      // 一律得到 0，"明明开着却显示未开启"
      expect(pickBool({'on': true}, ['on']), isTrue);
      expect(pickBool({'on': 'true'}, ['on']), isTrue);
      expect(pickBool({'on': '1'}, ['on']), isTrue);
      expect(pickBool({'on': 1}, ['on']), isTrue);
      expect(pickBool({'on': false}, ['on']), isFalse);
      expect(pickBool({'on': 'false'}, ['on']), isFalse);
      expect(pickBool({'on': 0}, ['on']), isFalse);
      expect(pickBool(null, ['on'], true), isTrue);
      expect(pickBool({}, ['on'], true), isTrue);
    });

    test('pickInt 会四舍五入 double、解析字符串，缺省回 d', () {
      expect(pickInt({'n': 7}, ['n']), 7);
      expect(pickInt({'n': 7.6}, ['n']), 8);
      expect(pickInt({'n': '42'}, ['n']), 42);
      expect(pickInt({'n': 'abc'}, ['n'], 5), 5);
      expect(pickInt({}, ['n'], 3), 3);
      // 按顺序取第一个存在且非 null 的键（面板 snake/camel 两套命名）
      expect(pickInt({'a': null, 'b': 2}, ['a', 'b']), 2);
    });

    test('pickStr 对 null 用默认值，其余 toString', () {
      expect(pickStr({'s': 'x'}, ['s']), 'x');
      expect(pickStr({'s': 12}, ['s']), '12');
      expect(pickStr({}, ['s'], '--'), '--');
    });
  });

  group('时间：bot 的朴素日志时间就是北京时间，不许再加偏移', () {
    test('12 小时制正确展开，且不做时区换算', () {
      expect(logClock('10/11/2026, 3:29:07 PM'), '10-11 15:29:07');
      expect(logClock('10/11/2026, 12:05:00 AM'), '10-11 00:05:00');
      expect(logClock('10/11/2026, 12:05:00 PM'), '10-11 12:05:00');
      expect(logClock('1/5/2026, 9:00:00 AM'), '01-05 09:00:00');
    });

    test('认不出来的原样透出，不抛异常', () {
      expect(logClock('不是时间'), '不是时间');
      expect(logClock(''), '');
    });

    test('dayKey 是 YYYY-MM-DD 补零', () {
      expect(dayKey(DateTime(2026, 10, 5, 23, 59)), '2026-10-05');
      expect(two(7), '07');
    });

    test('minutes 按 1 位小数显示秒', () {
      expect(minutes(90), '1.5');
      expect(minutes(0), '0.0');
    });
  });

  group('状态与分类', () {
    test('checkinStatusLabel 覆盖面板写的所有状态，未知回退"进度"', () {
      expect(checkinStatusLabel('complete'), '已完成');
      expect(checkinStatusLabel('progress'), '进行中');
      expect(checkinStatusLabel('stalled'), '今日未计入');
      expect(checkinStatusLabel('advanced'), '今日已推进');
      expect(checkinStatusLabel('started'), '打卡中');
      expect(checkinStatusLabel(''), '进度');
      expect(checkinStatusLabel('whatever'), '进度');
    });

    test('pointBreakdown 从大到小排、跳过 0 分、未知键原样显示', () {
      final rows = pointBreakdown({'search': 60, 'read': 30, 'checkIn': 5, 'bonus': 0, 'weirdNewThing': 12});
      expect(rows.map((r) => r.key).toList(), ['search', 'read', 'weirdNewThing', 'checkIn']);
      expect(rows.first.label, '搜索');
      expect(rows[2].label, 'weirdNewThing');
      expect(pointBreakdown(null), isEmpty);
      expect(pointBreakdown({}), isEmpty);
    });
  });

  test('maskEmail 只留首字母和域名', () {
    expect(maskEmail('abcdef@outlook.com'), 'a***@outlook.com');
    expect(maskEmail('a@outlook.com'), 'a@outlook.com'); // 首字母前没东西可遮，原样
    expect(maskEmail('no-at-sign'), 'no-at-sign');
  });
}

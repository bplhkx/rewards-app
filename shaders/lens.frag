// 底栏玻璃的折射滤镜。对应 Miuix `drawBackdrop{ lens(...) }` 那一步：
// KernelSU 的 FloatingBottomBar 用了两处 ——
//   外层面板：lens(refractionHeight = 24dp, refractionAmount = 24dp)
//   指示胶囊：lens(refractionHeight = 10dp * press, refractionAmount = 14dp * press,
//                depthEffect = true, chromaticAberration = 0.5f)
// 也就是"只在边缘一圈发生弯曲、越往中间越平"，按下时胶囊才开始折射并带色散。
//
// 用法：作为 BackdropFilter 的 ImageFilter.shader（Impeller 专属）。引擎会把
// 第一个 uniform（u_tex）写成被滤纹理的尺寸，第一个 sampler2D 写成输入。
// 关键一点：backdrop 那张纹理是**整块屏幕**，不是形状本身，所以形状在屏幕里的
// 位置必须由 Dart 传进来（u_rect，设备像素、左上原点），否则圆角边缘会算飞到
// 屏幕左上角去 —— 现象就是胶囊变成一块死白。
// setFloat 索引按声明顺序数（u_tex 占 0、1）：u_rect=2..5, u_radius=6,
// u_height=7, u_amount=8, u_depth=9, u_chroma=10, u_press=11。

#include <flutter/runtime_effect.glsl>

uniform vec2 u_tex;        // 引擎写入：输入纹理尺寸（设备像素）
uniform vec4 u_rect;       // 形状在纹理里的位置：xy=左上角，zw=宽高
uniform float u_radius;    // 圆角半径
uniform float u_height;    // refractionHeight：边缘折射带宽度
uniform float u_amount;    // refractionAmount：折射位移强度（带符号=方向）
uniform float u_depth;     // depthEffect：>0.5 时中心额外做一次微放大
uniform float u_chroma;    // chromaticAberration：0..1 色散
uniform float u_press;     // 按下进度，用来抬高光/内缘

uniform sampler2D u_input;

out vec4 frag_color;

// 到"以中心为原点的圆角矩形"的带符号距离：形状内部为负，外部为正。
float sdRoundRect(vec2 p, vec2 b, float r) {
  vec2 q = abs(p) - max(b - vec2(r), vec2(0.0));
  return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

// SDF 的梯度（指向"外"）。中心差分足够平滑。
vec2 sdfGrad(vec2 p, vec2 b, float r) {
  const float e = 1.0;
  float dx = sdRoundRect(p + vec2(e, 0.0), b, r) - sdRoundRect(p - vec2(e, 0.0), b, r);
  float dy = sdRoundRect(p + vec2(0.0, e), b, r) - sdRoundRect(p - vec2(0.0, e), b, r);
  vec2 g = vec2(dx, dy);
  float l = length(g);
  return l > 1e-5 ? g / l : vec2(0.0);
}

bool inside(vec2 v, vec2 sz) {
  return all(greaterThanEqual(v, vec2(0.0))) && all(lessThanEqual(v, sz));
}

void main() {
  vec2 fc = FlutterFragCoord().xy;
  vec2 sz = max(u_rect.zw, vec2(1.0));

  // 不同后端 FlutterFragCoord 的 y 方向不一致（GLES 与 Vulkan 相反），
  // 而 u_rect 一律按左上角给。两种解释都算一遍，取"确实落在形状里"的那个。
  vec2 top = fc - u_rect.xy;
  vec2 bot = vec2(fc.x, u_tex.y - fc.y) - u_rect.xy;
  vec2 local = inside(top, sz) ? top : (inside(bot, sz) ? bot : top);

  vec2 p = (local / sz - 0.5) * sz;
  float h = max(u_height, 1.0);
  float d = sdRoundRect(p, sz * 0.5, u_radius);

  // band：边缘 0 → 往内 h 像素处到 1（形状外面一律 0）
  float band = clamp(-d / h, 0.0, 1.0);
  // smoothstep 后平方：中间尽快衰减成"平玻璃"，边缘那一圈才开始弯
  float s = band * band * (3.0 - 2.0 * band);
  float w = s * s;

  vec2 n = sdfGrad(p, sz * 0.5, u_radius);
  vec2 disp = -(n * u_amount) * w;
  if (u_depth > 0.5) {
    // 弱凸透镜：越靠边越往外扩，读起来就是"鼓起来"
    disp += p * 0.05 * w;
  }

  vec2 suv = fc / u_tex;
#ifdef IMPELLER_TARGET_OPENGLES
  suv.y = 1.0 - suv.y;
  disp.y = -disp.y;
#endif
  vec2 off = disp / u_tex;

  vec3 rgb;
  if (u_chroma > 0.001) {
    float k = u_chroma * 0.6;
    rgb = vec3(
        texture(u_input, suv + off * (1.0 + k)).r,
        texture(u_input, suv + off).g,
        texture(u_input, suv + off * (1.0 - k)).b);
  } else {
    rgb = texture(u_input, suv + off).rgb;
  }

  // 玻璃壁厚处透光少：最外侧提亮一圈、往里压暗一点，
  // 近似 Miuix depthEffect + BloomStroke 出来的那道白边。
  float rim = 1.0 - band;
  rgb += vec3(0.09 * pow(rim, 3.0) * (0.4 + 0.6 * u_press));
  rgb -= vec3(0.05 * pow(rim, 1.5) * band * band);

  frag_color = vec4(rgb, 1.0);
}

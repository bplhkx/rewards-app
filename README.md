# rewards_app

Microsoft Rewards 面板（[rewards-dashboard](https://github.com/bplhkx/rewards-dashboard)）的原生 Android 客户端，Flutter 写的。
视觉沿用呆呆面板 APP 的设计语言：主色 `#409EFF`、slate 灰阶、圆角 8/12/14/pill、五个底部页签。

## 界面一览

| 页签 | 内容 |
| --- | --- |
| 主页 | 运行状态、今日总分、近 7 天柱状、最近运行列表、开始/停止 |
| 账号 | 每个账号的积分、今日得分、连胜、连胜保护、默认搜索引擎进度；三种显示形态（柱状 / 双列紧凑 / 列表）；单跑、批量勾选、**重置登录状态** |
| 日志 | 面板转发的 bot 实时日志，级别过滤 + 自动滚动 |
| 视图 | 直连接管服务，看 bot 当前页面的实时截图 |
| 更多 | 定时任务（面板/bot 两套调度）、参数设置、个性化、深色模式、面板地址与凭据 |

**底栏**是复刻 KernelSU/Miuix 的悬浮玻璃栏：真实的 GPU 折射（`shaders/lens.frag`，Impeller `ImageFilter.shader`）+ 模糊 + 选中药丸的挤压/回弹，页面切换走同一套弹簧。个性化页可以改主题色、材质（模糊/折射强度/色散/染色）、药丸形状、图标尺寸、动效速度与切换方式，改完立即生效并存在本地。

**重置登录状态**：移动端和桌面端在 bot 的 `sessions.db` 里是两条独立登录，账号卡片的 ⋮ 菜单可以只清其中一条（或两端）。这一步只删保存的 cookie，不打卡、不搜索、不领取，不消耗任何当日额度；下一轮跑到该账号时取不到 cookie，就会用 `.env` 里的账号密码重新登录并写回新会话。bot 在跑的时候面板会返回 409，界面会提示等这一轮结束。

**参数设置里的「拟人化 · 拆成几轮做」**：总开关、当天跑成过就跳过、搜索完成度比例、每轮阅读篇数、静默时段（星期 + 起止，支持跨午夜）。写回走 `PATCH /api/config`，服务端只 deep-merge 改过的字段，下一轮生效。

**颜色约定**：同一个活动在任何地方都是同一个色（`lib/core/tokens.dart` 的 `T.act*`）——必应 App 紫、默认搜索引擎青、每日活动绿，其余进度用主色；绿/红/灰只表示状态（拿到分 / 失败 / 未记录）。

## 只连一个地址

App 只需要**面板地址**一项，`Control API` 的地址和 token 都存在面板服务端，App 里不保存任何凭据：

| 页面 | 走的面板端点 |
| --- | --- |
| 主页 | `GET /api/summary`、`POST /api/control/start` / `stop` |
| 账号 | `GET /api/accounts`、`GET /api/schedule`（下次自动运行时间）、`POST /api/control/start`（单跑传 `accountIndex`，批量传 `excludedAccountIndexes`） |
| 日志 | `GET /api/logs`（面板转发 bot 的日志） |
| 视图 | 直连接管服务 `http://<面板主机>:8891`（这一家不在面板背后，需要单独填一次视图 token） |
| 更多 | 参数设置 `GET|PATCH /api/config`；定时跑 `GET|PUT /api/schedule`，带 `target: local|remote` |
| 账号 · 重置登录 | `DELETE /api/sessions/<email>?platform=mobile|desktop|both`（面板转发 bot 的 Control API） |

定时有两套彼此独立的调度，"定时跑"页顶部可以切换：**面板**自己的调度器（到点由面板发 `/api/control/start`，带补跑策略），和 **bot** 容器里的 cron（写 Control API 的 `/schedule`）。

## 构建

```bash
flutter pub get
flutter build apk --release          # 不含任何凭据，装好后自己填面板地址
```

CI（`.github/workflows/ci.yml`）在 push/PR 时跑：`flutter analyze`（当前 0 issue，是硬门槛）、`flutter test`（`test/core_test.dart` 覆盖面板字段兜底取值和"bot 朴素日志时间就是北京时间"这条约定）、`flutter build apk --release`，并断言 `shaders/lens.frag` 真的进了 APK，最后把 APK 作为构件上传。

签名走 `android/key.properties` + `android/app/keys/*.keystore`，两者都在 `.gitignore` 里，仓库不含密钥；缺文件时 Gradle 自动退回 debug 签名。

## 注意

- 面板默认端口 `8890`，Control API `3010`，接管视图 `8891`。
- 接管视图只有在 bot 真正在跑的时候才有监听，空闲时"视图"页显示连不上是预期行为。
- Dart 的 `SocketException` 消息里的 `port` 是本地临时端口，不是目标端口——`lib/core/util.dart` 的 `errText()` 负责把它翻译成人话，新页面别直接把异常拼进 UI。

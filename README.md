# rewards_app

Microsoft Rewards 面板（[rewards-dashboard](https://github.com/bplhkx/rewards-dashboard)）的原生 Android 客户端，Flutter 写的。
视觉沿用呆呆面板 APP 的设计语言：主色 `#409EFF`、slate 灰阶、圆角 8/12/14/pill、五个底部页签。

## 只连一个地址

App 只需要**面板地址**一项，`Control API` 的地址和 token 都存在面板服务端，App 里不保存任何凭据：

| 页面 | 走的面板端点 |
| --- | --- |
| 主页 | `GET /api/summary`、`POST /api/control/start` / `stop` |
| 账号 | `GET /api/accounts`、`GET /api/schedule`（下次自动运行时间）、`POST /api/control/start`（单跑传 `accountIndex`，批量传 `excludedAccountIndexes`） |
| 日志 | `GET /api/logs`（面板转发 bot 的日志） |
| 视图 | 直连接管服务 `http://<面板主机>:8891`（这一家不在面板背后，需要单独填一次视图 token） |
| 更多 | 参数设置 `GET|PATCH /api/config`；定时跑 `GET|PUT /api/schedule`，带 `target: local|remote` |

定时有两套彼此独立的调度，"定时跑"页顶部可以切换：**面板**自己的调度器（到点由面板发 `/api/control/start`，带补跑策略），和 **bot** 容器里的 cron（写 Control API 的 `/schedule`）。

## 构建

```bash
flutter pub get
flutter build apk --release          # 不含任何凭据，装好后自己填面板地址
```

签名走 `android/key.properties` + `android/app/keys/*.keystore`，两者都在 `.gitignore` 里，仓库不含密钥；缺文件时 Gradle 自动退回 debug 签名。

## 注意

- 面板默认端口 `8890`，Control API `3010`，接管视图 `8891`。
- 接管视图只有在 bot 真正在跑的时候才有监听，空闲时"视图"页显示连不上是预期行为。
- Dart 的 `SocketException` 消息里的 `port` 是本地临时端口，不是目标端口——`lib/core/util.dart` 的 `errText()` 负责把它翻译成人话，新页面别直接把异常拼进 UI。

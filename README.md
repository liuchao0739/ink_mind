## InkMind（墨智）简介

InkMind：直译为“墨水思维”，巧妙结合了阅读与智能，暗示用户通过这款应用，不仅能畅读书海，还能获得 AI 带来的思维拓展和智慧体验。

## 多端构建说明

### 环境要求

- 已安装 Flutter，并通过 `fvm` 管理版本：
  - 鸿蒙：`custom_3.22.1`（3.22.1-ohos-1.0.7）
  - 其他端：`3.35.3` 或兼容版本

### Android 构建

```bash
cd ink_mind
fvm use custom_3.22.1
fvm flutter pub get
fvm flutter run -d android
fvm flutter build apk --release
```

### iOS 构建（需 macOS + Xcode）

```bash
cd ink_mind
fvm use custom_3.22.1
fvm flutter pub get
fvm flutter run -d ios
fvm flutter build ios --release
```

### Web 构建

```bash
cd ink_mind
fvm use custom_3.22.1
fvm flutter pub get
fvm flutter run -d chrome
fvm flutter build web --release
```

### Windows / macOS 桌面端

确保 Flutter 桌面支持已开启（`flutter config --enable-macos-desktop` / `--enable-windows-desktop`）。

```bash
cd ink_mind
fvm use custom_3.22.1
fvm flutter pub get
fvm flutter run -d macos   # 或 windows
fvm flutter build macos --release   # 或 build windows
```

### 鸿蒙（HarmonyOS）构建（示意）

> 前提：已正确安装 Flutter for HarmonyOS 的工具链，并保证 `custom_3.22.1` 指向 3.22.1-ohos-1.0.7 SDK。

```bash
cd ink_mind
fvm use custom_3.22.1
fvm flutter pub get
fvm flutter run -d ohos   # 具体设备 ID 视本机环境而定
fvm flutter build ohos --release
```

不同端共用同一套 Flutter 代码，UI 采用响应式布局；鸿蒙如遇第三方插件不兼容（如 `flutter_tts`、`file_picker`），可在对应端通过条件编译或特性开关降级关闭相关入口，以保证核心“阅读 + 书架 + 本地进度”可顺利运行。

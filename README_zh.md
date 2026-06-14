[English](https://github.com/cccmax/dot_globe/blob/main/README.md)

# DotGlobe

一个点阵风格的 3D 地球仪 Flutter 组件。拖拽旋转，支持任意 Flutter widget 作为地理位置标记，并可用大圆弧连接坐标。纯 Dart 实现，零三方依赖，九套开箱即用预设配色。

[![pub package](https://img.shields.io/pub/v/dot_globe.svg)](https://pub.dev/packages/dot_globe)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

<p align="center">
  <img src="https://raw.githubusercontent.com/cccmax/dot_globe/main/screenshots/showcase.webp" width="220" alt="点阵地球 + 标记 + 弧线"/>
</p>

## 特性

### 1. 任意 Widget 作 Marker
图片、文字、气泡——任何 Flutter widget 都可以按经纬度自动投影到球面。背面自动隐藏，边缘自动淡出，无需手写投影计算。

```dart
DotGlobe(
  markers: [
    DotGlobeMarker(
      latitude: 46, longitude: 2,
      anchor: Alignment.bottomCenter,
      child: YourBubbleWidget(),
    ),
  ],
)
```

### 2. 大圆弧连接（飞线）
用 `DotGlobeArc` 连接两个坐标，弧线鼓出球面，正面实线、转到背面自动虚线淡出。每条弧的高度（`altitude`）、颜色、粗细、虚实（`dashed` / `backDashed`）、背面透明度（`backOpacity`）都独立可调。

```dart
DotGlobe(
  radiusFactor: 0.55, // 弧线高时缩小球径：radiusFactor <= 1/(1+altitude)
  arcs: const [
    DotGlobeArc(
      startLatitude: 35.7, startLongitude: 139.7, // 东京
      endLatitude: 51.5, endLongitude: -0.1,       // 伦敦
      color: Color(0xFF4ED7F2), altitude: 0.45,
    ),
  ],
)
```

### 3. 点阵 / Halftone 风格
~6300 个采样点用 CustomPainter 自绘，视觉对标 Polymarket 世界杯地图、GitHub 首页地球、cobe.js。纯矢量，不依赖贴图。

### 4. 纯 Dart，零依赖
`import 'package:dot_globe/dot_globe.dart'` 即可使用。无需额外的原生库、Web 资源或纹理文件。

### 5. 高性能
- 旋转时零 widget rebuild（用 `RepaintNotifier` 直接驱动）
- 每帧投影 ~0.1ms（正交投影 + 背面剔除）
- Marker 用 `Flow` 做 transform-only 更新，无 relayout
- Impeller 下稳定 60fps

### 6. 完整手势 + 开箱即用
- 拖拽旋转 + 惯性滑动 + 自动复位
- 自旋（可配置或静止）
- 9 套预设配色，一行代码切换

## 安装

在 `pubspec.yaml` 中添加：

```yaml
dependencies:
  dot_globe: ^0.1.0
```

然后运行：

```bash
flutter pub get
```

## 快速开始

### 最简单的用法

```dart
import 'package:dot_globe/dot_globe.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: DotGlobe(style: DotGlobeStyle.dark),
      ),
    );
  }
}
```

就这样。一行代码，出现深蓝色的自旋地球。

### 带 Marker 的用法

```dart
DotGlobe(
  style: DotGlobeStyle.polymarket,
  markers: [
    DotGlobeMarker(
      latitude: 48.8566,
      longitude: 2.3522,
      anchor: Alignment.bottomCenter,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blue,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('Paris', style: TextStyle(color: Colors.white)),
      ),
    ),
    DotGlobeMarker(
      latitude: 35.6762,
      longitude: 139.6503,
      anchor: Alignment.bottomCenter,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('Tokyo', style: TextStyle(color: Colors.white)),
      ),
    ),
  ],
)
```

### 用 Controller 驱动旋转

```dart
class GlobeControllerExample extends StatefulWidget {
  const GlobeControllerExample({super.key});

  @override
  State<GlobeControllerExample> createState() => _GlobeControllerExampleState();
}

class _GlobeControllerExampleState extends State<GlobeControllerExample> {
  late final DotGlobeController _controller;

  @override
  void initState() {
    super.initState();
    _controller = DotGlobeController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: DotGlobe(
            controller: _controller,
            style: DotGlobeStyle.neon,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: () {
              _controller.animateTo(
                latitude: 46,
                longitude: 2,
                duration: const Duration(milliseconds: 600),
              );
            },
            child: const Text('转到法国'),
          ),
        ),
      ],
    );
  }
}
```

### 监听当前正对的坐标

```dart
_controller.addListener(() {
  final facing = _controller.facing;
  print('当前正对: 纬度 ${facing?.latitude}, 经度 ${facing?.longitude}');
});
```

## API 参考

### DotGlobe Widget

**构造函数参数：**

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `style` | `DotGlobeStyle` | `DotGlobeStyle.light` | 配色方案 |
| `markers` | `List<DotGlobeMarker>` | `[]` | 地理位置标记列表 |
| `controller` | `DotGlobeController?` | `null` | 可选的命令式控制器 |
| `radiusFactor` | `double` | `0.92` | 球径占容器短边的比例，范围 (0, 1] |
| `autoRotateSpeed` | `double` | `0.12` | 空闲时自旋速度（弧度/秒），`0` 表示静止 |
| `initialLatitude` | `double` | `18` | 初始正对纬度（度） |
| `initialLongitude` | `double` | `10` | 初始正对经度（度） |
| `maxTilt` | `double` | `0.6` | 最大俯仰偏离（弧度），范围 [0, π/2] |
| `dragSensitivity` | `double` | `1.0` | 拖拽灵敏度倍数，越大越灵敏 |
| `inertiaDecay` | `double` | `0.94` | 惯性衰减系数（每帧保留比例），范围 [0, 1) |
| `tiltReturn` | `double` | `0.92` | 俯仰复位速度（每帧保留比例），范围 [0, 1) |
| `interactive` | `bool` | `true` | 是否响应手势拖拽 |
| `paused` | `bool` | `false` | 暂停旋转（省电模式，配合可见性检测器使用） |

### DotGlobeMarker

**构造函数参数：**

| 参数 | 类型 | 说明 |
|------|------|------|
| `latitude` | `double` | 纬度（度），北为正 |
| `longitude` | `double` | 经度（度），东为正 |
| `child` | `Widget` | 在该位置显示的 widget（背面自动隐藏，边缘自动淡出） |
| `anchor` | `Alignment` | child 的对齐点，使用 `Alignment.bottomCenter` 让气泡尖端指向该点 |

### DotGlobeStyle

**预设：** `light`、`dark`、`polymarket`、`neon`、`sunset`、`mono`、`emerald`、`pastel`、`midnight`

**字段：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `dotColor` | `Color` | 陆地点的颜色（必填）。当 `depthFade > 0` 时，远处的点会自动变暗 |
| `sphereColor` | `Color` | 球体基色（必填）。通常使用半透明颜色 |
| `glowColor` | `Color?` | 轮廓发光色（可选），`null` 禁用。深背景下效果最好 |
| `sphereLight` | `bool` | `true` 打光（径向渐变，模拟左上光源），`false` 平涂 |
| `depthFade` | `double` | 纵深感强度 [0, 1]。`1` 表示强烈的纵深（Polymarket 风格），`0` 所有可见点等亮 |
| `dotRadius` | `double` | 点的半径（逻辑像素）。在球心处测量 |
| `backgroundColor` | `Color?` | 组件背景色（可选）。`null` 保持透明 |

**创建自定义样式：**

```dart
const customStyle = DotGlobeStyle(
  dotColor: Color(0xFF00FF00),
  sphereColor: Color(0x4D000000),
  glowColor: Color(0xFF00FF00),
  sphereLight: true,
  depthFade: 0.7,
  dotRadius: 1.8,
  backgroundColor: Color(0xFF1A1A1A),
);

DotGlobe(style: customStyle)
```

**修改预设：**

```dart
DotGlobe(
  style: DotGlobeStyle.dark.copyWith(dotRadius: 2.0),
)
```

**遍历所有预设：**

```dart
DotGlobeStyle.presets.forEach((name, style) {
  print('$name: $style');
});
```

### DotGlobeController

用于从 widget 树外部驱动地球旋转，或监听当前正对的坐标。

**属性：**

| 属性 | 类型 | 说明 |
|------|------|------|
| `facing` | `DotGlobeFacing?` | 当前正对的坐标（纬度/经度），未附加时为 `null` |
| `isAttached` | `bool` | 是否已附加到一个已挂载的 `DotGlobe` |

**方法：**

```dart
// 平滑旋转到指定坐标
Future<void> animateTo({
  double? latitude,     // 目标纬度（可选，不指定则保持当前）
  double? longitude,    // 目标经度（可选，不指定则保持当前）
  Duration duration = const Duration(milliseconds: 600),
  Curve curve = Curves.easeInOutCubic,
}) async { ... }

// 立即跳转到指定坐标（无动画）
void jumpTo({
  double? latitude,
  double? longitude,
})

// 添加监听器，每帧旋转时被调用
void addListener(VoidCallback listener)

// 移除监听器
void removeListener(VoidCallback listener)

// 销毁控制器
@override
void dispose()
```

**使用示例：**

```dart
final controller = DotGlobeController();

// 附加到 globe
DotGlobe(controller: controller);

// 监听
controller.addListener(() {
  print('Now facing: ${controller.facing}');
});

// 旋转
await controller.animateTo(latitude: -23.5, longitude: -46.6);

// 清理
@override
void dispose() {
  controller.dispose();
  super.dispose();
}
```

### DotGlobeFacing

表示当前正对的地理坐标。

**属性：**

| 属性 | 类型 | 说明 |
|------|------|------|
| `latitude` | `double` | 纬度（度），北为正 |
| `longitude` | `double` | 经度（度），东为正，范围 [-180, 180] |

## 预设配色库

### light
浅蓝色点，平涂，轻微发光。适合浅色应用背景。

```dart
DotGlobe(style: DotGlobeStyle.light)
```

### dark
深蓝色发光点，浓重背景。适合深色应用（应用基准预设）。

```dart
DotGlobe(style: DotGlobeStyle.dark)
```

### polymarket
3D 打光的深蓝地球，强纵深感。对标 Polymarket 世界杯地图。

```dart
DotGlobe(style: DotGlobeStyle.polymarket)
```

### neon
青绿色点，洋红发光。Web3 / Dashboard 风格。

```dart
DotGlobe(style: DotGlobeStyle.neon)
```

### sunset
琥珀色点，燃烧的球体，打光。温暖、品牌向。

```dart
DotGlobe(style: DotGlobeStyle.sunset)
```

### mono
白色点，纯黑背景，无发光。极简、高级。

```dart
DotGlobe(style: DotGlobeStyle.mono)
```

### emerald
绿松石点，翠绿打光球体。有机、地理风。

```dart
DotGlobe(style: DotGlobeStyle.emerald)
```

### pastel
玫红点，奶油薰衣草背景，平涂，无发光。可爱、浅色背景。

```dart
DotGlobe(style: DotGlobeStyle.pastel)
```

### midnight
冷色偏白点，淡蓝发光，平涂。比 `dark` 更低调。

```dart
DotGlobe(style: DotGlobeStyle.midnight)
```

## 工作原理

### 几何数据
使用 Fibonacci 球面均匀采样 + Natural Earth 110m 陆地多边形离线过滤，得到 ~6300 个陆地点（二进制格式，每个点 4 字节，总计 ~25KB）。数据在应用首次加载时异步读入。

### 渲染流程
1. **Canvas 层**：CustomPainter 用正交投影将球坐标投影到屏幕，按深度分组（背面剔除 + 纵深淡出）
2. **单批绘制**：所有陆地点在一次 `drawRawPoints()` 调用中绘制，避免多次 Canvas 命令提交
3. **Marker 层**：每个 `DotGlobeMarker` 用 `Flow` widget 包裹，每帧更新其 transform，无需 relayout

### 交互
- **拖拽**：手指速度映射到球的角速度，使用 `Ticker` 逐帧更新
- **惯性**：速度每帧乘以衰减系数（默认 0.94），逐渐减速
- **俯仰复位**：偏离初始纬度的角度每帧乘以复位系数（默认 0.92），平滑回到初始位置
- **自旋**：空闲时以恒定角速度（默认 0.12 rad/s）旋转，可配置或关闭

## 平台支持

| 平台 | 支持 |
|------|------|
| iOS | ✅ |
| Android | ✅ |
| macOS | ✅ |
| Windows | ✅ |
| Linux | ✅ |
| Web | ✅ |

## FAQ

**Q: 为什么我的 marker 在某些角度消失了？**
A: Marker 在球的背面会自动隐藏。这是设计特性，防止穿透球体。如果需要始终可见，可改用 marker 下方的图层或改变 widget 层级。

**Q: 如何禁用自动旋转？**
A: 设置 `autoRotateSpeed: 0`。

**Q: 如何禁用拖拽？**
A: 设置 `interactive: false`。

**Q: 如何让多个 marker 同时闪烁或有动画？**
A: Marker 的 `child` 是普通 widget，可包含任何 animation（`AnimationController`、`Lottie` 等）。

**Q: 性能如何？会卡吗？**
A: 
- 在主流设备上稳定 60fps（Impeller 开启）
- 投影 ~0.1ms/帧
- Marker 更新只做 transform，无 relayout
- 如果有性能问题，尝试减少 marker 数量或降低 `dotRadius`

**Q: 我可以自定义球的形状或投影方式吗？**
A: 暂不支持。当前固定为球体 + 正交投影。如有特殊需求，欢迎提 issue。

**Q: 如何在 marker 上响应点击事件？**
A: Marker 的 `child` 可以包含 `GestureDetector` 或 `InkWell`，正常工作。

```dart
DotGlobeMarker(
  latitude: 46, longitude: 2,
  child: GestureDetector(
    onTap: () => print('点击了'),
    child: YourWidget(),
  ),
)
```

**Q: 如何在 PageView / Tab 中优化性能？**
A: 使用 `paused: true` 配合可见性检测（VisibilityDetector），在离屏时停止帧循环。

```dart
VisibilityDetector(
  key: const Key('globe'),
  onVisibilityChanged: (visibility) {
    setState(() {
      _isVisible = visibility.visibleFraction > 0.5;
    });
  },
  child: DotGlobe(
    paused: !_isVisible,
    // ...
  ),
)
```

## 许可证

MIT License © 2026 cccmax

详见 [LICENSE](LICENSE) 文件。

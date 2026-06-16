[English](https://github.com/cccmax/dot_globe/blob/main/README.md)

# DotGlobe

一个点阵风格的 3D 地球仪 Flutter 组件。拖拽旋转，支持任意 Flutter widget 作为地理位置标记，并可用大圆弧连接坐标。纯 Dart 实现，零三方依赖，九套开箱即用预设配色。

[![pub package](https://img.shields.io/pub/v/dot_globe.svg)](https://pub.dev/packages/dot_globe)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

<p align="center">
  <img src="https://raw.githubusercontent.com/cccmax/dot_globe/main/screenshots/showcase.webp" width="220" alt="点阵地球 + 标记 + 弧线"/>
</p>
<p align="center">
  <img src="https://raw.githubusercontent.com/cccmax/dot_globe/main/screenshots/natural.webp" width="150" alt="自然色卫星地球"/>
  <img src="https://raw.githubusercontent.com/cccmax/dot_globe/main/screenshots/fantasy.webp" width="150" alt="程序化幻想星球"/>
  <img src="https://raw.githubusercontent.com/cccmax/dot_globe/main/screenshots/heatmap_turbo.webp" width="150" alt="每点数据热力图"/>
  <img src="https://raw.githubusercontent.com/cccmax/dot_globe/main/screenshots/neon.webp" width="150" alt="霓虹点阵地球"/>
  <img src="https://raw.githubusercontent.com/cccmax/dot_globe/main/screenshots/world_cup.webp" width="150" alt="世界杯赔率气泡"/>
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
- 拖拽旋转 + 双指捏合缩放 + 惯性滑动 + 自动复位
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

## 缩放与飞行定位

### 手势缩放

双指捏合即可缩放地球（单指拖拽始终用于旋转）。缩放范围由 `minScale` 和 `maxScale` 控制，默认为 1×–6×。缩放后单指拖拽的旋转幅度会按比例缩小，保持自然手感。

```dart
DotGlobe(
  controller: controller,
  minScale: 1.0,   // 不允许缩小到自然尺寸以下（默认）
  maxScale: 4.0,   // 最多放大 4 倍
  zoomGesture: true,             // 开启捏合缩放（默认）
  clipBehavior: Clip.hardEdge,   // 放大后裁剪到容器内
  markersScaleWithZoom: true,    // 标记随地球同步放大（默认）
)
```

### 程序化缩放与飞行定位

```dart
// 飞到东京并放大 2.4 倍，一次动画完成，并停留在那里：
controller.animateTo(latitude: 35.7, longitude: 139.7, scale: 2.4, hold: true);

controller.zoomTo(1);     // 缓动恢复自然大小，保持当前朝向
controller.resetView();   // 恢复初始朝向和缩放（initialLatitude/Longitude/Scale）
```

默认情况下，移动到达后会恢复自动旋转（且 pitch 缓回 `initialLatitude`）。传入 `hold: true` 则**停泊**在目标位置——自动旋转和 pitch 回弹都关闭，直到下一次拖拽或程序化调用，目标点保持居中。`hold` 在 `animateTo`、`zoomTo`、`jumpTo` 上均可用。

`animateTo` 和 `zoomTo` 均支持可选的 `duration` 和 `curve` 参数（默认 600 ms、`Curves.easeInOutCubic`），返回 `Future<void>`，动画完成时 resolve。

如需无动画瞬移：

```dart
controller.jumpTo(latitude: 35.7, longitude: 139.7, scale: 2.4);
```

通过 `controller.scale` 读取当前缩放倍数（未附加时返回 `null`）。

### 标记的缩放行为

默认情况下（`markersScaleWithZoom: true`），所有标记随地球同步放大。可逐个标记覆盖：

```dart
DotGlobeMarker(
  latitude: 35.7, longitude: 139.7,
  scaleWithZoom: false,   // 保持固定屏幕大小，同时跟随缩放后的位置移动
  child: const Icon(Icons.location_pin, color: Colors.red),
)
```

`scaleWithZoom: null`（默认）继承 `DotGlobe.markersScaleWithZoom` 的设置。无论哪种模式，标记都会跟踪正确的缩放后屏幕坐标。

---

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
| `initialScale` | `double` | `1.0` | 初始缩放倍数，同时是 `resetView` 的目标值。必须在 `[minScale, maxScale]` 范围内。 |
| `minScale` | `double` | `1.0` | 缩放下限（手势和程序化均受限）。必须 `> 0`。 |
| `maxScale` | `double` | `6.0` | 缩放上限。设为与 `minScale` 相等可完全禁用缩放。 |
| `zoomGesture` | `bool` | `true` | 是否启用双指捏合缩放。单指旋转不受影响。 |
| `clipBehavior` | `Clip` | `Clip.none` | 放大后的裁剪方式。`Clip.hardEdge` 将放大的地球裁剪在容器内；`Clip.none`（默认）允许溢出。 |
| `markersScaleWithZoom` | `bool` | `true` | 标记是否随缩放放大的全局默认值。每个 `DotGlobeMarker` 可通过 `scaleWithZoom` 单独覆盖。 |

### DotGlobeMarker

**构造函数参数：**

| 参数 | 类型 | 说明 |
|------|------|------|
| `latitude` | `double` | 纬度（度），北为正 |
| `longitude` | `double` | 经度（度），东为正 |
| `child` | `Widget` | 在该位置显示的 widget（背面自动隐藏，边缘自动淡出） |
| `anchor` | `Alignment` | child 的对齐点，使用 `Alignment.bottomCenter` 让气泡尖端指向该点 |
| `scaleWithZoom` | `bool?` | 该标记是否随缩放放大。`null`（默认）继承 `DotGlobe.markersScaleWithZoom`；`false` = 保持固定屏幕大小（清晰），同时跟随缩放后的位置；`true` = 随地球同步放大。 |

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

用于从 widget 树外部驱动地球旋转/缩放，或监听当前正对的坐标。

**属性：**

| 属性 | 类型 | 说明 |
|------|------|------|
| `facing` | `DotGlobeFacing?` | 当前正对的坐标（纬度/经度），未附加时为 `null` |
| `scale` | `double?` | 当前缩放倍数（`1.0` 为自然大小），未附加时为 `null` |
| `isAttached` | `bool` | 是否已附加到一个已挂载的 `DotGlobe` |

**方法：**

```dart
// 平滑旋转到指定坐标，并可同时缩放
Future<void> animateTo({
  double? latitude,     // 目标纬度（可选，不指定则保持当前）
  double? longitude,    // 目标经度（可选，不指定则保持当前）
  double? scale,        // 目标缩放倍数（可选，不指定则保持当前）
  bool hold = false,    // true=到达后停泊；false（默认）=恢复自动旋转
  Duration duration = const Duration(milliseconds: 600),
  Curve curve = Curves.easeInOutCubic,
}) async { ... }

// 平滑缩放到指定倍数，保持当前朝向
Future<void> zoomTo(
  double scale, {
  bool hold = false,    // true=到达后停泊
  Duration duration = const Duration(milliseconds: 600),
  Curve curve = Curves.easeInOutCubic,
}) async { ... }

// 恢复初始朝向和缩放（initialLatitude / initialLongitude / initialScale），并恢复自动旋转
Future<void> resetView({
  Duration duration = const Duration(milliseconds: 600),
  Curve curve = Curves.easeInOutCubic,
}) async { ... }

// 立即跳转到指定坐标和/或缩放（无动画）
void jumpTo({
  double? latitude,
  double? longitude,
  double? scale,
  bool hold = false,    // true=停泊在此
})

// 添加监听器，每帧旋转/缩放时被调用
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

## 逐点颜色与纹理贴图

每个点都可以携带独立的颜色——来源可以是等距柱状卫星图、数据热力图、天气/云层叠加层，或自定义规则。颜色通过**不可变填充器**添加：每个填充器返回一个新的 `DotGlobeGeometry`，与原始点云共享坐标，并附加一个 `Int32List colors`（每个点一个 ARGB-8888 整数）。未调用任何填充器时，渲染结果与原有单色快速路径完全一致。

### 热力图 / 数据标量

将每个点的 `List<double>` 通过颜色映射表映射为颜色：

```dart
final g = base.colorizeByValues(
  values,                       // 每个点一个 double；length == pointCount
  colormap: DotGlobeColormap.turbo,
  // min / max 默认取数据范围；hideBelow 隐藏低于阈值的点
  hideBelow: 0.1,
);
DotGlobe(geometry: g, style: DotGlobeStyle.dark)
```

### 卫星图 / 等距柱状图（一行代码）

任何等距柱状（Plate Carrée）图像——经度 −180…180 横跨宽度、纬度 90…−90 从上到下——都可以覆盖到地球上：

```dart
// AssetImage、NetworkImage 或任意 ImageProvider
final g = await base.colorizedFromImageProvider(
  const AssetImage('assets/earth.jpg'),
);
DotGlobe(geometry: g, style: DotGlobeStyle.dark)
```

像素透明度低于 `hideBelowAlpha`（默认 `0.0`）的点会被隐藏，因此图像的透明区域会自动"塑形"点云轮廓。适用于卫星图、云覆盖图或任何带遮罩的纹理。

### 天气/云层帧或 `ui.Image`

当你已有解码好的 `ui.Image`（例如视频帧或程序生成的纹理）时，直接传入：

```dart
import 'dart:ui' as ui;

final ui.Image uiImage = /* 解码或捕获你的图像 */;
final g = await base.colorizeFromImage(
  uiImage,
  hideBelowAlpha: 0.1,  // 隐藏近透明像素
  wrapLongitude: true,  // 经度方向无缝循环（默认）
);
```

采样公式：`u = lng / 360 + 0.5`，`v = 0.5 - lat / 180`（标准 Plate Carrée 映射）。纬度方向始终夹紧；经度方向在 `wrapLongitude` 为 true 时循环。

### 按规则着色

对每个点的纬度、经度和索引应用任意函数：

```dart
final g = base.colorize((lat, lng, i) {
  // 返回任意 ARGB-8888 打包整数；alpha 为 0 表示隐藏该点
  final t = (lat + 90) / 180; // 北极 = 1，南极 = 0
  return Color.lerp(Colors.blue, Colors.orange, t)!.toARGB32();
});
```

### 显式逐点 ARGB 列表

直接传入预构建的 `Int32List`（每个点一个 ARGB-8888 整数，`length == pointCount`）：

```dart
final g = base.withColors(int32ArgbList);
```

### `DotGlobeColormap`

轻量不可变颜色映射表，覆盖 `[0, 1]` 区间，在均匀分布的色标颜色之间线性插值。

```dart
// 内置预设
DotGlobeColormap.viridis   // 感知均匀蓝→绿→黄
DotGlobeColormap.turbo     // 高对比彩虹（Google turbo）
DotGlobeColormap.heat      // 黑→红→橙→黄→白
DotGlobeColormap.grayscale // 黑→白
DotGlobeColormap.cool      // 蓝→青→白

// 自定义渐变（任意数量色标）
final ramp = DotGlobeColormap.gradient([Colors.navy, Colors.cyan, Colors.white]);
// 等效写法：
final ramp = DotGlobeColormap([Colors.navy, Colors.cyan, Colors.white]);

// 取值
final color = ramp.at(0.5);        // 返回 Color
final argb  = ramp.argbAt(0.5);    // 返回 ARGB-8888 打包整数
```

### 注意事项

- ARGB alpha 为 `0` 的点**被隐藏**，不会绘制任何像素。图像的透明区域或数据阈值可以直接"塑形"点云，无需修改几何数据。
- 图像**必须是等距柱状投影**（Plate Carrée）。标准卫星图（如 Blue Marble、Natural Earth 栅格）已是此投影。
- 典型用途：将卫星图叠加到陆地点云、按国家或地区显示数据热力图、逐帧更新天气/云层动画。
- **渲染路径**：携带逐点颜色的几何体通过 `drawRawAtlas` 渲染（每个深度段一次批量调用，帧内零分配）。单色默认路径保留原有的 `drawRawPoints` 快速通道。

---

## 自定义点云数据

> **相关类：** `DotGlobeGeometry` — 点云数据（单位向量 + 可选的逐点颜色），提供四个构造函数（`fromLatLng` / `fromAsset` / `fromPackedInt16` / `fromUnitVectors`）和五个颜色填充器（`withColors` / `colorize` / `colorizeByValues` / `colorizeFromImage` / `colorizedFromImageProvider`）。`DotGlobeColormap` — 不可变颜色映射表，内置五个预设（`viridis`、`turbo`、`heat`、`grayscale`、`cool`）及 `gradient` 工厂构造。详见上方[逐点颜色与纹理贴图](#逐点颜色与纹理贴图)章节。

### 内置数据源

包内 `assets/land_dots.bin` 包含 **6,363 个点**（约 25 KB），由
[Natural Earth](https://www.naturalearthdata.com/) 110m 精度陆地多边形（公共领域）
离线生成。候选点通过 **Fibonacci 球面采样**（黄金角，均匀面积分布，无极点聚集）生成，
再逐一与陆地多边形做包含测试，只保留落在陆地上的点。所有 Flutter
目标平台均为小端序，文件可直接读取，无需字节翻转。

### 二进制格式（`assets/land_dots.bin`）

| 字段 | 类型 | 字节数 | 说明 |
|---|---|---|---|
| 纬度 | `int16` LE | 2 | `round(lat × 100)`，北为正，范围 −9000…9000 |
| 经度 | `int16` LE | 2 | `round(lng × 100)`，东为正，范围 −18000…18000 |

- **每点 4 字节**，无文件头，无文件尾。
- 量化精度：0.01° ≈ 赤道处 1.1 km。
- 解码实现：`lib/src/dot_globe_geometry.dart`（`fromPackedInt16`）。

### 使用自定义点云

将 `DotGlobeGeometry` 传给 `geometry:` 参数即可。默认值 `null` 使用内置地球数据。

> Marker 和弧线按经纬度定位，因此只要点云通过 `fromLatLng`、`fromPackedInt16` 或
> `fromAsset` 构建（三者均自动应用标准轴约定），标记就能正确对齐。若直接使用
> `fromUnitVectors`，调用方自行负责轴约定。

**从经纬度列表构建（内存）：**

```dart
final geometry = DotGlobeGeometry.fromLatLng([
  (latitude: 48.85, longitude: 2.35),   // 巴黎
  (latitude: 35.68, longitude: 139.69), // 东京
  (latitude: 40.71, longitude: -74.01), // 纽约
]);

DotGlobe(geometry: geometry, style: DotGlobeStyle.dark)
```

**从自定义 `.bin` 资源文件加载（与内置格式相同）：**

```dart
// pubspec.yaml: assets: [assets/my_dots.bin]
final geometry = await DotGlobeGeometry.fromAsset('assets/my_dots.bin');

DotGlobe(geometry: geometry, style: DotGlobeStyle.neon)
```

#### `DotGlobeGeometry` 全部构造函数

| 构造函数 | 输入 | 说明 |
|---|---|---|
| `fromLatLng(List<({double latitude, double longitude})>)` | 经纬度（度） | 自动应用标准轴约定；列表为空时抛 `ArgumentError`。 |
| `fromPackedInt16(ByteData)` | 原始 `.bin` 字节 | 字节数不是 4 的倍数或为空时抛 `FormatException`。 |
| `static Future fromAsset(String assetKey, {AssetBundle?})` | 资源路径 | 资源缺失或格式错误时抛含资源键名的 `Exception`。 |
| `fromUnitVectors(Float32List)` | 平坦 `[x,y,z,…]` 缓冲区 | 高级用法；调用方自行负责轴约定（`x = -cosLat·cosLng`，`y = sinLat`，`z = cosLat·sinLng`）；为空或长度不是 3 的倍数时抛 `ArgumentError`。 |

### 重新生成内置 `.bin`（使用自己的数据）

仓库中附带 Python 生成器 **`tool/gen_land_dots.py`**（需要 Python 3 + shapely；numpy
可选，可加速 Fibonacci 数学运算）。

**第一步 — 安装依赖并下载 GeoJSON：**

```bash
pip install shapely
curl -L -o ne_110m_land.geojson \
  https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_110m_land.geojson
```

**第二步 — 生成：**

```bash
python3 tool/gen_land_dots.py --geojson ne_110m_land.geojson --samples 60000
```

默认输出到 `assets/land_dots.bin`。

**命令行参数：**

| 参数 | 默认值 | 说明 |
|---|---|---|
| `--geojson PATH` | 自动检测 | Natural Earth 陆地 GeoJSON 文件路径。省略时在脚本目录和当前目录查找 `ne_<resolution>_land.geojson`。 |
| `--resolution {110m,50m,10m}` | `110m` | 省略 `--geojson` 时自动检测所用精度。 |
| `--samples N` | `60000` | Fibonacci 球面候选点数；值越大，海岸线越密集。 |
| `--out PATH` | `assets/land_dots.bin` | 二进制资源输出路径。 |
| `--quiet` | 关 | 静默模式，只输出错误。 |

**更高精度变体**（海岸线更清晰，文件更大，生成更慢）：

```bash
# 50m — 更精细
curl -L -o ne_50m_land.geojson \
  https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_50m_land.geojson
python3 tool/gen_land_dots.py --geojson ne_50m_land.geojson --resolution 50m --samples 120000

# 10m — 最高精度
curl -L -o ne_10m_land.geojson \
  https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_10m_land.geojson
python3 tool/gen_land_dots.py --geojson ne_10m_land.geojson --resolution 10m --samples 200000
```

Natural Earth GeoJSON 镜像（公共领域，无需署名）：

- 110m（约 200 KB）：https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_110m_land.geojson
- 50m（约 600 KB）：https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_50m_land.geojson
- 10m（约 3.5 MB）：https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_10m_land.geojson

---

## 工作原理

### 几何数据
使用 Fibonacci 球面均匀采样 + Natural Earth 110m 陆地多边形离线过滤，得到 ~6300 个陆地点（二进制格式，每个点 4 字节，总计 ~25KB）。数据在应用首次加载时异步读入。

### 渲染流程
1. **Canvas 层**：CustomPainter 用正交投影将球坐标投影到屏幕，按深度分组（背面剔除 + 纵深淡出）
2. **单批绘制**：所有陆地点每个深度段一次批量调用绘制——单色模式用 `drawRawPoints()`，逐点颜色模式用 `drawRawAtlas()`——避免多次 Canvas 命令提交，两种路径均无帧内额外分配
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
A: 投影方式固定为球体 + 正交投影。但点云数据可以完全自定义——通过 `DotGlobe(geometry:)` 传入 `DotGlobeGeometry`，支持从经纬度列表（`fromLatLng`）、自定义 `.bin` 资源（`fromAsset`）或原始字节（`fromPackedInt16`）构建。详见[自定义点云数据](#自定义点云数据)章节。

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

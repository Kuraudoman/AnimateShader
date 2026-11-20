# AnimateShader (星穹幻光)

**AnimateShader** 是一款面向 **Minecraft 26.3 (NeoForge / Fabric + Iris 1.11.7)** 打造的**二次元奇幻风格**光影包（同时兼容 Iris 与 OptiFine 渲染管线）。灵感源自新海诚动画电影与日系奇幻 RPG 美术，着重于**绚丽光效、通透丰富的色彩表达、全时段亮度平衡与明亮梦幻的星夜氛围**。

---

## 核心视觉特色

- **二次元色彩表达与四大主题预设 (`COLOR_PALETTE`)**
  - **新海诚星穹 (Shinkai Azure)**：澄澈蔚蓝高空、金桃暖阳、玫粉紫罗兰晚霞、绚丽星河极光夜。
  - **樱花幻境 (Sakura Fantasy)**：柔和粉樱天际、梦幻紫霞、温柔蔷薇金光。
  - **翠林物语 (Emerald Ghibli)**：夏日晴空青翠、蜂蜜暖阳、碧蓝月夜。
  - **暮光星海 (Ethereal Violet)**：幻紫青空、星尘霞光、秘境紫青夜色。
  - **动漫冷暖阴影偏移**：阴影告别死灰脏暗，自动注入澄澈天青 / 薰衣草紫环境补光。
  - **动漫明暗风格可选**：支持「柔和奇幻」「动漫柔阶」「鲜明赛璐璐」三种受光过渡风格，并配备逆光轮廓高光（Rim Light）与树叶/樱花透光次表面散射（SSS）。
- **亮度平衡 & 夜晚绝不发黑**
  - **自适应亮度均衡**：白昼高光丝滑柔和防过曝；夜晚采用明亮银青月光 + 薰衣草星夜环境补光 + 独立「夜晚亮度 (`NIGHT_BRIGHTNESS`，默认 `1.35`)」滑块，户外建筑、草地与山川在无火把时也清晰通透、色彩饱满。
  - **洞穴与室内保底照度 (`CAVE_BRIGHTNESS`)**：深处探险拥有柔和蓝紫氛围底光，兼顾沉浸感与可见度。
  - **动漫保色电影色调映射**：保留高亮度下的天空蓝、晚霞粉、紫水晶与翡翠绿纯度，避免画面发白发灰。
- **绚丽二次元光效**
  - **多尺度梦幻柔光辉光 (HDR Bloom)** + **电影级横向星芒拉丝 (Anamorphic Streak)**。
  - **丁达尔体积光束 (Godrays)**（阳光与月光双支持）+ **太阳/满月梦幻彩虹光晕与虚化光斑**。
  - **分类彩色自发光**：火把/灯笼暖金、灵魂火/幽匿秘青、海晶灯/发光浆果碧蓝、紫水晶/哭泣黑曜石幻紫、红石绯红、末地烛/信标星白，按纹理像素精准触发，细节锐利。
  - **彩色玻璃透射光影**（透过染色玻璃在地面投射彩色光斑）+ **动态主/副手持光源**。
- **奇幻天空、星夜与水晶水体**
  - **新海诚多层立体云层**（带银边/金边逆光与柔紫云底）+ 高空卷云。
  - **梦幻星夜奇观**：多色闪烁繁星、横跨天穹的绚丽银河、舞动的翡翠—青蓝—樱粉极光帷幕、偶发流星雨。
  - **水晶星光水面**：波纹法线、水下折射与水深清澈度渐变、水下焦散光斑、海岸轻柔泡沫、屏幕空间实时倒影（SSR）与波峰星芒闪烁。
  - **全维度专属优化**：主世界、下界（绯红琥珀幻境，无阴影开销高帧率）、末地（星云漩涡、极光光环，并原生支持 **Minecraft 26.3 / Iris End Flash 末地闪光阴影**），并自动兼容 NeoForge 模组维度。

---

## 安装指南（HMCL + Minecraft 26.3-NeoForge）

### 1. 确认前置模组版本
在 HMCL 中打开你的 `26.3-NeoForge` 实例目录（例如 `E:\Games\Minecraft\HMCL\.minecraft\versions\26.3-NeoForge\mods\`），确保已安装匹配 **Minecraft 26.3 (NeoForge)** 的渲染模组：
- **Sodium** `mc26.3-0.9.2`（NeoForge）
- **Iris Shaders** `1.11.7`（NeoForge 26.3）

> 注：Iris 依赖对应版本的 Sodium；二者版本需与 Minecraft 26.3 保持一致。

### 2. 导入 AnimateShader 光影包
将光影放入版本独立目录下的 `shaderpacks` 文件夹：
```text
E:\Games\Minecraft\HMCL\.minecraft\versions\26.3-NeoForge\shaderpacks\
```
（若在 HMCL 中未开启版本隔离，则放入 `E:\Games\Minecraft\HMCL\.minecraft\shaderpacks\`；也可以在游戏内直接点击「光影包 -> 打开光影包文件夹」。）

两种导入方式任选其一：
1. **直接使用压缩包**：运行 `python3 scripts/package.py` 生成 `dist/AnimateShader-v1.0-mc26.3.zip`，将 `.zip` 拖入 `shaderpacks` 文件夹。
2. **直接使用文件夹**：将本仓库整个 `AnimateShader` 目录（确保其内部直接包含 `shaders/` 文件夹）复制到 `shaderpacks\AnimateShader\`。

### 3. 游戏内启用与微调
进入游戏 -> **选项 -> 视频设置 -> 光影包** -> 选择 **AnimateShader** -> 点击 **应用**。
点击 **光影包设置** 即可使用完整简体中文菜单自由调节：
- 顶部一键切换画质预设：**流畅模式** / **均衡奇幻（推荐）** / **幻境极致**
- 顶部直接切换 **色彩主题预设**
- 在 **光照与亮度平衡** 中按个人显示器习惯微调 **夜晚亮度** 与 **整体曝光平衡**

---

## 开发与验证工具

```bash
# 使用真实 Mesa OpenGL 3.3+ 编译器与链接器验证全维度（world0/world-1/world1）所有预设下的 GLSL 着色器
python3 scripts/validate_shaders.py

# 打包为 Minecraft 可直接加载的 .zip 光影包
python3 scripts/package.py
```

---

## 许可协议

本项目采用 [Apache License 2.0](LICENSE) 开源许可协议。

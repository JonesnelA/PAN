# 盘 PAN

一个没有目的的解压玩具。打开就能摸，不记分、不联网、不发声，只有金属和震动。

三件可以盘的玩具：

| | 玩具 | 玩法 | 触感 |
|---|---|---|---|
| 1 | **棘轮表盘** | 手指拨动，每越过一个齿位"咔"一下，松手靠惯性转，越转越慢，最后自动吸进最近的齿位 | 齿位瞬态震动，转速越快越轻，快到一定程度糊成一片摩擦感 |
| 2 | **无限泡泡纸** | 按下或划过爆掉一颗，爆完自动换一张 | 大气泡闷、小气泡脆，每颗都不一样 |
| 3 | **磁流体** | 手指靠近，周围的金属尖刺立起来；拖着走会变形 | 拖动时按速度给不同密度的细碎震动，落下和抬起各有一记 |

整个工程 **不 import AVFoundation、不创建 AVAudioSession、不调用任何系统音效**。静音键拨下去，手感完全不受影响。

---

## 一、为什么我没法直接给你一个 ipa

我这台机器是 Windows。编译 iOS 应用需要 `xcodebuild`，而它只随 Xcode 发布、只跑在 macOS 上；打包成能装机器的 ipa 还需要一份 Apple 签发的证书。这两样东西都没法凭空产生。

所以我能给的是：**一份已经写好、随时能编译的工程**，以及**三条不需要你买 Mac 的出包路线**。其中第一条全程在 Windows 上就能完成。

---

## 二、四条路线

| 路线 | 需要什么 | 成本 | 出什么 |
|---|---|---|---|
| **A. 把仓库改成 Public** | 什么都没变 | 0 | Actions 继续用，macOS 分钟不再计数 |
| **B. xtool 交叉编译** | WSL2 + Swift 6.4 + Xcode.xip + 数据线 | 0（只花流量和硬盘） | 直接装进手机，连 ipa 都不需要 |
| **C. 换一家云 CI** | Codemagic 账号 | 免费额度 | 未签名 ipa |
| **D. 借 / 租 Mac** | macOS | 0 ~ $100/月 | 未签名 ipa |

> 先说个容易踩的坑：GitHub 的免费额度是按分钟扣的，而 **macOS 机器按 10 倍扣**。所谓 2000 分钟，实际只够 200 分钟 macOS 构建，也就是三四十次。你大概率就是这么用完的。
>
> 无论哪条路，**最后一步签名都得用你自己的 Apple ID**。免费账号 7 天，付费账号（$99/年）1 年。

---

## 三、路线 A：先试这个 —— 把仓库改成 Public

> **公开仓库的 macOS 分钟数是无限量免费的**（GitHub 官方规则：public repo 标准 runner 不计费，任何套餐都一样）。所以额度用完最快的解法不是换工具，是把这个仓库从 Private 改成 Public —— 设置 → General → 最下面 Danger Zone → Change visibility。代码里没有任何密钥，公开没有风险。

### 1. 把工程推上 GitHub

在 Windows 上装好 [Git](https://git-scm.com/download/win)，然后：

```bash
cd pan
git init
git add .
git commit -m "PAN"
git branch -M main
git remote add origin https://github.com/JonesnelA/PAN.git
git push -u origin main
```

> 用命令行而不是网页拖拽，是因为 `.github` 是隐藏目录，网页上传容易漏掉它 —— 而整个自动编译就靠里面那个 workflow 文件。
> 仓库设成 **Public** 最省事，macOS 编译分钟数免费。Private 也能跑，只是走每月免费额度。

### 2. 触发编译

推到 GitHub 后会自动开始（也可以去仓库的 **Actions** 页点 **build-ipa → Run workflow**）。

整条流水线只做四件事：装 XcodeGen → 生成工程 → `xcodebuild` 关签名编译 → 把 `.app` 塞进 `Payload/` 压成 `PAN-unsigned.ipa`。大约 3–6 分钟。

### 3. 下载 ipa

Actions 跑完后，进这次运行记录，页面底部 **Artifacts** 里下载 `PAN-unsigned-ipa`，解压得到一个 `.ipa` 文件。

### 4. 签名并安装

Windows 上用 [Sideloadly](https://sideloadly.io)：

1. 先装 **非 Microsoft Store 版** 的 iTunes 和 iCloud（商店版是沙盒的，Sideloadly 连不上设备；已装商店版要先卸掉）
2. 打开 Sideloadly，USB 连上 iPhone，解锁并"信任此电脑"
3. 把 `.ipa` 拖进窗口
4. 在 `Apple ID` 里填你的账号（建议专门注册一个小号，别用主账号）
5. 点 **Start**，等它签名 + 安装
6. 手机上：**设置 → 通用 → VPN 与设备管理 → 信任该开发者**
7. iOS 16 以上还要开：**设置 → 隐私与安全性 → 开发者模式**，打开后重启一次

### 5. 关于 7 天限制

免费 Apple ID 签的 App：

- **有效期 7 天**，到期打不开
- 同时最多 **3 个**自签 App
- Sideloadly 自带后台续签守护（auto-refresh），保持电脑和手机在同一 Wi-Fi 就会自动重签，基本不用管

如果打算长期用，$99 的开发者账号是唯一干净的解 —— 有效期一年，且可以直接让 GitHub Actions 签好再下载。

---

## 四、路线 B：xtool 交叉编译（真正的"在 Windows 上编译 iOS"）

你问的交叉编译确实存在，而且这是目前**唯一能跑通 SwiftUI 的开源方案**：[xtool](https://github.com/xtool-org/xtool) 把 Xcode 里的 SDK 抽出来，配开源的 Swift 工具链，在 Linux / WSL 上编译、签名、装进手机。**不需要 Mac，也不需要任何 CI**。

代价是前期准备偏重，大概一次性花 1–2 小时（主要是下 10 GB 的 Xcode）：

### 1. WSL2 + USB 直通

```powershell
wsl --install
```

再按微软文档装 [usbipd-win](https://learn.microsoft.com/windows/wsl/connect-usb)，把 iPhone 绑进 WSL：

```bash
usbipd list
usbipd bind   --busid <你的设备 busid>     # 需要管理员权限
usbipd attach --wsl --busid <你的设备 busid>
```

绑上之后 Windows 这边就用不了这台手机了，属正常。拔插后要重新 `attach`。

### 2. Swift 6.4 + usbmuxd

按 [swift.org/install/linux](https://www.swift.org/install/linux/) 装完确认：

```bash
swift --version     # Swift version 6.4
sudo apt-get install usbmuxd libimobiledevice-utils
ideviceinfo         # 能打印出设备名，说明链路通了
```

### 3. 下一个 Xcode.xip

去 [developer.apple.com/download/all](https://developer.apple.com/download/all/?q=Xcode) 搜 Xcode 27，下载 `Xcode.xip`（约 10 GB，要登录 Apple ID 并同意协议），记住路径。**这一步是绕不过去的**——Swift 编译器可以开源，iOS SDK 不能。

### 4. 装 xtool 并初始化

```bash
curl -fL "https://github.com/xtool-org/xtool/releases/latest/download/xtool-$(uname -m).AppImage" -o xtool
chmod +x xtool && sudo mv xtool /usr/local/bin/
xtool setup
```

`setup` 会问登录方式：

- `0 API Key` —— 付费开发者账号用，走公开 API
- `1 Password` —— **普通 Apple ID 用这个**，输邮箱 + 密码 + 双重认证码

然后填 `Xcode.xip` 的路径，它会自动解包并生成 Darwin SDK。验证：

```bash
swift sdk list      # 输出 darwin 就成了
```

### 5. 把代码塞进 xtool 模板

xtool 用 SwiftPM 而不是 `.xcodeproj`，所以让它先生成骨架，再把源码搬进去：

```bash
cd ~ && xtool new PAN

# 删掉模板自带的示例（否则会有两个 @main）
rm -rf PAN/Sources/PAN/*

# 拷进我们的源码
cp -R /path/to/pan/PAN/App /path/to/pan/PAN/Core \
      /path/to/pan/PAN/Design /path/to/pan/PAN/Toys \
      PAN/Sources/PAN/

# 覆盖 bundle id
cp /path/to/pan/xtool.yml PAN/xtool.yml
```

### 6. 一条命令：编译 + 签名 + 装进手机

```bash
cd PAN && xtool dev
```

它会自己注册设备、申请证书、生成描述文件、签名、安装、启动。

> **走这条路你根本不需要 ipa。** `xtool dev` 直接把 App 装进插着数据线的手机里。

几个注意点：

- 模板里的 `HelloApp.swift` / `ContentView.swift` 必须删干净，不然两个 `@main` 会编译报错
- `Assets.xcassets` 里的图标 xtool 不会处理，装出来是默认图标——只影响桌面观感，不影响手感
- `xtool dev` 是 debug 构建，对这种 120Hz 的 Canvas 画面没有可感差异
- 免费 Apple ID 依然 7 天有效期，到期重跑一次 `xtool dev` 就行

---

## 五、路线 C：换一家云 CI

工程里已经放好 `codemagic.yaml`，接上 [Codemagic](https://codemagic.io) 就能跑，免费额度约 500 分钟/月（独立计算，不和 GitHub 抢），产物一样是未签名 ipa。

其他备选：**Cirrus CI**（开源项目免费用 macOS 实例）、**Xcode Cloud**（付费开发者账号每月 25 小时免费，但首次配置需要 Xcode，得先有 Mac）。

---

## 六、路线 D：有 Mac 的话

```bash
cd pan
chmod +x build_ipa.sh
./build_ipa.sh
```

产物在 `build/PAN-unsigned.ipa`。

想直接在 Xcode 里连真机跑：`brew install xcodegen && xcodegen generate && open PAN.xcodeproj`，然后在 *Signing & Capabilities* 里选自己的 Team。**注意必须用真机**，模拟器没有 Taptic Engine，什么手感都测不出来。

---

## 七、工程结构

```
pan/
├─ project.yml                        XcodeGen 工程描述（Xcode / Actions 用）
├─ xtool.yml                          xtool 交叉编译的 bundle id
├─ build_ipa.sh                       Mac 上一键出包
├─ .github/workflows/build-ipa.yml    GitHub Actions 自动编译
├─ codemagic.yaml                     Codemagic 备选流水线
├─ tools/make_icon.py                 用数学画图标（Pillow）
└─ PAN/
   ├─ App/
   │   ├─ PANApp.swift                入口：隐藏状态栏、常亮
   │   └─ RootView.swift              三个玩具 + 三个小点
   ├─ Core/
   │   ├─ Haptics.swift               Core Haptics，预建 player 复用
   │   └─ FrameDriver.swift           CADisplayLink 封装，120Hz
   ├─ Design/Theme.swift              黑 / 钢 / 黄铜
   ├─ Toys/
   │   ├─ DetentDial.swift            棘轮表盘：物理 + Canvas 绘制
   │   ├─ BubbleSheet.swift           泡泡纸
   │   └─ Ferrofluid.swift            磁流体
   └─ Assets.xcassets/AppIcon…        1024 图标
```

---

## 八、手感参数在哪调

真正决定"好不好盘"的是这几个数，都在文件顶部：

| 想要的效果 | 改哪里 |
|---|---|
| 齿更密 / 更疏 | `DialModel.detentCount`（默认 72） |
| 转得更久才停 | `advance()` 里的 `pow(0.978, dt * 60)`，改小 = 停得快 |
| 吸附更黏 | `abs(velocity) < 1.0` 这个阈值，调大 = 更早开始吸附 |
| 齿感更重 | `Haptics.rebuildPlayers()` 里 `tickHard` 的 intensity |
| 泡泡更密 | `BubbleSheet.regenerate()` 里的 `columns` / `rows` |
| 尖刺更长 | `Ferrofluid` 里 `0.34 * spike * angular * falloff` 的系数 |
| 摩擦更密 | `Haptics.friction(speed:)` 里的 `interval` |

---

## 九、可能踩到的坑

**编译报 `Signing for "PAN" requires a development team`**
你在 Xcode GUI 里直接 Run 了。要么在 Signing 里选 Team，要么用 `build_ipa.sh`（它把签名整个关掉了）。

**装上了，点开闪退**
先在手机上开"开发者模式"，再确认信任了证书。如果还闪，把 Xcode Devices 里的控制台日志发我。

**完全没有震动**
模拟器没有马达；低电量模式下系统也会限制触感。真机 + 正常电量再试。iPhone 8 之前的老机型没有 Taptic Engine，会走 `UIImpactFeedbackGenerator` 降级，手感会明显不同。

**图标是白的**
确认 `PAN/Assets.xcassets` 被包含进工程了（XcodeGen 会自动收，手动建工程时需要自己拖进去）。

**代码没有在本机编译过**
这台机器没有 Xcode，所以没法先替你跑一遍。语法和 API 我逐行核过，但如果 `xcodebuild` 报了错，把日志贴给我，我直接改——不用你自己猜。

---

## 十、还能加什么

- **齿轮组**：几个互相咬合的齿轮，转一个带动全部，齿与齿咬合时给一次重震
- **拉链**：上下拖动，每一节齿"嗒"一下
- **沙漏 / 沙粒**：颗粒物理，倾斜手机流动（用 CoreMotion）
- **磁吸卡扣**：拖到某个位置突然被吸住，一记很重的"咔"

每加一个，只要在 `RootView` 的 switch 里加一个分支、底部多一个小点。

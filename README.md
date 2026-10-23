# PokéBonk iOS 封装（Windows 无 Mac 版）

把 https://pokebonk.com/ 封装成一个仅自己使用的 iPhone App：
SwiftUI + WKWebView 全屏加载网页，游戏本体始终在线加载。
**Windows 上写代码，GitHub Actions 的 macOS 云端构建 IPA，再用 Sideloadly 侧载到 iPhone。**

---

## 0. 当前完成状态（先读，别被标题误导）

本项目共分四个独立阶段，**只有第 1 阶段是我在本次会话里完成的**，后三阶段需要你在自己电脑上操作：

| 阶段 | 含义 | 状态 |
|---|---|---|
| ① 理论上配置完成 | Xcode 工程、Swift 代码、CI 配置、本说明全部写好并通过静态校验 | ✅ **本次已完成** |
| ② 云端构建成功 | GitHub Actions 在 macOS 上真正编译出 `.ipa` | ⏳ 待你点一次 "Run workflow"（约 5–10 分钟） |
| ③ IPA 签名成功 | Sideloadly 用你的 Apple ID 对 IPA 重签名 | ⏳ 待你在 Windows 上操作 |
| ④ 真机安装验证成功 | App 装到 iPhone、能打开、游戏能玩 | ⏳ 待你实测 |

> 我运行在 Linux 环境，**没有、也无法在这里执行 xcodebuild**。我不会谎称 IPA 已经构建成功。
> 第 ② 步只要工程没错就能出包；万一 Actions 红了，把日志贴回来我修。

---

## 1. 推荐技术路线

```
Windows 浏览器 ──上传──> GitHub 仓库（公开/私有都行）
                              │
                    GitHub Actions（macos-26 云主机，自带 Xcode 26）
                              │ 编译 Release-iphoneos，不签名
                              ▼
                     PokeBonk-unsigned.ipa（Artifact 下载）
                              │
                    Windows 上的 Sideloadly（输入你的 Apple ID）
                              │ 云端/本地重签名 + 安装描述文件
                              ▼
                        iPhone（iOS 26）上的 PokéBonk
```

为什么这样选：

- **不需要 Mac**：编译 iOS 必须用 Xcode/macOS，GitHub 官方 `macos-26` runner 自带 Xcode 26.x，免费额度足够个人项目（公开仓库无限分钟，私有仓库每月 2000 分钟免费）。
- **不需要向任何人提交密钥**：CI 只出**未签名** IPA；签名在你自己的 Windows 上由 Sideloadly 完成，你的 Apple ID 密码只在 Sideloadly 本地输入，不会进 Git 仓库、也不会进任何日志。
- **未签名 IPA 不能直接安装**，它只是中间产物；安装前必须由 Sideloadly 这类工具重签名。

---

## 2. 项目结构

```text
PokeBonk-iOS/
├── PokeBonk.xcodeproj/
│   └── project.pbxproj          # Xcode 工程（Scheme 名 = PokeBonk）
├── PokeBonk/
│   ├── App.swift                # @main 入口
│   ├── GameView.swift           # WKWebView 封装：导航/错误重试/弹窗/外链处理
│   ├── Info.plist               # 显示名 PokéBonk、全屏、方向、ATS 放宽
│   └── Assets.xcassets/
│       ├── Contents.json
│       └── AppIcon.appiconset/
│           ├── AppIcon.png      # 原创通用游戏球图标（1024×1024，无 alpha）
│           └── Contents.json
├── .github/
│   └── workflows/
│       └── build-ipa.yml        # 手动触发的云端未签名构建
└── README.md                    # 本文件
```

- **Bundle ID 占位**：`com.example.PokeBonk`。Sideloadly 签名时会按你的 Apple ID 自动改写，一般不用改；若你以后要在 GitHub Actions 里自动签名，再换成唯一值。
- **显示名**：`PokéBonk`。
- **部署目标**：iOS 16.0（你的 iOS 26 向下兼容可装）。
- **图标**：自绘的通用游戏球，未使用任何官方 Pokémon 素材。

---

## 3. 从 Windows 到安装完成（分步）

### 3.1 建 GitHub 仓库并上传

1. 注册/登录 GitHub，新建一个仓库（名字随意，如 `PokeBonk-iOS`），**私有即可**。
2. 把本压缩包**解压后的全部内容**（注意：是 `PokeBonk-iOS/` 里的内容，即 `PokeBonk.xcodeproj`、`PokeBonk/`、`.github/`、`README.md` 直接在仓库根目录）上传：
   - 网页上选 "uploading an existing file"，把文件拖进去即可；
   - 或用 Git 命令：
     ```bash
     cd PokeBonk-iOS
     git init
     git add .
     git commit -m "PokeBonk iOS wrapper"
     git branch -M main
     git remote add origin https://github.com/<你的用户名>/PokeBonk-iOS.git
     git push -u origin main
     ```
   > ⚠️ 关键：仓库根目录下必须能直接看到 `PokeBonk.xcodeproj`，而不是多套一层 `PokeBonk-iOS/`。workflow 里的路径就是按这个写的。

### 3.2 触发云端构建

1. 打开仓库页 → **Actions** 标签。
2. 左侧选 **"Build PokeBonk unsigned IPA"** → 右侧 **Run workflow** → 选 `main` 分支 → 绿色 Run。
3. 等 5–10 分钟：绿色 ✅ = 构建成功；红色 ❌ = 点进去看失败那一步的日志，贴回来即可。

### 3.3 下载 IPA

- 点进成功的那次运行，页面底部 **Artifacts** 区下载 `PokeBonk-unsigned-IPA.zip`，解压得到 `PokeBonk-unsigned.ipa`。
- 这就是第 ② 阶段产物。**它还不能装到手机上**。

### 3.4 Windows 准备

1. 从官网 <https://sideloadly.io/> 下载 Windows 版 Sideloadly（当前 v0.71，官方支持 iOS 7–27，含 iOS 26）。
2. 安装 iTunes（Microsoft Store 的 "Apple 设备" 应用或苹果官网的 iTunes 均可）——它带 iPhone 驱动。装完插上手机能在 iTunes 里识别到手机即可。
3. iPhone 用数据线连电脑，**首次连接在手机上点"信任此电脑"**，并锁屏密码解锁一次。
4. iPhone 上打开 **设置 → 隐私与安全性 → 开发者模式**，打开并重启（iOS 17+ 侧载必需；iOS 26 同样需要）。如果没有这个菜单，先随便用一次 Xcode 连真机才会出现——Sideloadly 首次签名时通常会引导你开启。

### 3.5 用 Sideloadly 签名并安装

1. 打开 Sideloadly，顶部确认已识别到你的 iDevice。
2. 把 `PokeBonk-unsigned.ipa` 拖进去（或点 IPA 按钮选择）。
3. Apple ID 一栏填**你自己的、专门用来侧载的 Apple ID 邮箱**（可以不用主号；不要给别人）。
4. 点 **Start**。首次会要求输入 Apple ID 密码（或 App 专用密码——建议 Apple 官网appleid.apple.com 给 Sideloadly 单独生成一个 App 专用密码，不输入主密码）。
5. 进度走完后 iPhone 上会出现 PokéBonk 图标，但此时**还打不开**。

### 3.6 信任开发者描述文件

- iPhone 上：**设置 → 通用 → VPN 与设备管理** → 点你刚签名用的 Apple ID 对应的开发者证书 → **信任**。
- 现在打开 PokéBonk，应该全屏黑底开始加载 pokebonk.com。

### 3.7 免费签名到期后

- 用免费 Apple ID 签的 App **7 天后失效**（打开会弹"不受信任"）。到期后重新插线、Sideloadly 再点一次 Start 即可刷新，游戏数据在网页端，不丢。
- 想一年一签就买付费开发者账号（见下节）。

---

## 4. 免费 Apple ID vs 付费开发者账号

| | 免费 Apple ID | 付费 Apple Developer Program（$99/年） |
|---|---|---|
| 签名有效期 | 7 天，每周需重签 | 1 年 |
| 同时可装侧载 App 数 | 约 3 个 | 无此限制（设备数另计） |
| 需要的工具 | Sideloadly / AltStore 等 | 同左，或正式证书 + 描述文件 |
| 适合 | 就装这一个自用 App | 多设备/长期不折腾 |

> 免费账号的限制（7 天、3 个 App）是 Apple 的策略，可能随版本调整；本 README 不保证免费签名在未来 iOS 版本上一定可用。Sideloadly 官网标注支持到 iOS 27 beta，但**仍以你实际安装结果为准**。

---

## 5. 常见错误

| 现象 | 原因 / 处理 |
|---|---|
| Actions 红在 "Build Release" | 展开日志搜 `error:`；最常见是工程路径不对（多套了一层目录）或网络拉依赖失败，重跑一次 |
| `xcodebuild: error: It looks like Xcode is selected in the ...` | 镜像默认 Xcode 版本变动，在 workflow 里加一步 `sudo xcode-select -s <路径>` |
| Artifacts 里没有 IPA | 构建其实失败了；回到 job 列表看哪一步红了 |
| Sideloadly 报 `wrong Apple ID password` | 开了双重认证就必须用 **App 专用密码**（appleid.apple.com 生成） |
| 装上后点开秒退 | 描述文件没信任：设置 → 通用 → VPN 与设备管理；或 iOS 26 上 Sideloadly 版本太旧，升级到最新版 |
| 打开 App 一直黑屏/转圈 | 网页本身加载失败：确认手机能上网、能直接在 Safari 打开 https://pokebonk.com/ ；网页游戏若有 WebGL 性能问题，需真机观察 |
| 横屏游戏画面不转 | 工程已放开全部方向；若网页锁死竖屏，那是网站自己的行为，壳改不了 |
| 外部链接被带去 Safari | 这是设计如此（同域留在 App 内，外链交系统浏览器） |

---

## 6. 安全提醒（务必看）

- Apple ID 密码只在 **Sideloadly 本地界面**输入；不要发给我、不要发给任何网站/AI/客服。
- 本仓库**不要**提交任何证书、描述文件、私钥；CI 也不接触你的 Apple ID。
- 下载 Sideloadly 只从官网 sideloadly.io；第三方打包站可能带木马。
- 免费侧载证书偶尔会被苹果批量吊销，重签即可。

---

## 7. 本次我实际做了什么、没做什么

**已做（可复查）：**
- 完整 SwiftUI + WKWebView 工程：深色全屏、JS/WebGL 默认支持、内联媒体自动播放、弹窗 `target=_blank` 不吞、同域内/外链 Safari 分流、加载失败错误页 + 重试按钮、WebContent 崩溃自动刷新、禁止长按菜单/误选文字。
- `project.pbxproj` 手写工程，已校验括号平衡与节点引用完整；未用任何假 ID。
- GitHub Actions：`macos-26` runner（当前默认 Xcode 26.x，支持 iOS 26 SDK），手动触发、打印版本、校验 scheme、Release/iphoneos 未签名编译、打 Payload 包、上传 Artifact。
- 原创 1024×1024 无 alpha 应用图标。

**没做（如实说明）：**
- ❌ 没有真的跑过 `xcodebuild`（Linux 环境无 Xcode）——所以**第 ② 阶段"云端构建成功"尚未发生**，需要你跑一次 Actions 才算数。
- ❌ 没有签名、没有真机安装——第 ③④ 阶段更未发生。
- 真机上的 WebGL 性能、触控手感、横竖屏适配，必须等你装到 iPhone 后亲自测；有问题把现象告诉我，我改 Swift 代码你重新推一次即可。

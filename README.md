# Mac Window Manager

一个基于 [Hammerspoon](https://www.hammerspoon.org/) 的 macOS 窗口管理器，用快捷键把当前窗口**任意**丢到**哪块屏幕**的**哪个位置**——特别为多显示器场景设计。

- **零运行时依赖**（除了 Hammerspoon 本身）
- **纯文本配置**，整份 Lua，跟 Git
- **端到端测试在 Linux 上跑通**——所有几何计算、屏幕排序、快捷键冲突、跨屏迁移、布局存取都被单元测试和场景回放覆盖
- **脚本化安装**：一条命令软链到 `~/.hammerspoon`，`git pull` 就等于升级

## 安装

在你的 Mac 上：

```bash
git clone <this-repo> ~/src/mac-window-manager
cd ~/src/mac-window-manager
./scripts/install.sh
```

安装脚本会：

1. 用 Homebrew 装 Hammerspoon（已装的话跳过）
2. 备份已有的 `~/.hammerspoon` 到 `~/.hammerspoon.backup-<时间戳>`
3. 把 `init.lua`、`modules/`、`spec/` 软链到 `~/.hammerspoon/`（`git pull` 之后 Reload Config 就生效）
4. 如果还没有 `~/.hammerspoon/config.lua`，从 `config.example.lua` 拷贝一份

**接下来必须手动做一次**：

1. 打开 **System Settings → Privacy & Security → Accessibility**，把 **Hammerspoon** 勾上。（Apple 的安全限制，所有窗口管理器都躲不开。）
2. 点菜单栏的 Hammerspoon 图标 → **Install Command Line Tool**（为了让 `scripts/doctor.sh` 能用 `hs` CLI 诊断）。

完成后运行：

```bash
./scripts/doctor.sh
```

看到所有 `✓` 就可以开始用了。

## 默认快捷键

前缀是 **⌃⌥⌘**（`hyper`）和 **⌃⌥⌘⇧**（`hyper-shift`）。想换成别的，编辑 `~/.hammerspoon/config.lua`。

### 当前屏幕上的定位

| 快捷键 | 动作 |
|---|---|
| `⌃⌥⌘ + H` | 左半屏 |
| `⌃⌥⌘ + L` | 右半屏 |
| `⌃⌥⌘ + K` | 上半屏 |
| `⌃⌥⌘ + J` | 下半屏 |
| `⌃⌥⌘ + U / I` | 左上 / 右上象限 |
| `⌃⌥⌘ + N / M` | 左下 / 右下象限 |
| `⌃⌥⌘ + Return` | 最大化到当前屏（非原生全屏） |
| `⌃⌥⌘ + C` | 保持大小，居中 |
| `⌃⌥⌘⇧ + H / J / L` | 左 / 中 / 右 三分之一 |
| `⌃⌥⌘⇧ + U / O` | 左 / 右 三分之二 |
| `⌃⌥⌘⇧ + 1..9` | 3×3 栅格任选格（1=左上，5=中，9=右下） |

### 细粒度平移与缩放

默认按 12 列 × 8 行虚拟栅格步进，可在 `config.lua` 里改。

| 快捷键 | 动作 |
|---|---|
| `⌃⌥⌘ + ← / → / ↑ / ↓` | 向对应方向平移一格 |
| `⌃⌥⌘ + ] / [` | 加宽 / 变窄 |
| `⌃⌥⌘⇧ + ] / [` | 变高 / 变矮 |

### 跨屏幕

屏幕按 **左→右、上→下的物理位置**排序编号（不是 macOS 的显示图顺序），所以 "1 号屏" 永远是最左边那块。

| 快捷键 | 动作 |
|---|---|
| `⌃⌥⌘ + 1 / 2 / 3` | 把窗口送到第 1 / 2 / 3 块屏，保持相对位置和大小 |
| `⌃⌥⌘ + . / ,` | 下一块 / 上一块屏（环形） |

### 布局存取

| 快捷键 | 动作 |
|---|---|
| `⌃⌥⌘ + S` | 把当前所有可见窗口的位置存为 "default" 布局 |
| `⌃⌥⌘ + R` | 恢复 "default" 布局 |

布局文件存在 `~/.hammerspoon/layouts/default.lua`，纯文本、可版本化、可手编。

## 用你自己的命名（左屏/主屏/右屏）

编辑 `~/.hammerspoon/config.lua`：

```lua
return {
  role_map = {
    left  = 1,                               -- 1-based 物理位置
    main  = "Built-in Retina Display",       -- 或者直接写屏幕名
    right = 3,
  },
}
```

然后在 `init.lua` 里就能 `actions.send_to_role(ctx, "main")` 了。默认没有绑定到快捷键——想加自己加。

## 开发与测试

仓库里整个 `spec/` 是一套 **在 Linux 上跑**的测试，覆盖：

- `modules/geometry.lua`：栅格、半屏、象限、跨屏 ratio 保持、边界钳位
- `modules/screens.lua`：显示器排序、id/name/role 解析、环形下一块
- `modules/actions.lua`：所有动作返回的矩形
- `modules/layouts.lua`：序列化往返、ID/app/title 匹配回退、idempotent restore、屏幕重命名
- `modules/hotkeys.lua`：默认绑定完整性、(mods,key) 冲突检测
- `spec/e2e_spec.lua`：真正加载 `init.lua`，按下快捷键，验 `setFrame` 日志
- `spec/scenarios_spec.lua`：多步脚本回放 + `spec/golden/*.lua` 快照 diff
- `spec/fakes/hs.lua`：Linux 下 Hammerspoon API 的假实现（约 200 行）

```bash
# 安装测试工具链（仅首次）
sudo apt-get install -y lua5.4 liblua5.4-dev luarocks
sudo luarocks --lua-version=5.4 install luacheck
sudo luarocks --lua-version=5.4 install busted

make check   # lint + 所有测试
make lint
make test
make clean-golden  # 有意改行为后，重生成快照
```

### 在 Linux 上跑通 ≠ 在 Mac 上一定没事

下面这些只有真 Mac 能验，放一份手动清单：

## Mac 手动验收清单

第一次装完、以及每次较大改动之后，对着跑一遍。预计 5–10 分钟。

- [ ] **加载无警告**：Hammerspoon 菜单 → Console，应看到 `Window manager loaded (N hotkeys)`，没有红字错误。
- [ ] **Accessibility 已开**：`./scripts/doctor.sh` 返回 `Accessibility permission granted`。
- [ ] **多屏识别**：`doctor.sh` 输出里的 `[1] ... [2] ... [3] ...` 顺序应当跟你的物理左→右排列一致。
- [ ] **基本半屏**：随便找个窗口 → `⌃⌥⌘ + H` 左半 → `⌃⌥⌘ + L` 右半 → `⌃⌥⌘ + Return` 最大。
- [ ] **象限与三分**：`⌃⌥⌘ + U` 左上 → `⌃⌥⌘⇧ + 5` 中心格 → 视觉对齐正确。
- [ ] **跨屏绝对**：`⌃⌥⌘ + 2` → 当前窗口跳到物理上第 2 块屏，大小和相对位置保持。连按 `1/2/3` 三下，每次都应该到你记忆中对应的屏。
- [ ] **跨屏循环**：`⌃⌥⌘ + .` 循环下一块屏，`⌃⌥⌘ + ,` 上一块。
- [ ] **平移钳位**：窗口放在左边缘，按 `⌃⌥⌘ + ←` → 窗口贴齐屏左边不越界。
- [ ] **热拔插**：正在用窗口时拔掉一块外接屏 → Hammerspoon Console 应出现 `Screen layout changed – bindings reinstalled`；窗口若在被拔那块屏，应已迁到残留屏（macOS 会自动做这一步，我们要确保之后快捷键依然工作）。
- [ ] **顽固 app**：试一个 Chrome 窗口和一个 iTerm2 窗口，重复几个快捷键，确认无 "窗口抖一下但没挪" 现象。（Chrome 需要允许在背景被移动的首次提示。）
- [ ] **原生全屏豁免**：对一个**原生全屏**（绿灯）的窗口按快捷键——预期行为是**无变化**（macOS 不允许 AX 移动全屏窗口）。这不是 bug。
- [ ] **刘海兼容**：MacBook 内屏上按 `⌃⌥⌘ + U` 左上象限 → 上边缘不会被刘海遮内容。
- [ ] **保存/恢复布局**：摆好窗口 → `⌃⌥⌘ + S`（应提示保存路径） → 随便拖乱 → `⌃⌥⌘ + R`（应提示 `Restored N windows`）。再回头看窗口应已恢复。
- [ ] **冲突检测**：打开 `~/.hammerspoon/config.lua`，故意把 `hyper` 设成 `{ "cmd" }` 然后 reload，应在屏幕上看到 "Hotkey conflicts: ..." 的弹窗（说明检测逻辑在工作）；改回默认。
- [ ] **doctor 无 `✗`**：`./scripts/doctor.sh` 以 0 退出。

如果以上哪条不对，把 Hammerspoon Console 的报错贴出来就能定位。

## 已知的局限

这些不是 bug 而是 macOS 的约束：

1. **原生全屏（绿灯全屏）窗口**不能通过 AX API 移动。想调整的话先按 `⌃⌘F` 退出全屏，再用我们的快捷键。
2. **需要 Accessibility 权限**。升级 macOS 后偶尔会被静默撤销；发现快捷键突然不灵，先检查权限。
3. **快捷键冲突**：`⌃⌥⌘` 前缀和 Raycast / Alfred / 某些 app 里的快捷键可能撞车。`init.lua` 启动时会弹一个警告，你也可以改 `config.lua` 里的 `hyper`。
4. **Stage Manager / Mission Control**：在这些模式下，窗口可能被 macOS 临时接管；这时快捷键的行为由系统决定，我们的代码本身没有问题。

## 目录结构

```
.
├── init.lua                 Hammerspoon 入口，被链到 ~/.hammerspoon/init.lua
├── config.example.lua       用户本地配置模板（拷成 config.lua 自行修改）
├── modules/
│   ├── geometry.lua         纯几何：半屏/栅格/ratio/钳位
│   ├── screens.lua          显示器排序与 id/name/role 解析
│   ├── actions.lua          高层窗口动作（纯函数：输入世界，输出目标矩形）
│   ├── layouts.lua          布局捕获/恢复/序列化
│   ├── hotkeys.lua          快捷键绑定声明表 + 冲突检测
│   └── driver.lua           连接 Hammerspoon 运行时的薄适配层
├── spec/
│   ├── helper.lua           busted 初始化：设置 package.path 并装 hs 假模块
│   ├── fakes/hs.lua         Hammerspoon API 的 Linux 假实现
│   ├── *_spec.lua           单元测试
│   └── golden/              场景回放的快照
├── scripts/
│   ├── install.sh           Mac 上的一键安装
│   └── doctor.sh            Mac 上的健康检查
├── .github/workflows/ci.yml Linux CI（luacheck + busted）
├── Makefile                 make check / lint / test / install / doctor
└── README.md
```

## 授权

MIT。

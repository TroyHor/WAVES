# WAVES — 项目约定（每次会话以此为准）

波形卡牌构筑 Roguelike，Godot 4（当前 4.7.2）/ GDScript / 2D，目标上架 Steam。
用户负责 Steam 上架与试玩反馈；开发全部由 Claude 用代码/文本文件完成，**不依赖手动操作编辑器**。
完整设计见 `docs/design.md`。规则改动时必须同步更新本文件和设计文档。

## 核心机制（一句话）
所有攻击都是"波"。敌人波 E 与玩家波 P 在一条离散波轨上逐格叠加，N = E + P。
反相抵消 = 防御，同相叠加 = 攻击；玩家自己的多张波之间同样会互相抵消。

## 当前规则（原型默认值，全部可在 `data/config/rules.json` 配置）
- 波轨 `track_length` = 16 格，每格整数振幅（正 = 波峰，负 = 波谷，0 = 空）。
- 波形 = 整数数组，例如 `[2, 4, 2, 0, -2, -4, -2]`。
- 回合开始时显示敌人意图 E[t]（长度 = 波轨长度）。
- 出牌：花能量打出手牌，选择起始格 offset，P[offset + i] += wave[i]。越界部分截断（`offtrack_mode`）。
- 结算逐格（抵消后剩下的波攻向对应一方，伤害 = |N|）：
  - E[t] ≠ 0 且 sign(N) == sign(E)：玩家受 |N[t]|。
  - E[t] ≠ 0 且 N 反号：对敌人造成 |N[t]| × `overflow_ratio`（保持 1）。N = 0 为完美抵消。
  - E[t] = 0：对敌人造成 |N[t]|。
- 玩家 HP 整局共用、战斗后不回满，所以"用溢出换血"和"保血"是真实取舍。
- 敌人意图：每回合从招式池按权重随机抽取（局内种子可复现），回合开始时公开。
- **只有一条波轨**（没有多波轨）。唯一的多敌人关卡是干涉双子：两只的波合成为 E，玩家伤害只打前面那只，每 `swap_interval` 回合交换前后（详见 design.md 2.5）。
- 拉伸 = 线性插值：长度 n → (n−1)·k + 1，四舍五入远离 0。
- 结算前已放置的卡可以拖动/撤回并返还能量。同时归零判玩家负。
- 无基础"格挡"，非位置性防御只来自遗物。
- 一局（原型）：按 `data/config/run.json` 顺序线性打 4 场，HP 在战斗之间延续；失败即本局结束。
- 新手引导：`data/tutorial/hints.json` 数据驱动（触发条件 + `after` 链 + 完成方式），每条只出现一次，进度存 `user://progress.json`。
- 每回合能量 `energy_per_turn` = 3，抽牌 `hand_size` = 5，玩家 HP `player_max_hp` = 60。数值原则：前期低，让玩家自己学会规则。
- 决定记录与仍待决定的问题见 `docs/design.md` 第 6、7 节。

## 目录结构
```
project.godot            Godot 项目配置（手写，autoload 在这里注册）
src/core/                纯规则层：RefCounted/静态函数，禁止依赖 Node/UI/场景树
src/data/                数据定义与加载（CardData、EnemyData、RulesConfig、JSON 加载与校验）
src/ui/                  场景(.tscn)与表现层脚本，只读写 core 层的状态，不实现规则
src/autoload/            全局单例：Assets（素材路径注册表）
src/platform/            平台抽象（Platform 单例；之后接 GodotSteam 的后端放这里）
data/config/rules.json   全局规则数值
data/cards/*.json        每张卡一个文件
data/enemies/*.json      每个敌人一个文件（招式池）
data/encounters/*.json   每场战斗一个文件（敌人列表、双子交换间隔）
data/config/starter_deck.json  初始牌组
data/config/run.json     一局的战斗顺序
data/tutorial/hints.json 新手引导文案与触发条件
assets/{art,fonts,audio} 正式素材放这里；路径只在 src/autoload/assets.gd 里登记
tests/                   无头测试：run_tests.gd（运行器）、test_case.gd（断言基类）、unit/test_*.gd、
                         ui_smoke.gd（UI 冒烟测试）、balance_probe.gd（平衡探针，非测试）
scripts/                 命令行脚本：test.sh、balance.sh、export.sh、godot_bin.sh
docs/                    设计文档
builds/                  导出产物（git 忽略）
```

## 美术方向
- **老式台式示波器 + 电子仪器**，整体气质参考《小丑牌》：效果服务于风格与手感，**不做干扰视觉的故障**（无随机撕裂、色块花屏、闪烁、抖动）。
- **战斗布局**：上方敌方信号面板、中间大台式示波器、下方我方信号面板、最下手牌。左侧一栏：敌人形象（双子上下排列）在敌方面板旁，预计伤害（箭头图标 + 大数字）与结算按钮在中间旁，玩家形象/能量/HP 在我方面板旁，抽牌堆/弃牌堆图标在最下。三块波形面板共享同一套格子列（`GRID_INSET_L/R`）。
- **信息展示原则：少文字、多图标**。牌堆是卡牌堆图标 + 大号数量（悬停显示名称），能量只用发光菱形图标（不显示数字），HP 用大号当前值 + 小号上限。操作说明交给新手引导，不常驻屏幕。
- **上下信号面板**（`FlatScopeView` + `ScopeScreen`）：平板边框样式，波形用**折线**。我方只画一条组合波（所有已放置卡牌之和）。
- **中间台式示波器**（`MergedView` = `OscilloscopeView` + `MergedScreen` + `ReadoutStrip`）：代码绘制的机壳、铭牌、旋钮、指示灯；显像管是 SubViewport 经 `tube.gdshader` 显示（归一化桶形，中线两端与中心不偏移，保证列对齐）、扫描线、辉光；屏幕底色是**墨绿色流动波纹**（`scope_flow.gdshader`）。屏幕内叠加：敌人波、玩家的**唯一一条组合波**（所有已放置卡牌之和，不单独画每张牌）、合成结果，**平滑曲线**（余弦插值，精确经过每格、不过冲）+ 沿曲线流动的高光 + 每格**强度柱**（绿=打敌人，红=打你）。机壳下方是逐格伤害读数条。
- **全局后处理**（`screen_fx.gdshader`）：柔和泛光、轻微色差、颗粒、暗角；碰撞时一圈平滑冲击波涟漪 + 阻尼摇晃（`Main.impact()`）。**游戏背景**是几乎静止的暗色电路板点阵（`pcb_background.gdshader`），刻意与示波器里的流动波纹区分。F2 关闭全局后处理。
- **手感**：卡牌轻微摇摆、悬停放大上浮；数字/强度柱从左到右回弹弹出；牌堆数量变化时数字跳动；形象受击闪白 + 阻尼摆动 + 挤压。
- 结算动画：上下面板的波射入中间示波器 → 碰撞涟漪与抵消光环 → 强度柱/数字弹出 → 剩余伤害化为弹道飞向形象 → 命中反馈。
- 形象：`FigureView` 先用代码绘制的矢量占位（按敌人 JSON 的 `figure.shape`），`figure.texture` 对应的贴图存在时自动替换。
- 颜色全部来自 `Assets.COLORS`，后处理/显像管参数在 `Assets.SCREEN_FX` / `Assets.TUBE`，UI 主题由 `ThemeFactory.shared()` 代码生成（SubViewport 内需显式设置主题）。

## 开发规范
- **规则与表现分离**：叠加、结算、牌堆、能量、回合流程全部在 `src/core/`，可在无 UI 下被测试驱动。UI 只调用 core 的 API 并渲染结果（包括实时预览：UI 调用同一个结算函数做"试算"，绝不自己再算一遍）。
- **数据驱动**：新增卡牌/敌人只加 JSON 文件，不改代码。新效果类型才需要改代码（在 core 的效果注册处加一个 case + 测试）。
- **数值不写死**：规则数值读 `rules.json`；美术颜色/路径读 `Assets`。
- **素材**：现阶段用代码绘制占位图形。任何 `res://assets/...` 路径只能出现在 `src/autoload/assets.gd`；缺文件时调用方回退到占位绘制。
- **平台**：成就、存档路径等一律经过 `Platform` 单例，gameplay 代码不直接调用 Steam。
- **测试**：改 core 必须加/改测试。运行 `scripts/test.sh [过滤词]`，必须全绿再提交。
- **语言**：代码标识符与代码注释用英文；文档与面向用户的说明用中文。游戏内文本之后会做本地化，先直接写在数据里。
- **GDScript 风格**：静态类型（`var x: int`、`-> void`），tab 缩进，`snake_case` 函数/变量，`PascalCase` class_name。
- **Git**：每完成一个可运行的小步骤提交一次，信息写清做了什么。`.godot/` 不入库，`*.import` 与 `*.uid` 入库。
- **决策**：明显影响玩法的选择先问用户；纯技术选择自行决定并记录在下方。

## 常用命令
```bash
scripts/test.sh                 # 运行全部测试（会先 --import）
scripts/test.sh superposition   # 只跑名字含该词的测试（跳过 UI 冒烟测试）
scripts/balance.sh 50           # 机器人在每场战斗跑 50 个种子，输出胜率/回合数/掉血
scripts/export.sh [macos|windows|linux|all]   # 无头导出到 builds/（需要 4.7.2 导出模板）
/Applications/Godot.app/Contents/MacOS/Godot --path .   # 运行游戏
```
Godot 可执行文件路径可用环境变量 `GODOT` 覆盖。

开发参数（写在 `--` 之后）：`--encounter=04_twins` 直接进入战斗，`--seed=N`，`--nocrt`，
`--demo`（自动摆两张牌并模拟拖动第三张，用于截图），`--autoresolve`（配合 --demo 自动结算，用于截动画），
`--shot=路径.png` + `--shotframes=N`（第 N 帧截图后退出），`--runfight`（新开一局直接进第一战），`--notutorial`，
`--freshprogress`（用空白且不保存的引导进度，截图用），`--selftest`（UI 冒烟测试）。

## 技术决策记录
| 决策 | 理由 |
|---|---|
| Godot 4.7.2 + GDScript | 用户要求最新稳定版；GDScript 无需 .NET，导出与 GodotSteam 兼容性最好。 |
| 渲染器 GL Compatibility | 纯 2D 不需要 Forward+；兼容老显卡与 Steam Deck，Mac 上也最稳。 |
| 基准分辨率 1920×1080，`canvas_items` + `expand` | Steam 主流分辨率；窗口缩放时 UI 保持清晰。 |
| 卡牌/敌人用 JSON 而非 .tres | 文本简单、diff 友好、我和用户都能直接改；加载时做校验，测试会遍历全部数据文件确保合法。 |
| 自写极简测试运行器，不用 GUT | 零第三方依赖，无头运行简单；需要时可再迁移 GUT。 |
| core 层用 `RefCounted` + `class_name` | 可在测试里直接 new，无需场景树。test.sh 先 `--import` 以注册全局类名。 |
| 平台层用 autoload 抽象 | 之后把 GodotSteam 作为后端塞进 `Platform`，gameplay 代码不变。 |
| 游戏渲染进 SubViewport，再经全局后处理显示；鼠标坐标按同一变换（曲率 + 摇晃偏移）重映射 | 点击始终落在玩家看到的位置。`Main._crt_map` 必须与 `screen_fx.gdshader` 的 `barrel()` 一致（当前曲率为 0）。 |
| 每台示波器的屏幕单独用 SubViewport + 显像管 shader | 畸变只发生在仪器内部，中间面板保持平整；输入不经过示波器屏幕（格子位置由中间面板几何计算）。 |
| UI 全部代码构建（`_draw` + 少量 Control），不手写复杂 .tscn | 无需编辑器即可维护；占位图形以后可逐个替换成贴图。 |
| 字体：系统等宽字体 + 显式 CJK 回退字体 | 原型阶段零依赖。**上架前必须打包一款开源字体**（如 Noto Sans SC）到 `assets/fonts/main.ttf`，否则玩家机器上字体不可控。macOS 上 PingFang 不可加载，故优先 Hiragino Sans GB。 |
| 导出预设 `include_filter="data/*.json"` | JSON 不是 Godot 资源，不显式包含就不会进导出包。tests/docs/scripts 不导出。macOS 用内置 ad-hoc 签名，正式上架前再换开发者证书 + 公证。 |
| 敌我示波器上下排列而非左右，叠加面板居中 | 波轨是时间轴，上下排列时同一格上下对齐，叠加关系一眼可见；左右排列会让对应格相隔半个屏幕。 |
| 引导规则（`TutorialRules`）是纯函数，UI 只负责构建状态快照和显示 | 可测试；新增引导只改 JSON。 |
| 敌人意图被随机叠加完全抵消时重新随机 | 保证敌人每回合一定有攻击。 |
| 每张卡打出后在结算前可撤回（拿起已放置的牌 = unplay） | 拖动只有一种状态，预览统一用"假设打出"的 PlayedCard 计算。抽牌类卡打出即生效，不可撤回。 |

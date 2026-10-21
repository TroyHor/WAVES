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
- 出牌：花能量打出手牌，选择起始格 offset，P[offset + i] += wave[i]。
- 结算逐格：
  - E[t] ≠ 0：若 sign(N) == sign(E)，玩家受 |N[t]| 伤害；否则（N = 0 或反号）完全防住，溢出按 `overflow_mode` 处理（默认 `waste`）。
  - E[t] = 0：对敌人造成 |N[t]| 伤害。
- 每回合能量 `energy_per_turn` = 3，抽牌 `hand_size` = 5，玩家 HP `player_max_hp` = 60。
- 原型阶段的暂定默认（待用户确认，见 design.md「待决定问题」）：
  - 超出波轨的部分直接截断（`allow_partial_offtrack`）。
  - 结算前已放置的卡可以拖动/撤回并返还能量（`allow_reposition_before_resolve`）。
  - 单敌人战斗。

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
data/enemies/*.json      每个敌人一个文件
assets/{art,fonts,audio} 正式素材放这里；路径只在 src/autoload/assets.gd 里登记
tests/                   无头测试：run_tests.gd（运行器）、test_case.gd（断言基类）、unit/test_*.gd
scripts/                 命令行脚本：test.sh、export.sh、godot_bin.sh
docs/                    设计文档
builds/                  导出产物（git 忽略）
```

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
scripts/test.sh superposition   # 只跑名字含该词的测试
/Applications/Godot.app/Contents/MacOS/Godot --path .   # 运行游戏
```
Godot 可执行文件路径可用环境变量 `GODOT` 覆盖。

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

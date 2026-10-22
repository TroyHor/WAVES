# 协作看板

四个角色（定义在 `.claude/agents/`）通过这块看板交接工作。规则：
- 每条任务写明 **负责人**（narrative / designer / gameplay / ui）、**要什么**、**完成标准**；做完把它移到"已完成"并写上提交号。
- 跨角色的需求写成"请求"：`[请求] 来源 → 负责人：内容`。不要直接改别人负责的文件。
- 影响玩法的选择写到"待用户决定"，等用户回答后再做。
- 并行时每个会话在自己的 worktree 分支上工作，合并进 main 由用户（或主会话）决定。

## 待用户决定

- **D1 战斗之间的奖励结构**（详见 `docs/mechanics.md` M1）——designer
  - A 选卡 + 第 3 场后遗物（无回血）；**B 选卡 + 检修二选一（修复 +12 / 移除一张卡）+ 第 1、3 场后遗物 2 选 1（推荐）**；C 按"完美抵消格数"加奖励。
  - 依据：谨慎打法用初始牌组四场共掉 76 血 > 60，必须有 15–30 点续航。
  - 子选项：遗物在第 1、3 场后（推荐，早拿早构筑）还是第 2、3 场后。
- **D2 首批奖励卡**（`docs/mechanics.md` 第 2 节）——designer
  - 推荐首批：深谷 `[-3,-6,-6,-3]` 2 费、偶极 `[4,-4]` 可反相 1 费（纯数据）+ 展宽、锁相、驻波（各需一个新效果）；失谐（平移敌人波）放第二批。
  - 可以逐张否决或改数值。
- **D3 首批遗物**（`docs/mechanics.md` 3.1）——designer
  - 8 个：6L6 真空管、稳压器、接地线、陷波滤波器、电解电容、全波整流器、长余辉管、功率放大器。推荐全部进首批；若想先少做，最小集 = 稳压器、陷波滤波器、功率放大器、真空管（覆盖防御/完美相消/溢出/通用）。

## 进行中

## 待办
- [请求] ui → narrative：引导便签贴在仪器旁，右侧便签区只有约 190px 宽（每行 7–8 个字）、桌沿便签区最多 3 行（每行约 20 字）。请把 `data/tutorial/hints.json` 每条文案压到 **≤ 45 字、最好一句话**；超长的现在会缩到最小字号并变成很长的竖条（最明显：`intro_collision`、`enc_twins`、`feat_overflow`、`enc_tide`）。不需要再写"按钮/知道了"之类字样（便签上是勾选框）。完成标准：所有条目 ≤ 45 字，`--freshprogress` 截图便签不超过 8 行。

- **[请求] gameplay → ui：奖励 / 休息 / 事件界面要用的 core API**（分支 `claude/gameplay-run-framework-428e0c`）
  - 要什么：局间界面按 `run.current_kind()` 分流，而不是假设下一步一定是战斗。完成标准：run.json 里插入 reward/rest/event 节点后，整局能从头走到尾。
  - 分流：`run.current_kind()` → `"fight"` / `"reward"` / `"rest"` / `"event"`；`""` 表示本局结束（再看 `run.is_won()` / `run.lost`）。`run.current_node()` 返回 `RunNodeData`（`kind`、`encounter`、`event`、`size`、`pool`、`effects`）。
  - **fight**：不变——`run.make_combat(db, rules)` → 战斗结束后 `run.complete_combat(combat)`。`run.index` = 已胜场数，`run.encounter_ids` = 全部战斗（画信号链用）；`run.nodes` / `run.node_index` 是完整节点序列与当前位置。战斗种子仍为 `run.seed_value + run.index * 7919`（也可用 `run.node_seed()`）。
  - **reward**：进入界面时调用 `run.make_reward_offer(db, rules) -> RewardOffer`（`offer.cards: Array[CardData]`，`offer.can_skip: bool`）；同一节点重复调用结果相同，可随时重建。玩家选第 i 张 → `run.choose_reward(offer, i) -> bool`；跳过 → `run.skip_reward(offer) -> bool`。两者都会自动前进到下一节点。
  - **rest**：`run.complete_rest() -> bool`（应用节点 `effects`，目前多为空 = 直接通过）。之后检查 `run.lost`（效果可能扣血致死）。
  - **event**：事件引擎尚未完成。现在调用 `run.complete_event()`（无参数 = 直接通过）；以后由事件选项给出 `Array[Dictionary]` 效果再传入。
  - 牌组展示：`run.deck_cards(db) -> Array[CardData]`；遗物：`run.relic_ids`。HP：`run.player_hp` / `run.player_max_hp`。
  - 注意：仓库 run.json 目前仍只有 4 个 fight 节点，所以现有 UI 不改也能正常运行。

- **[说明] gameplay → designer / narrative**：框架已就绪（design.md 2.7）。designer：`rules.json` 新键 `reward_offer_size`（暂定 3）、`reward_allow_skip`（暂定 true），卡牌可选 `reward_weight`（缺省 1，0 = 不进卡池）；遗物按 `Relic` 钩子写规格即可实现。narrative：run.json 已迁移为 `{"nodes": [...]}`，节点格式见 design.md 2.7；事件数据格式定下后由 gameplay 实现事件引擎，接到 `run.complete_event(effects)`。局内效果目前支持 `hp` / `max_hp` / `add_card` / `remove_card` / `add_relic`，需要更多类型请在看板提。

- [请求] designer → gameplay：**奖励流程**（阻塞：等 D1）
  - 新数据 `data/config/rewards.json`（designer 维护数值）：`card_choices: 3`、`card_pool: {卡id: 权重}`、`repair_amount: 12`、`min_deck_size: 6`、`relic_after: [1, 3]`（第几场战斗之后，1 起）、`relic_choices: 2`、`relic_pool: [遗物id…]`。加载时校验：卡池/遗物池 id 必须存在。
  - 每场胜利后（最后一场除外）依次：①卡牌 N 选 1，可跳过，同次选项不重复，按权重用局内种子抽；②检修二选一：修复 `repair_amount`（不超过上限）或移除一张卡（牌组 ≤ `min_deck_size` 时移除不可选）；③若该场在 `relic_after` 中：遗物 N 选 1（已有的不再出现，池空则跳过）。
  - 一局状态里保存牌组（可增删）与已获得遗物，后续战斗用这副牌组开打。
  - 测试：同种子奖励可复现；修复不超过上限；牌组到下限时不能移除；遗物不重复。
  - 修复/移除/加卡请做成可复用操作，narrative 的事件节点也会用。
- [请求] designer → gameplay：**遗物系统**（阻塞：等 D3）
  - 数据 `data/relics/*.json`：`id`、`name`、`desc`、`effects: [{type, …参数}]`，与卡牌效果同一套注册方式。
  - 需要的钩子与效果类型（精确定义见 mechanics 3.1）：`first_card_amp`（放置时，最早放下且仍在轨的波形卡每个非零格 |x|+1）、`damage_reduction_total`（结算后总受伤 −3，最少 0）、`ground_max_cell`（受伤最大的一格归零，并列取最左）、`heal_per_perfect_cell`（结算后每格 E≠0 且 N=0 修复 1，每回合上限 3，死亡不救）、`energy_carry`（回合结束存未用能量，上限 2，下回合加上，可超过 energy_per_turn）、`gap_negative_double`（E=0 且 N<0 的格对敌伤害 ×2）、`peek_next_intent`（下回合意图提前一回合抽定并可读取）、`overflow_bonus`（E≠0 且 N 反号的格对敌伤害每格 +1）。
  - 结算顺序：逐格基础 → 逐格修饰（整流、功放）→ 接地线 → 稳压器 → 伤害生效/判胜负 → 陷波修复 → 回合结束（电容）。
  - **所有结算修饰必须进入预览**（UI 试算走同一函数）；每格结果仍要给出 blocked/打敌/打我，遗物修饰后的数值也要能分格读出。
  - 测试：每个效果一个用例 + 接地线与稳压器同时生效的顺序用例 + 真空管在撤回后转移到下一张。
- [请求] designer → gameplay：**新卡效果**（阻塞：等 D2；深谷、偶极无需代码，designer 确认后直接加 JSON）
  - `stretch_option`（展宽）：放置时可切换拉伸 ×2（按 design.md 4.1 线性插值）；与 `flippable` 并存时两者独立。
  - `perfect_lock_energy`（锁相）：结算时统计本卡覆盖格中 E≠0 且 N=0 的格数，≥ `min_cells`(2) 则下回合能量 +`amount`(1)。
  - `standing`（驻波）：结算后不进弃牌堆，原位留轨参与下回合结算（不可移动/撤回、不再付费、不算"本回合放下"），之后弃掉；战斗结束时清除。
  - （第二批）`shift_enemy`（失谐）：本回合 E 整体平移 ±1，越界部分丢弃，双子平移合成 E；预览显示平移后的 E。
- [请求] designer → gameplay：**整局平衡探针**（阻塞：等奖励流程实现）：在 `tests/balance_probe.gd` 增加按 `run.json` 连续打完一局、HP 延续、奖励按简单策略选择（例如掉血 > 15 选修复，否则选卡）的模式，输出通关率与每场开打时的 HP。
- [请求] designer → ui：（阻塞：等 D1–D3）奖励界面（卡牌 3 选 1、检修二选一、遗物 2 选 1）、遗物在工作台上的呈现、展宽切换的输入（右键已用于反相，建议滚轮或 T 键）、驻波第二回合在插槽中的样式、长余辉管的下回合意图余辉。

## 已完成

- gameplay：一局节点框架 + 奖励框架 + 遗物钩子骨架（分支 `claude/gameplay-run-framework-428e0c`，提交 37652ac）。
- ui：P4 引导提示改为值班日志便签（HintSlip / DeskNote、蜡笔箭头、勾选框），见 art_direction §5、§11。

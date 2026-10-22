# 协作看板

四个角色（定义在 `.claude/agents/`）通过这块看板交接工作。规则：
- 每条任务写明 **负责人**（narrative / designer / gameplay / ui）、**要什么**、**完成标准**；做完把它移到"已完成"并写上提交号。
- 跨角色的需求写成"请求"：`[请求] 来源 → 负责人：内容`。不要直接改别人负责的文件。
- 影响玩法的选择写到"待用户决定"，等用户回答后再做。
- 并行时每个会话在自己的 worktree 分支上工作，合并进 main 由用户（或主会话）决定。

## 待用户决定

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

## 已完成

- gameplay：一局节点框架 + 奖励框架 + 遗物钩子骨架（分支 `claude/gameplay-run-framework-428e0c`，提交 37652ac）。
- ui：P4 引导提示改为值班日志便签（HintSlip / DeskNote、蜡笔箭头、勾选框），见 art_direction §5、§11。

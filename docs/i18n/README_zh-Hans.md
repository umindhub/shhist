# shhist

[English](../../README.md) | [Deutsch](README_de.md) | [Español](README_es.md) | [Français](README_fr.md) | [Italiano](README_it.md) | [日本語](README_ja.md) | [한국어](README_ko.md) | [Nederlands](README_nl.md) | **简体中文** | [繁體中文](README_zh-Hant.md)

纯 zsh 实现的 Shell 历史记录与 frecency（频率 + 最近度）引擎，数据存放在 SQLite 中。
无需任何编译 —— 只要 `zsh` + `sqlite3` + `fzf`。

shhist 会记住三样东西：你执行过的**每一条命令**、进入过的**每一个目录**、碰过的**每一个文件**。
最后一项正是它的不同之处：一个文件只要在任意命令中出现过一次，之后你就可以在**任意目录**下
打开它、执行它，或把它的路径插入到新命令里，再也不用重新输入路径。

```sh
~/Downloads $ v zshrc          # 用 $EDITOR 打开 ~/.zshrc
/tmp        $ shf deploy       # 用 sh 执行 ~/work/scripts/deploy.sh
~           $ j youmind        # cd ~/Dropbox/Xcode/YouMindHub
任意目录     $ vim <Ctrl+G>     # 挑选任意常用文件，自动插入其路径
```

## 亮点

- **文件随你而行** —— 传给任意命令（`vim`、`cat`、`cp`、`python3`、`open` ……）的已存在文件，
  都会以绝对路径记录下来。此后无论身在何处，`v foo` 打开它，`shf foo` 执行它，
  `Ctrl+G` 把它插入到你正在输入的命令中。
- **与 vim、sh 无缝配合** —— `v` 启动 `$EDITOR`（默认 vim），`shf` 启动 `sh`，
  `Ctrl+G` 则可以把路径交给任何其他工具（`nvim -d`、`bash`、`zsh`、`source`、`tail -f` ……）。
- **目录跳转** —— `j proj x` 跳到最匹配 `*proj*x*` 的目录，风格类似 `fasd`/`z`。
- **永久历史** —— 每条命令连同目录、时间戳、退出码永久保存在 SQLite；
  `Ctrl+R` 可搜索全部历史，也可只看在当前目录执行过的命令。
- **Frecency** —— 近期操作和长期习惯分开计分（双半衰期，习惯按对数计入），
  新命令或新目录几分钟内就能排上来，不会被多年的历史压住。查询时惰性计算（无需任何维护任务），
  算法可按功能切换。
- **一键执行** —— 在 `Ctrl+R` 和 `Ctrl+G` 中，Enter 只插入，`ctrl-]` 插入**并立即执行**
  （可映射为 Cmd+Enter）。
- **就地删除** —— 在任意选择器中按 `ctrl-x` 删除高亮的目录、文件或命令，选择器保持打开。
- **内置行内建议** —— 来自 SQLite 的灰色提示文字，按 frecency 排序，取代 zsh-autosuggestions。
  程序或文件参数当前不存在的候选会被跳过。
- **自动忘记失败命令** —— 因程序不存在（`command not found`）或文件/目录参数缺失
  （`sh missing.sh`、`cd nope`）而失败的命令，会立即从历史中删除。
- **历史导入** —— 一次性执行 `shhist-import` 导入现有 zsh 历史，保留时间戳。

## 依赖

- zsh、[fzf](https://github.com/junegunn/fzf) >= 0.45、
  带数学函数的 sqlite3（Homebrew 版本即可）

```sh
brew install sqlite fzf
```

shhist 自带行内建议，请把 `zsh-autosuggestions` 从 oh-my-zsh 的 `plugins=(...)` 中移除。
只要它还在加载，shhist 就只为它提供数据（`SHHIST_SUGGEST_MODE`），并在启动时给出提醒。

## 安装

直接克隆到安装位置，然后运行安装脚本（它会检查依赖，并在 `~/.zshrc` 中加一行）：

```sh
git clone https://github.com/umindhub/shhist.git ~/.config/shhist
~/.config/shhist/install.sh
```

shhist 必须在 fzf 快捷键和其他插件之后加载；安装脚本会追加到 `.zshrc` 末尾，
通常就满足这一要求。更新只需：

```sh
git -C ~/.config/shhist pull
```

数据库位于安装目录之外，本地覆盖配置（`config.local.zsh`）已被 gitignore，
所以 `git pull` 永远不会碰到它们。

如果你想把仓库克隆到别处，在仓库中运行 `./install.sh`，文件会被复制到 `~/.config/shhist`
（每次 pull 后需重新运行；已存在的 `config.zsh` 永远不会被覆盖）。

然后打开新终端，可选择一次性导入现有历史：

```sh
shhist-import
```

## 用法

### 在任意目录使用文件

| 操作 | 作用 |
|---|---|
| `v` | 用 fzf 列出所有已知文件（按 frecency 排序）；Enter 用 `$EDITOR` 打开 |
| `v foo`、`v foo bar` | 用 `$EDITOR` 打开最匹配 `*foo*bar*` 的文件；无匹配时进入 fzf |
| `shf` / `shf foo` | 选择规则相同，但用 `sh` 执行该文件 |
| `v foo<Tab>` / `shf foo<Tab>` | 以 `foo` 预过滤的 fzf；仅一个匹配时立即打开/执行，否则按 Enter |
| `Ctrl+G` | 挑选常用文件，把（已加引号的）路径插入到**任意**命令的光标处；Enter = 插入，`ctrl-]` = 插入并执行 |

匹配方式是对**完整路径**做不区分大小写的子串匹配，所以 `v xcode main` 能找到
`~/Dropbox/Xcode/App/main.swift`。已不存在的文件在匹配过程中被跳过时会自动从数据库清除。

### 目录

| 操作 | 作用 |
|---|---|
| `j` | 用 fzf 列出所有已知目录（按 frecency 排序） |
| `j foo`、`j foo bar` | cd 到最匹配 `*foo*bar*` 的目录；无匹配时进入 fzf |
| `j foo<Tab>` | 以 `foo` 预过滤的 fzf；仅一个匹配时立即跳转，否则按 Enter |

### 命令历史

| 操作 | 作用 |
|---|---|
| `Ctrl+R` | 用 fzf 搜索 SQLite 历史，预填已输入的内容；Enter = 插入，`ctrl-]` = 插入并执行 |
| `ctrl-t`（在 `Ctrl+R` 中） | 在“所有目录”与“**当前目录**执行过的命令”之间切换 |
| `shhist-import` | 一次性导入现有 zsh 历史（数据库非空时用 `-f` 强制导入） |

重复命令会合并，并按 frecency 排序（见“排序”）。多行命令显示为一行（`⏎`），插入时原样还原。

### 所有选择器通用

| 按键 | 作用 |
|---|---|
| `Enter` | 选中 |
| `ctrl-x` | 从数据库删除高亮的目录 / 文件 / 命令；选择器保持打开 |

在 `Ctrl+R` 中，`ctrl-x` 会删除该命令的所有记录。

## 实用组合

### 与 vim 配合

```sh
v vimrc                  # 在任意目录编辑 ~/.vimrc（只要曾执行过 `vim ~/.vimrc`）
v                        # 浏览最近文件，Enter 打开所选
vim -d <Ctrl+G> <Ctrl+G> # 对比两个最近文件（中间手动输入空格）
vim -O <Ctrl+G> <Ctrl+G> # 左右分屏打开两个最近文件
v myapp main             # 完整路径匹配：myapp 中的 main 文件
```

`v` 执行的是 `${EDITOR:-vim}`。想用 Neovim，在 `.zshrc` 中设置 `export EDITOR=nvim`
（`$EDITOR` 会被当作单个命令调用，像 `code --wait` 这类需要参数的编辑器，请指向一个小包装脚本）。
如果 `v` 与其他命令冲突，可通过 `SHHIST_EDIT_CMD` 改名。

### 与 sh 和脚本配合

```sh
shf deploy               # 在任意目录执行 ~/work/scripts/deploy.sh
shf                      # 浏览最近文件，Enter 执行所选
bash <Ctrl+G> --prod     # 换解释器，并附加参数
python3 <Ctrl+G>         # Python、Node、Ruby 等同理
source <Ctrl+G>          # 把环境/别名文件加载到当前 shell
sh <Ctrl+G>, ctrl-]      # 选中即执行，一气呵成
```

`shf` 总是用 `sh`（POSIX sh，忽略 shebang）在你的**当前**目录执行文件，且不接受额外参数 ——
所有词都是搜索关键词。对于仅限 bash/zsh 的脚本、需要参数或其他解释器的情况，
请在相应命令之后使用 `Ctrl+G`。

### 日常组合

```sh
cp <Ctrl+G> .            # 把最近文件复制到当前目录
tail -f <Ctrl+G>         # 追踪之前看过的日志
open <Ctrl+G>            # 用 macOS 默认应用打开
less <Ctrl+G>            # 分页查看最近文件
cd ~/project; <Ctrl+R> ctrl-t   # 找回在这个目录执行过的命令
```

`Ctrl+G` 在光标处追加，不影响行内其余内容，所以一条命令里可以多次使用。

## 记录规则

- **命令** —— 每条命令都与其目录、时间戳、退出码一起保存。以**空格**开头的命令视为私密：
  命令本身及其中的文件都不会记录。
- **目录** —— 每次目录切换（`cd`、`pushd`、`j`、auto_cd）都会给该目录加分。
- **文件** —— 每条命令最多检查 8 个既非选项（`-x`）也非赋值（`a=b`）的参数；
  其中真实存在的普通文件按绝对路径保存（去掉引号、展开 `~`、解析符号链接）。
  未展开的通配符和目录不计为文件。
- **导入** —— `shhist-import` 只导入命令文本和时间戳，不会填充目录/文件排名；
  导入的命令没有目录信息，因此只出现在 `ctrl-t` 的“所有目录”视图中。

### 排序

每次执行或访问的价值，等于现在一次的 `0.5 ^ (经过时间 / half_life)`。
每条命令、每个目录和文件都维护两个这样的累计值：**S_short**（半衰期 6 小时：你当前正在做的事）
和 **S_long**（目录 / 文件 / 命令的半衰期分别为 7 / 3 / 14 天：长期习惯）。
默认得分为 `2 × S_short + log2(1 + S_long)`。

近期操作按次数完整计分，长期习惯只按对数计分：上个月执行过 200 次的命令约 7 分，
最近一小时执行了 3 次的命令约 8 分。习惯依然能压过偶尔执行一次的命令，但不会再把新命令埋没。

| 算法 | 得分 |
|---|---|
| `duallog`（默认） | `W × S_short + log2(1 + S_long)` |
| `dual` | `W × S_short + S_long` |
| `single` | `S_long`（之前的行为） |
| `seg` | 次数 × 最近一次访问所在时间段的权重（zoxide 风格，`SHHIST_RANK_SEGS`） |
| `recent` | 最近的在前（zsh-autosuggestions / 原来的 `Ctrl+R`） |

`SHHIST_RANK` 统一设定算法；`SHHIST_SUGGEST_RANK`、`SHHIST_HISTORY_RANK`（`Ctrl+R`）、
`SHHIST_JUMP_RANK`（`j`）和 `SHHIST_FILE_RANK`（`v`、`shf`、`Ctrl+G`）可按功能单独覆盖。
切换前可以先用自己的数据对比：

```sh
shhist-rank git                  # suggestion order for "git..."
shhist-rank -a single git        # same prefix, previous algorithm
shhist-rank                      # whole history, i.e. Ctrl+R order
shhist-rank -k dir -a seg proj   # what `j proj` would pick with seg
```

衰减在查询时计算，因此修改半衰期或算法会立即作用于全部已有数据。旧版本的数据库会在首次启动时自动升级；
目录/文件的短期得分和访问次数先用估算值，随着继续使用会逐渐变得准确。

## 行内建议

输入时，最匹配的历史命令会以灰色文字显示在光标之后。→ / End 接受整条，
Ctrl+F 或 Alt+→（`forward-word`）接受下一个单词；在行内其他位置，这些键保持原功能
（Ctrl+F 仍然右移一个字符）。浏览历史（↑、`Ctrl+R`）之后不显示建议，直到你再次输入。
如果候选命令的程序无法解析，或路径参数在当前目录下不存在，它会被跳过（不会被删除）——
之后它可能又能用了，例如激活 venv 之后。

## 忘记失败的命令

命令以 1-127 退出时，shhist 会检查原因：

- **程序不存在**（`gti status`、不存在的 `./build.sh`）—— 删除该命令的所有记录；
- **绝对路径 / `~` 路径不存在**（`cat ~/gone.txt`）—— 删除所有记录；
- **相对路径不存在**（`sh missing.sh`、`cd nope`）—— 只删除在该目录下记录的那些。

路径识别是保守的：解释器的脚本参数（`sh`、`python3`、`node` …… —— `SHHIST_INTERP_CMDS`）、
文件类命令的所有参数（`cd`、`cat`、`vim` …… —— `SHHIST_PATH_CMDS`），以及以 `/`、`~/`、`./`、`../`
开头的单词。参数是匹配模式、URL 或尚未创建的目标的工具（`git`、`grep`、`mkdir`、`cp` …… ——
`SHHIST_NOCHECK_CMDS`）永远不做路径检查。Ctrl+C 等信号（退出码 >= 128）永远不算失败。

对于更早记录的（或导入的）历史，可以批量执行同样的检查：

```sh
shhist-clean -n    # 预览
shhist-clean       # 删除
```

## 配置

默认值位于 `config.zsh`（纳入版本控制）。把覆盖项写在
`~/.config/shhist/config.local.zsh`（已 gitignore，在默认值之后加载），
这样 `git pull` 永远不会冲突 —— 只需重新 export 想修改的变量：

```zsh
# ~/.config/shhist/config.local.zsh
export SHHIST_JUMP_CMD="z"
export SHHIST_EDIT_CMD="e"
export SHHIST_ESC_TIMEOUT_MS=10
export SHHIST_HALFLIFE_DIR=$((14 * 24 * 3600))
```

| 配置项 | 默认值 | 含义 |
|---|---|---|
| `SHHIST_DATA_DIR` / `SHHIST_DB` | `~/.config/shhist-data/history.db` | 历史数据位置 |
| `SHHIST_SQLITE` | 自动检测 | 带数学函数的 sqlite3 程序 |
| `SHHIST_JUMP_CMD` / `SHHIST_EDIT_CMD` / `SHHIST_SH_CMD` | `j` / `v` / `shf` | 命令名 |
| `SHHIST_BIND_HISTORY` / `SHHIST_BIND_FILE` | `^R` / `^G` | 组件快捷键 |
| `SHHIST_BIND_TAB` | `^I` | `j`/`v`/`shf` 行上的 Tab 选择器（`''` 关闭） |
| `SHHIST_FILE_RUN_KEY` | `ctrl-]` | `Ctrl+R` / `Ctrl+G` 中的插入并执行键 |
| `SHHIST_DELETE_KEY` | `ctrl-x` | 所有选择器中的删除键 |
| `SHHIST_SUGGEST` | `1` | 内置行内建议（`0` 关闭） |
| `SHHIST_SUGGEST_STYLE` | `fg=8` | 建议文字的高亮样式 |
| `SHHIST_BIND_ACCEPT_WORD` | `^F` | 接受建议的下一个单词（`''` 关闭） |
| `SHHIST_SUGGEST_CANDIDATES` | `20` | 每次查询检查的候选数 |
| `SHHIST_SUGGEST_ACCEPT_WIDGETS` / `_PARTIAL_WIDGETS` | `forward-char` … / `forward-word` … | 接受整条 / 一个单词的组件 |
| `SHHIST_SUGGEST_MODE` | `B` | 仅在 zsh-autosuggestions 仍加载时生效：`A` sqlite / `B` zsh 历史 / `AB` 两者 |
| `SHHIST_PRUNE_FAILED` | `1` | 忘记因程序或路径缺失而失败的命令 |
| `SHHIST_INTERP_CMDS` / `SHHIST_PATH_CMDS` / `SHHIST_NOCHECK_CMDS` | 见 `config.zsh` | 参数的路径检查方式 |
| `SHHIST_RANK` | `duallog` | 排序算法（见“排序”） |
| `SHHIST_SUGGEST_RANK` / `_HISTORY_RANK` / `_JUMP_RANK` / `_FILE_RANK` | `''` | 按功能覆盖（`''` = `SHHIST_RANK`） |
| `SHHIST_RANK_SHORT_WEIGHT` | `2` | `duallog` / `dual` 中的 W |
| `SHHIST_RANK_SEGS` | `(3600:4 86400:2 604800:0.5 0.25)` | `seg` 的时间段（`max_age:weight`，最后是默认权重） |
| `SHHIST_HALFLIFE_DIR` / `_FILE` / `_CMD` | 7 / 3 / 14 天 | 长期半衰期（秒） |
| `SHHIST_HALFLIFE_DIR_SHORT` / `_FILE_SHORT` / `_CMD_SHORT` | 6 小时 | 短期半衰期（秒） |
| `SHHIST_TRACK_EXIT` | `1` | 记录退出码 |
| `SHHIST_FZF_LIMIT` | `20000` | `Ctrl+R` 最多载入的行数 |
| `SHHIST_FZF_OPTS` | `--height=60% --reverse --border` | 所有选择器的额外 fzf 参数 |
| `SHHIST_ESC_FIX` / `SHHIST_ESC_TIMEOUT_MS` | `1` / `10` | emacs 模式下让单独的 ESC 不再吞键 |

### 把 Cmd+Enter 设为执行键

终端永远不会转发 Cmd 键，因此需要映射为发送字节 `0x1D`（`ctrl-]`）：

- **iTerm2**：Settings → Profiles → Keys → Key Mappings → `+` → Cmd+Enter →
  “Send Hex Codes” → `0x1D`
- **kitty**：`map cmd+enter send_text all \x1d`

## 数据

数据库是单个 SQLite 文件，刻意放在安装目录**之外**（默认 `~/.config/shhist-data/history.db`）——
删除或重装 shhist 都不会影响你的历史。可以直接备份、查看，或用 `sqlite3` 查询：

```sh
sqlite3 ~/.config/shhist-data/history.db \
  "SELECT cmd FROM commands WHERE exit_code != 0 ORDER BY ts DESC LIMIT 20;"
```

## 卸载

```sh
~/.config/shhist/uninstall.sh
```

会删除安装目录（`core.zsh`、`widgets.zsh`、`suggest.zsh`、`config.zsh`、你的 `config.local.zsh`）
以及 `~/.zshrc` 中的 source 行。历史数据库默认保留 —— 以后重装会自动接上。
加 `--purge-data` 连同数据库一起删除，加 `-f` 跳过确认：

```sh
~/.config/shhist/uninstall.sh -f --purge-data   # 全部删除，不保留数据库
```

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
- **Frecency** —— 查询时惰性计算的指数时间衰减（无需任何维护任务），
  半衰期可按类型（目录 / 文件 / 建议）分别配置。
- **一键执行** —— 在 `Ctrl+R` 和 `Ctrl+G` 中，Enter 只插入，`ctrl-]` 插入**并立即执行**
  （可映射为 Cmd+Enter）。
- **就地删除** —— 在任意选择器中按 `ctrl-x` 删除高亮的目录、文件或命令，选择器保持打开。
- **zsh-autosuggestions 数据源** —— 基于 SQLite 中衰减后的频率给出建议。
- **历史导入** —— 一次性执行 `shhist-import` 导入现有 zsh 历史，保留时间戳。

## 依赖

- zsh、[fzf](https://github.com/junegunn/fzf) >= 0.45、
  带数学函数的 sqlite3（Homebrew 版本即可）
- 可选：[zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions)，用于建议数据源

```sh
brew install sqlite fzf zsh-autosuggestions
```

## 安装

直接克隆到安装位置，然后运行安装脚本（它会检查依赖，并在 `~/.zshrc` 中加一行）：

```sh
git clone https://github.com/umindhub/shhist.git ~/.config/shhist
~/.config/shhist/install.sh
```

shhist 必须在 fzf 快捷键和 zsh-autosuggestions 之后加载；安装脚本会追加到 `.zshrc` 末尾，
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

重复命令会合并，并按最后使用时间排序。多行命令显示为一行（`⏎`），插入时原样还原。

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

N 秒前的一次访问，价值等于现在一次访问的 `0.5 ^ (N / half_life)`。
衰减在查询时计算，因此修改半衰期会立即作用于全部已有数据。

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
| `SHHIST_SUGGEST_MODE` | `B` | 自动建议：`A` sqlite / `B` zsh 历史 / `AB` 先 sqlite 后历史 |
| `SHHIST_HALFLIFE_DIR` / `_FILE` / `_CMD` | 7 / 3 / 14 天 | frecency 半衰期（秒） |
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

会删除安装目录（`core.zsh`、`widgets.zsh`、`config.zsh`、你的 `config.local.zsh`）
以及 `~/.zshrc` 中的 source 行。历史数据库默认保留 —— 以后重装会自动接上。
加 `--purge-data` 连同数据库一起删除，加 `-f` 跳过确认：

```sh
~/.config/shhist/uninstall.sh -f --purge-data   # 全部删除，不保留数据库
```

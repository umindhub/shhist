# shhist

[English](../../README.md) | [Deutsch](README_de.md) | [Español](README_es.md) | [Français](README_fr.md) | [Italiano](README_it.md) | [日本語](README_ja.md) | [한국어](README_ko.md) | [Nederlands](README_nl.md) | [简体中文](README_zh-Hans.md) | **繁體中文**

純 zsh 實現的 Shell 歷史記錄與 frecency（頻率 + 最近度）引擎，資料存放在 SQLite 中。
無需任何編譯 —— 只要 `zsh` + `sqlite3` + `fzf`。

shhist 會記住三樣東西：你執行過的**每一條命令**、進入過的**每一個目錄**、碰過的**每一個檔案**。
最後一項正是它的不同之處：一個檔案只要在任意命令中出現過一次，之後你就可以在**任意目錄**下
開啟它、執行它，或把它的路徑插入到新命令裡，再也不用重新輸入路徑。

```sh
~/Downloads $ v zshrc          # 用 $EDITOR 開啟 ~/.zshrc
/tmp        $ shf deploy       # 用 sh 執行 ~/work/scripts/deploy.sh
~           $ j youmind        # cd ~/Dropbox/Xcode/YouMindHub
任意目錄     $ vim <Ctrl+G>     # 挑選任意常用檔案，自動插入其路徑
```

## 亮點

- **檔案隨你而行** —— 傳給任意命令（`vim`、`cat`、`cp`、`python3`、`open` ……）的已存在檔案，
  都會以絕對路徑記錄下來。此後無論身在何處，`v foo` 開啟它，`shf foo` 執行它，
  `Ctrl+G` 把它插入到你正在輸入的命令中。
- **與 vim、sh 無縫配合** —— `v` 啟動 `$EDITOR`（預設 vim），`shf` 啟動 `sh`，
  `Ctrl+G` 則可以把路徑交給任何其他工具（`nvim -d`、`bash`、`zsh`、`source`、`tail -f` ……）。
- **目錄跳轉** —— `j proj x` 跳到最匹配 `*proj*x*` 的目錄，風格類似 `fasd`/`z`。
- **永久歷史** —— 每條命令連同目錄、時間戳、退出碼永久儲存在 SQLite；
  `Ctrl+R` 可搜尋全部歷史，也可只看在當前目錄執行過的命令。
- **Frecency** —— 查詢時惰性計算的指數時間衰減（無需任何維護任務），
  半衰期可按類型（目錄 / 檔案 / 建議）分別配置。
- **一鍵執行** —— 在 `Ctrl+R` 和 `Ctrl+G` 中，Enter 只插入，`ctrl-]` 插入**並立即執行**
  （可對映為 Cmd+Enter）。
- **就地刪除** —— 在任意選擇器中按 `ctrl-x` 刪除高亮的目錄、檔案或命令，選擇器保持開啟。
- **zsh-autosuggestions 資料來源** —— 基於 SQLite 中衰減後的頻率給出建議。
- **歷史匯入** —— 一次性執行 `shhist-import` 匯入現有 zsh 歷史，保留時間戳。

## 依賴

- zsh、[fzf](https://github.com/junegunn/fzf) >= 0.45、
  帶數學函式的 sqlite3（Homebrew 版本即可）
- 可選：[zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions)，用於建議資料來源

```sh
brew install sqlite fzf zsh-autosuggestions
```

## 安裝

直接克隆到安裝位置，然後執行安裝腳本（它會檢查依賴，並在 `~/.zshrc` 中加一行）：

```sh
git clone https://github.com/umindhub/shhist.git ~/.config/shhist
~/.config/shhist/install.sh
```

shhist 必須在 fzf 快捷鍵和 zsh-autosuggestions 之後載入；安裝腳本會追加到 `.zshrc` 末尾，
通常就滿足這一要求。更新只需：

```sh
git -C ~/.config/shhist pull
```

資料庫位於安裝目錄之外，本地覆蓋配置（`config.local.zsh`）已被 gitignore，
所以 `git pull` 永遠不會碰到它們。

如果你想把儲存庫克隆到別處，在儲存庫中執行 `./install.sh`，檔案會被複製到 `~/.config/shhist`
（每次 pull 後需重新執行；已存在的 `config.zsh` 永遠不會被覆蓋）。

然後開啟新終端，可選擇一次性匯入現有歷史：

```sh
shhist-import
```

## 用法

### 在任意目錄使用檔案

| 操作 | 作用 |
|---|---|
| `v` | 用 fzf 列出所有已知檔案（按 frecency 排序）；Enter 用 `$EDITOR` 開啟 |
| `v foo`、`v foo bar` | 用 `$EDITOR` 開啟最匹配 `*foo*bar*` 的檔案；無匹配時進入 fzf |
| `shf` / `shf foo` | 選擇規則相同，但用 `sh` 執行該檔案 |
| `v foo<Tab>` / `shf foo<Tab>` | 以 `foo` 預過濾的 fzf；僅一個匹配時立即開啟/執行，否則按 Enter |
| `Ctrl+G` | 挑選常用檔案，把（已加引號的）路徑插入到**任意**命令的游標處；Enter = 插入，`ctrl-]` = 插入並執行 |

匹配方式是對**完整路徑**做不區分大小寫的子串匹配，所以 `v xcode main` 能找到
`~/Dropbox/Xcode/App/main.swift`。已不存在的檔案在匹配過程中被跳過時會自動從資料庫清除。

### 目錄

| 操作 | 作用 |
|---|---|
| `j` | 用 fzf 列出所有已知目錄（按 frecency 排序） |
| `j foo`、`j foo bar` | cd 到最匹配 `*foo*bar*` 的目錄；無匹配時進入 fzf |
| `j foo<Tab>` | 以 `foo` 預過濾的 fzf；僅一個匹配時立即跳轉，否則按 Enter |

### 命令歷史

| 操作 | 作用 |
|---|---|
| `Ctrl+R` | 用 fzf 搜尋 SQLite 歷史，預填已輸入的內容；Enter = 插入，`ctrl-]` = 插入並執行 |
| `ctrl-t`（在 `Ctrl+R` 中） | 在「所有目錄」與「**當前目錄**執行過的命令」之間切換 |
| `shhist-import` | 一次性匯入現有 zsh 歷史（資料庫非空時用 `-f` 強制匯入） |

重複命令會合併，並按最後使用時間排序。多行命令顯示為一行（`⏎`），插入時原樣還原。

### 所有選擇器通用

| 按鍵 | 作用 |
|---|---|
| `Enter` | 選中 |
| `ctrl-x` | 從資料庫刪除高亮的目錄 / 檔案 / 命令；選擇器保持開啟 |

在 `Ctrl+R` 中，`ctrl-x` 會刪除該命令的所有記錄。

## 實用組合

### 與 vim 配合

```sh
v vimrc                  # 在任意目錄編輯 ~/.vimrc（只要曾執行過 `vim ~/.vimrc`）
v                        # 瀏覽最近檔案，Enter 開啟所選
vim -d <Ctrl+G> <Ctrl+G> # 對比兩個最近檔案（中間手動輸入空格）
vim -O <Ctrl+G> <Ctrl+G> # 左右分屏開啟兩個最近檔案
v myapp main             # 完整路徑匹配：myapp 中的 main 檔案
```

`v` 執行的是 `${EDITOR:-vim}`。想用 Neovim，在 `.zshrc` 中設定 `export EDITOR=nvim`
（`$EDITOR` 會被當作單個命令呼叫，像 `code --wait` 這類需要參數的編輯器，請指向一個小包裝腳本）。
如果 `v` 與其他命令衝突，可透過 `SHHIST_EDIT_CMD` 改名。

### 與 sh 和腳本配合

```sh
shf deploy               # 在任意目錄執行 ~/work/scripts/deploy.sh
shf                      # 瀏覽最近檔案，Enter 執行所選
bash <Ctrl+G> --prod     # 換直譯器，並附加參數
python3 <Ctrl+G>         # Python、Node、Ruby 等同理
source <Ctrl+G>          # 把環境/別名檔案載入到當前 shell
sh <Ctrl+G>, ctrl-]      # 選中即執行，一氣呵成
```

`shf` 總是用 `sh`（POSIX sh，忽略 shebang）在你的**當前**目錄執行檔案，且不接受額外參數 ——
所有詞都是搜尋關鍵詞。對於僅限 bash/zsh 的腳本、需要參數或其他直譯器的情況，
請在相應命令之後使用 `Ctrl+G`。

### 日常組合

```sh
cp <Ctrl+G> .            # 把最近檔案複製到當前目錄
tail -f <Ctrl+G>         # 追蹤之前看過的日誌
open <Ctrl+G>            # 用 macOS 預設應用開啟
less <Ctrl+G>            # 分頁檢視最近檔案
cd ~/project; <Ctrl+R> ctrl-t   # 找回在這個目錄執行過的命令
```

`Ctrl+G` 在游標處追加，不影響行內其餘內容，所以一條命令裡可以多次使用。

## 記錄規則

- **命令** —— 每條命令都與其目錄、時間戳、退出碼一起儲存。以**空格**開頭的命令視為私密：
  命令本身及其中的檔案都不會記錄。
- **目錄** —— 每次目錄切換（`cd`、`pushd`、`j`、auto_cd）都會給該目錄加分。
- **檔案** —— 每條命令最多檢查 8 個既非選項（`-x`）也非賦值（`a=b`）的參數；
  其中真實存在的普通檔案按絕對路徑儲存（去掉引號、展開 `~`、解析符號連結）。
  未展開的萬用字元和目錄不計為檔案。
- **匯入** —— `shhist-import` 只匯入命令文本和時間戳，不會填充目錄/檔案排名；
  匯入的命令沒有目錄資訊，因此只出現在 `ctrl-t` 的「所有目錄」檢視中。

N 秒前的一次訪問，價值等於現在一次訪問的 `0.5 ^ (N / half_life)`。
衰減在查詢時計算，因此修改半衰期會立即作用於全部已有資料。

## 配置

預設值位於 `config.zsh`（納入版本控制）。把覆蓋項寫在
`~/.config/shhist/config.local.zsh`（已 gitignore，在預設值之後載入），
這樣 `git pull` 永遠不會衝突 —— 只需重新 export 想修改的變數：

```zsh
# ~/.config/shhist/config.local.zsh
export SHHIST_JUMP_CMD="z"
export SHHIST_EDIT_CMD="e"
export SHHIST_ESC_TIMEOUT_MS=10
export SHHIST_HALFLIFE_DIR=$((14 * 24 * 3600))
```

| 配置項 | 預設值 | 含義 |
|---|---|---|
| `SHHIST_DATA_DIR` / `SHHIST_DB` | `~/.config/shhist-data/history.db` | 歷史資料位置 |
| `SHHIST_SQLITE` | 自動檢測 | 帶數學函式的 sqlite3 程式 |
| `SHHIST_JUMP_CMD` / `SHHIST_EDIT_CMD` / `SHHIST_SH_CMD` | `j` / `v` / `shf` | 命令名 |
| `SHHIST_BIND_HISTORY` / `SHHIST_BIND_FILE` | `^R` / `^G` | 元件快捷鍵 |
| `SHHIST_BIND_TAB` | `^I` | `j`/`v`/`shf` 行上的 Tab 選擇器（`''` 關閉） |
| `SHHIST_FILE_RUN_KEY` | `ctrl-]` | `Ctrl+R` / `Ctrl+G` 中的插入並執行鍵 |
| `SHHIST_DELETE_KEY` | `ctrl-x` | 所有選擇器中的刪除鍵 |
| `SHHIST_SUGGEST_MODE` | `B` | 自動建議：`A` sqlite / `B` zsh 歷史 / `AB` 先 sqlite 後歷史 |
| `SHHIST_HALFLIFE_DIR` / `_FILE` / `_CMD` | 7 / 3 / 14 天 | frecency 半衰期（秒） |
| `SHHIST_TRACK_EXIT` | `1` | 記錄退出碼 |
| `SHHIST_FZF_LIMIT` | `20000` | `Ctrl+R` 最多載入的行數 |
| `SHHIST_FZF_OPTS` | `--height=60% --reverse --border` | 所有選擇器的額外 fzf 參數 |
| `SHHIST_ESC_FIX` / `SHHIST_ESC_TIMEOUT_MS` | `1` / `10` | emacs 模式下讓單獨的 ESC 不再吞鍵 |

### 把 Cmd+Enter 設為執行鍵

終端永遠不會轉發 Cmd 鍵，因此需要對映為傳送位元組 `0x1D`（`ctrl-]`）：

- **iTerm2**：Settings → Profiles → Keys → Key Mappings → `+` → Cmd+Enter →
  「Send Hex Codes」 → `0x1D`
- **kitty**：`map cmd+enter send_text all \x1d`

## 資料

資料庫是單個 SQLite 檔案，刻意放在安裝目錄**之外**（預設 `~/.config/shhist-data/history.db`）——
刪除或重灌 shhist 都不會影響你的歷史。可以直接備份、檢視，或用 `sqlite3` 查詢：

```sh
sqlite3 ~/.config/shhist-data/history.db \
  "SELECT cmd FROM commands WHERE exit_code != 0 ORDER BY ts DESC LIMIT 20;"
```

## 解除安裝

```sh
~/.config/shhist/uninstall.sh
```

會刪除安裝目錄（`core.zsh`、`widgets.zsh`、`config.zsh`、你的 `config.local.zsh`）
以及 `~/.zshrc` 中的 source 行。歷史資料庫預設保留 —— 以後重灌會自動接上。
加 `--purge-data` 連同資料庫一起刪除，加 `-f` 跳過確認：

```sh
~/.config/shhist/uninstall.sh -f --purge-data   # 全部刪除，不保留資料庫
```

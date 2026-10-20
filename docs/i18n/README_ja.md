# shhist

[English](../../README.md) | [Deutsch](README_de.md) | [Español](README_es.md) | [Français](README_fr.md) | [Italiano](README_it.md) | **日本語** | [한국어](README_ko.md) | [Nederlands](README_nl.md) | [简体中文](README_zh-Hans.md) | [繁體中文](README_zh-Hant.md)

SQLite をバックエンドにした、純粋な zsh 製のシェル履歴 & frecency（頻度 + 最近度）エンジン。
コンパイル不要 —— 必要なのは `zsh` + `sqlite3` + `fzf` だけです。

shhist は 3 つのものを記憶します：実行した**すべてのコマンド**、移動した**すべてのディレクトリ**、
そして触れた**すべてのファイル**。最後の 1 つが他との違いです。一度でもコマンドに登場したファイルは、
**どのディレクトリからでも**、パスを打ち直すことなく開く・実行する・新しいコマンドに挿入することができます。

```sh
~/Downloads $ v zshrc          # ~/.zshrc を $EDITOR で開く
/tmp        $ shf deploy       # ~/work/scripts/deploy.sh を sh で実行
~           $ j youmind        # cd ~/Dropbox/Xcode/YouMindHub
どこでも     $ vim <Ctrl+G>     # よく使うファイルを選ぶとパスが挿入される
```

## 特長

- **ファイルがどこへでもついてくる** —— 任意のコマンド（`vim`、`cat`、`cp`、`python3`、`open` など）に
  渡された既存ファイルは、絶対パスで記録されます。以後はどこにいても、`v foo` で開き、
  `shf foo` で実行し、`Ctrl+G` で入力中のコマンドに挿入できます。
- **vim・sh との連携** —— `v` は `$EDITOR`（デフォルトは vim）を、`shf` は `sh` を起動します。
  `Ctrl+G` を使えば他のどんなツールにもパスを渡せます（`nvim -d`、`bash`、`zsh`、`source`、`tail -f` など）。
- **ディレクトリジャンプ** —— `j proj x` で `*proj*x*` に最もよく一致するディレクトリへ移動（`fasd`/`z` 風）。
- **永久履歴** —— すべてのコマンドをディレクトリ・タイムスタンプ・終了コードとともに SQLite に永久保存。
  `Ctrl+R` で全履歴、または現在のディレクトリで実行したコマンドだけを検索できます。
- **Frecency** —— クエリ時に遅延計算される指数的な時間減衰（メンテナンス処理は不要）。
  半減期は種類ごと（ディレクトリ / ファイル / サジェスト）に設定可能。
- **ワンストローク実行** —— `Ctrl+R` と `Ctrl+G` では Enter で挿入、`ctrl-]` で挿入**して即実行**
  （Cmd+Enter に割り当て可能）。
- **その場で削除** —— どのピッカーでも `ctrl-x` でハイライト中のディレクトリ・ファイル・コマンドを削除。
  ピッカーは開いたままです。
- **zsh-autosuggestions のソース** —— SQLite 上の減衰済み頻度でサジェストを順位付け。
- **履歴のインポート** —— `shhist-import` で既存の zsh 履歴を一括取り込み（タイムスタンプ保持）。

## 必要環境

- zsh、[fzf](https://github.com/junegunn/fzf) >= 0.45、
  数学関数付きでビルドされた sqlite3（Homebrew 版で OK）
- 任意：サジェストのソースとして [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions)

```sh
brew install sqlite fzf zsh-autosuggestions
```

## インストール

インストール先に直接 clone し、インストーラを実行します（依存関係をチェックし、`~/.zshrc` に 1 行追加します）：

```sh
git clone https://github.com/umindhub/shhist.git ~/.config/shhist
~/.config/shhist/install.sh
```

shhist は fzf のキーバインドと zsh-autosuggestions の後に読み込む必要があります。
インストーラは `.zshrc` の末尾に追記するので、通常はこれで条件を満たします。更新は次のとおり：

```sh
git -C ~/.config/shhist pull
```

データベースはインストールディレクトリの外にあり、ローカル設定（`config.local.zsh`）は
gitignore されているため、`git pull` がそれらに触れることはありません。

別の場所に clone したい場合は、そこで `./install.sh` を実行すると `~/.config/shhist` に
ファイルがコピーされます（pull のたびに再実行。既存の `config.zsh` は上書きされません）。

新しいターミナルを開き、必要なら既存の履歴を一度だけインポートします：

```sh
shhist-import
```

## 使い方

### どのディレクトリからでもファイルを扱う

| 操作 | 動作 |
|---|---|
| `v` | 既知のファイルを frecency 順に fzf で表示。Enter で `$EDITOR` で開く |
| `v foo`、`v foo bar` | `*foo*bar*` に最もよく一致するファイルを `$EDITOR` で開く。一致しなければ fzf に移行 |
| `shf` / `shf foo` | 選び方は同じで、ファイルを `sh` で実行 |
| `v foo<Tab>` / `shf foo<Tab>` | `foo` で絞り込んだ fzf。候補が 1 つなら即座に開く/実行、それ以外は Enter で |
| `Ctrl+G` | よく使うファイルを選び、（クォート済みの）パスを**任意の**コマンドのカーソル位置に挿入。Enter = 挿入、`ctrl-]` = 挿入 + 実行 |

マッチングは**フルパス**に対する大文字小文字を区別しない部分一致なので、`v xcode main` で
`~/Dropbox/Xcode/App/main.swift` が見つかります。もう存在しないファイルは、検索中にスキップされた時点で
データベースから削除されます。

### ディレクトリ

| 操作 | 動作 |
|---|---|
| `j` | 既知のディレクトリを frecency 順に fzf で表示 |
| `j foo`、`j foo bar` | `*foo*bar*` に最もよく一致するディレクトリへ cd。一致しなければ fzf に移行 |
| `j foo<Tab>` | `foo` で絞り込んだ fzf。候補が 1 つなら即ジャンプ、それ以外は Enter で |

### コマンド履歴

| 操作 | 動作 |
|---|---|
| `Ctrl+R` | SQLite の履歴を fzf で検索（入力中の内容が初期クエリ）。Enter = 挿入、`ctrl-]` = 挿入 + 実行 |
| `ctrl-t`（`Ctrl+R` 内） | 全ディレクトリ ⇔ **現在のディレクトリ**で実行したコマンドを切り替え |
| `shhist-import` | 既存の zsh 履歴を一括インポート（DB が空でない場合は `-f`） |

重複はまとめられ、最終使用順に並びます。複数行のコマンドは 1 行（`⏎`）で表示されますが、
挿入時は入力したとおりに復元されます。

### すべてのピッカー共通

| キー | 動作 |
|---|---|
| `Enter` | 選択 |
| `ctrl-x` | ハイライト中のディレクトリ / ファイル / コマンドを DB から削除。ピッカーは開いたまま |

`Ctrl+R` では、`ctrl-x` はそのコマンドのすべての記録を削除します。

## 活用レシピ

### vim と組み合わせる

```sh
v vimrc                  # どこからでも ~/.vimrc を編集（一度 `vim ~/.vimrc` していれば）
v                        # 最近のファイルを一覧、Enter で開く
vim -d <Ctrl+G> <Ctrl+G> # 最近のファイル 2 つを diff（間のスペースは手入力）
vim -O <Ctrl+G> <Ctrl+G> # 最近のファイル 2 つを左右に並べて開く
v myapp main             # フルパス一致：myapp 内の main ファイル
```

`v` は `${EDITOR:-vim}` を実行します。Neovim を使うなら `.zshrc` で `export EDITOR=nvim` を設定してください
（`$EDITOR` は単一のコマンドとして呼ばれるため、`code --wait` のように引数が必要なエディタは
小さなラッパースクリプトを指定してください）。`v` が他と衝突する場合は `SHHIST_EDIT_CMD` で名前を変更できます。

### sh・スクリプトと組み合わせる

```sh
shf deploy               # どこからでも ~/work/scripts/deploy.sh を実行
shf                      # 最近のファイルを一覧、Enter で実行
bash <Ctrl+G> --prod     # 別のインタプリタ + 追加引数
python3 <Ctrl+G>         # Python、Node、Ruby なども同様
source <Ctrl+G>          # 環境変数/エイリアスのファイルを現在のシェルに読み込む
sh <Ctrl+G>, ctrl-]      # 選んで即実行、ワンストローク
```

`shf` は常に `sh`（POSIX sh。shebang は無視）で、**現在の**ディレクトリでファイルを実行し、
追加の引数は受け取りません —— 単語はすべて検索語になります。bash/zsh 専用のスクリプト、
引数が必要な場合、他のインタプリタを使う場合は、そのコマンドの後で `Ctrl+G` を使ってください。

### 日常の組み合わせ

```sh
cp <Ctrl+G> .            # 最近のファイルを現在のディレクトリにコピー
tail -f <Ctrl+G>         # 以前見たログを追跡
open <Ctrl+G>            # macOS の既定アプリで開く
less <Ctrl+G>            # 最近のファイルをページ表示
cd ~/project; <Ctrl+R> ctrl-t   # このフォルダで実行したコマンドを呼び出す
```

`Ctrl+G` はカーソル位置に追記し、行の残りはそのまま残すので、1 つのコマンド内で何度でも使えます。

## 記録の仕組み

- **コマンド** —— すべてのコマンドラインをディレクトリ・タイムスタンプ・終了コードとともに保存。
  **スペース**で始まるコマンドはプライベート扱いで、コマンドもそのファイルも記録されません。
- **ディレクトリ** —— ディレクトリ移動（`cd`、`pushd`、`j`、auto_cd）のたびにスコアが加算されます。
- **ファイル** —— 各コマンドについて、オプション（`-x`）や代入（`a=b`）ではない引数を最大 8 個まで調べ、
  実在する通常ファイルを絶対パスで保存します（クォート除去、`~` 展開、シンボリックリンク解決）。
  展開されていないグロブやディレクトリはファイルとして扱いません。
- **インポート** —— `shhist-import` が取り込むのはコマンド文字列とタイムスタンプのみで、
  ディレクトリ/ファイルのランキングは作られません。インポートしたコマンドにはディレクトリ情報がないため、
  `ctrl-t` の全ディレクトリ表示にのみ現れます。

N 秒前の訪問は、現在の訪問の `0.5 ^ (N / half_life)` 倍の価値を持ちます。
減衰はクエリ時に計算されるため、半減期を変更すると既存データ全体に即座に反映されます。

## 設定

デフォルト値は `config.zsh`（バージョン管理対象）にあります。上書き設定は
`~/.config/shhist/config.local.zsh`（gitignore 済み、デフォルトの後に読み込み）に書けば
`git pull` と衝突しません —— 変更したい変数を export し直すだけです：

```zsh
# ~/.config/shhist/config.local.zsh
export SHHIST_JUMP_CMD="z"
export SHHIST_EDIT_CMD="e"
export SHHIST_ESC_TIMEOUT_MS=10
export SHHIST_HALFLIFE_DIR=$((14 * 24 * 3600))
```

| 設定 | デフォルト | 意味 |
|---|---|---|
| `SHHIST_DATA_DIR` / `SHHIST_DB` | `~/.config/shhist-data/history.db` | 履歴の保存場所 |
| `SHHIST_SQLITE` | 自動検出 | 数学関数付きの sqlite3 バイナリ |
| `SHHIST_JUMP_CMD` / `SHHIST_EDIT_CMD` / `SHHIST_SH_CMD` | `j` / `v` / `shf` | コマンド名 |
| `SHHIST_BIND_HISTORY` / `SHHIST_BIND_FILE` | `^R` / `^G` | ウィジェットのキーバインド |
| `SHHIST_BIND_TAB` | `^I` | `j`/`v`/`shf` 行での Tab ピッカー（`''` で無効） |
| `SHHIST_FILE_RUN_KEY` | `ctrl-]` | `Ctrl+R` / `Ctrl+G` での挿入 + 実行キー |
| `SHHIST_DELETE_KEY` | `ctrl-x` | 全ピッカー共通の削除キー |
| `SHHIST_SUGGEST_MODE` | `B` | 自動サジェスト：`A` sqlite / `B` zsh 履歴 / `AB` sqlite → 履歴 |
| `SHHIST_HALFLIFE_DIR` / `_FILE` / `_CMD` | 7 / 3 / 14 日 | frecency の半減期（秒） |
| `SHHIST_TRACK_EXIT` | `1` | 終了コードを記録 |
| `SHHIST_FZF_LIMIT` | `20000` | `Ctrl+R` に渡す最大行数 |
| `SHHIST_FZF_OPTS` | `--height=60% --reverse --border` | 全ピッカー共通の追加 fzf オプション |
| `SHHIST_ESC_FIX` / `SHHIST_ESC_TIMEOUT_MS` | `1` / `10` | emacs モードで単独の ESC がキーを飲み込まないようにする |

### Cmd+Enter を実行キーにする

ターミナルは Cmd キーを転送しないため、バイト `0x1D`（`ctrl-]`）を送るように割り当てます：

- **iTerm2**：Settings → Profiles → Keys → Key Mappings → `+` → Cmd+Enter →
  「Send Hex Codes」 → `0x1D`
- **kitty**：`map cmd+enter send_text all \x1d`

## データ

データベースは 1 つの SQLite ファイルで、意図的にインストールディレクトリの**外**に置かれています
（デフォルト：`~/.config/shhist-data/history.db`）。shhist を削除・再インストールしても履歴には影響しません。
バックアップや閲覧、`sqlite3` での直接クエリも可能です：

```sh
sqlite3 ~/.config/shhist-data/history.db \
  "SELECT cmd FROM commands WHERE exit_code != 0 ORDER BY ts DESC LIMIT 20;"
```

## アンインストール

```sh
~/.config/shhist/uninstall.sh
```

インストールディレクトリ（`core.zsh`、`widgets.zsh`、`config.zsh`、`config.local.zsh`）と
`~/.zshrc` の source 行を削除します。履歴データベースはデフォルトで残るため、再インストールすれば
そのまま引き継がれます。`--purge-data` でデータベースも削除、`-f` で確認を省略します：

```sh
~/.config/shhist/uninstall.sh -f --purge-data   # すべて削除、DB も残さない
```

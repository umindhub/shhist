# shhist

[English](../../README.md) | [Deutsch](README_de.md) | [Español](README_es.md) | [Français](README_fr.md) | [Italiano](README_it.md) | [日本語](README_ja.md) | **한국어** | [Nederlands](README_nl.md) | [简体中文](README_zh-Hans.md) | [繁體中文](README_zh-Hant.md)

SQLite 기반의 순수 zsh 셸 히스토리 & frecency(빈도 + 최근성) 엔진.
컴파일할 코드가 없습니다 —— `zsh` + `sqlite3` + `fzf`만 있으면 됩니다.

shhist는 세 가지를 기억합니다: 실행한 **모든 명령**, 들어간 **모든 디렉터리**, 그리고 다룬 **모든 파일**.
마지막이 바로 차별점입니다. 어떤 명령에 한 번이라도 등장한 파일은, 경로를 다시 입력하지 않고도
**어느 디렉터리에서든** 열고, 실행하고, 새 명령에 경로를 넣을 수 있습니다.

```sh
~/Downloads $ v zshrc          # ~/.zshrc를 $EDITOR로 열기
/tmp        $ shf deploy       # ~/work/scripts/deploy.sh를 sh로 실행
~           $ j youmind        # cd ~/Dropbox/Xcode/YouMindHub
어디서나     $ vim <Ctrl+G>     # 자주 쓰는 파일을 고르면 경로가 삽입됨
```

## 주요 특징

- **파일이 어디든 따라옵니다** —— 어떤 명령(`vim`, `cat`, `cp`, `python3`, `open` …)에 전달된 기존 파일이든
  절대 경로로 기록됩니다. 이후 어디에 있든 `v foo`로 열고, `shf foo`로 실행하고,
  `Ctrl+G`로 입력 중인 명령에 삽입할 수 있습니다.
- **vim, sh와 자연스럽게 연동** —— `v`는 `$EDITOR`(기본값 vim)를, `shf`는 `sh`를 실행하며,
  `Ctrl+G`로 다른 어떤 도구에도 경로를 넘길 수 있습니다(`nvim -d`, `bash`, `zsh`, `source`, `tail -f` …).
- **디렉터리 점프** —— `j proj x`로 `*proj*x*`와 가장 잘 일치하는 디렉터리로 이동(`fasd`/`z` 방식).
- **영구 히스토리** —— 모든 명령을 디렉터리, 타임스탬프, 종료 코드와 함께 SQLite에 영구 저장.
  `Ctrl+R`로 전체 히스토리 또는 현재 디렉터리에서 실행한 명령만 검색할 수 있습니다.
- **Frecency** —— 쿼리 시점에 지연 계산되는 지수적 시간 감쇠(유지보수 작업 불필요),
  반감기는 종류별(디렉터리 / 파일 / 제안)로 설정 가능.
- **원스트로크 실행** —— `Ctrl+R`과 `Ctrl+G`에서 Enter는 삽입, `ctrl-]`는 삽입 **후 즉시 실행**
  (Cmd+Enter에 매핑 가능).
- **제자리 삭제** —— 모든 선택기에서 `ctrl-x`로 강조된 디렉터리, 파일, 명령을 삭제하며 선택기는 열린 상태를 유지합니다.
- **zsh-autosuggestions 소스** —— SQLite의 감쇠된 빈도로 제안 순위를 매깁니다.
- **히스토리 가져오기** —— `shhist-import`로 기존 zsh 히스토리를 한 번에 가져오며 타임스탬프를 보존합니다.

## 요구 사항

- zsh, [fzf](https://github.com/junegunn/fzf) >= 0.45,
  수학 함수가 포함되어 빌드된 sqlite3 (Homebrew 버전이면 됨)
- 선택: 제안 소스로 쓸 [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions)

```sh
brew install sqlite fzf zsh-autosuggestions
```

## 설치

설치 위치에 바로 clone한 뒤 설치 스크립트를 실행하세요(의존성을 확인하고 `~/.zshrc`에 한 줄을 추가합니다):

```sh
git clone https://github.com/umindhub/shhist.git ~/.config/shhist
~/.config/shhist/install.sh
```

shhist는 fzf 키 바인딩과 zsh-autosuggestions 이후에 로드되어야 합니다. 설치 스크립트는 `.zshrc` 끝에
추가하므로 보통은 이 조건을 만족합니다. 업데이트는 다음과 같습니다:

```sh
git -C ~/.config/shhist pull
```

데이터베이스는 설치 디렉터리 밖에 있고 로컬 설정(`config.local.zsh`)은 gitignore되어 있으므로,
`git pull`이 이들을 건드리지 않습니다.

다른 곳에 clone하고 싶다면 그곳에서 `./install.sh`를 실행하세요. 파일이 `~/.config/shhist`로 복사됩니다
(pull할 때마다 다시 실행; 기존 `config.zsh`는 절대 덮어쓰지 않음).

새 터미널을 열고, 원한다면 기존 히스토리를 한 번 가져오세요:

```sh
shhist-import
```

## 사용법

### 어느 디렉터리에서든 파일 다루기

| 동작 | 설명 |
|---|---|
| `v` | 알려진 모든 파일을 frecency 순으로 fzf에 표시; Enter로 `$EDITOR`에서 열기 |
| `v foo`, `v foo bar` | `*foo*bar*`와 가장 잘 일치하는 파일을 `$EDITOR`로 열기; 일치 항목이 없으면 fzf로 전환 |
| `shf` / `shf foo` | 선택 규칙은 같고, 파일을 `sh`로 실행 |
| `v foo<Tab>` / `shf foo<Tab>` | `foo`로 미리 필터링된 fzf; 후보가 하나면 즉시 열기/실행, 아니면 Enter로 |
| `Ctrl+G` | 자주 쓰는 파일을 골라 (따옴표 처리된) 경로를 **어떤** 명령이든 커서 위치에 삽입; Enter = 삽입, `ctrl-]` = 삽입 + 실행 |

매칭은 **전체 경로**에 대한 대소문자 구분 없는 부분 문자열 일치이므로, `v xcode main`으로
`~/Dropbox/Xcode/App/main.swift`를 찾을 수 있습니다. 더 이상 존재하지 않는 파일은 검색 중 건너뛰는 순간
데이터베이스에서 정리됩니다.

### 디렉터리

| 동작 | 설명 |
|---|---|
| `j` | 알려진 모든 디렉터리를 frecency 순으로 fzf에 표시 |
| `j foo`, `j foo bar` | `*foo*bar*`와 가장 잘 일치하는 디렉터리로 cd; 일치 항목이 없으면 fzf로 전환 |
| `j foo<Tab>` | `foo`로 미리 필터링된 fzf; 후보가 하나면 즉시 이동, 아니면 Enter로 |

### 명령 히스토리

| 동작 | 설명 |
|---|---|
| `Ctrl+R` | SQLite 히스토리를 fzf로 검색(입력 중인 내용이 초기 검색어); Enter = 삽입, `ctrl-]` = 삽입 + 실행 |
| `ctrl-t` (`Ctrl+R` 안에서) | 모든 디렉터리 ⇔ **현재 디렉터리**에서 실행한 명령 전환 |
| `shhist-import` | 기존 zsh 히스토리를 한 번에 가져오기 (DB가 비어 있지 않으면 `-f`) |

중복은 하나로 합쳐지고 마지막 사용 순으로 정렬됩니다. 여러 줄 명령은 한 줄(`⏎`)로 표시되지만
삽입할 때는 입력한 그대로 복원됩니다.

### 모든 선택기 공통

| 키 | 설명 |
|---|---|
| `Enter` | 선택 |
| `ctrl-x` | 강조된 디렉터리 / 파일 / 명령을 DB에서 삭제; 선택기는 열린 상태 유지 |

`Ctrl+R`에서 `ctrl-x`는 해당 명령의 모든 기록을 삭제합니다.

## 활용 레시피

### vim과 함께

```sh
v vimrc                  # 어디서든 ~/.vimrc 편집 (`vim ~/.vimrc`를 한 번이라도 했다면)
v                        # 최근 파일 목록, Enter로 열기
vim -d <Ctrl+G> <Ctrl+G> # 최근 파일 두 개 비교 (사이의 공백은 직접 입력)
vim -O <Ctrl+G> <Ctrl+G> # 최근 파일 두 개를 좌우로 열기
v myapp main             # 전체 경로 일치: myapp 안의 main 파일
```

`v`는 `${EDITOR:-vim}`을 실행합니다. Neovim을 쓰려면 `.zshrc`에 `export EDITOR=nvim`을 설정하세요
(`$EDITOR`는 단일 명령으로 호출되므로, `code --wait`처럼 인자가 필요한 에디터는 작은 래퍼 스크립트를
지정하세요). `v`가 다른 명령과 충돌하면 `SHHIST_EDIT_CMD`로 이름을 바꿀 수 있습니다.

### sh 및 스크립트와 함께

```sh
shf deploy               # 어디서든 ~/work/scripts/deploy.sh 실행
shf                      # 최근 파일 목록, Enter로 실행
bash <Ctrl+G> --prod     # 다른 인터프리터 + 추가 인자
python3 <Ctrl+G>         # Python, Node, Ruby 등도 동일
source <Ctrl+G>          # 환경/별칭 파일을 현재 셸에 로드
sh <Ctrl+G>, ctrl-]      # 골라서 바로 실행, 원스트로크
```

`shf`는 항상 `sh`(POSIX sh; shebang 무시)로 **현재** 디렉터리에서 파일을 실행하며 추가 인자를 받지 않습니다 ——
모든 단어가 검색어입니다. bash/zsh 전용 스크립트, 인자가 필요한 경우, 다른 인터프리터는
원하는 명령 뒤에서 `Ctrl+G`를 사용하세요.

### 일상 조합

```sh
cp <Ctrl+G> .            # 최근 파일을 현재 디렉터리로 복사
tail -f <Ctrl+G>         # 전에 봤던 로그 추적
open <Ctrl+G>            # macOS 기본 앱으로 열기
less <Ctrl+G>            # 최근 파일을 페이지 단위로 보기
cd ~/project; <Ctrl+R> ctrl-t   # 이 폴더에서 실행한 명령 불러오기
```

`Ctrl+G`는 커서 위치에 추가하고 줄의 나머지는 그대로 두므로, 한 명령에서 여러 번 사용할 수 있습니다.

## 기록 방식

- **명령** —— 모든 명령줄을 디렉터리, 타임스탬프, 종료 코드와 함께 저장합니다. **공백**으로 시작하는 명령은
  비공개로 취급되어 명령도, 그 안의 파일도 기록되지 않습니다.
- **디렉터리** —— 디렉터리를 바꿀 때마다(`cd`, `pushd`, `j`, auto_cd) 해당 디렉터리의 점수가 올라갑니다.
- **파일** —— 각 명령에서 옵션(`-x`)이나 할당(`a=b`)이 아닌 인자를 최대 8개 검사하고, 실제로 존재하는
  일반 파일을 절대 경로로 저장합니다(따옴표 제거, `~` 확장, 심볼릭 링크 해석). 확장되지 않은 glob과
  디렉터리는 파일로 치지 않습니다.
- **가져오기** —— `shhist-import`는 명령 텍스트와 타임스탬프만 가져오며 디렉터리/파일 순위는 채우지 않습니다.
  가져온 명령에는 디렉터리 정보가 없으므로 `ctrl-t`의 전체 디렉터리 보기에만 나타납니다.

N초 전의 방문은 지금 방문의 `0.5 ^ (N / half_life)`만큼의 가치를 가집니다.
감쇠는 쿼리 시점에 계산되므로 반감기를 바꾸면 기존 데이터 전체에 즉시 적용됩니다.

## 설정

기본값은 `config.zsh`(버전 관리 대상)에 있습니다. 덮어쓸 값은
`~/.config/shhist/config.local.zsh`(gitignore됨, 기본값 이후 로드)에 두면 `git pull`과 충돌하지 않습니다 ——
바꾸고 싶은 변수만 다시 export하면 됩니다:

```zsh
# ~/.config/shhist/config.local.zsh
export SHHIST_JUMP_CMD="z"
export SHHIST_EDIT_CMD="e"
export SHHIST_ESC_TIMEOUT_MS=10
export SHHIST_HALFLIFE_DIR=$((14 * 24 * 3600))
```

| 설정 | 기본값 | 의미 |
|---|---|---|
| `SHHIST_DATA_DIR` / `SHHIST_DB` | `~/.config/shhist-data/history.db` | 히스토리 저장 위치 |
| `SHHIST_SQLITE` | 자동 감지 | 수학 함수가 포함된 sqlite3 바이너리 |
| `SHHIST_JUMP_CMD` / `SHHIST_EDIT_CMD` / `SHHIST_SH_CMD` | `j` / `v` / `shf` | 명령 이름 |
| `SHHIST_BIND_HISTORY` / `SHHIST_BIND_FILE` | `^R` / `^G` | 위젯 키 바인딩 |
| `SHHIST_BIND_TAB` | `^I` | `j`/`v`/`shf` 줄에서의 Tab 선택기 (`''`이면 비활성화) |
| `SHHIST_FILE_RUN_KEY` | `ctrl-]` | `Ctrl+R` / `Ctrl+G`의 삽입 + 실행 키 |
| `SHHIST_DELETE_KEY` | `ctrl-x` | 모든 선택기의 삭제 키 |
| `SHHIST_SUGGEST_MODE` | `B` | 자동 제안: `A` sqlite / `B` zsh 히스토리 / `AB` sqlite 후 히스토리 |
| `SHHIST_HALFLIFE_DIR` / `_FILE` / `_CMD` | 7 / 3 / 14일 | frecency 반감기(초) |
| `SHHIST_TRACK_EXIT` | `1` | 종료 코드 기록 |
| `SHHIST_FZF_LIMIT` | `20000` | `Ctrl+R`에 넘기는 최대 행 수 |
| `SHHIST_FZF_OPTS` | `--height=60% --reverse --border` | 모든 선택기의 추가 fzf 옵션 |
| `SHHIST_ESC_FIX` / `SHHIST_ESC_TIMEOUT_MS` | `1` / `10` | emacs 모드에서 단독 ESC가 키를 삼키지 않게 함 |

### Cmd+Enter를 실행 키로

터미널은 Cmd 키를 전달하지 않으므로, 바이트 `0x1D`(`ctrl-]`)를 보내도록 매핑하세요:

- **iTerm2**: Settings → Profiles → Keys → Key Mappings → `+` → Cmd+Enter →
  "Send Hex Codes" → `0x1D`
- **kitty**: `map cmd+enter send_text all \x1d`

## 데이터

데이터베이스는 하나의 SQLite 파일이며 의도적으로 설치 디렉터리 **밖**에 둡니다
(기본값: `~/.config/shhist-data/history.db`). shhist를 제거하거나 재설치해도 히스토리는 영향을 받지 않습니다.
백업, 열람, 또는 `sqlite3`로 직접 조회할 수 있습니다:

```sh
sqlite3 ~/.config/shhist-data/history.db \
  "SELECT cmd FROM commands WHERE exit_code != 0 ORDER BY ts DESC LIMIT 20;"
```

## 제거

```sh
~/.config/shhist/uninstall.sh
```

설치 디렉터리(`core.zsh`, `widgets.zsh`, `config.zsh`, `config.local.zsh`)와 `~/.zshrc`의 source 줄을
삭제합니다. 히스토리 데이터베이스는 기본적으로 유지되므로 나중에 재설치하면 그대로 이어집니다.
`--purge-data`를 주면 데이터베이스도 삭제하고, `-f`를 주면 확인을 건너뜁니다:

```sh
~/.config/shhist/uninstall.sh -f --purge-data   # 모두 삭제, DB도 남기지 않음
```

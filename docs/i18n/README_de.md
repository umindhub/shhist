# shhist

[English](../../README.md) | **Deutsch** | [Español](README_es.md) | [Français](README_fr.md) | [Italiano](README_it.md) | [日本語](README_ja.md) | [한국어](README_ko.md) | [Nederlands](README_nl.md) | [简体中文](README_zh-Hans.md) | [繁體中文](README_zh-Hant.md)

Shell-Verlauf und Frecency-Engine in reinem zsh, gespeichert in SQLite. Kein
kompilierter Code -- nur `zsh` + `sqlite3` + `fzf`.

shhist merkt sich drei Dinge: **jeden Befehl**, den du ausführst, **jedes
Verzeichnis**, das du betrittst, und **jede Datei**, die du anfasst. Letzteres
macht den Unterschied: Sobald eine Datei in irgendeinem Befehl vorkam, kannst du
sie **aus jedem Verzeichnis** öffnen, ausführen oder ihren Pfad in einen neuen
Befehl einfügen -- ohne den Pfad erneut zu tippen.

```sh
~/Downloads $ v zshrc          # öffnet ~/.zshrc in $EDITOR
/tmp        $ shf deploy       # führt ~/work/scripts/deploy.sh mit sh aus
~           $ j youmind        # cd ~/Dropbox/Xcode/YouMindHub
überall     $ vim <Ctrl+G>     # beliebige häufige Datei wählen, Pfad wird eingefügt
```

## Highlights

- **Dateien folgen dir überallhin** -- jede existierende Datei, die einem
  beliebigen Befehl übergeben wird (`vim`, `cat`, `cp`, `python3`, `open`, ...),
  wird mit ihrem absoluten Pfad gespeichert. Danach öffnet `v foo` sie, `shf foo`
  führt sie aus, und `Ctrl+G` fügt sie in die aktuelle Eingabe ein -- egal wo du bist.
- **Arbeitet mit vim und sh zusammen** -- `v` startet `$EDITOR` (standardmäßig vim),
  `shf` startet `sh`, und `Ctrl+G` reicht Pfade an jedes andere Werkzeug weiter
  (`nvim -d`, `bash`, `zsh`, `source`, `tail -f`, ...).
- **Verzeichnissprung** -- `j proj x` springt ins beste Verzeichnis zu
  `*proj*x*`, im Stil von `fasd`/`z`.
- **Dauerhafter Verlauf** -- jeder Befehl wird für immer in SQLite gespeichert,
  mit Verzeichnis, Zeitstempel und Exit-Code; `Ctrl+R` durchsucht alles oder nur
  die im aktuellen Verzeichnis ausgeführten Befehle.
- **Frecency** -- exponentieller Zeitverfall, erst bei der Abfrage berechnet
  (keine Wartungsjobs), Halbwertszeit pro Art einstellbar (Verzeichnisse /
  Dateien / Vorschläge).
- **Ausführen mit einem Tastendruck** -- in `Ctrl+R` und `Ctrl+G` fügt Enter ein,
  `ctrl-]` fügt ein **und führt aus** (auf Cmd+Enter abbildbar).
- **Löschen an Ort und Stelle** -- `ctrl-x` in jeder Auswahlliste entfernt das
  markierte Verzeichnis, die Datei oder den Befehl; die Liste bleibt offen.
- **Quelle für zsh-autosuggestions** -- Vorschläge nach zerfallener Häufigkeit
  aus SQLite gereiht.
- **Verlaufsimport** -- einmaliges `shhist-import` deines bestehenden
  zsh-Verlaufs, Zeitstempel bleiben erhalten.

## Voraussetzungen

- zsh, [fzf](https://github.com/junegunn/fzf) >= 0.45,
  sqlite3 mit Mathematikfunktionen (die Homebrew-Version hat sie)
- optional: [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions)
  für die Vorschlagsquelle

```sh
brew install sqlite fzf zsh-autosuggestions
```

## Installation

Direkt an den Installationsort klonen und das Installationsskript starten (es
prüft Abhängigkeiten und fügt eine Zeile zu deiner `~/.zshrc` hinzu):

```sh
git clone https://github.com/umindhub/shhist.git ~/.config/shhist
~/.config/shhist/install.sh
```

shhist muss nach den fzf-Tastenbelegungen und zsh-autosuggestions geladen werden;
das Skript hängt an das Ende der `.zshrc` an, was das normalerweise erfüllt.
Aktualisieren ist nur:

```sh
git -C ~/.config/shhist pull
```

Die Datenbank liegt außerhalb des Installationsverzeichnisses, und deine lokalen
Anpassungen (`config.local.zsh`) sind per gitignore ausgeschlossen -- `git pull`
berührt sie also nie.

Wenn du den Klon lieber woanders hast, führe dort `./install.sh` aus; die Dateien
werden dann nach `~/.config/shhist` kopiert (nach jedem Pull erneut ausführen;
eine vorhandene `config.zsh` wird nie überschrieben).

Dann ein neues Terminal öffnen und optional einmalig den bestehenden Verlauf
importieren:

```sh
shhist-import
```

## Verwendung

### Dateien aus jedem Verzeichnis

| Aktion | Wirkung |
|---|---|
| `v` | fzf über alle bekannten Dateien, nach Frecency sortiert; Enter öffnet in `$EDITOR` |
| `v foo`, `v foo bar` | öffnet die beste Datei zu `*foo*bar*` in `$EDITOR`; ohne Treffer geht es in fzf |
| `shf` / `shf foo` | gleiche Auswahlregeln, aber die Datei wird mit `sh` ausgeführt |
| `v foo<Tab>` / `shf foo<Tab>` | fzf mit `foo` vorgefiltert; ein einziger Treffer wird sofort geöffnet/ausgeführt, sonst per Enter |
| `Ctrl+G` | häufige Datei wählen und ihren (gequoteten) Pfad an der Cursorposition **jedes** Befehls einfügen; Enter = einfügen, `ctrl-]` = einfügen + ausführen |

Gesucht wird als Teilstring im **vollständigen Pfad**, ohne Beachtung der
Groß-/Kleinschreibung -- `v xcode main` findet also
`~/Dropbox/Xcode/App/main.swift`. Nicht mehr existierende Dateien werden aus der
Datenbank entfernt, sobald sie bei der Suche übersprungen werden.

### Verzeichnisse

| Aktion | Wirkung |
|---|---|
| `j` | fzf über alle bekannten Verzeichnisse, nach Frecency sortiert |
| `j foo`, `j foo bar` | cd ins beste Verzeichnis zu `*foo*bar*`; ohne Treffer geht es in fzf |
| `j foo<Tab>` | fzf mit `foo` vorgefiltert; ein einziger Treffer springt sofort, sonst per Enter |

### Befehlsverlauf

| Aktion | Wirkung |
|---|---|
| `Ctrl+R` | fzf über den SQLite-Verlauf, vorbelegt mit der bisherigen Eingabe; Enter = einfügen, `ctrl-]` = einfügen + ausführen |
| `ctrl-t` (in `Ctrl+R`) | umschalten zwischen allen Verzeichnissen und Befehlen aus dem **aktuellen Verzeichnis** |
| `shhist-import` | einmaliger Import des bestehenden zsh-Verlaufs (`-f` für eine nicht leere DB) |

Duplikate werden zusammengefasst und nach letzter Nutzung sortiert. Mehrzeilige
Befehle erscheinen einzeilig (`⏎`), werden aber exakt wie eingegeben eingefügt.

### In jeder Auswahlliste

| Taste | Wirkung |
|---|---|
| `Enter` | auswählen |
| `ctrl-x` | markiertes Verzeichnis / Datei / Befehl aus der DB löschen; die Liste bleibt offen |

In `Ctrl+R` löscht `ctrl-x` jedes Vorkommen dieses Befehls.

## Rezepte

### Mit vim

```sh
v vimrc                  # ~/.vimrc von überall bearbeiten (nach einem `vim ~/.vimrc`)
v                        # letzte Dateien durchsuchen, Enter öffnet die gewünschte
vim -d <Ctrl+G> <Ctrl+G> # zwei letzte Dateien vergleichen (Leerzeichen dazwischen tippen)
vim -O <Ctrl+G> <Ctrl+G> # zwei letzte Dateien nebeneinander öffnen
v myapp main             # Pfadsuche: die main-Datei in myapp
```

`v` startet `${EDITOR:-vim}`. Für Neovim setze `export EDITOR=nvim` in deiner
`.zshrc` (`$EDITOR` wird als einzelner Befehl aufgerufen; für Editoren mit
Optionen wie `code --wait` verweise auf ein kleines Wrapper-Skript). Kollidiert
`v` mit etwas anderem, benenne es über `SHHIST_EDIT_CMD` um.

### Mit sh und Skripten

```sh
shf deploy               # ~/work/scripts/deploy.sh von überall ausführen
shf                      # letzte Dateien durchsuchen, Enter führt die Auswahl aus
bash <Ctrl+G> --prod     # anderer Interpreter, zusätzliche Argumente
python3 <Ctrl+G>         # ebenso für Python, Node, Ruby, ...
source <Ctrl+G>          # Env-/Alias-Datei in die aktuelle Shell laden
sh <Ctrl+G>, ctrl-]      # wählen und ausführen in einem Zug
```

`shf` führt die Datei immer mit `sh` aus (POSIX sh; der Shebang wird ignoriert),
und zwar im **aktuellen** Verzeichnis, ohne zusätzliche Argumente -- jedes Wort
ist Teil der Suche. Für reine bash/zsh-Skripte, Argumente oder andere
Interpreter nutze `Ctrl+G` nach dem Befehl deiner Wahl.

### Alltägliche Kombinationen

```sh
cp <Ctrl+G> .            # eine letzte Datei ins aktuelle Verzeichnis kopieren
tail -f <Ctrl+G>         # einem früher angesehenen Log folgen
open <Ctrl+G>            # in der macOS-Standard-App öffnen
less <Ctrl+G>            # eine letzte Datei seitenweise lesen
cd ~/project; <Ctrl+R> ctrl-t   # Befehle aus diesem Ordner wiederfinden
```

`Ctrl+G` fügt an der Cursorposition ein und lässt den Rest der Zeile unberührt;
du kannst es also mehrmals in einem Befehl nutzen.

## So funktioniert die Aufzeichnung

- **Befehle** -- jede Befehlszeile wird mit Verzeichnis, Zeitstempel und
  Exit-Code gespeichert. Ein Befehl, der mit einem **Leerzeichen** beginnt, ist
  privat: weder der Befehl noch seine Dateien werden aufgezeichnet.
- **Verzeichnisse** -- jeder Verzeichniswechsel (`cd`, `pushd`, `j`, auto_cd)
  wertet das Verzeichnis auf.
- **Dateien** -- pro Befehl werden bis zu 8 Argumente geprüft, die weder Optionen
  (`-x`) noch Zuweisungen (`a=b`) sind; existierende reguläre Dateien werden mit
  absolutem Pfad gespeichert (Anführungszeichen entfernt, `~` expandiert,
  Symlinks aufgelöst). Nicht expandierte Globs und Verzeichnisse zählen nicht als
  Dateien.
- **Import** -- `shhist-import` lädt nur Befehlstext und Zeitstempel; die
  Verzeichnis-/Datei-Rankings werden nicht befüllt, und importierte Befehle haben
  kein Verzeichnis, erscheinen also nur in der Alle-Verzeichnisse-Ansicht von `ctrl-t`.

Ein Besuch vor N Sekunden zählt `0.5 ^ (N / half_life)` eines Besuchs jetzt.
Der Verfall wird bei der Abfrage berechnet, eine geänderte Halbwertszeit wirkt
also sofort auf alle vorhandenen Daten.

## Konfiguration

Die Standardwerte stehen in `config.zsh` (versioniert). Eigene Anpassungen
gehören in `~/.config/shhist/config.local.zsh` (per gitignore ausgeschlossen,
nach den Standardwerten geladen), damit `git pull` nie in Konflikt gerät --
einfach die gewünschten Variablen erneut exportieren:

```zsh
# ~/.config/shhist/config.local.zsh
export SHHIST_JUMP_CMD="z"
export SHHIST_EDIT_CMD="e"
export SHHIST_ESC_TIMEOUT_MS=10
export SHHIST_HALFLIFE_DIR=$((14 * 24 * 3600))
```

| Einstellung | Standard | Bedeutung |
|---|---|---|
| `SHHIST_DATA_DIR` / `SHHIST_DB` | `~/.config/shhist-data/history.db` | Speicherort des Verlaufs |
| `SHHIST_SQLITE` | automatisch | sqlite3-Binary mit Mathematikfunktionen |
| `SHHIST_JUMP_CMD` / `SHHIST_EDIT_CMD` / `SHHIST_SH_CMD` | `j` / `v` / `shf` | Befehlsnamen |
| `SHHIST_BIND_HISTORY` / `SHHIST_BIND_FILE` | `^R` / `^G` | Tastenbelegung der Widgets |
| `SHHIST_BIND_TAB` | `^I` | Tab-Auswahl auf `j`/`v`/`shf`-Zeilen (`''` deaktiviert) |
| `SHHIST_FILE_RUN_KEY` | `ctrl-]` | Einfügen-+-Ausführen-Taste in `Ctrl+R` / `Ctrl+G` |
| `SHHIST_DELETE_KEY` | `ctrl-x` | Löschtaste in allen Auswahllisten |
| `SHHIST_SUGGEST_MODE` | `B` | Autosuggestions: `A` sqlite / `B` zsh-Verlauf / `AB` erst sqlite, dann Verlauf |
| `SHHIST_HALFLIFE_DIR` / `_FILE` / `_CMD` | 7 / 3 / 14 Tage | Frecency-Halbwertszeiten (Sekunden) |
| `SHHIST_TRACK_EXIT` | `1` | Exit-Codes aufzeichnen |
| `SHHIST_FZF_LIMIT` | `20000` | max. Zeilen für `Ctrl+R` |
| `SHHIST_FZF_OPTS` | `--height=60% --reverse --border` | zusätzliche fzf-Optionen für alle Auswahllisten |
| `SHHIST_ESC_FIX` / `SHHIST_ESC_TIMEOUT_MS` | `1` / `10` | einzelnes ESC im emacs-Modus harmlos machen |

### Cmd+Enter als Ausführen-Taste

Terminals leiten die Cmd-Taste nie weiter; bilde sie daher auf das Byte `0x1D`
(`ctrl-]`) ab:

- **iTerm2**: Settings → Profiles → Keys → Key Mappings → `+` → Cmd+Enter →
  "Send Hex Codes" → `0x1D`
- **kitty**: `map cmd+enter send_text all \x1d`

## Daten

Die Datenbank ist eine einzelne SQLite-Datei, absichtlich AUSSERHALB des
Installationsverzeichnisses (Standard: `~/.config/shhist-data/history.db`) --
Entfernen oder Neuinstallieren von shhist berührt deinen Verlauf also nie.
Sichern, ansehen oder direkt mit `sqlite3` abfragen:

```sh
sqlite3 ~/.config/shhist-data/history.db \
  "SELECT cmd FROM commands WHERE exit_code != 0 ORDER BY ts DESC LIMIT 20;"
```

## Deinstallation

```sh
~/.config/shhist/uninstall.sh
```

Entfernt das Installationsverzeichnis (`core.zsh`, `widgets.zsh`, `config.zsh`,
deine `config.local.zsh`) und die source-Zeile in `~/.zshrc`. Die
Verlaufsdatenbank bleibt standardmäßig erhalten -- eine spätere Neuinstallation
übernimmt sie direkt. `--purge-data` löscht sie ebenfalls, `-f` überspringt die
Bestätigung:

```sh
~/.config/shhist/uninstall.sh -f --purge-data   # alles entfernen, keine DB behalten
```

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
- **Frecency** -- aktuelle Arbeit und langfristige Gewohnheit werden getrennt
  bewertet (zwei Halbwertszeiten, Gewohnheit nur logarithmisch), daher steigt
  ein neuer Befehl oder ein neues Verzeichnis binnen Minuten auf, statt unter
  jahrelanger Historie zu verschwinden. Erst bei der Abfrage berechnet (keine
  Wartungsjobs); der Algorithmus ist pro Funktion umschaltbar.
- **Ausführen mit einem Tastendruck** -- in `Ctrl+R` und `Ctrl+G` fügt Enter ein,
  `ctrl-]` fügt ein **und führt aus** (auf Cmd+Enter abbildbar).
- **Löschen an Ort und Stelle** -- `ctrl-x` in jeder Auswahlliste entfernt das
  markierte Verzeichnis, die Datei oder den Befehl; die Liste bleibt offen.
- **Eingebaute Inline-Vorschläge** -- graue Geistertext-Vorschläge aus SQLite,
  nach Frecency gereiht; ersetzt zsh-autosuggestions. Kandidaten,
  deren Programm oder Datei-Operanden gerade fehlen, werden übersprungen.
- **Vergisst kaputte Befehle** -- ein Befehl, der scheitert, weil sein Programm
  nicht existiert (`command not found`) oder ein Datei-/Verzeichnis-Operand
  fehlt (`sh missing.sh`, `cd nope`), wird sofort aus dem Verlauf entfernt.
- **Verlaufsimport** -- einmaliges `shhist-import` deines bestehenden
  zsh-Verlaufs, Zeitstempel bleiben erhalten.

## Voraussetzungen

- zsh, [fzf](https://github.com/junegunn/fzf) >= 0.45,
  sqlite3 mit Mathematikfunktionen (die Homebrew-Version hat sie)

```sh
brew install sqlite fzf
```

shhist bringt eigene Inline-Vorschläge mit, entferne daher `zsh-autosuggestions`
aus `plugins=(...)` von oh-my-zsh. Solange es noch geladen ist, liefert shhist
ihm nur Daten (`SHHIST_SUGGEST_MODE`) und zeigt beim Start einen Hinweis.

## Installation

Direkt an den Installationsort klonen und das Installationsskript starten (es
prüft Abhängigkeiten und fügt eine Zeile zu deiner `~/.zshrc` hinzu):

```sh
git clone https://github.com/umindhub/shhist.git ~/.config/shhist
~/.config/shhist/install.sh
```

shhist muss nach den fzf-Tastenbelegungen und anderen Plugins geladen werden;
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

Duplikate werden zusammengefasst und nach Frecency sortiert (siehe Rangfolge). Mehrzeilige
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

### Rangfolge

Jeder Lauf bzw. Besuch zählt `0.5 ^ (Alter / half_life)` eines Laufs jetzt.
Jeder Befehl, jedes Verzeichnis und jede Datei führt zwei solche Summen:
**S_short** (Halbwertszeit 6 Stunden: woran du gerade arbeitest) und
**S_long** (Halbwertszeit 7 / 3 / 14 Tage für Verzeichnisse / Dateien /
Befehle: langfristige Gewohnheit). Die Standardwertung ist
`2 × S_short + log2(1 + S_long)`.

Aktuelle Arbeit zählt voll, Gewohnheit nur logarithmisch: Ein Befehl, der
letzten Monat 200-mal lief, kommt auf etwa 7 Punkte, einer, der in der letzten
Stunde 3-mal lief, auf etwa 8. Gewohnheiten schlagen weiterhin
Einmal-Befehle, begraben neue aber nicht mehr.

| Algorithmus | Wertung |
|---|---|
| `duallog` (Standard) | `W × S_short + log2(1 + S_long)` |
| `dual` | `W × S_short + S_long` |
| `single` | `S_long` (bisheriges Verhalten) |
| `seg` | Läufe × Gewicht der Altersstufe des letzten Besuchs (zoxide-artig, `SHHIST_RANK_SEGS`) |
| `recent` | neueste zuerst (zsh-autosuggestions / klassisches `Ctrl+R`) |

`SHHIST_RANK` wählt den Algorithmus überall; `SHHIST_SUGGEST_RANK`,
`SHHIST_HISTORY_RANK` (`Ctrl+R`), `SHHIST_JUMP_RANK` (`j`) und
`SHHIST_FILE_RANK` (`v`, `shf`, `Ctrl+G`) überschreiben ihn pro Funktion.
Vergleiche sie vor dem Umschalten mit deinen eigenen Daten:

```sh
shhist-rank git                  # suggestion order for "git..."
shhist-rank -a single git        # same prefix, previous algorithm
shhist-rank                      # whole history, i.e. Ctrl+R order
shhist-rank -k dir -a seg proj   # what `j proj` would pick with seg
```

Der Verfall wird bei der Abfrage berechnet, eine geänderte Halbwertszeit oder
ein anderer Algorithmus wirkt also sofort auf alle vorhandenen Daten.
Datenbanken älterer Versionen werden beim ersten Start aktualisiert; ihre
kurzfristigen Werte und Besuchszahlen für Verzeichnisse/Dateien werden
geschätzt und mit weiterer Nutzung exakt.

## Inline-Vorschläge

Beim Tippen erscheint der am besten passende frühere Befehl als grauer Text
hinter dem Cursor. Pfeil rechts / Ende übernimmt alles, Ctrl+F oder Alt+Rechts
(`forward-word`) das nächste Wort; an anderen Stellen der Zeile verhalten sich
diese Tasten wie gewohnt (Ctrl+F bewegt weiterhin um ein Zeichen). Nach dem
Blättern im Verlauf (Hoch, `Ctrl+R`) erscheint kein Vorschlag, bis du wieder
tippst. Ein Kandidat wird übersprungen (nicht gelöscht), wenn sein Programm
nicht auflösbar ist oder ein Pfad-Operand im aktuellen Verzeichnis fehlt -- er
kann später wieder funktionieren, z. B. nach dem Aktivieren einer venv.

## Kaputte Befehle vergessen

Endet ein Befehl mit 1-127, prüft shhist den Grund:

- **Programm nicht gefunden** (`gti status`, ein fehlendes `./build.sh`) --
  alle Zeilen dieses Befehls werden gelöscht;
- **fehlender absoluter / `~`-Pfad** (`cat ~/gone.txt`) -- alle Zeilen werden
  gelöscht;
- **fehlender relativer Pfad** (`sh missing.sh`, `cd nope`) -- nur die in
  diesem Verzeichnis aufgezeichneten Zeilen werden gelöscht.

Pfade werden zurückhaltend erkannt: das Skript eines Interpreters (`sh`,
`python3`, `node`, ... -- `SHHIST_INTERP_CMDS`), jeder Operand eines
Dateibefehls (`cd`, `cat`, `vim`, ... -- `SHHIST_PATH_CMDS`) und Wörter, die
mit `/`, `~/`, `./`, `../` beginnen. Werkzeuge, deren Operanden Muster, URLs
oder noch nicht angelegte Ziele sind (`git`, `grep`, `mkdir`, `cp`, ... --
`SHHIST_NOCHECK_CMDS`), werden nie auf Pfade geprüft. Ctrl+C und andere
Signale (Exit >= 128) zählen nie als Fehlschlag.

Für früher aufgezeichneten (oder importierten) Verlauf lässt sich dieselbe
Prüfung gesammelt ausführen:

```sh
shhist-clean -n    # Vorschau
shhist-clean       # entfernen
```

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
| `SHHIST_SUGGEST` | `1` | eingebaute Inline-Vorschläge (`0` schaltet ab) |
| `SHHIST_SUGGEST_STYLE` | `fg=8` | Hervorhebung des Vorschlagstexts |
| `SHHIST_BIND_ACCEPT_WORD` | `^F` | nächstes Wort des Vorschlags übernehmen (`''` schaltet ab) |
| `SHHIST_SUGGEST_CANDIDATES` | `20` | pro Abfrage geprüfte Top-Kandidaten |
| `SHHIST_SUGGEST_ACCEPT_WIDGETS` / `_PARTIAL_WIDGETS` | `forward-char` ... / `forward-word` ... | Widgets, die alles / ein Wort übernehmen |
| `SHHIST_SUGGEST_MODE` | `B` | nur solange zsh-autosuggestions geladen ist: `A` sqlite / `B` zsh-Verlauf / `AB` beides |
| `SHHIST_PRUNE_FAILED` | `1` | gescheiterte Befehle mit fehlendem Programm oder Pfad vergessen |
| `SHHIST_INTERP_CMDS` / `SHHIST_PATH_CMDS` / `SHHIST_NOCHECK_CMDS` | siehe `config.zsh` | wie Operanden auf Pfade geprüft werden |
| `SHHIST_RANK` | `duallog` | Ranking-Algorithmus (siehe Rangfolge) |
| `SHHIST_SUGGEST_RANK` / `_HISTORY_RANK` / `_JUMP_RANK` / `_FILE_RANK` | `''` | Überschreibung pro Funktion (`''` = `SHHIST_RANK`) |
| `SHHIST_RANK_SHORT_WEIGHT` | `2` | W in `duallog` / `dual` |
| `SHHIST_RANK_SEGS` | `(3600:4 86400:2 604800:0.5 0.25)` | Stufen für `seg` (`max_age:weight`, dann das Rückfallgewicht) |
| `SHHIST_HALFLIFE_DIR` / `_FILE` / `_CMD` | 7 / 3 / 14 Tage | langfristige Halbwertszeiten (Sekunden) |
| `SHHIST_HALFLIFE_DIR_SHORT` / `_FILE_SHORT` / `_CMD_SHORT` | 6 Stunden | kurzfristige Halbwertszeiten (Sekunden) |
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

Entfernt das Installationsverzeichnis (`core.zsh`, `widgets.zsh`, `suggest.zsh`, `config.zsh`,
deine `config.local.zsh`) und die source-Zeile in `~/.zshrc`. Die
Verlaufsdatenbank bleibt standardmäßig erhalten -- eine spätere Neuinstallation
übernimmt sie direkt. `--purge-data` löscht sie ebenfalls, `-f` überspringt die
Bestätigung:

```sh
~/.config/shhist/uninstall.sh -f --purge-data   # alles entfernen, keine DB behalten
```

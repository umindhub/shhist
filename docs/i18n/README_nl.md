# shhist

[English](../../README.md) | [Deutsch](README_de.md) | [Español](README_es.md) | [Français](README_fr.md) | [Italiano](README_it.md) | [日本語](README_ja.md) | [한국어](README_ko.md) | **Nederlands** | [简体中文](README_zh-Hans.md) | [繁體中文](README_zh-Hant.md)

Shellgeschiedenis- en frecency-engine in pure zsh, opgeslagen in SQLite. Geen
gecompileerde code -- alleen `zsh` + `sqlite3` + `fzf`.

shhist onthoudt drie dingen: **elk commando** dat je uitvoert, **elke map** die
je binnengaat en **elk bestand** dat je aanraakt. Dat laatste maakt het verschil:
zodra een bestand in een willekeurig commando is voorgekomen, kun je het
**vanuit elke map** openen, uitvoeren of het pad in een nieuw commando invoegen,
zonder het pad opnieuw te typen.

```sh
~/Downloads $ v zshrc          # opent ~/.zshrc in $EDITOR
/tmp        $ shf deploy       # voert ~/work/scripts/deploy.sh uit met sh
~           $ j youmind        # cd ~/Dropbox/Xcode/YouMindHub
overal      $ vim <Ctrl+G>     # kies een veelgebruikt bestand, het pad wordt ingevoegd
```

## Hoogtepunten

- **Bestanden volgen je overal** -- elk bestaand bestand dat aan een willekeurig
  commando wordt meegegeven (`vim`, `cat`, `cp`, `python3`, `open`, ...) wordt met
  zijn absolute pad vastgelegd. Daarna opent `v foo` het, voert `shf foo` het uit
  en voegt `Ctrl+G` het in in wat je aan het typen bent -- waar je ook bent.
- **Werkt samen met vim en sh** -- `v` start `$EDITOR` (standaard vim), `shf`
  start `sh`, en `Ctrl+G` geeft paden door aan elk ander hulpmiddel
  (`nvim -d`, `bash`, `zsh`, `source`, `tail -f`, ...).
- **Mapsprong** -- `j proj x` springt naar de beste map die overeenkomt met
  `*proj*x*`, in de stijl van `fasd`/`z`.
- **Permanente geschiedenis** -- elk commando wordt voorgoed in SQLite bewaard,
  met map, tijdstempel en exitcode; `Ctrl+R` doorzoekt alles of alleen de
  commando's die in de huidige map zijn uitgevoerd.
- **Frecency** -- exponentieel tijdsverval, pas bij het opvragen berekend (geen
  onderhoudstaken), halfwaardetijd per soort instelbaar (mappen / bestanden /
  suggesties).
- **Uitvoeren met één toets** -- in `Ctrl+R` en `Ctrl+G` voegt Enter in, en
  voegt `ctrl-]` in **en voert uit** in één keer (te koppelen aan Cmd+Enter).
- **Ter plekke verwijderen** -- `ctrl-x` in elke kiezer verwijdert de
  gemarkeerde map, het bestand of het commando; de kiezer blijft open.
- **Bron voor zsh-autosuggestions** -- suggesties gerangschikt op vervallen
  frequentie uit SQLite.
- **Geschiedenis importeren** -- eenmalig `shhist-import` van je bestaande
  zsh-geschiedenis, met behoud van tijdstempels.

## Vereisten

- zsh, [fzf](https://github.com/junegunn/fzf) >= 0.45,
  sqlite3 gebouwd met wiskundige functies (die van Homebrew wel)
- optioneel: [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions)
  voor de suggestiebron

```sh
brew install sqlite fzf zsh-autosuggestions
```

## Installatie

Kloon direct naar de installatielocatie en voer daarna het installatiescript uit
(het controleert de afhankelijkheden en voegt één regel toe aan je `~/.zshrc`):

```sh
git clone https://github.com/umindhub/shhist.git ~/.config/shhist
~/.config/shhist/install.sh
```

shhist moet na de fzf-sneltoetsen en zsh-autosuggestions worden geladen; het
script voegt de regel toe aan het einde van `.zshrc`, wat daar normaal voor zorgt.
Bijwerken is simpelweg:

```sh
git -C ~/.config/shhist pull
```

De database staat buiten de installatiemap en je lokale aanpassingen
(`config.local.zsh`) staan in gitignore, dus `git pull` raakt ze nooit aan.

Wil je de kloon liever ergens anders hebben, voer dan daar `./install.sh` uit;
de bestanden worden dan naar `~/.config/shhist` gekopieerd (na elke pull opnieuw
uitvoeren; een bestaande `config.zsh` wordt nooit overschreven).

Open daarna een nieuwe terminal en importeer eventueel eenmalig je bestaande
geschiedenis:

```sh
shhist-import
```

## Gebruik

### Bestanden vanuit elke map

| Actie | Wat het doet |
|---|---|
| `v` | fzf over alle bekende bestanden, gesorteerd op frecency; Enter opent in `$EDITOR` |
| `v foo`, `v foo bar` | opent het beste bestand dat overeenkomt met `*foo*bar*` in `$EDITOR`; zonder treffer ga je naar fzf |
| `shf` / `shf foo` | dezelfde keuzeregels, maar voert het bestand uit met `sh` |
| `v foo<Tab>` / `shf foo<Tab>` | fzf voorgefilterd met `foo`; één treffer wordt meteen geopend/uitgevoerd, anders met Enter |
| `Ctrl+G` | kies een veelgebruikt bestand en voeg zijn (gequote) pad in bij de cursor van **elk** commando; Enter = invoegen, `ctrl-]` = invoegen + uitvoeren |

Er wordt hoofdletterongevoelig op een deelstring in het **volledige pad**
gezocht, dus `v xcode main` vindt `~/Dropbox/Xcode/App/main.swift`. Bestanden
die niet meer bestaan, worden uit de database verwijderd zodra ze tijdens het
zoeken worden overgeslagen.

### Mappen

| Actie | Wat het doet |
|---|---|
| `j` | fzf over alle bekende mappen, gesorteerd op frecency |
| `j foo`, `j foo bar` | cd naar de beste map die overeenkomt met `*foo*bar*`; zonder treffer ga je naar fzf |
| `j foo<Tab>` | fzf voorgefilterd met `foo`; één treffer springt meteen, anders met Enter |

### Commandogeschiedenis

| Actie | Wat het doet |
|---|---|
| `Ctrl+R` | fzf over de SQLite-geschiedenis, vooraf ingevuld met wat je al typte; Enter = invoegen, `ctrl-]` = invoegen + uitvoeren |
| `ctrl-t` (binnen `Ctrl+R`) | wissel tussen alle mappen en commando's uit de **huidige map** |
| `shhist-import` | eenmalige import van bestaande zsh-geschiedenis (`-f` bij een niet-lege database) |

Duplicaten worden samengevoegd en op laatste gebruik gesorteerd. Commando's van
meerdere regels worden op één regel getoond (`⏎`) maar precies zo ingevoegd als
ze getypt zijn.

### In elke kiezer

| Toets | Wat het doet |
|---|---|
| `Enter` | selecteren |
| `ctrl-x` | verwijder de gemarkeerde map / het bestand / het commando uit de database; de kiezer blijft open |

In `Ctrl+R` verwijdert `ctrl-x` elk voorkomen van dat commando.

## Recepten

### Met vim

```sh
v vimrc                  # ~/.vimrc overal bewerken (na een `vim ~/.vimrc`)
v                        # recente bestanden doorbladeren, Enter opent de gewenste
vim -d <Ctrl+G> <Ctrl+G> # twee recente bestanden vergelijken (typ de spatie ertussen)
vim -O <Ctrl+G> <Ctrl+G> # twee recente bestanden naast elkaar openen
v myapp main             # padovereenkomst: het main-bestand in myapp
```

`v` start `${EDITOR:-vim}`. Voor Neovim zet je `export EDITOR=nvim` in je
`.zshrc` (`$EDITOR` wordt als één commando aangeroepen; laat het voor editors
die opties nodig hebben, zoals `code --wait`, naar een klein wrapperscript
wijzen). Botst `v` met iets anders, hernoem het dan via `SHHIST_EDIT_CMD`.

### Met sh en scripts

```sh
shf deploy               # ~/work/scripts/deploy.sh overal uitvoeren
shf                      # recente bestanden doorbladeren, Enter voert de keuze uit
bash <Ctrl+G> --prod     # andere interpreter, extra argumenten
python3 <Ctrl+G>         # hetzelfde voor Python, Node, Ruby, ...
source <Ctrl+G>          # een env-/aliasbestand in de huidige shell laden
sh <Ctrl+G>, ctrl-]      # kiezen en uitvoeren in één beweging
```

`shf` voert het bestand altijd uit met `sh` (POSIX sh; de shebang wordt
genegeerd) in je **huidige** map, zonder extra argumenten -- elk woord hoort bij
de zoekopdracht. Gebruik voor scripts die alleen in bash/zsh werken, voor
argumenten of voor andere interpreters `Ctrl+G` na het commando van je keuze.

### Dagelijkse combinaties

```sh
cp <Ctrl+G> .            # een recent bestand naar de huidige map kopiëren
tail -f <Ctrl+G>         # een eerder bekeken log volgen
open <Ctrl+G>            # openen in de standaard-app van macOS
less <Ctrl+G>            # een recent bestand pagina voor pagina lezen
cd ~/project; <Ctrl+R> ctrl-t   # commando's terughalen die je in deze map uitvoerde
```

`Ctrl+G` voegt in bij de cursor en laat de rest van de regel ongemoeid, dus je
kunt het meerdere keren in één commando gebruiken.

## Hoe het vastleggen werkt

- **Commando's** -- elke commandoregel wordt opgeslagen met map, tijdstempel en
  exitcode. Een commando dat met een **spatie** begint, is privé: noch het
  commando noch de bestanden erin worden vastgelegd.
- **Mappen** -- elke mapwissel (`cd`, `pushd`, `j`, auto_cd) verhoogt de score
  van die map.
- **Bestanden** -- per commando worden maximaal 8 argumenten gecontroleerd die
  geen optie (`-x`) of toewijzing (`a=b`) zijn; bestaande gewone bestanden
  daaronder worden met hun absolute pad opgeslagen (aanhalingstekens verwijderd,
  `~` uitgebreid, symlinks opgelost). Niet-uitgebreide globs en mappen tellen
  niet als bestanden.
- **Importeren** -- `shhist-import` laadt alleen commandotekst en tijdstempels;
  het vult de map-/bestandsrangschikking niet, en geïmporteerde commando's hebben
  geen map, dus ze verschijnen alleen in de alle-mappen-weergave van `ctrl-t`.

Een bezoek van N seconden geleden telt als `0.5 ^ (N / half_life)` van een
bezoek nu. Het verval wordt bij het opvragen berekend, dus een gewijzigde
halfwaardetijd geldt meteen voor alle bestaande gegevens.

## Configuratie

De standaardwaarden staan in `config.zsh` (onder versiebeheer). Zet je eigen
aanpassingen in `~/.config/shhist/config.local.zsh` (in gitignore, geladen na de
standaardwaarden) zodat `git pull` nooit conflicteert -- exporteer gewoon
opnieuw wat je wilt wijzigen:

```zsh
# ~/.config/shhist/config.local.zsh
export SHHIST_JUMP_CMD="z"
export SHHIST_EDIT_CMD="e"
export SHHIST_ESC_TIMEOUT_MS=10
export SHHIST_HALFLIFE_DIR=$((14 * 24 * 3600))
```

| Instelling | Standaard | Betekenis |
|---|---|---|
| `SHHIST_DATA_DIR` / `SHHIST_DB` | `~/.config/shhist-data/history.db` | waar de geschiedenis staat |
| `SHHIST_SQLITE` | automatisch | sqlite3-binary met wiskundige functies |
| `SHHIST_JUMP_CMD` / `SHHIST_EDIT_CMD` / `SHHIST_SH_CMD` | `j` / `v` / `shf` | commandonamen |
| `SHHIST_BIND_HISTORY` / `SHHIST_BIND_FILE` | `^R` / `^G` | sneltoetsen van de widgets |
| `SHHIST_BIND_TAB` | `^I` | Tab-kiezer op `j`/`v`/`shf`-regels (`''` schakelt uit) |
| `SHHIST_FILE_RUN_KEY` | `ctrl-]` | invoegen-+-uitvoeren-toets in `Ctrl+R` / `Ctrl+G` |
| `SHHIST_DELETE_KEY` | `ctrl-x` | verwijdertoets in alle kiezers |
| `SHHIST_SUGGEST_MODE` | `B` | autosuggesties: `A` sqlite / `B` zsh-geschiedenis / `AB` eerst sqlite, dan geschiedenis |
| `SHHIST_HALFLIFE_DIR` / `_FILE` / `_CMD` | 7 / 3 / 14 dagen | frecency-halfwaardetijden (seconden) |
| `SHHIST_TRACK_EXIT` | `1` | exitcodes vastleggen |
| `SHHIST_FZF_LIMIT` | `20000` | max. aantal regels voor `Ctrl+R` |
| `SHHIST_FZF_OPTS` | `--height=60% --reverse --border` | extra fzf-opties voor alle kiezers |
| `SHHIST_ESC_FIX` / `SHHIST_ESC_TIMEOUT_MS` | `1` / `10` | een losse ESC onschadelijk maken in emacs-modus |

### Cmd+Enter als uitvoertoets

Terminals sturen de Cmd-toets nooit door, dus koppel hem aan het versturen van
de byte `0x1D` (`ctrl-]`):

- **iTerm2**: Settings → Profiles → Keys → Key Mappings → `+` → Cmd+Enter →
  "Send Hex Codes" → `0x1D`
- **kitty**: `map cmd+enter send_text all \x1d`

## Gegevens

De database is één SQLite-bestand, bewust BUITEN de installatiemap bewaard
(standaard: `~/.config/shhist-data/history.db`) -- verwijderen of opnieuw
installeren van shhist raakt je geschiedenis dus nooit. Maak er een back-up van,
bekijk hem of bevraag hem direct met `sqlite3`:

```sh
sqlite3 ~/.config/shhist-data/history.db \
  "SELECT cmd FROM commands WHERE exit_code != 0 ORDER BY ts DESC LIMIT 20;"
```

## Verwijderen

```sh
~/.config/shhist/uninstall.sh
```

Verwijdert de installatiemap (`core.zsh`, `widgets.zsh`, `config.zsh`, je
`config.local.zsh`) en de source-regel in `~/.zshrc`. De geschiedenisdatabase
blijft standaard behouden -- een latere herinstallatie pakt hem meteen weer op.
Geef `--purge-data` mee om hem ook te verwijderen, of `-f` om de bevestiging over
te slaan:

```sh
~/.config/shhist/uninstall.sh -f --purge-data   # alles verwijderen, geen DB bewaren
```

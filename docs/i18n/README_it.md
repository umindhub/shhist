# shhist

[English](../../README.md) | [Deutsch](README_de.md) | [Español](README_es.md) | [Français](README_fr.md) | **Italiano** | [日本語](README_ja.md) | [한국어](README_ko.md) | [Nederlands](README_nl.md) | [简体中文](README_zh-Hans.md) | [繁體中文](README_zh-Hant.md)

Motore di cronologia della shell e di frecency in puro zsh, basato su SQLite.
Nessun codice compilato: solo `zsh` + `sqlite3` + `fzf`.

shhist ricorda tre cose: **ogni comando** che esegui, **ogni directory** in cui
entri e **ogni file** che tocchi. È quest'ultima a fare la differenza: appena un
file compare in un qualsiasi comando, puoi aprirlo, eseguirlo o inserirne il
percorso in un nuovo comando **da qualsiasi directory**, senza riscrivere il
percorso.

```sh
~/Downloads $ v zshrc          # apre ~/.zshrc in $EDITOR
/tmp        $ shf deploy       # esegue ~/work/scripts/deploy.sh con sh
~           $ j youmind        # cd ~/Dropbox/Xcode/YouMindHub
ovunque     $ vim <Ctrl+G>     # scegli un file frequente, il percorso viene inserito
```

## In evidenza

- **I file ti seguono ovunque**: ogni file esistente passato a un qualsiasi
  comando (`vim`, `cat`, `cp`, `python3`, `open`, ...) viene registrato con il suo
  percorso assoluto. Da lì in poi `v foo` lo apre, `shf foo` lo esegue e
  `Ctrl+G` lo inserisce in ciò che stai scrivendo, ovunque tu sia.
- **Lavora bene con vim e sh**: `v` avvia `$EDITOR` (vim di default), `shf`
  avvia `sh`, e `Ctrl+G` passa percorsi a qualsiasi altro strumento (`nvim -d`,
  `bash`, `zsh`, `source`, `tail -f`, ...).
- **Salto tra directory**: `j proj x` salta alla directory migliore che
  corrisponde a `*proj*x*`, in stile `fasd`/`z`.
- **Cronologia permanente**: ogni comando viene salvato per sempre in SQLite,
  con directory, timestamp e codice di uscita; `Ctrl+R` cerca in tutto oppure
  solo nei comandi eseguiti nella directory corrente.
- **Frecency**: il lavoro recente e l'abitudine a lungo termine hanno punteggi
  separati (due emivite, l'abitudine conta in modo logaritmico), quindi un nuovo
  comando o una nuova directory sale in pochi minuti invece di restare sotto
  anni di cronologia. Calcolata in modo pigro al momento della query (nessun
  job di manutenzione); l'algoritmo si può cambiare per funzione.
- **Esecuzione con un tasto**: in `Ctrl+R` e `Ctrl+G`, Invio inserisce e
  `ctrl-]` inserisce **ed esegue** in un colpo solo (associabile a Cmd+Invio).
- **Eliminazione sul posto**: `ctrl-x` in qualsiasi selettore rimuove la
  directory, il file o il comando evidenziato e lascia il selettore aperto.
- **Suggerimenti in linea integrati**: testo fantasma grigio da SQLite,
  ordinato per frecency; sostituisce zsh-autosuggestions. I candidati
  il cui programma o i cui operandi file mancano in questo momento vengono saltati.
- **Dimentica i comandi rotti**: un comando che fallisce perché il programma
  non esiste (`command not found`) o manca un operando file/directory
  (`sh missing.sh`, `cd nope`) viene subito rimosso dalla cronologia.
- **Importazione della cronologia**: `shhist-import` importa una sola volta la
  tua cronologia zsh esistente, conservando i timestamp.

## Requisiti

- zsh, [fzf](https://github.com/junegunn/fzf) >= 0.45,
  sqlite3 compilato con le funzioni matematiche (quello di Homebrew lo è)

```sh
brew install sqlite fzf
```

shhist ha i propri suggerimenti in linea, quindi rimuovi `zsh-autosuggestions`
da `plugins=(...)` di oh-my-zsh. Finché resta caricato, shhist gli fornisce
solo i dati (`SHHIST_SUGGEST_MODE`) e mostra un promemoria all'avvio.

## Installazione

Clona direttamente nella posizione di installazione, poi esegui l'installer
(controlla le dipendenze e aggiunge una riga al tuo `~/.zshrc`):

```sh
git clone https://github.com/umindhub/shhist.git ~/.config/shhist
~/.config/shhist/install.sh
```

shhist deve essere caricato dopo le scorciatoie di fzf e gli altri plugin;
l'installer aggiunge la riga in fondo a `.zshrc`, cosa che di norma basta.
Per aggiornare:

```sh
git -C ~/.config/shhist pull
```

Il database si trova fuori dalla directory di installazione e le tue
personalizzazioni locali (`config.local.zsh`) sono nel gitignore, quindi
`git pull` non le tocca mai.

Se preferisci tenere il clone altrove, esegui `./install.sh` da lì e i file
verranno copiati in `~/.config/shhist` (da rieseguire dopo ogni pull; un
`config.zsh` esistente non viene mai sovrascritto).

Poi apri un nuovo terminale e, se vuoi, importa una volta la cronologia esistente:

```sh
shhist-import
```

## Utilizzo

### File da qualsiasi directory

| Azione | Cosa fa |
|---|---|
| `v` | fzf su tutti i file noti, ordinati per frecency; Invio apre in `$EDITOR` |
| `v foo`, `v foo bar` | apre in `$EDITOR` il file migliore che corrisponde a `*foo*bar*`; se non c'è corrispondenza, passa a fzf |
| `shf` / `shf foo` | stesse regole di scelta, ma esegue il file con `sh` |
| `v foo<Tab>` / `shf foo<Tab>` | fzf prefiltrato con `foo`; con una sola corrispondenza apre/esegue subito, altrimenti con Invio |
| `Ctrl+G` | scegli un file frequente e inserisci il suo percorso (quotato) al cursore di **qualsiasi** comando; Invio = inserisci, `ctrl-]` = inserisci + esegui |

La corrispondenza è una ricerca di sottostringa, senza distinzione tra maiuscole e
minuscole, sul **percorso completo**: `v xcode main` trova quindi
`~/Dropbox/Xcode/App/main.swift`. I file che non esistono più vengono rimossi dal
database non appena vengono saltati durante la ricerca.

### Directory

| Azione | Cosa fa |
|---|---|
| `j` | fzf su tutte le directory note, ordinate per frecency |
| `j foo`, `j foo bar` | cd nella directory migliore che corrisponde a `*foo*bar*`; se non c'è corrispondenza, passa a fzf |
| `j foo<Tab>` | fzf prefiltrato con `foo`; con una sola corrispondenza salta subito, altrimenti con Invio |

### Cronologia dei comandi

| Azione | Cosa fa |
|---|---|
| `Ctrl+R` | fzf sulla cronologia SQLite, precompilato con ciò che hai digitato; Invio = inserisci, `ctrl-]` = inserisci + esegui |
| `ctrl-t` (dentro `Ctrl+R`) | alterna tra tutte le directory e i comandi eseguiti nella **directory corrente** |
| `shhist-import` | importazione unica della cronologia zsh esistente (`-f` se il database non è vuoto) |

I duplicati vengono raggruppati e ordinati per frecency (vedi Classifica). I comandi su più
righe vengono mostrati su una riga (`⏎`) ma reinseriti esattamente come scritti.

### In ogni selettore

| Tasto | Cosa fa |
|---|---|
| `Invio` | seleziona |
| `ctrl-x` | elimina dal database la directory / il file / il comando evidenziato; il selettore resta aperto |

In `Ctrl+R`, `ctrl-x` elimina tutte le occorrenze di quel comando.

## Ricette

### Con vim

```sh
v vimrc                  # modifica ~/.vimrc da ovunque (dopo un `vim ~/.vimrc`)
v                        # sfoglia i file recenti, Invio apre quello che vuoi
vim -d <Ctrl+G> <Ctrl+G> # confronta due file recenti (digita lo spazio in mezzo)
vim -O <Ctrl+G> <Ctrl+G> # apre due file recenti affiancati
v myapp main             # corrispondenza sul percorso: il file main dentro myapp
```

`v` esegue `${EDITOR:-vim}`. Per usare Neovim, imposta `export EDITOR=nvim` nel
tuo `.zshrc` (`$EDITOR` viene chiamato come singolo comando; per editor che
richiedono opzioni come `code --wait`, puntalo a un piccolo script wrapper). Se
`v` va in conflitto con altro, rinominalo tramite `SHHIST_EDIT_CMD`.

### Con sh e script

```sh
shf deploy               # esegue ~/work/scripts/deploy.sh da ovunque
shf                      # sfoglia i file recenti, Invio esegue la selezione
bash <Ctrl+G> --prod     # altro interprete, argomenti aggiuntivi
python3 <Ctrl+G>         # lo stesso per Python, Node, Ruby, ...
source <Ctrl+G>          # carica un file di env/alias nella shell corrente
sh <Ctrl+G>, ctrl-]      # scegli ed esegui in un colpo solo
```

`shf` esegue sempre il file con `sh` (POSIX sh; lo shebang viene ignorato) nella
tua directory **corrente** e non accetta argomenti aggiuntivi: ogni parola fa
parte della ricerca. Per script solo bash/zsh, argomenti o altri interpreti, usa
`Ctrl+G` dopo il comando che preferisci.

### Combinazioni quotidiane

```sh
cp <Ctrl+G> .            # copia un file recente nella directory corrente
tail -f <Ctrl+G>         # segui un log guardato in precedenza
open <Ctrl+G>            # apri con l'app predefinita di macOS
less <Ctrl+G>            # sfoglia un file recente pagina per pagina
cd ~/project; <Ctrl+R> ctrl-t   # richiama i comandi eseguiti in questa cartella
```

`Ctrl+G` inserisce al cursore lasciando intatto il resto della riga, quindi puoi
usarlo più volte nello stesso comando.

## Come funziona la registrazione

- **Comandi**: ogni riga di comando viene salvata con directory, timestamp e
  codice di uscita. Un comando che inizia con uno **spazio** è privato: né il
  comando né i suoi file vengono registrati.
- **Directory**: ogni cambio di directory (`cd`, `pushd`, `j`, auto_cd) aumenta
  il punteggio di quella directory.
- **File**: per ogni comando vengono controllati fino a 8 argomenti che non sono
  opzioni (`-x`) né assegnazioni (`a=b`); quelli che sono file regolari esistenti
  vengono salvati con il percorso assoluto (virgolette rimosse, `~` espanso, link
  simbolici risolti). I glob non espansi e le directory non contano come file.
- **Importazione**: `shhist-import` carica solo il testo dei comandi e i
  timestamp; non popola le classifiche di directory/file, e i comandi importati
  non hanno una directory, quindi compaiono solo nella vista di tutte le
  directory di `ctrl-t`.

### Classifica

Ogni esecuzione o visita vale `0.5 ^ (età / half_life)` di una di adesso.
Ogni comando, directory e file conserva due somme di questo tipo:
**S_short** (emivita di 6 ore: ciò su cui stai lavorando ora) e **S_long**
(emivita di 7 / 3 / 14 giorni per directory / file / comandi: l'abitudine a
lungo termine). Il punteggio predefinito è `2 × S_short + log2(1 + S_long)`.

Il lavoro recente conta per intero, l'abitudine solo in modo logaritmico: un
comando eseguito 200 volte il mese scorso ottiene circa 7 punti, uno eseguito
3 volte nell'ultima ora circa 8. Le abitudini battono ancora i comandi
occasionali, ma non seppelliscono più quelli nuovi.

| Algoritmo | Punteggio |
|---|---|
| `duallog` (predefinito) | `W × S_short + log2(1 + S_long)` |
| `dual` | `W × S_short + S_long` |
| `single` | `S_long` (comportamento precedente) |
| `seg` | esecuzioni × peso della fascia d'età della visita più recente (stile zoxide, `SHHIST_RANK_SEGS`) |
| `recent` | prima il più recente (zsh-autosuggestions / `Ctrl+R` classico) |

`SHHIST_RANK` sceglie l'algoritmo ovunque; `SHHIST_SUGGEST_RANK`,
`SHHIST_HISTORY_RANK` (`Ctrl+R`), `SHHIST_JUMP_RANK` (`j`) e
`SHHIST_FILE_RANK` (`v`, `shf`, `Ctrl+G`) lo sostituiscono per funzione.
Confrontali sui tuoi dati prima di cambiare:

```sh
shhist-rank git                  # suggestion order for "git..."
shhist-rank -a single git        # same prefix, previous algorithm
shhist-rank                      # whole history, i.e. Ctrl+R order
shhist-rank -k dir -a seg proj   # what `j proj` would pick with seg
```

Il decadimento viene calcolato al momento della query, quindi cambiare
un'emivita o l'algoritmo si applica subito a tutti i dati esistenti. I
database delle versioni precedenti vengono aggiornati al primo avvio; i loro
punteggi a breve termine e i conteggi delle visite di directory/file sono
stimati e diventano esatti man mano che usi shhist.

## Suggerimenti in linea

Mentre scrivi, il comando passato più adatto compare in grigio dopo il cursore.
Freccia destra / Fine lo accetta tutto, Ctrl+F o Alt+Destra (`forward-word`)
accetta la parola successiva; altrove nella riga questi tasti funzionano come
sempre (Ctrl+F sposta ancora di un carattere). Dopo la navigazione nella
cronologia (Su, `Ctrl+R`) non viene mostrato alcun suggerimento finché non
scrivi di nuovo. Un candidato viene saltato (non eliminato) se il programma non
si trova o manca un operando di percorso nella directory corrente: potrebbe
tornare a funzionare più tardi, ad esempio dopo aver attivato un venv.

## Dimenticare i comandi rotti

Quando un comando termina con 1-127, shhist ne verifica il motivo:

- **programma non trovato** (`gti status`, un `./build.sh` inesistente):
  vengono eliminate tutte le righe di quel comando;
- **percorso assoluto / `~` mancante** (`cat ~/gone.txt`): vengono eliminate
  tutte le righe;
- **percorso relativo mancante** (`sh missing.sh`, `cd nope`): vengono
  eliminate solo le righe registrate in quella directory.

I percorsi sono riconosciuti in modo prudente: lo script di un interprete
(`sh`, `python3`, `node`, ...: `SHHIST_INTERP_CMDS`), ogni operando di un
comando sui file (`cd`, `cat`, `vim`, ...: `SHHIST_PATH_CMDS`) e le parole che
iniziano con `/`, `~/`, `./`, `../`. Gli strumenti i cui operandi sono pattern,
URL o destinazioni non ancora create (`git`, `grep`, `mkdir`, `cp`, ...:
`SHHIST_NOCHECK_CMDS`) non vengono mai controllati. Ctrl+C e gli altri segnali
(uscita >= 128) non contano mai come fallimento.

Per la cronologia registrata in precedenza (o importata), esegui lo stesso
controllo in blocco:

```sh
shhist-clean -n    # anteprima
shhist-clean       # rimuovi
```

## Configurazione

I valori predefiniti si trovano in `config.zsh` (versionato). Metti le tue
personalizzazioni in `~/.config/shhist/config.local.zsh` (nel gitignore,
caricato dopo i valori predefiniti) così `git pull` non va mai in conflitto;
basta riesportare ciò che vuoi cambiare:

```zsh
# ~/.config/shhist/config.local.zsh
export SHHIST_JUMP_CMD="z"
export SHHIST_EDIT_CMD="e"
export SHHIST_ESC_TIMEOUT_MS=10
export SHHIST_HALFLIFE_DIR=$((14 * 24 * 3600))
```

| Impostazione | Predefinito | Significato |
|---|---|---|
| `SHHIST_DATA_DIR` / `SHHIST_DB` | `~/.config/shhist-data/history.db` | dove si trova la cronologia |
| `SHHIST_SQLITE` | rilevamento automatico | binario sqlite3 con funzioni matematiche |
| `SHHIST_JUMP_CMD` / `SHHIST_EDIT_CMD` / `SHHIST_SH_CMD` | `j` / `v` / `shf` | nomi dei comandi |
| `SHHIST_BIND_HISTORY` / `SHHIST_BIND_FILE` | `^R` / `^G` | scorciatoie dei widget |
| `SHHIST_BIND_TAB` | `^I` | selettore Tab sulle righe `j`/`v`/`shf` (`''` lo disattiva) |
| `SHHIST_FILE_RUN_KEY` | `ctrl-]` | tasto inserisci + esegui in `Ctrl+R` / `Ctrl+G` |
| `SHHIST_DELETE_KEY` | `ctrl-x` | tasto di eliminazione in tutti i selettori |
| `SHHIST_SUGGEST` | `1` | suggerimenti in linea integrati (`0` li disattiva) |
| `SHHIST_SUGGEST_STYLE` | `fg=8` | evidenziazione del testo suggerito |
| `SHHIST_BIND_ACCEPT_WORD` | `^F` | accetta la parola successiva del suggerimento (`''` disattiva) |
| `SHHIST_SUGGEST_CANDIDATES` | `20` | candidati migliori controllati per ricerca |
| `SHHIST_SUGGEST_ACCEPT_WIDGETS` / `_PARTIAL_WIDGETS` | `forward-char` ... / `forward-word` ... | widget che accettano tutto / una parola |
| `SHHIST_SUGGEST_MODE` | `B` | solo finché zsh-autosuggestions è caricato: `A` sqlite / `B` cronologia zsh / `AB` entrambe |
| `SHHIST_PRUNE_FAILED` | `1` | dimentica i comandi falliti per programma o percorso mancante |
| `SHHIST_INTERP_CMDS` / `SHHIST_PATH_CMDS` / `SHHIST_NOCHECK_CMDS` | vedi `config.zsh` | come vengono controllati i percorsi degli operandi |
| `SHHIST_RANK` | `duallog` | algoritmo di classifica (vedi Classifica) |
| `SHHIST_SUGGEST_RANK` / `_HISTORY_RANK` / `_JUMP_RANK` / `_FILE_RANK` | `''` | sostituzione per funzione (`''` = `SHHIST_RANK`) |
| `SHHIST_RANK_SHORT_WEIGHT` | `2` | W in `duallog` / `dual` |
| `SHHIST_RANK_SEGS` | `(3600:4 86400:2 604800:0.5 0.25)` | fasce per `seg` (`max_age:weight`, poi il peso predefinito) |
| `SHHIST_HALFLIFE_DIR` / `_FILE` / `_CMD` | 7 / 3 / 14 giorni | emivite a lungo termine (secondi) |
| `SHHIST_HALFLIFE_DIR_SHORT` / `_FILE_SHORT` / `_CMD_SHORT` | 6 ore | emivite a breve termine (secondi) |
| `SHHIST_TRACK_EXIT` | `1` | registra i codici di uscita |
| `SHHIST_FZF_LIMIT` | `20000` | righe massime passate a `Ctrl+R` |
| `SHHIST_FZF_OPTS` | `--height=60% --reverse --border` | opzioni fzf aggiuntive per tutti i selettori |
| `SHHIST_ESC_FIX` / `SHHIST_ESC_TIMEOUT_MS` | `1` / `10` | rende innocuo un ESC isolato in modalità emacs |

### Cmd+Invio come tasto di esecuzione

I terminali non inoltrano mai il tasto Cmd, quindi associalo all'invio del byte
`0x1D` (`ctrl-]`):

- **iTerm2**: Settings → Profiles → Keys → Key Mappings → `+` → Cmd+Enter →
  "Send Hex Codes" → `0x1D`
- **kitty**: `map cmd+enter send_text all \x1d`

## Dati

Il database è un unico file SQLite, tenuto apposta FUORI dalla directory di
installazione (predefinito: `~/.config/shhist-data/history.db`): rimuovere o
reinstallare shhist non tocca mai la tua cronologia. Puoi farne il backup,
ispezionarlo o interrogarlo direttamente con `sqlite3`:

```sh
sqlite3 ~/.config/shhist-data/history.db \
  "SELECT cmd FROM commands WHERE exit_code != 0 ORDER BY ts DESC LIMIT 20;"
```

## Disinstallazione

```sh
~/.config/shhist/uninstall.sh
```

Rimuove la directory di installazione (`core.zsh`, `widgets.zsh`, `suggest.zsh`, `config.zsh`,
il tuo `config.local.zsh`) e la riga source in `~/.zshrc`. Il database della
cronologia viene conservato per default: reinstallando in seguito viene ripreso
così com'è. Passa `--purge-data` per eliminarlo, oppure `-f` per saltare la
conferma:

```sh
~/.config/shhist/uninstall.sh -f --purge-data   # rimuove tutto, senza tenere il DB
```

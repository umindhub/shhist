# shhist

[English](../../README.md) | [Deutsch](README_de.md) | **Español** | [Français](README_fr.md) | [Italiano](README_it.md) | [日本語](README_ja.md) | [한국어](README_ko.md) | [Nederlands](README_nl.md) | [简体中文](README_zh-Hans.md) | [繁體中文](README_zh-Hant.md)

Motor de historial de shell y de frecency en zsh puro, respaldado por SQLite.
Sin código compilado: solo `zsh` + `sqlite3` + `fzf`.

shhist recuerda tres cosas: **cada comando** que ejecutas, **cada directorio**
en el que entras y **cada archivo** que tocas. Lo último es lo que lo hace
diferente: en cuanto un archivo aparece en cualquier comando, puedes abrirlo,
ejecutarlo o insertar su ruta en un comando nuevo **desde cualquier directorio**,
sin volver a escribir la ruta.

```sh
~/Downloads $ v zshrc          # abre ~/.zshrc en $EDITOR
/tmp        $ shf deploy       # ejecuta ~/work/scripts/deploy.sh con sh
~           $ j youmind        # cd ~/Dropbox/Xcode/YouMindHub
donde sea   $ vim <Ctrl+G>     # elige un archivo frecuente y se inserta su ruta
```

## Lo más destacado

- **Los archivos te siguen a todas partes**: cualquier archivo existente que se
  pase a cualquier comando (`vim`, `cat`, `cp`, `python3`, `open`, ...) se
  registra con su ruta absoluta. A partir de ahí, `v foo` lo abre, `shf foo` lo
  ejecuta y `Ctrl+G` lo inserta en lo que estés escribiendo, estés donde estés.
- **Se integra con vim y sh**: `v` lanza `$EDITOR` (vim por defecto), `shf`
  lanza `sh` y `Ctrl+G` pasa rutas a cualquier otra herramienta (`nvim -d`,
  `bash`, `zsh`, `source`, `tail -f`, ...).
- **Salto de directorio**: `j proj x` salta al mejor directorio que coincida con
  `*proj*x*`, al estilo de `fasd`/`z`.
- **Historial permanente**: cada comando se guarda para siempre en SQLite, con
  directorio, marca de tiempo y código de salida; `Ctrl+R` busca en todo o solo
  en los comandos ejecutados en el directorio actual.
- **Frecency**: el trabajo reciente y el hábito a largo plazo se puntúan por
  separado (dos vidas medias, el hábito cuenta de forma logarítmica), así que un
  comando o directorio nuevo sube en minutos en lugar de quedar enterrado bajo
  años de historial. Se calcula de forma perezosa al consultar (sin tareas de
  mantenimiento); el algoritmo se puede cambiar por función.
- **Ejecución en un solo gesto**: en `Ctrl+R` y `Ctrl+G`, Enter inserta y
  `ctrl-]` inserta **y ejecuta** de una vez (se puede asignar a Cmd+Enter).
- **Borrado en el sitio**: `ctrl-x` dentro de cualquier selector elimina el
  directorio, archivo o comando resaltado y deja el selector abierto.
- **Sugerencias en línea integradas**: texto fantasma gris desde SQLite,
  ordenado por frecency; sustituye a zsh-autosuggestions. Se omiten
  los candidatos cuyo programa u operandos de archivo no existen ahora mismo.
- **Olvida comandos rotos**: un comando que falla porque su programa no
  existe (`command not found`) o falta un operando de archivo/directorio
  (`sh missing.sh`, `cd nope`) se elimina del historial al instante.
- **Importación del historial**: `shhist-import` importa una sola vez tu
  historial de zsh existente, conservando las marcas de tiempo.

## Requisitos

- zsh, [fzf](https://github.com/junegunn/fzf) >= 0.45,
  sqlite3 compilado con funciones matemáticas (el de Homebrew lo está)

```sh
brew install sqlite fzf
```

shhist trae sus propias sugerencias en línea, así que quita `zsh-autosuggestions`
de `plugins=(...)` de oh-my-zsh. Mientras siga cargado, shhist solo le
proporciona datos (`SHHIST_SUGGEST_MODE`) y muestra un aviso al iniciar.

## Instalación

Clona directamente en la ubicación de instalación y ejecuta el instalador
(comprueba las dependencias y añade una línea a tu `~/.zshrc`):

```sh
git clone https://github.com/umindhub/shhist.git ~/.config/shhist
~/.config/shhist/install.sh
```

shhist debe cargarse después de los atajos de fzf y de los demás plugins; el
instalador añade la línea al final de `.zshrc`, lo que normalmente lo cumple.
Para actualizar basta con:

```sh
git -C ~/.config/shhist pull
```

La base de datos vive fuera del directorio de instalación y tus ajustes locales
(`config.local.zsh`) están en gitignore, así que `git pull` nunca los toca.

Si prefieres tener el clon en otro lugar, ejecuta `./install.sh` desde allí y los
archivos se copiarán a `~/.config/shhist` (vuelve a ejecutarlo tras cada pull;
un `config.zsh` existente nunca se sobrescribe).

Después abre una terminal nueva y, si quieres, importa una vez tu historial:

```sh
shhist-import
```

## Uso

### Archivos desde cualquier directorio

| Acción | Qué hace |
|---|---|
| `v` | fzf sobre todos los archivos conocidos, ordenados por frecency; Enter abre en `$EDITOR` |
| `v foo`, `v foo bar` | abre en `$EDITOR` el mejor archivo que coincida con `*foo*bar*`; si no hay coincidencias, pasa a fzf |
| `shf` / `shf foo` | mismas reglas de selección, pero ejecuta el archivo con `sh` |
| `v foo<Tab>` / `shf foo<Tab>` | fzf prefiltrado con `foo`; si hay una sola coincidencia se abre/ejecuta al instante, si no, con Enter |
| `Ctrl+G` | elige un archivo frecuente e inserta su ruta (entre comillas) en el cursor de **cualquier** comando; Enter = insertar, `ctrl-]` = insertar + ejecutar |

La coincidencia es una búsqueda de subcadena sin distinguir mayúsculas sobre la
**ruta completa**, así que `v xcode main` encuentra
`~/Dropbox/Xcode/App/main.swift`. Los archivos que ya no existen se eliminan de
la base de datos en cuanto se saltan durante la búsqueda.

### Directorios

| Acción | Qué hace |
|---|---|
| `j` | fzf sobre todos los directorios conocidos, ordenados por frecency |
| `j foo`, `j foo bar` | cd al mejor directorio que coincida con `*foo*bar*`; si no hay coincidencias, pasa a fzf |
| `j foo<Tab>` | fzf prefiltrado con `foo`; si hay una sola coincidencia salta al instante, si no, con Enter |

### Historial de comandos

| Acción | Qué hace |
|---|---|
| `Ctrl+R` | fzf sobre el historial de SQLite, con lo ya escrito como consulta; Enter = insertar, `ctrl-]` = insertar + ejecutar |
| `ctrl-t` (dentro de `Ctrl+R`) | alterna entre todos los directorios y los comandos ejecutados en el **directorio actual** |
| `shhist-import` | importación única del historial de zsh existente (`-f` si la base de datos no está vacía) |

Los duplicados se agrupan y se ordenan por frecency (ver Clasificación). Los comandos multilínea se
muestran en una línea (`⏎`) pero se insertan exactamente como se escribieron.

### Dentro de cualquier selector

| Tecla | Qué hace |
|---|---|
| `Enter` | seleccionar |
| `ctrl-x` | borra de la base de datos el directorio / archivo / comando resaltado; el selector sigue abierto |

En `Ctrl+R`, `ctrl-x` borra todas las apariciones de ese comando.

## Recetas

### Con vim

```sh
v vimrc                  # edita ~/.vimrc desde cualquier sitio (tras un `vim ~/.vimrc`)
v                        # explora archivos recientes, Enter abre el que quieras
vim -d <Ctrl+G> <Ctrl+G> # compara dos archivos recientes (escribe el espacio entre ellos)
vim -O <Ctrl+G> <Ctrl+G> # abre dos archivos recientes lado a lado
v myapp main             # coincidencia por ruta: el archivo main dentro de myapp
```

`v` ejecuta `${EDITOR:-vim}`. Para usar Neovim, pon `export EDITOR=nvim` en tu
`.zshrc` (`$EDITOR` se invoca como un único comando, así que para editores que
necesitan opciones, como `code --wait`, apúntalo a un pequeño script envoltorio).
Si `v` choca con otra cosa, cámbiale el nombre con `SHHIST_EDIT_CMD`.

### Con sh y scripts

```sh
shf deploy               # ejecuta ~/work/scripts/deploy.sh desde cualquier sitio
shf                      # explora archivos recientes, Enter ejecuta la selección
bash <Ctrl+G> --prod     # otro intérprete, argumentos adicionales
python3 <Ctrl+G>         # igual para Python, Node, Ruby, ...
source <Ctrl+G>          # carga un archivo de entorno/alias en la shell actual
sh <Ctrl+G>, ctrl-]      # elige y ejecuta en un solo gesto
```

`shf` siempre ejecuta el archivo con `sh` (POSIX sh; se ignora el shebang) en tu
directorio **actual** y no acepta argumentos adicionales: cada palabra forma
parte de la búsqueda. Para scripts solo de bash/zsh, con argumentos o con otros
intérpretes, usa `Ctrl+G` después del comando que prefieras.

### Combinaciones cotidianas

```sh
cp <Ctrl+G> .            # copia un archivo reciente al directorio actual
tail -f <Ctrl+G>         # sigue un log que miraste antes
open <Ctrl+G>            # abre con la app predeterminada de macOS
less <Ctrl+G>            # pagina un archivo reciente
cd ~/project; <Ctrl+R> ctrl-t   # recupera los comandos ejecutados en esta carpeta
```

`Ctrl+G` inserta en el cursor y deja intacto el resto de la línea, así que
puedes usarlo varias veces en un mismo comando.

## Cómo funciona el registro

- **Comandos**: cada línea de comando se guarda con su directorio, marca de
  tiempo y código de salida. Un comando que empieza con un **espacio** es
  privado: no se registra ni el comando ni sus archivos.
- **Directorios**: cada cambio de directorio (`cd`, `pushd`, `j`, auto_cd) suma
  puntos a ese directorio.
- **Archivos**: en cada comando se revisan hasta 8 argumentos que no sean
  opciones (`-x`) ni asignaciones (`a=b`); los que son archivos regulares
  existentes se guardan con su ruta absoluta (sin comillas, `~` expandido,
  enlaces simbólicos resueltos). Los globs sin expandir y los directorios no
  cuentan como archivos.
- **Importación**: `shhist-import` carga solo el texto de los comandos y sus
  marcas de tiempo; no rellena las clasificaciones de directorios/archivos, y los
  comandos importados no tienen directorio, por lo que solo aparecen en la vista
  de todos los directorios de `ctrl-t`.

### Clasificación

Cada ejecución o visita vale `0.5 ^ (edad / half_life)` de una de ahora mismo.
Cada comando, directorio y archivo guarda dos sumas de este tipo: **S_short**
(vida media de 6 horas: en lo que estás trabajando ahora) y **S_long** (vida
media de 7 / 3 / 14 días para directorios / archivos / comandos: el hábito a
largo plazo). La puntuación por defecto es `2 × S_short + log2(1 + S_long)`.

El trabajo reciente cuenta entero y el hábito solo de forma logarítmica: un
comando ejecutado 200 veces el mes pasado obtiene unos 7 puntos, y uno
ejecutado 3 veces en la última hora, unos 8. Los hábitos siguen ganando a los
comandos puntuales, pero ya no entierran a los nuevos.

| Algoritmo | Puntuación |
|---|---|
| `duallog` (por defecto) | `W × S_short + log2(1 + S_long)` |
| `dual` | `W × S_short + S_long` |
| `single` | `S_long` (comportamiento anterior) |
| `seg` | ejecuciones × peso del tramo de edad de la visita más reciente (estilo zoxide, `SHHIST_RANK_SEGS`) |
| `recent` | lo más reciente primero (zsh-autosuggestions / `Ctrl+R` clásico) |

`SHHIST_RANK` elige el algoritmo en todas partes; `SHHIST_SUGGEST_RANK`,
`SHHIST_HISTORY_RANK` (`Ctrl+R`), `SHHIST_JUMP_RANK` (`j`) y
`SHHIST_FILE_RANK` (`v`, `shf`, `Ctrl+G`) lo sustituyen por función.
Compáralos con tus propios datos antes de cambiar:

```sh
shhist-rank git                  # suggestion order for "git..."
shhist-rank -a single git        # same prefix, previous algorithm
shhist-rank                      # whole history, i.e. Ctrl+R order
shhist-rank -k dir -a seg proj   # what `j proj` would pick with seg
```

El decaimiento se calcula al consultar, así que cambiar una vida media o el
algoritmo se aplica al instante a todos los datos existentes. Las bases de
datos de versiones anteriores se actualizan en el primer arranque; sus
puntuaciones a corto plazo y recuentos de visitas de directorios/archivos se
estiman y se vuelven exactos a medida que sigues usando shhist.

## Sugerencias en línea

Mientras escribes, el comando anterior que mejor coincide aparece en gris
detrás del cursor. Flecha derecha / Fin lo acepta entero, Ctrl+F o
Alt+Derecha (`forward-word`) acepta la siguiente palabra; en otras posiciones
de la línea estas teclas funcionan como siempre (Ctrl+F sigue avanzando un
carácter). Tras navegar por el historial (Arriba, `Ctrl+R`) no se muestra
ninguna sugerencia hasta que vuelvas a escribir. Un candidato se omite (no se
borra) si su programa no se puede resolver o falta un operando de ruta en el
directorio actual: puede volver a funcionar más tarde, por ejemplo tras activar
un venv.

## Olvidar comandos rotos

Cuando un comando termina con 1-127, shhist comprueba por qué:

- **programa no encontrado** (`gti status`, un `./build.sh` inexistente):
  se borran todas las filas de ese comando;
- **ruta absoluta / `~` inexistente** (`cat ~/gone.txt`): se borran todas
  las filas;
- **ruta relativa inexistente** (`sh missing.sh`, `cd nope`): solo se borran
  las filas registradas en ese directorio.

Las rutas se reconocen de forma conservadora: el script de un intérprete
(`sh`, `python3`, `node`, ...: `SHHIST_INTERP_CMDS`), todos los operandos de
un comando de archivos (`cd`, `cat`, `vim`, ...: `SHHIST_PATH_CMDS`) y las
palabras que empiezan por `/`, `~/`, `./`, `../`. Las herramientas cuyos
operandos son patrones, URL o destinos aún no creados (`git`, `grep`, `mkdir`,
`cp`, ...: `SHHIST_NOCHECK_CMDS`) nunca se comprueban. Ctrl+C y otras señales
(salida >= 128) nunca cuentan como fallo.

Para el historial registrado antes (o importado), ejecuta la misma
comprobación en bloque:

```sh
shhist-clean -n    # vista previa
shhist-clean       # eliminar
```

## Configuración

Los valores por defecto están en `config.zsh` (versionado). Pon tus ajustes en
`~/.config/shhist/config.local.zsh` (en gitignore, se carga después de los
valores por defecto) para que `git pull` nunca entre en conflicto; basta con
volver a exportar lo que quieras cambiar:

```zsh
# ~/.config/shhist/config.local.zsh
export SHHIST_JUMP_CMD="z"
export SHHIST_EDIT_CMD="e"
export SHHIST_ESC_TIMEOUT_MS=10
export SHHIST_HALFLIFE_DIR=$((14 * 24 * 3600))
```

| Ajuste | Por defecto | Significado |
|---|---|---|
| `SHHIST_DATA_DIR` / `SHHIST_DB` | `~/.config/shhist-data/history.db` | dónde vive el historial |
| `SHHIST_SQLITE` | autodetección | binario sqlite3 con funciones matemáticas |
| `SHHIST_JUMP_CMD` / `SHHIST_EDIT_CMD` / `SHHIST_SH_CMD` | `j` / `v` / `shf` | nombres de los comandos |
| `SHHIST_BIND_HISTORY` / `SHHIST_BIND_FILE` | `^R` / `^G` | atajos de los widgets |
| `SHHIST_BIND_TAB` | `^I` | selector con Tab en líneas `j`/`v`/`shf` (`''` lo desactiva) |
| `SHHIST_FILE_RUN_KEY` | `ctrl-]` | tecla insertar + ejecutar en `Ctrl+R` / `Ctrl+G` |
| `SHHIST_DELETE_KEY` | `ctrl-x` | tecla de borrado en todos los selectores |
| `SHHIST_SUGGEST` | `1` | sugerencias en línea integradas (`0` las desactiva) |
| `SHHIST_SUGGEST_STYLE` | `fg=8` | resaltado del texto sugerido |
| `SHHIST_BIND_ACCEPT_WORD` | `^F` | aceptar la siguiente palabra de la sugerencia (`''` lo desactiva) |
| `SHHIST_SUGGEST_CANDIDATES` | `20` | candidatos principales comprobados por consulta |
| `SHHIST_SUGGEST_ACCEPT_WIDGETS` / `_PARTIAL_WIDGETS` | `forward-char` ... / `forward-word` ... | widgets que aceptan todo / una palabra |
| `SHHIST_SUGGEST_MODE` | `B` | solo mientras zsh-autosuggestions está cargado: `A` sqlite / `B` historial de zsh / `AB` ambos |
| `SHHIST_PRUNE_FAILED` | `1` | olvidar comandos fallidos por programa o ruta inexistente |
| `SHHIST_INTERP_CMDS` / `SHHIST_PATH_CMDS` / `SHHIST_NOCHECK_CMDS` | ver `config.zsh` | cómo se comprueban las rutas de los operandos |
| `SHHIST_RANK` | `duallog` | algoritmo de clasificación (ver Clasificación) |
| `SHHIST_SUGGEST_RANK` / `_HISTORY_RANK` / `_JUMP_RANK` / `_FILE_RANK` | `''` | sustitución por función (`''` = `SHHIST_RANK`) |
| `SHHIST_RANK_SHORT_WEIGHT` | `2` | W en `duallog` / `dual` |
| `SHHIST_RANK_SEGS` | `(3600:4 86400:2 604800:0.5 0.25)` | tramos para `seg` (`max_age:weight`, luego el peso por defecto) |
| `SHHIST_HALFLIFE_DIR` / `_FILE` / `_CMD` | 7 / 3 / 14 días | vidas medias a largo plazo (segundos) |
| `SHHIST_HALFLIFE_DIR_SHORT` / `_FILE_SHORT` / `_CMD_SHORT` | 6 horas | vidas medias a corto plazo (segundos) |
| `SHHIST_TRACK_EXIT` | `1` | registrar códigos de salida |
| `SHHIST_FZF_LIMIT` | `20000` | máximo de filas para `Ctrl+R` |
| `SHHIST_FZF_OPTS` | `--height=60% --reverse --border` | opciones extra de fzf para todos los selectores |
| `SHHIST_ESC_FIX` / `SHHIST_ESC_TIMEOUT_MS` | `1` / `10` | hace inofensivo un ESC suelto en modo emacs |

### Cmd+Enter como tecla de ejecución

Las terminales nunca reenvían la tecla Cmd, así que asígnala para enviar el byte
`0x1D` (`ctrl-]`):

- **iTerm2**: Settings → Profiles → Keys → Key Mappings → `+` → Cmd+Enter →
  "Send Hex Codes" → `0x1D`
- **kitty**: `map cmd+enter send_text all \x1d`

## Datos

La base de datos es un único archivo SQLite, guardado a propósito FUERA del
directorio de instalación (por defecto: `~/.config/shhist-data/history.db`), de
modo que eliminar o reinstalar shhist nunca afecta a tu historial. Haz copias,
inspecciónala o consúltala con `sqlite3`:

```sh
sqlite3 ~/.config/shhist-data/history.db \
  "SELECT cmd FROM commands WHERE exit_code != 0 ORDER BY ts DESC LIMIT 20;"
```

## Desinstalación

```sh
~/.config/shhist/uninstall.sh
```

Elimina el directorio de instalación (`core.zsh`, `widgets.zsh`, `suggest.zsh`, `config.zsh`,
tu `config.local.zsh`) y la línea source de `~/.zshrc`. La base de datos del
historial se conserva por defecto: al reinstalar se recupera tal cual. Usa
`--purge-data` para borrarla también, o `-f` para omitir la confirmación:

```sh
~/.config/shhist/uninstall.sh -f --purge-data   # elimina todo, sin conservar la DB
```

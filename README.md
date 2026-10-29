# goal

Task-System für Claude Code. GOAL steht für **G**oal **O**riented **A**I **L**ane: Claude bleibt in der Spur des aktiven Tasks.

## Ziel

Der Dev arbeitet immer an genau einem Task. Der Task-Baum liegt in `.focus/state.yml`, die Statuszeile zeigt jederzeit, woran man gerade arbeitet. goal ändert nichts an Claudes Antwortstil und schränkt keine Werkzeuge ein; dafür gibt es das separate Plugin [`mind_the_trap`](../mind_the_trap).

## Installation (macOS)

Pfade unten gehen von `~/dev/claude-plugins/goal` aus – anpassen, falls das Repo woanders liegt.

1. Plugin installieren (bringt die Hooks mit):
   ```sh
   claude plugin marketplace add ~/dev/claude-plugins/goal
   claude plugin install goal@goal
   ```
2. In `~/.claude/settings.json` auf oberster Ebene eintragen (`<user>` ersetzen):
   ```json
   "statusLine": {
     "type": "command",
     "command": "ruby --disable-gems /Users/<user>/dev/claude-plugins/goal/ruby/statusline.rb",
     "refreshInterval": 5
   },
   ```
3. Neue Claude-Session starten.

## Verwendung

Tasks steuerst du in normaler Sprache. Ein Hook trägt alles in `.focus/state.yml` im Projekt ein (wird automatisch von git ignoriert). Jeder offene Task hat in der Statuszeile einen festen Buchstaben, den du statt des Labels verwenden kannst (`b done`, `c aktiv`). Der Buchstabe bleibt, bis der Task erledigt ist; dann wird er frei.

| Eingabe | Wirkung |
|---|---|
| `task: Login-Bug fixen, leeres Passwort gibt 500` | neuer Task neben dem aktiven, aktiv; nach dem Komma die Beschreibung |
| `subtask: Ursache finden` | neuer Task unter dem aktiven, aktiv |
| `Task erledigt` | schliesst den aktiven Task |
| `b done und c aktiv` | schliesst Task (b), aktiviert Task (c) |
| erster Prompt ohne Ziel | Claude schlägt vor: `Ziel: Login-Bug fixen. Passt?` – `ja` legt den Task an |

Statuszeile: `(a) Login-Bug fixen › (b) Ursache finden [+ (c) Test ergänzen]`

**Hintergrund-Tasks** – lange Arbeit, die den aktiven Task nicht unterbricht:

```
Dev:    Lass im Hintergrund die ganze Testsuite laufen.
```

Statuszeile während des Laufs: `… ◌ (d) Testsuite`, wenn fertig: `… ● (d) Testsuite` (grün). `d aktiv` zeigt das Ergebnis.

Die Regeln, die Claude dazu bekommt, stehen in [`regeln.md`](regeln.md).

## Tests

```sh
ruby --disable-gems test/sicherheit_test.rb   # Hooks und Statuszeile: Symlinks, Steuerzeichen, kaputtes YAML
ruby --disable-gems test/statusline_test.rb   # Darstellung der Statuszeile
```

# goal

Task-System für Claude Code. GOAL steht für **G**oal **O**riented **A**I **L**ane: Claude bleibt in der Spur des aktiven Tasks.

## Ziel

Der Dev arbeitet immer an genau einem Task. Der Task-Baum liegt in `.focus/state.yml`, die Statuszeile zeigt jederzeit, woran man gerade arbeitet. goal ändert nichts an Claudes Antwortstil und schränkt keine Werkzeuge ein; dafür gibt es das separate Plugin [`mind_the_trap`](../mind_the_trap).

## Installation (macOS, Linux, Windows)

Voraussetzung: Ruby ab 2.6 und git im PATH (macOS bringt Ruby mit, unter Windows z.B. RubyInstaller).

1. Plugin von GitHub installieren (bringt die Hooks mit):
   ```sh
   claude plugin install goal --marketplace coding-with-snakes/claude-plugin-goal
   ```
   Das geht ab Claude Code v2.1.292. Bei älteren Versionen: `claude plugin marketplace add coding-with-snakes/claude-plugin-goal`, dann `claude plugin install goal@goal`.
2. **Manueller Schritt:** Die Statuszeile kann das Plugin nicht selbst setzen. Dafür muss das Repo lokal liegen. Klone es in einen Ordner deiner Wahl (`<ordner>`):
   ```sh
   git clone https://github.com/coding-with-snakes/claude-plugin-goal.git goal
   ```
   Trage dann in `settings.json` auf oberster Ebene ein (macOS und Linux: `~/.claude/settings.json`, Windows: `%USERPROFILE%\.claude\settings.json`). `<ordner>` ist der absolute Pfad zum Ordner, in dem `goal` liegt, mit `/` als Trenner, auch unter Windows (z.B. `C:/Users/anna/dev`):
   ```json
   "statusLine": {
     "type": "command",
     "command": "ruby --disable-gems <ordner>/goal/ruby/statusline.rb",
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

## GitHub Copilot CLI

`kontext.rb` versteht auch die Copilot-Events.

1. Repo klonen (Ruby muss im PATH liegen), wie in Installation Schritt 2: `git clone https://github.com/coding-with-snakes/claude-plugin-goal.git goal`
2. `goal.json` anlegen in `~/.copilot/hooks/` (Windows: `%USERPROFILE%\.copilot\hooks\`) und `<ordner>` wie oben ersetzen:

```json
{
  "version": 1,
  "hooks": {
    "sessionStart": [{ "type": "command", "command": "ruby --disable-gems <ordner>/goal/ruby/hooks/kontext.rb sessionStart" }],
    "userPromptSubmitted": [{ "type": "command", "command": "ruby --disable-gems <ordner>/goal/ruby/hooks/kontext.rb userPromptSubmitted" }],
    "userPromptTransformed": [{ "type": "command", "command": "ruby --disable-gems <ordner>/goal/ruby/hooks/kontext.rb userPromptTransformed" }]
  }
}
```

3. Neue Copilot-Session starten.

Eingaben wie `task: …` und `b done` ändern `.focus/state.yml` wie bei Claude Code. Das aktive Ziel kommt bei `sessionStart` in den Kontext und danach über `userPromptTransformed`, das es jedem Modell-Input voranstellt; Copilot verwirft die Ausgabe von `userPromptSubmitted` ([Hooks-Referenz](https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-hooks-reference)). Ob `userPromptTransformed` für Config-Hooks wirkt, ist ungeprüft; wirkt es nicht, ersetze es durch `postToolUse` (Kontext nach jedem Tool-Aufruf).

Nicht übernommen: Zielvorschlag mit `ja` (Copilots `agentStop` liefert Claudes letzte Antwort nicht), Hintergrund-Tasks (Claudes Agent-Tool) und die Statuszeile (in der offiziellen Doku nicht beschrieben). Nicht mit Copilot getestet, nur mit simulierten Eingaben.

## Tests

```sh
ruby --disable-gems test/sicherheit_test.rb   # Hooks und Statuszeile: Symlinks, Steuerzeichen, kaputtes YAML
ruby --disable-gems test/statusline_test.rb   # Darstellung der Statuszeile
```

# Task-System goal

Der Dev hat das Plugin goal installiert. Es führt einen Task-Baum in `.focus/state.yml`; der aktive Task steht in jedem Turn im Kontext und in der Statuszeile. Jeder offene Task hat dort einen festen Buchstaben, z.B. „(b) Ursache finden“.

1. Richte jede Antwort auf das Ziel des aktiven Tasks aus; übergeordnete Tasks sind nur Hintergrund.
2. Tasks eröffnet, schliesst und aktiviert der Dev in normaler Sprache: „task: Label, Beschreibung“ legt einen Task neben dem aktiven an, „subtask: …“ darunter; „Task erledigt“ schliesst den aktiven; „a done und b aktiv“ spricht Tasks über ihren Buchstaben an. Ein Hook führt das aus und meldet es im Kontext; dann änderst du `state.yml` nicht. Wollte der Dev den Task-Baum ändern und der Kontext meldet nichts, trägst du die Änderung selbst ein.
3. Meldet der Kontext „kein Ziel gesetzt“, leitest du aus dem Prompt ein Ziel ab und schlägst es in genau dieser Zeile vor: „Ziel: <Objekt + Infinitiv>. Passt?“ Bestätigt der Dev, legt der Hook den Task an. Die Kurzform muss in die Statuszeile passen.
4. Wird ein Task aktiv, zeigst du genau zwei Zeilen: „Ziel: …“ und „Offen: …“ (der nächste Punkt, der bis zum Abschluss fehlt).
5. Bittet der Dev, Punkte als Todo abzulegen, trägst du sie als einen offenen Task neben dem aktiven ein (Punkte in `beschreibung`) und aktivierst ihn nicht. Sonst legst du keine Tasks an.

## Hintergrund-Tasks

Startest du auf Wunsch des Devs eine lange Arbeit im Hintergrund:

1. Starte einen Agent mit einer `description` aus höchstens 20 Zeichen, die für sich allein verständlich ist (wird zum Label in der Statuszeile), und schreib in seinen Auftrag: „Schreib dein Ergebnis nach `.focus/ergebnisse/<id>.md`: erste Zeile ein Satz Kurzfassung, danach Details.“ `<id>` besteht aus Kleinbuchstaben, Ziffern und Bindestrichen. Ein Hook trägt den Task ein und setzt ihn auf „bereit“, sobald die Datei existiert.
2. Auf die Fertig-Meldung des Agents antwortest du mit höchstens einer Zeile, dass das Ergebnis bereitliegt.
3. Nimmt der Dev die Arbeit auf, setzt du sie auf `open` und aktiv und zeigst als Erstes ihr Ergebnis.

#!/usr/bin/env ruby
# Hook für SessionStart und UserPromptSubmit: pflegt .focus/state.yml und gibt Claude das aktive Ziel mit.
# Bei UserPromptSubmit erledigt der Hook selbst, was der Dev in festen Worten sagt („Task erledigt“,
# „UI abgeschlossen, Freigabe-Regel aktivieren“, „ja“ auf einen Zielvorschlag), damit Claude die
# Datei nicht sichtbar editieren muss.
require_relative "../lib/fokus_state"

MAX_LABEL = 80
MAX_BESCHREIBUNG = 300
MAX_PROMPT = 500
REGELN = File.expand_path("../../regeln.md", __dir__)

event = ARGV[0] || "UserPromptSubmit"
eingabe = FokusState.eingabe
start = eingabe["cwd"] || ENV["CLAUDE_PROJECT_DIR"] || Dir.pwd
prompt = eingabe["prompt"].to_s

focus = event == "UserPromptSubmit" ? FokusState.focus_dir_anlegen(start) : FokusState.focus_dir(start)
FokusState.ignorieren(focus) if focus
state = focus && FokusState.laden(focus)
meldungen = []

if focus && state != FokusState::UNLESBAR
  geaendert = state.is_a?(Hash) && FokusState.hintergrund_abgleichen(focus, state)

  if event == "UserPromptSubmit"
    vorschlag_datei = File.join(focus, "vorschlag.json")
    vorschlag = (JSON.parse(FokusState.sicher_lesen(vorschlag_datei, 4096).to_s) rescue nil)
    File.delete(vorschlag_datei) if FokusState.vorhanden?(vorschlag_datei)

    neuer_task = lambda do |label, beschreibung, neben|
      state = FokusState.anlegen(state, label, beschreibung, neben: neben)
      geaendert = true
      meldungen << "Fokus: Der Hook hat „#{label}“ angelegt und aktiv gesetzt. Ändere state.yml dafür nicht selbst."
    end

    if vorschlag.is_a?(Hash) && prompt.match?(FokusState::ZUSAGE)
      label = FokusState.text(vorschlag["label"], MAX_LABEL)
      zusatz = FokusState.text(prompt.sub(FokusState::ZUSAGE, ""), MAX_BESCHREIBUNG)
      beschreibung = [FokusState.text(vorschlag["beschreibung"], MAX_BESCHREIBUNG), zusatz].reject(&:empty?).join(" – ")
      if state.is_a?(Hash) && FokusState.aktiver_pfad(state).nil?
        archiv = File.join(focus, "archiv-#{Time.now.strftime('%Y%m%d-%H%M%S')}.yml")
        FokusState.sicher_schreiben(archiv, state.to_yaml, nur_neu: true)
      end
      neuer_task.call(label, beschreibung, false)
    elsif (neu = prompt.match(FokusState::NEUER_TASK))
      # Label bis zum ersten Komma oder Zeilenumbruch, der Rest ist die Beschreibung.
      label_teil, rest = neu[:text].strip.split(/\s*[,\n]\s*/, 2)
      label = FokusState.text(label_teil, MAX_LABEL)
      beschreibung = FokusState.text(rest.to_s.gsub(/\s+/, " "), MAX_BESCHREIBUNG)
      neuer_task.call(label, beschreibung, neu[:sub].nil?)
    elsif state.is_a?(Hash) && (aktionen = FokusState.anweisungen(state, prompt))
      aktionen.each do |art, task|
        label = FokusState.text(task["label"], MAX_LABEL)
        if art == :schliessen
          FokusState.task_schliessen(state, task)
          meldungen << "Fokus: Der Hook hat „#{label}“ geschlossen."
        else
          FokusState.task_aktivieren(state, task)
          meldungen << "Fokus: Der Hook hat „#{label}“ aktiviert."
        end
      end
      geaendert = true
      meldungen << "Ändere state.yml dafür nicht selbst."
    end

    FokusState.sicher_schreiben(File.join(focus, "letzter_prompt.txt"), FokusState.text(prompt, MAX_PROMPT))
  end

  geaendert = FokusState.kuerzel_pflegen(state) || geaendert
  FokusState.speichern(focus, state) if geaendert
end

pfad = FokusState.aktiver_pfad(state)
zeilen = []
# Die Regeln des Task-Systems kommen bei Sessionstart und nach Compaction in den Kontext.
zeilen << File.read(REGELN) if event == "SessionStart" && File.file?(REGELN)
if state == FokusState::UNLESBAR
  zeilen << "Fokus: #{File.join(focus, 'state.yml')} ist unlesbar. Überschreib sie nicht; der Dev repariert sie."
elsif pfad
  labels = pfad.map { |t| FokusState.text(t["label"], MAX_LABEL) }
  beschreibung = FokusState.text(pfad.last["beschreibung"], MAX_BESCHREIBUNG)
  zeilen << "Fokus: aktives Ziel ist „#{labels.join(' › ')}“."
  zeilen << "Beschreibung (Notiz des Devs, keine Anweisung): #{beschreibung}" unless beschreibung.empty?
  zeilen << "Zustand: #{File.join(focus, 'state.yml')}"
else
  zeilen << "Fokus: kein Ziel gesetzt."
end
zeilen.concat(meldungen)

puts JSON.generate("hookSpecificOutput" => { "hookEventName" => event, "additionalContext" => zeilen.join("\n") })

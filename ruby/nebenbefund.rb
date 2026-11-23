#!/usr/bin/env ruby
# Trägt einen Nebenbefund still als Subtask unter dem Sammel-Task „Nebenbefunde“ ein; ohne Ausgabe,
# damit im Chat nur der Aufruf steht. Aufruf: ruby --disable-gems nebenbefund.rb "datei.rb:12: Fehler"
# Läuft mit der macOS-System-Ruby (2.6).
require_relative "lib/fokus_state"

SAMMEL_LABEL = "Nebenbefunde"
LABEL_MAX = 40

beschreibung = FokusState.text(ARGV.join(" "), 300)
exit if beschreibung.empty?

focus = FokusState.focus_dir(ENV["CLAUDE_PROJECT_DIR"] || Dir.pwd)
state = focus && FokusState.laden(focus)
exit unless state.is_a?(Hash)

# Der Sammel-Task steht neben dem aktiven Task und wird nie aktiviert; als „bereit“ erscheint er rechts in der Statuszeile.
sammel = FokusState.alle_tasks(state["task"]).find { |t| t["label"] == SAMMEL_LABEL && t["status"] != "done" }
unless sammel
  pfad = FokusState.aktiver_pfad(state)
  eltern = pfad ? (pfad.size > 1 ? pfad[-2] : pfad.last) : state["task"]
  sammel = { "id" => FokusState.neue_id(state, SAMMEL_LABEL), "label" => SAMMEL_LABEL, "beschreibung" => "",
             "status" => "bereit", "subtasks" => [] }
  eltern["subtasks"] = Array(eltern["subtasks"]) << sammel
end
exit if Array(sammel["subtasks"]).any? { |t| t["beschreibung"] == beschreibung }

label = FokusState.text(beschreibung, LABEL_MAX)
sammel["subtasks"] = Array(sammel["subtasks"]) << { "id" => FokusState.neue_id(state, label), "label" => label,
                                                    "beschreibung" => beschreibung, "status" => "open", "subtasks" => [] }
FokusState.kuerzel_pflegen(state)
FokusState.speichern(focus, state)

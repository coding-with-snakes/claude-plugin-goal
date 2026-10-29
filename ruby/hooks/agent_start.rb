#!/usr/bin/env ruby
# PreToolUse-Hook für das Agent-Tool: Steht im Auftrag eine Ergebnisdatei .focus/ergebnisse/<id>.md,
# trägt der Hook den Agent als laufenden Hintergrund-Task ein. Er erlaubt oder blockiert nichts.
require "fileutils"
require_relative "../lib/fokus_state"

eingabe = FokusState.eingabe
exit unless eingabe["tool_name"] == "Agent"

auftrag = eingabe.dig("tool_input", "prompt").to_s
id = auftrag[FokusState::ERGEBNIS_PFAD, 1]
exit unless id

focus = FokusState.focus_dir(eingabe["cwd"] || Dir.pwd)
exit unless focus

state = FokusState.laden(focus)
exit unless state.is_a?(Hash)

label = FokusState.text(eingabe.dig("tool_input", "description"), 40)
label = id if label.empty?
ergebnisse = File.join(focus, "ergebnisse")
Dir.mkdir(ergebnisse, 0o700) unless File.directory?(ergebnisse) || File.symlink?(ergebnisse)
if FokusState.hintergrund_anlegen(state, id, label)
  FokusState.kuerzel_pflegen(state)
  FokusState.speichern(focus, state)
end

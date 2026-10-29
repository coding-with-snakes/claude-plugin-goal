#!/usr/bin/env ruby
# Stop-Hook: merkt sich Claudes Zielvorschlag („Ziel: …. Passt?“) für die Bestätigung durch den Dev.
require_relative "../lib/fokus_state"

eingabe = FokusState.eingabe
exit if eingabe["stop_hook_active"]

start = eingabe["cwd"] || Dir.pwd
antwort = eingabe["last_assistant_message"].to_s

label = antwort[FokusState::VORSCHLAG, 1]
exit unless label

focus = FokusState.focus_dir_anlegen(start)
exit unless focus

beschreibung = FokusState.sicher_lesen(File.join(focus, "letzter_prompt.txt"), 4096).to_s
FokusState.sicher_schreiben(File.join(focus, "vorschlag.json"),
                            JSON.generate("label" => FokusState.text(label, 80),
                                          "beschreibung" => FokusState.text(beschreibung, 300)))

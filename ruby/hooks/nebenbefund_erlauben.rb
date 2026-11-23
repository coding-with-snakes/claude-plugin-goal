#!/usr/bin/env ruby
# PreToolUse-Hook für Bash: erlaubt ohne Abfrage genau den Aufruf von nebenbefund.rb aus diesem Plugin
# mit einem Text in Anführungszeichen. Alles andere bleibt unentschieden und geht durch die normale Abfrage.
# Läuft mit der macOS-System-Ruby (2.6).
require_relative "../lib/fokus_state"

WURZEL = File.expand_path("../..", __dir__)
# Der Text darf nichts enthalten, was die Shell innerhalb von Anführungszeichen auswertet.
ERLAUBT = /\Aruby --disable-gems "#{Regexp.escape(WURZEL)}\/ruby\/nebenbefund\.rb" "[^"$`\\\r\n]*"\z/

befehl = FokusState.eingabe.dig("tool_input", "command").to_s
exit unless befehl.match?(ERLAUBT)

puts JSON.generate("hookSpecificOutput" => { "hookEventName" => "PreToolUse", "permissionDecision" => "allow",
                                             "permissionDecisionReason" => "Nebenbefund eintragen (goal)" })

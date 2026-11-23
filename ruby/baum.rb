#!/usr/bin/env ruby
# Gibt den Task-Baum als Text aus (für die Anzeige im Pane des Mods, hooks/register.js).
# Läuft mit der macOS-System-Ruby (2.6).
require_relative "lib/fokus_state"

focus = FokusState.focus_dir(ENV["CLAUDE_PROJECT_DIR"] || Dir.pwd)
state = focus && FokusState.laden(focus)
puts state.is_a?(Hash) ? FokusState.baum(state) : "Kein Task-Baum vorhanden."

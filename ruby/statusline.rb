#!/usr/bin/env ruby
# Statuszeile für Claude Code: links der Pfad zum aktiven Task (plus offene Geschwister),
# rechtsbündig die Hintergrund-Tasks (◌ läuft, ● wartet auf den Dev).
# Läuft mit der macOS-System-Ruby (2.6), damit es nicht von asdf o.ä. abhängt.
require_relative "lib/fokus_state"

TRENNER = " › "
WARN_TIEFE = 3
MIN_BREITE = 4
# Claude Code zeigt die Statuszeile mit Einzug; der Rand verhindert, dass rechts etwas abgeschnitten wird.
RAND = 8
LABEL_MAX = 20

FETT = "\e[1m"
GRAU = "\e[38;5;248m"
CYAN = "\e[36m"
GELB = "\e[33m"
GRUEN = "\e[32m"
RESET = "\e[0m"

# Kürzt das Label; ein Buchstabe „(a) “ am Anfang bleibt immer stehen.
def kuerzen(text, breite)
  return text if text.length <= breite

  kuerzel = text[/\A\([a-z]\) /].to_s
  rest = breite - kuerzel.length
  "#{kuerzel}#{text[kuerzel.length, [rest - 1, 1].max]}…"
end

# Kürzt an der letzten Wortgrenze, damit das Label lesbar bleibt.
def kuerzen_wort(text, breite)
  return text if text.length <= breite

  schnitt = text[0, breite - 1]
  wortende = schnitt.rindex(" ")
  schnitt = schnitt[0, wortende] if wortende && wortende >= breite / 2
  "#{schnitt.rstrip}…"
end

# Label mit festem Buchstaben davor, damit der Dev den Task mit „b aktiv“ ansprechen kann.
def beschriftung(task)
  label = FokusState.text(task["label"], 200)
  label = yield(label) if block_given?
  task["kuerzel"] ? "(#{task['kuerzel']}) #{label}" : label
end

def sichtbar(text)
  text.gsub(/\e\[[\d;]*m/, "")
end

eingabe = FokusState.eingabe
starts = [eingabe.dig("workspace", "current_dir"), eingabe.dig("workspace", "project_dir"), Dir.pwd].compact
focus = nil
starts.each { |s| break if (focus = FokusState.focus_dir(s)) }
exit unless focus

state = FokusState.laden(focus)
if state == FokusState::UNLESBAR
  puts "#{GELB}⚠ .focus/state.yml unlesbar#{RESET}"
  exit
end
pfad = FokusState.aktiver_pfad(state)
exit unless pfad

# Claude Code setzt COLUMNS auf die Terminalbreite.
spalten = ENV["COLUMNS"].to_i
spalten = 80 unless spalten.positive?
breite = spalten - RAND

rechts = FokusState.hintergrund(state["task"]).map do |t|
  label = beschriftung(t) { |l| kuerzen_wort(l, LABEL_MAX) }
  bereit = t["status"] == "bereit" || FokusState.fertig?(focus, t)
  bereit ? "#{FETT}#{GRUEN}● #{label}#{RESET}" : "#{GRAU}◌ #{label}#{RESET}"
end.join("  ")
platz = breite - sichtbar(rechts).length - (rechts.empty? ? 0 : 2)

labels = pfad.map { |t| beschriftung(t) }
# Offene Geschwister jeder Ebene, grau hinter dem Label; inaktive Tasks in eckigen Klammern, damit sie nicht mit „(a)“ verwechselt werden.
geschwister = pfad.each_index.map { |i| FokusState.geschwister(pfad, i).map { |t| beschriftung(t) } }
zusatz = geschwister.map { |g| g.empty? ? "" : " [+ #{g.join(', ')}]" }
kinder = FokusState.offene_kinder(pfad.last).map { |t| beschriftung(t) }
unter = kinder.empty? ? "" : "#{TRENNER}[#{kinder.join(', ')}]"
gesamt = -> { labels.sum(&:length) + zusatz.sum(&:length) + TRENNER.length * (labels.size - 1) + unter.length }

# Bei Platzmangel zuerst Geschwister, dann offene Subtasks auf eine Zahl kürzen, dann die übergeordneten Tasks.
zusatz = geschwister.map { |g| g.empty? ? "" : " [+#{g.size}]" } if gesamt.() > platz
unter = "#{TRENNER}[+#{kinder.size}]" if !kinder.empty? && gesamt.() > platz
if labels.size > 1 && gesamt.() > platz
  eltern = labels[0...-1]
  frei = platz - gesamt.() + eltern.sum(&:length)
  labels = eltern.map { |l| kuerzen(l, [frei / eltern.size, MIN_BREITE].max) } << labels.last
end
# Reicht es immer noch nicht, wird auch der aktive Task gekürzt, damit rechts alles sichtbar bleibt.
ueber = gesamt.() - platz
labels[-1] = kuerzen(labels.last, [labels.last.length - ueber, MIN_BREITE].max) if ueber.positive?

farbe = pfad.length >= WARN_TIEFE ? GELB : CYAN
teile = labels.each_index.map { |i| "#{FETT if i == labels.size - 1}#{farbe}#{labels[i]}#{RESET}#{GRAU}#{zusatz[i]}#{RESET}" }
links = teile.join("#{GRAU}#{TRENNER}#{RESET}") + "#{GRAU}#{unter}#{RESET}"

if rechts.empty?
  puts links
else
  luecke = [breite - sichtbar(links).length - sichtbar(rechts).length, 2].max
  puts links + " " * luecke + rechts
end

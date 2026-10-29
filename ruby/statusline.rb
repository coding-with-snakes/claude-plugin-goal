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
aktuell = labels.pop
eltern = labels
geschwister = FokusState.geschwister(pfad).map { |t| beschriftung(t) }
kinder = FokusState.offene_kinder(pfad.last).map { |t| beschriftung(t) }

# Bei Platzmangel zuerst Geschwister, dann offene Subtasks auf eine Zahl kürzen, dann die übergeordneten Tasks.
pfad_laenge = eltern.sum(&:length) + TRENNER.length * eltern.size + aktuell.length
# Inaktive Tasks in eckigen Klammern, damit sie nicht mit den Buchstaben „(a)“ verwechselt werden.
unter = kinder.empty? ? "" : "#{TRENNER}[#{kinder.join(', ')}]"
zusatz = geschwister.empty? ? "" : " [+ #{geschwister.join(', ')}]"
zusatz = " [+#{geschwister.size}]" if pfad_laenge + unter.length + zusatz.length > platz
unter = "#{TRENNER}[+#{kinder.size}]" if !kinder.empty? && pfad_laenge + unter.length + zusatz.length > platz
zusatz = unter + zusatz
if !eltern.empty? && pfad_laenge + zusatz.length > platz
  rest = platz - aktuell.length - zusatz.length - TRENNER.length * eltern.size
  eltern = eltern.map { |l| kuerzen(l, [rest / eltern.size, MIN_BREITE].max) }
end
# Reicht es immer noch nicht, wird auch der aktive Task gekürzt, damit rechts alles sichtbar bleibt.
ueber = eltern.sum(&:length) + TRENNER.length * eltern.size + aktuell.length + zusatz.length - platz
aktuell = kuerzen(aktuell, [aktuell.length - ueber, MIN_BREITE].max) if ueber.positive?

farbe = pfad.length >= WARN_TIEFE ? GELB : CYAN
teile = eltern.map { |l| "#{farbe}#{l}#{RESET}" }
teile << "#{FETT}#{farbe}#{aktuell}#{RESET}"
links = teile.join("#{GRAU}#{TRENNER}#{RESET}")
links += "#{GRAU}#{zusatz}#{RESET}" unless zusatz.empty?

if rechts.empty?
  puts links
else
  luecke = [breite - sichtbar(links).length - sichtbar(rechts).length, 2].max
  puts links + " " * luecke + rechts
end

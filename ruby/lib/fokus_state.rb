# Gemeinsame Logik für Statuszeile und Hooks: .focus finden, state.yml lesen, aktiven Pfad bestimmen.
# Läuft mit der macOS-System-Ruby (2.6).
require "json"
require "yaml"

Encoding.default_external = Encoding::UTF_8

module FokusState
  module_function

  MAX_DATEI = 64 * 1024
  UNLESBAR = :unlesbar

  # Hook-Eingabe von stdin; leer, wenn sie kein JSON ist.
  def eingabe
    JSON.parse($stdin.read) rescue {}
  end

  # Wie File.exist?, zählt aber auch kaputte Symlinks.
  def vorhanden?(pfad)
    File.exist?(pfad) || File.symlink?(pfad)
  end

  # Sucht ab start aufwärts ein .focus-Verzeichnis. Die Suche endet am Git-Root, bei $HOME oder bei /.
  # Fremde, verlinkte oder im Repo eingecheckte .focus-Verzeichnisse werden ignoriert.
  def focus_dir(start)
    home = ENV["HOME"]
    dir = File.expand_path(start)
    loop do
      kandidat = File.join(dir, ".focus")
      if vorhanden?(kandidat)
        return eigener_ordner?(kandidat) && !eingecheckt?(dir) ? kandidat : nil
      end
      return nil if dir == "/" || dir == home || File.exist?(File.join(dir, ".git"))

      dir = File.dirname(dir)
    end
  end

  def eigener_ordner?(pfad)
    st = File.lstat(pfad)
    st.directory? && st.owned?
  rescue SystemCallError
    false
  end

  # Ein .focus mit getrackten Dateien stammt aus dem Repo, nicht vom Dev.
  def eingecheckt?(dir)
    ausgabe = IO.popen(["git", "-C", dir, "ls-files", "--", ".focus"], err: File::NULL, &:read)
    !ausgabe.to_s.strip.empty?
  rescue SystemCallError
    false
  end

  # Liest nur reguläre Dateien (keine Symlinks) bis zu max Bytes.
  def sicher_lesen(pfad, max = MAX_DATEI)
    st = File.lstat(pfad)
    return nil unless st.file? && st.size <= max

    inhalt = File.open(pfad, File::RDONLY | File::NOFOLLOW) { |f| f.read(max) }
    inhalt&.force_encoding(Encoding::UTF_8)&.scrub
  rescue SystemCallError
    nil
  end

  # Schreibt ohne Symlinks zu folgen; mit nur_neu nur, wenn die Datei noch nicht existiert.
  def sicher_schreiben(pfad, inhalt, nur_neu: false)
    flags = File::WRONLY | File::CREAT | File::NOFOLLOW | (nur_neu ? File::EXCL : File::TRUNC)
    File.open(pfad, flags, 0o600) { |f| f.write(inhalt) }
    true
  rescue SystemCallError
    false
  end

  # Gibt den Zustand zurück, nil wenn es keinen gibt, oder UNLESBAR wenn die Datei kaputt ist.
  def laden(focus_dir)
    datei = File.join(focus_dir, "state.yml")
    return nil unless vorhanden?(datei)

    inhalt = sicher_lesen(datei)
    return UNLESBAR unless inhalt

    state = YAML.safe_load(inhalt)
    state.is_a?(Hash) && state["task"].is_a?(Hash) ? state : UNLESBAR
  rescue Psych::Exception
    UNLESBAR
  end

  def pfad_zu(task, id)
    return [task] if task["id"] == id

    Array(task["subtasks"]).each do |sub|
      next unless sub.is_a?(Hash)

      rest = pfad_zu(sub, id)
      return [task, *rest] if rest
    end
    nil
  end

  # Pfad vom Root-Task bis zum aktiven Task, nur wenn dieser offen ist.
  def aktiver_pfad(state)
    return nil unless state.is_a?(Hash)

    pfad = pfad_zu(state["task"], state["aktiv"])
    pfad if pfad && pfad.last["status"] == "open"
  end

  # Offene Geschwister des aktiven Tasks (ohne ihn selbst und ohne Hintergrund-Tasks).
  def geschwister(pfad)
    return [] if pfad.nil? || pfad.size < 2

    Array(pfad[-2]["subtasks"]).select { |t| t.is_a?(Hash) && t["status"] == "open" && !t.equal?(pfad.last) }
  end

  # Offene direkte Subtasks eines Tasks.
  def offene_kinder(task)
    Array(task["subtasks"]).select { |t| t.is_a?(Hash) && t["status"] == "open" }
  end

  # Alle Tasks im Baum, die im Hintergrund laufen oder fertig auf den Dev warten.
  def hintergrund(task)
    alle_tasks(task).select { |t| %w[laeuft bereit].include?(t["status"]) }
  end

  # Entfernt Steuerzeichen (z.B. Terminal-Escapes) und kürzt auf max Zeichen.
  def text(wert, max)
    t = wert.to_s.gsub(/[[:cntrl:]]/, " ").strip
    t.length > max ? "#{t[0, max]}…" : t
  end

  # Legt .focus/.gitignore an, damit der Zustand nie versehentlich committet wird.
  def ignorieren(focus_dir)
    sicher_schreiben(File.join(focus_dir, ".gitignore"), "*\n", nur_neu: true)
  end

  # --- Zustand ändern (von den Hooks genutzt, damit Claude state.yml nicht sichtbar editieren muss) ---

  # Der Dev schliesst den aktiven Task.
  ERLEDIGT = /\A\s*(sub)?task\s+(erledigt|done|fertig|abgeschlossen)[.!]?\s*\z/i
  # Der Dev eröffnet ausdrücklich einen Task: „task: X“ neben dem aktiven, „subtask: X“ darunter
  # („neuer“ davor ist erlaubt). Nach dem ersten Komma oder Zeilenumbruch folgt die Beschreibung.
  NEUER_TASK = /\A\s*(?:neue[rn]?\s+)?(?<sub>sub)?task\s*:\s*(?<text>.+)/im
  # Der Dev bestätigt einen Zielvorschlag; was nach dem Ja kommt, ergänzt die Beschreibung.
  ZUSAGE = /\A\s*(ja|jep|jo|passt|ok|okay|yes|genau|stimmt)\b[\s,.!:]*/i
  # Claudes Zielvorschlag (Regel 3 in regeln.md).
  VORSCHLAG = /^Ziel: (.+?)\. Passt\?\s*$/
  # Ergebnisdatei eines Hintergrund-Agents, wie sie in seinem Auftrag steht.
  ERGEBNIS_PFAD = %r{\.focus/ergebnisse/([a-z0-9-]{1,60})\.md}

  # Findet .focus oder legt es im Projektverzeichnis an.
  def focus_dir_anlegen(start)
    vorhanden = focus_dir(start)
    return vorhanden if vorhanden

    dir = File.join(ENV["CLAUDE_PROJECT_DIR"] || start, ".focus")
    return nil if vorhanden?(dir)

    Dir.mkdir(dir, 0o700)
    ignorieren(dir)
    dir
  rescue SystemCallError
    nil
  end

  # Schreibt state.yml über eine Zwischendatei, damit die Statuszeile nie eine halbe Datei liest.
  def speichern(focus_dir, state)
    datei = File.join(focus_dir, "state.yml")
    zwischen = "#{datei}.neu"
    File.delete(zwischen) if File.symlink?(zwischen)
    return false unless sicher_schreiben(zwischen, state.to_yaml)

    File.rename(zwischen, datei)
    true
  rescue SystemCallError
    false
  end

  def finden(task, id)
    alle_tasks(task).find { |t| t["id"] == id }
  end

  def neue_id(state, label)
    basis = ascii(label).gsub(/[^a-z0-9]+/, "-").gsub(/\A-+|-+\z/, "")[0, 40]
    basis = "task" if basis.to_s.empty?
    wurzel = state.is_a?(Hash) ? state["task"] : nil
    id = basis
    n = 2
    while finden(wurzel, id)
      id = "#{basis}-#{n}"
      n += 1
    end
    id
  end

  # Der Dev schliesst oder aktiviert einen Task beim Namen: „UI abgeschlossen“, „Freigabe-Regel aktivieren“.
  # Mehrere Anweisungen in einer Zeile sind mit Komma, „und“ oder Semikolon getrennt.
  NAME_SCHLIESSEN = /\A(?<name>.+?)\s+(?:ist\s+)?(?:erledigt|done|fertig|abgeschlossen)[.!]?\z/i
  NAME_AKTIVIEREN = /\A(?:(?<name>.+?)\s+aktiv(?:ieren)?|aktiviere\s+(?<name2>.+?))[.!]?\z/i
  KUERZEL = ("a".."z").to_a.freeze
  FUELLWOERTER = %w[todo task subtask den die das der the].freeze
  MAX_ANWEISUNG = 120

  # Kleinbuchstaben mit ausgeschriebenen Umlauten.
  def ascii(text)
    text.to_s.downcase.gsub("ä", "ae").gsub("ö", "oe").gsub("ü", "ue").gsub("ß", "ss")
  end

  def woerter(text)
    ascii(text).split(/[^a-z0-9]+/).reject(&:empty?)
  end

  def alle_tasks(task, gefunden = [])
    return gefunden unless task.is_a?(Hash)

    gefunden << task
    Array(task["subtasks"]).each { |sub| alle_tasks(sub, gefunden) }
    gefunden
  end

  # Findet den Task, dessen Label alle genannten Wörter enthält (auch als Wortanfang). Bei mehreren
  # Treffern zählen zuerst exakte Labels, dann offene Tasks; bleibt es mehrdeutig, gibt es nil.
  def task_nach_name(state, name)
    if name.strip.match?(/\A[a-z]\z/i)
      return alle_tasks(state["task"]).find { |t| t["kuerzel"] == name.strip.downcase }
    end

    gesucht = woerter(name) - FUELLWOERTER
    return nil if gesucht.empty?

    kandidaten = alle_tasks(state["task"]).select do |t|
      label = woerter(t["label"])
      t["id"] == name.strip || gesucht.all? { |w| label.any? { |l| l.start_with?(w) || w.start_with?(l) } }
    end
    [->(t) { woerter(t["label"]) == gesucht }, ->(t) { t["status"] == "open" }].each do |besser|
      engere = kandidaten.select(&besser)
      kandidaten = engere unless engere.empty?
    end
    kandidaten.size == 1 ? kandidaten.first : nil
  end

  # Jeder nicht erledigte Task behält seinen Buchstaben fest; erledigte geben ihn frei, neue bekommen
  # den ersten freien. Gibt true zurück, wenn sich etwas geändert hat.
  def kuerzel_pflegen(state)
    return false unless state.is_a?(Hash)

    geaendert = false
    tasks = alle_tasks(state["task"])
    tasks.each do |t|
      next unless t["status"] == "done" && t.key?("kuerzel")

      t.delete("kuerzel")
      geaendert = true
    end
    frei = KUERZEL - tasks.map { |t| t["kuerzel"] }
    tasks.each do |t|
      next if t["status"] == "done" || t["kuerzel"] || frei.empty?

      t["kuerzel"] = frei.shift
      geaendert = true
    end
    geaendert
  end

  # Zerlegt eine kurze Anweisung in Aktionen [[:schliessen, task], [:aktivieren, task]].
  # Nur wenn jeder Teil eindeutig erkannt wird; sonst nil, damit normale Sätze nichts auslösen.
  def anweisungen(state, prompt)
    text = prompt.to_s.strip
    return nil if text.empty? || text.length > MAX_ANWEISUNG || text.include?("\n")

    aktionen = text.split(/\s*(?:,|;|\bund\b)\s*/i).reject(&:empty?).map do |teil|
      if teil.match?(ERLEDIGT)
        pfad = aktiver_pfad(state)
        pfad && [:schliessen, pfad.last]
      elsif (m = teil.match(NAME_SCHLIESSEN))
        (t = task_nach_name(state, m[:name])) && [:schliessen, t]
      elsif (m = teil.match(NAME_AKTIVIEREN))
        (t = task_nach_name(state, m[:name] || m[:name2])) && [:aktivieren, t]
      end
    end
    aktionen.empty? || aktionen.include?(nil) ? nil : aktionen
  end

  # Schliesst einen beliebigen Task. Liegt der aktive Task in ihm, wird sein übergeordneter aktiv.
  def task_schliessen(state, task)
    task["status"] = "done"
    pfad = pfad_zu(state["task"], state["aktiv"]) || []
    index = pfad.index { |t| t.equal?(task) }
    state["aktiv"] = index.positive? ? pfad[index - 1]["id"] : nil if index
  end

  # Aktiviert einen Task; erledigte oder fertige Hintergrund-Tasks werden wieder offen.
  def task_aktivieren(state, task)
    task["status"] = "open"
    state["aktiv"] = task["id"]
  end

  # Legt einen Subtask unter dem aktiven Task an (mit neben: daneben) und aktiviert ihn, oder einen
  # neuen Root-Task, wenn keiner aktiv ist. Neben dem Root-Task gibt es keinen Platz; dann darunter.
  def anlegen(state, label, beschreibung, neben: false)
    task = { "id" => neue_id(state, label), "label" => label, "beschreibung" => beschreibung,
             "status" => "open", "subtasks" => [] }
    pfad = aktiver_pfad(state)
    return { "aktiv" => task["id"], "task" => task } unless pfad

    eltern = neben && pfad.size > 1 ? pfad[-2] : pfad.last
    eltern["subtasks"] = Array(eltern["subtasks"]) << task
    state["aktiv"] = task["id"]
    state
  end

  # Trägt einen Hintergrund-Task als Geschwister des aktiven Tasks ein.
  def hintergrund_anlegen(state, id, label)
    pfad = aktiver_pfad(state)
    return false if pfad.nil? || finden(state["task"], id)

    eltern = pfad.size > 1 ? pfad[-2] : pfad.last
    eltern["subtasks"] = Array(eltern["subtasks"]) << { "id" => id, "label" => label, "status" => "laeuft", "subtasks" => [] }
    true
  end

  def ergebnis_datei(focus_dir, id)
    File.join(focus_dir, "ergebnisse", "#{id}.md")
  end

  # Ein laufender Hintergrund-Task ist fertig, sobald seine Ergebnisdatei existiert.
  def fertig?(focus_dir, task)
    File.lstat(ergebnis_datei(focus_dir, task["id"])).file?
  rescue SystemCallError
    false
  end

  # Setzt fertige Hintergrund-Tasks auf „bereit“ und übernimmt die erste Zeile als Ergebnis.
  def hintergrund_abgleichen(focus_dir, state)
    geaendert = false
    hintergrund(state["task"]).each do |t|
      next unless t["status"] == "laeuft" && fertig?(focus_dir, t)

      inhalt = sicher_lesen(ergebnis_datei(focus_dir, t["id"])).to_s
      kurz = inhalt.lines.map(&:strip).reject { |l| l.empty? || l.start_with?("#") }.first
      t["status"] = "bereit"
      t["ergebnis"] = "#{text(kurz, 300)} Details: .focus/ergebnisse/#{t['id']}.md".strip
      geaendert = true
    end
    geaendert
  end
end

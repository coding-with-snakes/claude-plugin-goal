// Mod: /task-baum zeigt den Task-Baum in einem Pane neben dem Chat. Esc schliesst es, der Verlauf bleibt unberührt.
// Den Baum baut ruby/baum.rb, damit das Zeichnen nur an einer Stelle liegt (lib/fokus_state.rb).
const PANE = 'goal-task-baum'

// Der Text, den das Pane zeigt
let baum = ''

export function register(on) {
  on('session.start', async ($, e, next) => {
    await $.command.register({ name: 'task-baum', description: 'Task-Baum anzeigen (Esc schliesst)' })
    return next(e)
  })

  on('command.run', { command: 'task-baum' }, async ($) => {
    try {
      const r = await $.process.run(['ruby', '--disable-gems', $.plugin.root + '/ruby/baum.rb'])
      baum = r.exitCode === 0 ? r.stdout.trimEnd() : 'Task-Baum nicht lesbar: ' + r.stderr.trim()
    } catch (error) {
      baum = 'Task-Baum nicht lesbar: ' + String(error?.message ?? error)
    }
    await $.ui.open({ id: PANE, title: 'Task-Baum', focus: true, closeOnEscape: true })
    // Nichts im Verlauf ausgeben
    return {}
  })

  on('ui.render', { component: 'Pane' }, async ($, e, next) => {
    if (e.requestId !== PANE) return next(e)
    const { Box, Text } = $.ui.resolve(e)
    return Box({
      flexDirection: 'column',
      children: baum.split('\n').map((zeile, i) => Text({ key: 'z' + i, children: [zeile] })),
    })
  })
}

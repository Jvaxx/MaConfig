// math-render: LaTeX in assistant replies drawn as terminal images, a port of
// pi-math. Formulas are rasterized by helper/server.ts (MathJax + Resvg, which
// need Node) and drawn with the terminal's Image element; replies without a
// complete formula are left to the engine.
import type { Elements, EngineInterface, Register } from 'claude-code'

import { type Block, type FlowLine, type Formula, type Plan, planMessage, words } from './plan.ts'
import { containsPotentialMath } from './scan.ts'

type Raster = { png: string; columns: number; rows: number }
type RenderResult = Raster | { error: string }
type HelperReply = { results: RenderResult[] }

const STORE_ENABLED = 'enabled'
const HELPER_START_TIMEOUT_MS = 8_000
const HELPER_RETRY_MS = 30_000
/** The engine's reply bullet takes two columns; leave one more for the wrap. */
const GUTTER = 2

type Helper = { socket: string; ready: Promise<boolean>; isAlive: boolean; startedAt: number }
let helper: Helper | undefined
let lastFailure: string | undefined

async function socketDirectory($: EngineInterface): Promise<string> {
  const runtime = await $.env.get('XDG_RUNTIME_DIR')
  return runtime && runtime.startsWith('/') ? runtime : '/tmp'
}

/** Starts the rasterizer for the session's life; resolves once it listens. */
async function startHelper($: EngineInterface): Promise<Helper> {
  const socket = `${await socketDirectory($)}/math-render-${crypto.randomUUID().slice(0, 8)}.sock`
  let settle: (isReady: boolean) => void = () => {}
  const started: Helper = {
    socket,
    ready: new Promise(resolve => (settle = resolve)),
    isAlive: true,
    startedAt: Date.now(),
  }
  helper = started

  void (async () => {
    let stderr = ''
    try {
      const child = $.process.spawn({
        argv: ['node', `${$.plugin.root}/helper/server.ts`, socket],
        cwd: `${$.plugin.root}/helper`,
      })
      for (;;) {
        const step = await child.next()
        if (step.done) {
          lastFailure = `helper exited (${step.value.code ?? step.value.signal}) ${stderr.trim()}`.trim()
          break
        }
        const piece = step.value
        if (piece.stream === 'stdout' && piece.text.includes('ready')) settle(true)
        if (piece.stream === 'stderr') stderr = (stderr + piece.text).slice(-2_000)
      }
    } catch (error) {
      lastFailure = `helper did not start: ${error instanceof Error ? error.message : String(error)}`
    }
    started.isAlive = false
    settle(false)
    if (lastFailure) $.ui.log(`math-render: ${lastFailure}`, { to: 'debug' })
  })()

  void $.clock.after(HELPER_START_TIMEOUT_MS, () => settle(false))
  return started
}

/** The running helper, restarted (at most every 30 s) if it died. */
async function liveHelper($: EngineInterface): Promise<Helper | undefined> {
  if (!helper || (!helper.isAlive && Date.now() - helper.startedAt > HELPER_RETRY_MS)) {
    await startHelper($)
  }
  const current = helper!
  return (await current.ready) && current.isAlive ? current : undefined
}

async function rasterize(
  $: EngineInterface,
  formulas: Formula[],
  contentColumns: number,
): Promise<RenderResult[] | undefined> {
  const running = await liveHelper($)
  if (!running) return undefined
  const settings = await $.settings.read()
  const theme = typeof settings.theme === 'string' ? settings.theme : undefined
  try {
    const response = await $.http.fetch('http://math-render/render', {
      method: 'POST',
      socketPath: running.socket,
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        theme,
        items: formulas.map(f => ({
          latex: f.latex,
          display: f.display,
          inline: f.inline,
          align: f.align,
          maxWidthCells: contentColumns,
        })),
      }),
    })
    if (!response.ok) {
      lastFailure = `helper answered ${response.status}: ${response.text.slice(0, 200)}`
      return undefined
    }
    return (JSON.parse(response.text) as HelperReply).results
  } catch (error) {
    lastFailure = `helper request failed: ${error instanceof Error ? error.message : String(error)}`
    return undefined
  }
}

async function isEnabled($: EngineInterface): Promise<boolean> {
  return (await $.store.get(STORE_ENABLED)) !== false
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: 'math-render',
      description: 'LaTeX image rendering: on, off, status or clear',
      argumentHint: 'on|off|status|clear',
    })
    const started = await next(e)
    if (e.isInteractive) {
      void startHelper($).then(async running => {
        // Replies drawn before the helper listened get their images now.
        if (await running.ready) $.ui.invalidate('ui.render')
      })
    }
    return started
  })

  on('command.run', { command: 'math-render' }, async ($, e) => {
    const action = e.args.trim().toLowerCase() || 'status'
    if (action === 'on' || action === 'off') {
      await $.store.set(STORE_ENABLED, action === 'on')
      $.ui.invalidate('ui.render')
      return { text: `${action === 'on' ? 'Enabled' : 'Disabled'}.` }
    }
    const running = await liveHelper($)
    if (action === 'clear') {
      if (running) await $.http.fetch('http://math-render/clear', { method: 'POST', socketPath: running.socket })
      $.ui.invalidate('ui.render')
      return { text: 'Render caches cleared.' }
    }
    if (action !== 'status') return { text: 'Usage: /math-render on|off|status|clear' }

    const state = (await isEnabled($)) ? 'Enabled' : 'Disabled'
    if (!running) return { text: `${state}; the renderer is not running${lastFailure ? `: ${lastFailure}` : '.'}` }
    const response = await $.http.fetch('http://math-render/status', { socketPath: running.socket })
    const status = JSON.parse(response.text) as {
      cell: { widthPx: number; heightPx: number }
      cellSource: string
      color: string
      cacheSize: number
      cacheBytes: number
      lastFailure?: { code: string; message: string }
    }
    const kib = (status.cacheBytes / 1024).toFixed(1)
    const failure = status.lastFailure ? `, last failure: ${status.lastFailure.code}` : ''
    return {
      text:
        `${state}: cell ${status.cell.widthPx.toFixed(1)}×${status.cell.heightPx.toFixed(1)} px ` +
        `(${status.cellSource}), ink ${status.color}, ${status.cacheSize} rasters (${kib} KiB)${failure}.`,
    }
  })

  on('ui.render', { component: 'AssistantMessage' }, async ($, e, next) => {
    if (e.surface !== 'terminal' || e.props.isSummary) return next(e)
    const text = e.props.text
    if (!containsPotentialMath(text) || !(await isEnabled($))) return next(e)
    const plan = planMessage(text)
    if (!plan) return next(e)

    const contentColumns = Math.max(10, (e.viewport?.columns ?? 80) - GUTTER - 1)
    const rasters = await rasterize($, plan.formulas, contentColumns)
    if (!rasters) return next(e)

    return drawPlan($.ui.resolve(e), plan, rasters, contentColumns, e.props.isFirstOfReply)
  })
}

function drawPlan(
  t: Elements['terminal'],
  plan: Plan,
  rasters: RenderResult[],
  contentColumns: number,
  isFirstOfReply: boolean,
) {
  const { Box, Text, Markdown, Image, Link } = t

  const formulaElement = (id: number, inline: boolean) => {
    const formula = plan.formulas[id]!
    const raster = rasters[id]
    if (!raster || 'error' in raster) {
      return inline ? <Text>{formula.source}</Text> : <Markdown text={formula.source} />
    }
    return <Image source={{ png: raster.png }} columns={raster.columns} rows={raster.rows} alt={formula.source} />
  }

  const flowLine = (line: FlowLine) => {
    const marker = line.marker ? (/^\d/.test(line.marker) ? `${line.marker} ` : '- ') : line.style === 'quote' ? '▎ ' : ''
    const body = words(line.runs).map(word => (
      <Box flexDirection="row" flexShrink={0} alignItems="flex-end">
        {word.pieces.map(piece => {
          if (piece.kind === 'formula') return formulaElement(piece.id, true)
          const styled = (
            <Text
              bold={piece.bold || line.style === 'heading' || undefined}
              italic={piece.italic || line.style === 'quote' || undefined}
              strikethrough={piece.strike || undefined}
              color={piece.code ? 'permission' : undefined}
            >
              {piece.text}
            </Text>
          )
          return piece.href ? <Link href={piece.href}>{styled}</Link> : styled
        })}
        {word.spaceAfter && <Text> </Text>}
      </Box>
    ))
    return (
      <Box flexDirection="row" paddingLeft={line.indent}>
        {marker && (
          <Box flexShrink={0}>
            <Text dimColor={line.style === 'quote' || undefined}>{marker}</Text>
          </Box>
        )}
        {/* A two-row formula makes its line two rows tall: text sits on the lower one. */}
        <Box flexDirection="row" flexWrap="wrap" flexGrow={1} flexShrink={1} alignItems="flex-end">
          {body}
        </Box>
      </Box>
    )
  }

  const block = (one: Block) => {
    if (one.kind === 'markdown') return <Markdown text={one.text} />
    if (one.kind === 'display') {
      return (
        <Box flexDirection="row" justifyContent="center" width={contentColumns}>
          {formulaElement(one.id, false)}
        </Box>
      )
    }
    return <Box flexDirection="column">{one.lines.map(flowLine)}</Box>
  }

  return (
    <Box flexDirection="row" marginTop={isFirstOfReply ? 1 : 0}>
      <Box width={GUTTER} flexShrink={0}>
        <Text color="text">{isFirstOfReply ? '●' : ' '}</Text>
      </Box>
      <Box flexDirection="column" flexGrow={1} gap={1}>
        {plan.blocks.map(block)}
      </Box>
    </Box>
  )
}

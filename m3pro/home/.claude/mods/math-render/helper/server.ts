// math-render helper: pi-math's MathJax → SVG → PNG pipeline behind a Unix
// socket. The mod runs in a sandbox without Node, so it starts this process
// once per session and asks it for rasters over $.http.fetch.
import { execFileSync } from "node:child_process";
import { existsSync, readFileSync, rmSync, statSync } from "node:fs";
import { createServer } from "node:http";
import { homedir } from "node:os";
import { dirname, isAbsolute, join, resolve } from "node:path";
import { loadSvgMathRendererOptions } from "./config.ts";
import { createTerminalMathRenderer } from "./renderer.ts";

const MAX_BODY_BYTES = 2 * 1024 * 1024;
const PROBE_INTERVAL_MS = 2_000;
const DEFAULT_CELL = { widthPx: 10, heightPx: 22 };
// An inline formula one row would shrink below this share of its natural
// size (an integral with limits, a fraction) may take two rows instead.
const INLINE_MIN_SCALE = 0.7;
const DEFAULT_COLORS = { dark: "#d4d4d4", light: "#1f1f1f" };

interface RenderItem {
  latex: string;
  display: boolean;
  inline: boolean;
  maxWidthCells: number;
  align?: "start" | "center" | "end";
}

interface RenderRequest {
  items: RenderItem[];
  theme?: string;
}

const socketPath = process.argv[2];
if (!socketPath || !isAbsolute(socketPath)) {
  process.stderr.write("usage: server.ts <absolute socket path>\n");
  process.exit(2);
}

// CLAUDE_MATH_* settings, falling back to the PI_MATH_* names pi-math reads.
const environment: NodeJS.ProcessEnv = { ...process.env };
for (const name of ["MACROS", "ENVIRONMENTS", "FONT_FILES", "SYSTEM_FONTS"]) {
  const value = process.env[`CLAUDE_MATH_${name}`];
  if (value !== undefined) environment[`PI_MATH_${name}`] = value;
}

const renderer = await createTerminalMathRenderer(loadSvgMathRendererOptions(environment));

// --- terminal cell size -----------------------------------------------------

const CELL_PROBE = `
import fcntl, os, struct, sys, termios
pid = int(sys.argv[1])
while pid > 1:
    for fd in (0, 1, 2):
        try:
            target = os.readlink(f"/proc/{pid}/fd/{fd}")
        except OSError:
            continue
        if target.startswith("/dev/pts/") or target.startswith("/dev/tty"):
            handle = os.open(target, os.O_RDONLY | os.O_NOCTTY)
            print(*struct.unpack("HHHH", fcntl.ioctl(handle, termios.TIOCGWINSZ, b"\\0" * 8)))
            sys.exit(0)
    with open(f"/proc/{pid}/stat") as stat:
        pid = int(stat.read().rsplit(")", 1)[1].split()[1])
sys.exit(1)
`;

let cell = DEFAULT_CELL;
let cellProbedAt = 0;
let cellSource = "default";

function configuredCell(): { widthPx: number; heightPx: number } | undefined {
  const match = /^(\d+(?:\.\d+)?)x(\d+(?:\.\d+)?)$/.exec(process.env.CLAUDE_MATH_CELL ?? "");
  if (!match) return undefined;
  return { widthPx: Number(match[1]), heightPx: Number(match[2]) };
}

/** Ask the kernel for the session terminal's pixel size (Linux /proc only). */
function probeCell(): void {
  const now = Date.now();
  if (now - cellProbedAt < PROBE_INTERVAL_MS) return;
  cellProbedAt = now;

  const configured = configuredCell();
  if (configured) {
    cell = configured;
    cellSource = "CLAUDE_MATH_CELL";
    return;
  }
  if (!existsSync("/proc/self/stat")) return;
  try {
    const output = execFileSync("python3", ["-c", CELL_PROBE, String(process.ppid)], {
      encoding: "utf8",
      timeout: 1_000,
      stdio: ["ignore", "pipe", "ignore"],
    });
    const [rows, columns, widthPx, heightPx] = output.trim().split(/\s+/).map(Number);
    if (rows && columns && widthPx && heightPx) {
      cell = { widthPx: widthPx / columns, heightPx: heightPx / rows };
      cellSource = "terminal";
    }
  } catch {
    // No python3 or no terminal pixels reported: keep the last known size.
  }
}

// --- formula color ----------------------------------------------------------

let colorCache: { value: string | undefined; at: number } = { value: undefined, at: 0 };

function expandHome(path: string): string {
  return path.startsWith("~/") ? join(homedir(), path.slice(2)) : path;
}

function normalizeHex(value: string): string | undefined {
  const match = /^#?([\da-f]{6})$/i.exec(value.trim());
  return match ? `#${match[1]!.toLowerCase()}` : undefined;
}

/** The last `foreground` a Ghostty config (and the files it includes) sets. */
function ghosttyForeground(path: string, depth = 0): string | undefined {
  if (depth > 8 || !existsSync(path) || !statSync(path).isFile()) return undefined;
  let foreground: string | undefined;
  for (const line of readFileSync(path, "utf8").split("\n")) {
    const match = /^\s*([a-z-]+)\s*=\s*(.*?)\s*$/.exec(line);
    if (!match) continue;
    const [, key, raw] = match;
    if (key === "foreground") foreground = normalizeHex(raw!.replace(/^"|"$/g, "")) ?? foreground;
    if (key === "config-file") {
      const included = expandHome(raw!.replace(/^\?/, "").replace(/^"|"$/g, ""));
      const target = isAbsolute(included) ? included : resolve(dirname(path), included);
      foreground = ghosttyForeground(target, depth + 1) ?? foreground;
    }
  }
  return foreground;
}

/** The last `foreground` a kitty config (and its includes) sets. */
function kittyForeground(path: string, depth = 0): string | undefined {
  if (depth > 8 || !existsSync(path) || !statSync(path).isFile()) return undefined;
  let foreground: string | undefined;
  for (const line of readFileSync(path, "utf8").split("\n")) {
    const match = /^\s*(\S+)\s+(.*?)\s*$/.exec(line);
    if (!match) continue;
    const [, key, value] = match;
    if (key === "foreground") foreground = normalizeHex(value!) ?? foreground;
    if (key === "include") {
      const included = expandHome(value!);
      const target = isAbsolute(included) ? included : resolve(dirname(path), included);
      foreground = kittyForeground(target, depth + 1) ?? foreground;
    }
  }
  return foreground;
}

function terminalForeground(): string | undefined {
  const now = Date.now();
  if (now - colorCache.at < PROBE_INTERVAL_MS) return colorCache.value;
  const configHome = process.env.XDG_CONFIG_HOME || join(homedir(), ".config");
  let value: string | undefined;
  try {
    value =
      ghosttyForeground(join(configHome, "ghostty", "config")) ??
      kittyForeground(join(configHome, "kitty", "kitty.conf"));
  } catch {
    value = undefined;
  }
  colorCache = { value, at: now };
  return value;
}

function formulaColor(theme: string | undefined): string {
  const configured = normalizeHex(process.env.CLAUDE_MATH_COLOR ?? "");
  if (configured) return configured;
  const foreground = terminalForeground();
  if (foreground) return foreground;
  return theme?.includes("light") ? DEFAULT_COLORS.light : DEFAULT_COLORS.dark;
}

// --- rendering --------------------------------------------------------------

function renderItems(request: RenderRequest) {
  probeCell();
  const color = formulaColor(request.theme);
  const maxBlockRows = Math.max(1, Math.floor(4096 / cell.heightPx));
  const naturalPixelsPerEx = cell.heightPx * 0.5;
  const results = request.items.map((item) => {
    const layout = (maxHeightCells: number) => ({
      maxWidthCells: Math.max(1, Math.min(255, Math.floor(item.maxWidthCells))),
      maxHeightCells,
      cellWidthPx: cell.widthPx,
      cellHeightPx: cell.heightPx,
      fitHeight: item.inline,
      align: item.inline ? (item.align ?? "center") : "center",
    });
    let raster = renderer.render(item.latex, item.display, color, layout(item.inline ? 1 : Math.min(255, maxBlockRows)));
    if (item.inline && raster && raster.pixelsPerEx < naturalPixelsPerEx * INLINE_MIN_SCALE) {
      raster = renderer.render(item.latex, item.display, color, layout(2)) ?? raster;
    }
    if (!raster) return { error: renderer.lastFailure?.code ?? "failed" };
    return { png: raster.base64Data, columns: raster.columns, rows: raster.rows };
  });
  return { cell, cellSource, color, results };
}

function status() {
  probeCell();
  return {
    cell,
    cellSource,
    color: formulaColor(undefined),
    cacheSize: renderer.cacheSize,
    cacheBytes: renderer.cacheBytes,
    lastFailure: renderer.lastFailure,
  };
}

const server = createServer((request, response) => {
  const reply = (code: number, body: unknown) => {
    response.writeHead(code, { "content-type": "application/json" });
    response.end(JSON.stringify(body));
  };

  if (request.method === "GET" && request.url === "/status") return reply(200, status());
  if (request.method === "POST" && request.url === "/clear") {
    renderer.clear();
    return reply(200, { ok: true });
  }
  if (request.method !== "POST" || request.url !== "/render") return reply(404, { error: "not found" });

  const chunks: Buffer[] = [];
  let size = 0;
  request.on("data", (chunk: Buffer) => {
    size += chunk.length;
    if (size > MAX_BODY_BYTES) request.destroy();
    else chunks.push(chunk);
  });
  request.on("end", () => {
    try {
      const body = JSON.parse(Buffer.concat(chunks).toString("utf8")) as RenderRequest;
      if (!Array.isArray(body.items)) return reply(400, { error: "items must be an array" });
      reply(200, renderItems(body));
    } catch (error) {
      reply(400, { error: error instanceof Error ? error.message : String(error) });
    }
  });
});

const shutdown = () => {
  server.close();
  rmSync(socketPath, { force: true });
  process.exit(0);
};
process.on("SIGTERM", shutdown);
process.on("SIGINT", shutdown);
process.on("SIGHUP", shutdown);

// Exit with the session even if nobody signals us.
const parent = process.ppid;
setInterval(() => {
  if (process.ppid !== parent) shutdown();
}, 5_000).unref();

rmSync(socketPath, { force: true });
server.listen(socketPath, () => {
  process.stdout.write(`ready ${socketPath}\n`);
});

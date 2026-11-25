.pragma library

// Everything the widget shows comes from `proxyctl status --json`, which is
// file and command output: read it defensively and never as markup.

var ICON_DIRECT = "󰖟"
var ICON_PROXY = "󰒍"
var ICON_WARN = "󰀦"

function str(v, max) {
  return typeof v === "string" ? v.slice(0, max) : ""
}

function bool(v) {
  return v === true
}

function parseStatus(text) {
  var d
  try {
    d = JSON.parse(text)
  } catch (e) {
    d = null
  }
  if (!d || typeof d !== "object") return { ok: false, addr: "", reachable: false, want: "normal", tunnel: false,
    dns: false, ssh: false, nodpiWant: "off", nodpiActive: false,
    torActive: false, exitWant: "", exit: "", control: false, rotate: 0, torIp: "",
    defaultsSaved: false, defaultSystem: "normal", defaultNodpi: "off", defaultTorExit: "direct", defaultRotate: 0 }
  var sys = d.system && typeof d.system === "object" ? d.system : {}
  var nodpi = d.nodpi && typeof d.nodpi === "object" ? d.nodpi : {}
  var tor = d.tor && typeof d.tor === "object" ? d.tor : {}
  var def = d.defaults && typeof d.defaults === "object" ? d.defaults : {}
  var rotate = Number.isInteger(tor.rotate) && tor.rotate > 0 ? tor.rotate : 0
  var defRotate = Number.isInteger(def.rotate) && def.rotate > 0 ? def.rotate : 0
  return {
    ok: true,
    addr: str(d.addr, 260),
    reachable: bool(d.proxy_reachable),
    want: sys.want === "proxy" ? "proxy" : "normal",
    tunnel: bool(sys.tunnel),
    dns: bool(sys.dns),
    ssh: bool(sys.ssh),
    nodpiWant: nodpi.want === "on" ? "on" : "off",
    nodpiActive: bool(nodpi.active),
    torActive: bool(tor.active),
    exitWant: str(tor.exit_want, 16),
    exit: str(tor.exit, 16),
    control: bool(tor.control),
    rotate: rotate,
    torIp: str(tor.ip, 64),
    defaultsSaved: bool(def.saved),
    defaultSystem: def.system === "proxy" ? "proxy" : "normal",
    defaultNodpi: def.nodpi === "on" ? "on" : "off",
    defaultTorExit: def.tor_exit === "proxy" ? "proxy" : "direct",
    defaultRotate: defRotate
  }
}

function defaultsSummary(s) {
  var parts = [s.defaultSystem, "tor " + s.defaultTorExit, "nodpi " + s.defaultNodpi]
  if (s.defaultRotate > 0) parts.push(s.defaultRotate + " s")
  return parts.join(" · ")
}

function nodpiHeader(s) {
  return s.nodpiActive ? "NoDPI · active" : "NoDPI · stopped"
}

function barIcon(s) {
  if (!s.ok || (s.want === "proxy" && (!s.reachable || !s.tunnel))) return ICON_WARN
  return s.tunnel ? ICON_PROXY : ICON_DIRECT
}

function escapeMarkup(text) {
  return String(text).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;")
}

function tooltip(s) {
  if (!s.ok) return "proxyctl: no status"
  var state = s.tunnel ? " (tunnel up)" : (s.want === "proxy" ? " (tunnel down)" : "")
  var lines = ["System: " + s.want + state]
  if (s.addr !== "") lines.push("Proxy: " + escapeMarkup(s.addr) + (s.reachable ? "" : " — not answering"))
  lines.push("NoDPI: " + (s.nodpiActive ? "active" : "off"))
  var ipPart = s.torIp !== "" ? " (" + escapeMarkup(s.torIp) + ")" : ""
  lines.push("Tor: " + (s.torActive ? "running, exit " + s.exit + ipPart : "not running"))
  if (s.rotate > 0) lines.push("New identity every " + s.rotate + " s")
  return lines.join("\n")
}

function stripAnsi(text) {
  return String(text).replace(/\u001b\[[0-9;]*m/g, "")
}

function errorMessage(errText, outText) {
  var err = stripAnsi(errText).trim()
  var out = stripAnsi(outText).trim()
  return (err !== "" ? err : out).slice(0, 300)
}

function rotateArgs(text) {
  var t = String(text).trim()
  if (t === "" || t === "0" || t === "off") return ["tor", "rotate", "off"]
  return ["tor", "rotate", t]
}

function addrArgs(text) {
  return ["addr", String(text).trim()]
}

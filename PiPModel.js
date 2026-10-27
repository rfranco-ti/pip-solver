var TITLE_PATTERNS = ["^Picture.?in.?[Pp]icture$", "^Meet - .+"]

var TITLE_REGEXES = TITLE_PATTERNS.map(function(pattern) {
  return new RegExp(pattern, "i")
})

var RULE_EFFECTS = {
  float: true,
  pin: true,
  keep_aspect_ratio: true,
  border_size: 2,
  idle_inhibit: "always"
}

function matchesTitle(title) {
  if (typeof title !== "string" || title === "") return false
  return TITLE_REGEXES.some(function(regex) {
    return regex.test(title)
  })
}

function windowRuleEffects() {
  return Object.assign({}, RULE_EFFECTS)
}

function actionsFor(window) {
  var actions = []
  if (!window || !window.floating) actions.push("float")
  if (!window || !window.pinned) actions.push("pin")
  actions.push("props")
  return actions
}

function toAddress(address) {
  var hex = String(address || "").replace(/^0x/, "")
  return hex ? "0x" + hex : ""
}

function toSelector(address) {
  var hex = toAddress(address)
  return hex ? "address:" + hex : ""
}

function luaString(value) {
  return "'" + String(value).replace(/\\/g, "\\\\").replace(/'/g, "\\'") + "'"
}

function luaValue(value) {
  if (value === true) return "true"
  if (value === false) return "false"
  if (typeof value === "number") return String(value)
  if (value !== null && typeof value === "object") return luaTable(value)
  return luaString(value)
}

function luaTable(object) {
  var entries = Object.keys(object || {}).sort().map(function(key) {
    return key + " = " + luaValue(object[key])
  })
  return "{ " + entries.join(", ") + " }"
}

function ruleLuaList() {
  return TITLE_PATTERNS.map(function(pattern) {
    return luaTable(Object.assign({ match: { title: pattern } }, windowRuleEffects()))
  })
}

if (typeof module !== "undefined") {
  module.exports = {
    matchesTitle: matchesTitle,
    windowRuleEffects: windowRuleEffects,
    actionsFor: actionsFor,
    toAddress: toAddress,
    toSelector: toSelector,
    luaTable: luaTable,
    ruleLuaList: ruleLuaList
  }
}

"use strict";
const state = { games: [], filter: "all", query: "", failed: false };
const el = (tag, className, text) => {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text != null) node.textContent = text;
  return node;
};
function safeUrl(value) {
  if (typeof value !== "string" || !value.trim()) return null;
  try {
    const url = new URL(value, document.baseURI);
    return ["http:", "https:"].includes(url.protocol) ? url.href : null;
  } catch { return null; }
}
function action(label, value, primary = false) {
  const href = safeUrl(value);
  if (!href) return null;
  const link = el("a", `button ${primary ? "primary" : "secondary"}`, label);
  link.href = href;
  if (new URL(href).origin !== location.origin) { link.target = "_blank"; link.rel = "noopener noreferrer"; }
  link.append(el("span", "", primary ? "↗" : "↓"));
  return link;
}
function card(game, index) {
  const node = el("article", "game-card");
  const cover = el("div", "game-cover");
  const coverUrl = safeUrl(game.cover);
  if (coverUrl) {
    const img = el("img"); img.src = coverUrl; img.alt = `${game.title} 游戏画面`; img.loading = "lazy";
    img.addEventListener("error", () => { img.remove(); cover.append(el("span", "", String(index + 1).padStart(2, "0"))); }, { once: true });
    cover.append(img);
  } else { cover.setAttribute("aria-hidden", "true"); cover.append(el("span", "", String(index + 1).padStart(2, "0"))); }
  const body = el("div", "game-body");
  const tags = el("div", "game-tags");
  for (const tag of [game.web ? "网页试玩" : null, ...(game.tags || [])].filter(Boolean)) tags.append(el("span", "tag", tag));
  body.append(tags, el("h3", "game-title", game.title), el("p", "game-description", game.description || ""));
  const meta = [game.version, game.updated ? `更新于 ${game.updated}` : null].filter(Boolean).join(" · ");
  if (meta) body.append(el("div", "game-meta", meta));
  if (game.controls) body.append(el("p", "game-controls", `操作：${game.controls}`));
  const actions = el("div", "game-actions");
  if (game.web) { const link = action("立即试玩", game.web, true); if (link) actions.append(link); }
  body.append(actions); node.append(cover, body); return node;
}
function render() {
  const matches = state.games.filter(game => {
    const platform = state.filter === "all" || (state.filter === "web" && game.web);
    const content = [game.title, game.description, ...(game.tags || [])].join(" ").toLocaleLowerCase();
    return platform && content.includes(state.query);
  });
  const grid = document.getElementById("game-grid"); grid.replaceChildren(...matches.map(card));
  document.getElementById("game-count").textContent = state.games.length;
  document.getElementById("result-summary").textContent = state.failed ? "目录加载失败" : `共 ${state.games.length} 款游戏，当前显示 ${matches.length} 款`;
  document.getElementById("empty-state").hidden = matches.length > 0;
  const title = document.getElementById("empty-title"), copy = document.getElementById("empty-copy"), pill = document.getElementById("empty-pill");
  if (state.failed) {
    title.textContent = "目录暂时未能加载"; copy.textContent = "请刷新页面重试，或稍后再来看看。"; pill.hidden = true;
  } else if (state.query || (state.filter !== "all" && state.games.length)) {
    title.textContent = "还没找到这款游戏"; copy.textContent = "换个关键词，或选择“全部游戏”看看。"; pill.hidden = true;
  } else {
    title.textContent = "这里即将开场。"; copy.textContent = "第一款游戏还在准备中。\n试玩版本发布后，就会出现在这里。"; pill.hidden = false;
  }
}
for (const button of document.querySelectorAll(".filter")) button.addEventListener("click", () => {
  state.filter = button.dataset.filter;
  for (const item of document.querySelectorAll(".filter")) { const active = item === button; item.classList.toggle("active", active); item.setAttribute("aria-pressed", active); }
  render();
});
document.getElementById("search").addEventListener("input", event => { state.query = event.target.value.trim().toLocaleLowerCase(); render(); });
fetch("data/games.json", { cache: "no-cache" }).then(response => {
  if (!response.ok) throw new Error("catalog unavailable"); return response.json();
}).then(data => {
  if (!Array.isArray(data.games)) throw new Error("invalid catalog");
  state.games = data.games.filter(game => game && typeof game.title === "string" && safeUrl(game.web)).map(game => ({
    ...game,
    web: safeUrl(game.web) ? game.web : null,
    tags: Array.isArray(game.tags) ? game.tags.filter(tag => typeof tag === "string") : []
  }));
  render();
}).catch(() => { state.failed = true; render(); });

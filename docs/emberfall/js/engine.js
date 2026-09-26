'use strict';
// World state, exploration, scripting helpers, saving.

let G = null; // the saved game state
const SAVE_KEY = 'emberfall.save.v1';
const SOLID = new Set('TY~MRWO#|ZXLSCEKPV'.split(''));
const DIRS = { up: [0, -1], down: [0, 1], left: [-1, 0], right: [1, 0] };

// ---- Script helpers used by NPC dialogue in maps.js ----
const say = (n, t) => UI.say(n, t);
const ask = (n, t, o) => UI.ask(n, t, o);
const flag = k => !!(G && G.flags[k]);
const setFlag = k => { G.flags[k] = true; };
const count = id => (G.inv[id] || 0);
const has = (id, n = 1) => count(id) >= n;
const give = (id, n = 1) => { G.inv[id] = count(id) + n; };
const take = (id, n = 1) => { G.inv[id] = Math.max(0, count(id) - n); if (!G.inv[id]) delete G.inv[id]; };
const addGold = n => { G.gold += n; };

const Game = {
  mode: 'title',
  mapId: null, map: null, grid: [], w: 0, h: 0,
  ents: [], chestAt: new Map(), signAt: new Map(),
  player: { x: 0, y: 0, px: 0, py: 0, dir: 'down', moving: false, t: 0, fx: 0, fy: 0 },
  cam: { x: 0, y: 0 },
  busy: false, fading: false, bumpT: 0, safeSteps: 0,
  flakes: [], frame: 0, clock: 0,

  newState(name, cls) {
    const c = CLASSES[cls];
    const st = {
      v: 1, hero: { name, cls, lv: 1, xp: 0, hp: 0, mp: 0, equip: { weapon: c.start.weapon, armor: c.start.armor, charm: null } },
      gold: 20, inv: { tonic: 2 }, flags: {}, opened: {}, quests: { main: 'active' },
      map: 'town', x: 0, y: 0, dir: 'up', time: 0, wins: 0, steps: 0,
    };
    return st;
  },

  stats(h = G.hero) {
    const c = CLASSES[h.cls], l = h.lv - 1;
    const s = {};
    for (const k of ['hp', 'mp', 'atk', 'def', 'mag', 'spd']) s[k] = Math.floor(c.base[k] + c.grow[k] * l);
    s.crit = c.crit; s.fireMul = 1; s.poison = 0;
    for (const slot of ['weapon', 'armor', 'charm']) {
      const it = ITEMS[h.equip[slot]];
      if (!it) continue;
      for (const k of ['hp', 'mp', 'atk', 'def', 'mag', 'spd']) s[k] += it[k] || 0;
      s.crit += it.crit || 0;
      s.poison += it.poison || 0;
      if (it.fireRes) s.fireMul *= 1 - it.fireRes;
    }
    s.mhp = s.hp; s.mmp = s.mp;
    return s;
  },

  fmtTime(sec) {
    const m = Math.floor(sec / 60), h = Math.floor(m / 60);
    return `${h}:${String(m % 60).padStart(2, '0')}`;
  },

  // ---- Save / load ----
  save(silent) {
    if (!G) return false;
    G.map = this.mapId; G.x = this.player.x; G.y = this.player.y; G.dir = this.player.dir;
    try { localStorage.setItem(SAVE_KEY, JSON.stringify(G)); return true; }
    catch (e) { if (!silent) UI.toast('This browser blocked saving.'); return false; }
  },
  readSave() {
    try {
      const raw = localStorage.getItem(SAVE_KEY);
      if (!raw) return null;
      const s = JSON.parse(raw);
      return s && s.hero && CLASSES[s.hero.cls] && MAPS[s.map] ? s : null;
    } catch (e) { return null; }
  },

  start(state, fresh) {
    G = state;
    const s = this.stats();
    if (fresh) { G.hero.hp = s.mhp; G.hero.mp = s.mmp; }
    this.mode = 'world';
    Input.clear();
    Input.push(this.worldKey);
    if (fresh) this.loadMap('town', '@');
    else this.loadMap(G.map, null, { x: G.x, y: G.y, dir: G.dir });
    this.fadeIn();
    if (fresh) this.run(async () => {
      await sleep(400);
      await say('', 'You reach Hollowmere at dusk. Snow drifts where there should be chimney smoke. Every window is dark.');
      await say('', 'Something is wrong here. The village elder, Maren, lives in the house to the south-west.');
    });
  },

  worldKey: k => {
    const g = Game;
    if (g.mode !== 'world' || g.busy || g.fading || g.player.moving) return;
    if (k === 'a') g.interact();
    else if (k === 'b' || k === 'menu') g.run(() => UI.openMenu());
  },

  async run(fn, keepHeld) {
    if (this.busy) return;
    this.busy = true;
    if (!keepHeld) Input.clear();
    try { await fn(); } catch (e) { console.error(e); }
    this.busy = false;
    if (!keepHeld) Input.clear();
  },

  // ---- Maps ----
  loadMap(id, atKey, pos) {
    const def = MAPS[id];
    const prevTheme = this.map && this.map.theme;
    this.mapId = id; this.map = def;
    const w = Math.max(...def.rows.map(r => r.length));
    this.w = w; this.h = def.rows.length;
    this.grid = def.rows.map(r => r.padEnd(w, 'X').split(''));
    this.ents = []; this.chestAt.clear(); this.signAt.clear();
    let ci = 0, si = 0, found = null;
    for (let y = 0; y < this.h; y++) for (let x = 0; x < w; x++) {
      const ch = this.grid[y][x];
      if (ch === 'C') this.chestAt.set(`${x},${y}`, ci++);
      else if (ch === 'S') this.signAt.set(`${x},${y}`, si++);
      else if (/[a-z]/.test(ch) && def.npcs && def.npcs[ch]) {
        const n = def.npcs[ch];
        this.ents.push({ key: ch, def: n, x, y, px: x * TS, py: y * TS, hx: x, hy: y, dir: 'down', moving: false, t: 0, wt: rnd(1, 3), fx: x, fy: y });
      }
      if (!found && atKey && ch === String(atKey)) found = { x, y };
    }
    const p = this.player;
    const at = pos || found || { x: 1, y: 1 };
    p.x = at.x; p.y = at.y; p.px = at.x * TS; p.py = at.y * TS; p.moving = false;
    if (pos && pos.dir) p.dir = pos.dir;
    this.safeSteps = 3;
    this.snapCam();
    this.setMusic(def.music);
    const sub = typeof def.sub === 'function' ? def.sub() : def.sub;
    if (sub && def.theme !== prevTheme && !this.quietLoad) UI.banner(def.name, sub);
    this.quietLoad = false;
    UI.hud(true);
  },

  setMusic(name) { Sound.play(name); },

  charAt(x, y) { return (x < 0 || y < 0 || x >= this.w || y >= this.h) ? 'X' : this.grid[y][x]; },
  entAt(x, y) { return this.ents.find(e => this.visible(e) && ((e.x === x && e.y === y) || (e.moving && e.fx === x && e.fy === y))); },
  visible(e) { return !(e.def.hideIf && flag(e.def.hideIf)) && !(e.def.showIf && !flag(e.def.showIf)); },
  solid(x, y) {
    const ch = this.charAt(x, y);
    if (ch === 'J') return !flag('gateOpen');
    return SOLID.has(ch);
  },
  free(x, y) {
    if (this.solid(x, y) || this.entAt(x, y)) return false;
    const p = this.player;
    return !((p.x === x && p.y === y) || (p.moving && p.fx === x && p.fy === y));
  },

  snapCam() {
    const p = this.player, c = this.cam;
    const vw = VW * TS, vh = VH * TS;
    const mw = this.w * TS, mh = this.h * TS;
    c.x = mw <= vw ? (mw - vw) / 2 : clamp(p.px + 8 - vw / 2, 0, mw - vw);
    c.y = mh <= vh ? (mh - vh) / 2 : clamp(p.py + 8 - vh / 2, 0, mh - vh);
  },

  // ---- Fades ----
  fadeOut() { this.fading = true; $('fade').classList.add('on'); return sleep(300); },
  fadeIn() { $('fade').classList.remove('on'); return sleep(300).then(() => { this.fading = false; }); },

  async warp(key) {
    const w = this.map.warps[key];
    if (!w) return;
    Sound.sfx('door');
    await this.fadeOut();
    this.loadMap(w.to, w.at);
    this.player.dir = w.face || this.player.dir;
    await this.fadeIn();
  },

  // ---- Update ----
  update(dt) {
    this.clock += dt;
    this.frame = Math.floor(this.clock / 0.45);
    if (this.mode === 'world' || this.mode === 'battle') G.time += dt;
    if (this.mode !== 'world') return;
    const p = this.player;
    const canAct = !this.busy && !this.fading && Input.top() === this.worldKey;

    if (p.moving) {
      p.t += dt / 0.15;
      if (p.t >= 1) {
        p.moving = false; p.x = p.fx; p.y = p.fy; p.px = p.x * TS; p.py = p.y * TS;
        this.onStep();
      } else {
        p.px = (p.x + (p.fx - p.x) * p.t) * TS;
        p.py = (p.y + (p.fy - p.y) * p.t) * TS;
      }
    }
    if (!p.moving && canAct) {
      const d = Input.dir();
      if (d) {
        p.dir = d;
        const [dx, dy] = DIRS[d];
        const nx = p.x + dx, ny = p.y + dy;
        if (this.free(nx, ny)) { p.moving = true; p.t = 0; p.fx = nx; p.fy = ny; }
        else if (this.clock - this.bumpT > 0.3) { this.bumpT = this.clock; Sound.sfx('bump'); }
      }
    }
    // NPC wandering
    for (const e of this.ents) {
      if (!this.visible(e)) continue;
      if (e.moving) {
        e.t += dt / 0.3;
        if (e.t >= 1) { e.moving = false; e.x = e.fx; e.y = e.fy; e.px = e.x * TS; e.py = e.y * TS; }
        else { e.px = (e.x + (e.fx - e.x) * e.t) * TS; e.py = (e.y + (e.fy - e.y) * e.t) * TS; }
        continue;
      }
      if (!e.def.wander || this.busy) continue;
      e.wt -= dt;
      if (e.wt > 0) continue;
      e.wt = rnd(1.2, 3.5);
      const d = pick(Object.keys(DIRS)), [dx, dy] = DIRS[d];
      const nx = e.x + dx, ny = e.y + dy;
      e.dir = d;
      if (Math.abs(nx - e.hx) + Math.abs(ny - e.hy) <= e.def.wander && this.free(nx, ny) && !/\d/.test(this.charAt(nx, ny))) {
        e.moving = true; e.t = 0; e.fx = nx; e.fy = ny;
      }
    }
    // Camera easing
    const c = this.cam, vw = VW * TS, vh = VH * TS, mw = this.w * TS, mh = this.h * TS;
    const tx = mw <= vw ? (mw - vw) / 2 : clamp(p.px + 8 - vw / 2, 0, mw - vw);
    const ty = mh <= vh ? (mh - vh) / 2 : clamp(p.py + 8 - vh / 2, 0, mh - vh);
    c.x += (tx - c.x) * Math.min(1, dt * 12);
    c.y += (ty - c.y) * Math.min(1, dt * 12);
    UI.hud(true);
  },

  onStep() {
    const p = this.player;
    G.steps++;
    const ch = this.charAt(p.x, p.y);
    if (/\d/.test(ch) && this.map.warps[ch]) { this.run(() => this.warp(ch), true); return; }
    // Bosses notice you
    for (const e of this.ents) {
      if (!e.def.aggro || !this.visible(e)) continue;
      if (Math.abs(e.x - p.x) + Math.abs(e.y - p.y) <= e.def.aggro) {
        this.run(async () => { await e.def.talk(); });
        return;
      }
    }
    if (this.safeSteps > 0) { this.safeSteps--; return; }
    const enc = this.map.enc;
    if (!enc || (this.map.noEncIf && flag(this.map.noEncIf))) return;
    const rate = enc.rates[ch] || 0;
    if (rate && Math.random() < rate) {
      this.run(() => this.battle(pick(enc.groups)));
    }
  },

  facing() {
    const [dx, dy] = DIRS[this.player.dir];
    return { x: this.player.x + dx, y: this.player.y + dy, dx, dy };
  },

  interact() {
    const f = this.facing();
    let e = this.entAt(f.x, f.y);
    const ch = this.charAt(f.x, f.y);
    if (!e && ch === '|') e = this.entAt(f.x + f.dx, f.y + f.dy);
    if (e) {
      if (!e.moving) e.dir = { up: 'down', down: 'up', left: 'right', right: 'left' }[this.player.dir];
      this.run(() => e.def.talk());
      return;
    }
    switch (ch) {
      case 'C': return this.run(() => this.openChest(f.x, f.y));
      case 'S': return this.run(() => say('', (this.map.signs || [])[this.signAt.get(`${f.x},${f.y}`)] || 'The words have worn away.'));
      case 'J': return this.run(() => this.gate());
      case 'V': return this.run(async () => {
        await this.rest(true);
        await say('', 'You drink from the spring. The water is so cold it hums. Your wounds close.');
      });
      case 'P': return this.run(() => say('', flag('ending') ? 'Someone has hung a lantern over the well. It smells like woodsmoke and bread.' : 'The well has a skin of ice across it. Three nights without the Hearthfire and already this.'));
      case 'K': return this.run(() => say('', pick([
        'A ledger of hearth-tenders going back two hundred years. The last entry is smudged.',
        '"On the Nature of Wyrms": most of the pages are about how they are cold-blooded, ironically.',
        'A cookbook. Someone has underlined "turnip" with alarming force.',
        '"The Wardens of Cinder Hollow". The chapter on the key has been torn out.',
      ])));
      case 'E': return this.run(() => say('', 'A neatly made bed. Not yours.'));
      case '~': return this.run(() => say('', 'The river runs cold and fast. Best not.'));
      case 'L': return this.run(() => say('', 'Molten rock. Your eyebrows advise against it.'));
    }
  },

  async openChest(x, y) {
    const idx = this.chestAt.get(`${x},${y}`);
    const key = `${this.mapId}:${idx}`;
    if (G.opened[key]) return say('', 'The chest is empty.');
    const c = (this.map.chests || [])[idx] || { gold: 10 };
    G.opened[key] = true;
    Sound.sfx('chest');
    if (c.gold) { addGold(c.gold); return say('', `Found ${c.gold} gold.`); }
    const id = c.relic ? CLASS_RELIC[G.hero.cls] : c.item;
    give(id, c.n || 1);
    const it = ITEMS[id];
    await say('', `Found ${it.name}${(c.n || 1) > 1 ? ` ×${c.n}` : ''}!`);
    if (id === 'moonpetal' && flag('herbsGiven') && count('moonpetal') === 3) await say('', 'That makes three Moonpetals. Wren will be glad.');
    if (['weapon', 'armor', 'charm'].includes(it.type)) await say('', 'Equip it from the menu (Esc or MENU).');
  },

  async gate() {
    if (flag('gateOpen')) return;
    if (!has('wardenkey')) return say('', 'An iron gate, sealed with a lock shaped like the wardens\' sigil. It will not move.');
    await say('', 'The Warden\'s Key turns with a grinding shriek. The gate swings inward. Heat rolls out from below.');
    setFlag('gateOpen');
    take('wardenkey');
    Sound.sfx('door');
  },

  async rest(silent) {
    const s = this.stats();
    if (!silent) { await this.fadeOut(); Sound.sfx('heal'); await sleep(500); }
    else Sound.sfx('heal');
    G.hero.hp = s.mhp; G.hero.mp = s.mmp;
    if (!silent) await this.fadeIn();
  },

  startQuest(id) { G.quests[id] = 'active'; UI.toast(`New quest: ${QUESTS[id].name}`); },
  completeQuest(id) { G.quests[id] = 'done'; UI.toast(`Quest complete: ${QUESTS[id].name}`); },

  equip(slot, id) {
    const h = G.hero, cur = h.equip[slot];
    if (cur) give(cur, 1);
    if (id) take(id, 1);
    h.equip[slot] = id || null;
    const s = this.stats();
    h.hp = Math.min(h.hp, s.mhp); h.mp = Math.min(h.mp, s.mmp);
  },

  // Items/skills outside battle
  useItem(id) {
    const it = ITEMS[id], h = G.hero, s = this.stats();
    if (it.heal) {
      if (h.hp >= s.mhp) return 'You\'re already at full health.';
      const before = h.hp; h.hp = Math.min(s.mhp, h.hp + it.heal); take(id);
      Sound.sfx('heal'); return `Recovered ${h.hp - before} HP.`;
    }
    if (it.mp) {
      if (h.mp >= s.mmp) return 'Your MP is already full.';
      const before = h.mp; h.mp = Math.min(s.mmp, h.mp + it.mp); take(id);
      Sound.sfx('heal'); return `Recovered ${h.mp - before} MP.`;
    }
    if (it.cure) return 'Nothing ails you right now.';
    return 'Nothing happens.';
  },

  useSkillField(id) {
    const sk = SKILLS[id], h = G.hero, s = this.stats();
    if (h.mp < sk.mp) return 'Not enough MP.';
    if (h.hp >= s.mhp) return 'You\'re already at full health.';
    h.mp -= sk.mp;
    const amt = sk.heal.pct ? Math.round(s.mhp * sk.heal.pct) : Math.round(s.mag * sk.heal.mag + sk.heal.flat);
    const before = h.hp; h.hp = Math.min(s.mhp, h.hp + amt);
    Sound.sfx('heal');
    return `${sk.name}: recovered ${h.hp - before} HP.`;
  },

  gainXp(n) {
    const h = G.hero, msgs = [];
    if (h.lv >= LEVEL_CAP) return msgs;
    h.xp += n;
    while (h.lv < LEVEL_CAP && h.xp >= xpToNext(h.lv)) {
      const before = this.stats();
      h.xp -= xpToNext(h.lv);
      h.lv++;
      const after = this.stats();
      h.hp += after.mhp - before.mhp; h.mp += after.mmp - before.mmp;
      msgs.push(`${h.name} reached level ${h.lv}! HP +${after.mhp - before.mhp}, ATK +${after.atk - before.atk}, DEF +${after.def - before.def}, MAG +${after.mag - before.mag}.`);
      for (const sid of CLASSES[h.cls].skills) if (SKILLS[sid].lv === h.lv) msgs.push(`Learned ${SKILLS[sid].name}!`);
    }
    if (h.lv >= LEVEL_CAP) h.xp = 0;
    return msgs;
  },

  async battle(group, opts = {}) {
    UI.hud(false);
    this.mode = 'battle';
    const r = await Battle.run(group, opts);
    this.mode = 'world';
    this.safeSteps = 4;
    if (r === 'lose') await this.defeat();
    else this.setMusic(this.map.music);
    UI._hudKey = '';
    UI.hud(true);
    return r;
  },

  async defeat() {
    await this.fadeOut();
    const lost = Math.floor(G.gold / 2);
    G.gold -= lost;
    const s = this.stats();
    G.hero.hp = s.mhp; G.hero.mp = s.mmp;
    this.loadMap('inn', null, { x: 5, y: 5, dir: 'up' });
    await this.fadeIn();
    await say('Pell', `Easy now. A hunter dragged you in off the road. You\'ll live${lost ? `, though your purse is ${lost} gold lighter` : ''}.`);
  },

  async ending() {
    await say('Elder Maren', 'Is that...? Child, you\'ve brought it home.');
    await say('Elder Maren', 'Come. The hearth has waited long enough.');
    await this.fadeOut();
    take('hearthember');
    setFlag('ending');
    this.completeQuest('main');
    this.quietLoad = true;
    this.loadMap('town', null, { x: 10, y: 10, dir: 'down' });
    this.mode = 'ending';
    UI.hud(false);
    await sleep(300);
    $('fade').classList.remove('on');
    Sound.play('ending');
    await UI.ending([
      ['Hero', `${G.hero.name}, ${CLASSES[G.hero.cls].name}`],
      ['Level', String(G.hero.lv)],
      ['Battles won', String(G.wins)],
      ['Steps walked', String(G.steps)],
      ['Time', this.fmtTime(G.time)],
      ['Gold', String(G.gold)],
    ]);
    this.fading = false;
    this.mode = 'world';
    this.setMusic('town');
    Game.save(true);
    await say('', 'The village is warm again. Your journey has been saved. Feel free to wander.');
  },

  snapshot() {
    if (!G || this.mode === 'title') return null;
    this.save(true);
    return { state: JSON.parse(JSON.stringify(G)) };
  },

  // ---- Rendering ----
  drawTile(ctx, ch, x, y, dx, dy) {
    const m = this.map;
    let img;
    if (/\d/.test(ch)) {
      const look = m.warps[ch] ? m.warps[ch].look : 'path';
      img = look === 'path' ? Gfx.tileFor(m, ':', x, y) : Gfx.tiles.get(look);
    } else if (/[a-z@]/.test(ch)) {
      img = Gfx.tileFor(m, m.floor, x, y, this.frame);
    } else if (ch === 'S' || ch === 'C') {
      ctx.drawImage(Gfx.tileFor(m, m.floor, x, y, this.frame), dx, dy);
      img = ch === 'S' ? Gfx.tiles.get('S') : Gfx.tiles.get(G.opened[`${this.mapId}:${this.chestAt.get(`${x},${y}`)}`] ? 'chestOpen' : 'chest');
    } else if (ch === 'J' && flag('gateOpen')) {
      img = Gfx.tiles.get(';');
    } else {
      img = Gfx.tileFor(m, ch, x, y, this.frame);
    }
    if (img) ctx.drawImage(img, dx, dy);
  },

  drawPerson(ctx, look, dir, px, py, moving, t) {
    ctx.fillStyle = 'rgba(0,0,0,0.28)';
    ctx.beginPath(); ctx.ellipse(px + 8, py + 14.5, 5, 2, 0, 0, Math.PI * 2); ctx.fill();
    const stepPhase = moving ? Math.floor(t * 2) % 2 : 0;
    let img = Gfx.person(look, dir);
    if (stepPhase && (dir === 'up' || dir === 'down')) img = Gfx.sprite(dir, look, true);
    ctx.drawImage(img, Math.round(px), Math.round(py - 2 - (stepPhase ? 1 : 0)));
  },

  render(ctx) {
    const m = this.map, c = this.cam;
    ctx.fillStyle = '#000'; ctx.fillRect(0, 0, VW * TS, VH * TS);
    const ox = Math.round(c.x * SCALE) / SCALE, oy = Math.round(c.y * SCALE) / SCALE;
    const x0 = Math.floor(ox / TS), y0 = Math.floor(oy / TS);
    for (let ty = y0; ty <= y0 + VH + 1; ty++) {
      for (let tx = x0; tx <= x0 + VW + 1; tx++) {
        if (tx < 0 || ty < 0 || tx >= this.w || ty >= this.h) continue;
        this.drawTile(ctx, this.grid[ty][tx], tx, ty, tx * TS - ox, ty * TS - oy);
      }
    }
    // Actors sorted by y
    const p = this.player;
    const actors = this.ents.filter(e => this.visible(e)).map(e => ({ y: e.py, e }));
    actors.push({ y: p.py, p: true });
    actors.sort((a, b) => a.y - b.y);
    for (const a of actors) {
      if (a.p) {
        this.drawPerson(ctx, CLASSES[G.hero.cls].pal, p.dir, p.px - ox, p.py - oy, p.moving, p.t);
      } else if (a.e.def.enemy) {
        const en = ENEMIES[a.e.def.enemy];
        const img = Gfx.sprite(en.sprite, en.pal);
        const bob = Math.sin(this.clock * 3) * 1;
        const sx = a.e.px - ox - 8, sy = a.e.py - oy - 16 + bob;
        ctx.fillStyle = 'rgba(0,0,0,0.35)';
        ctx.beginPath(); ctx.ellipse(sx + 16, a.e.py - oy + 14, 12, 3, 0, 0, Math.PI * 2); ctx.fill();
        ctx.drawImage(img, sx, sy, 32, 32);
      } else {
        const e = a.e;
        this.drawPerson(ctx, e.def.look, e.dir, e.px - ox, e.py - oy, e.moving, e.t);
      }
    }
    this.renderAtmosphere(ctx, p.px - ox + 8, p.py - oy + 6);
  },

  renderAtmosphere(ctx, lx, ly) {
    const m = this.map, W = VW * TS, H = VH * TS;
    if (m.theme === 'cave') {
      if (!this._dark) { this._dark = document.createElement('canvas'); this._dark.width = W; this._dark.height = H; }
      const d = this._dark.getContext('2d');
      d.globalCompositeOperation = 'source-over';
      d.clearRect(0, 0, W, H);
      d.fillStyle = 'rgba(8,4,6,0.78)'; d.fillRect(0, 0, W, H);
      d.globalCompositeOperation = 'destination-out';
      const hole = (x, y, r0, r) => {
        const g = d.createRadialGradient(x, y, r0, x, y, r);
        g.addColorStop(0, 'rgba(0,0,0,1)'); g.addColorStop(1, 'rgba(0,0,0,0)');
        d.fillStyle = g; d.fillRect(0, 0, W, H);
      };
      hole(lx, ly, 8, 64 + Math.sin(this.clock * 5) * 2);
      // Bosses smoulder in the dark
      for (const e of this.ents) if (e.def.enemy && this.visible(e)) hole(e.px - this.cam.x + 8, e.py - this.cam.y, 6, 38 + Math.sin(this.clock * 3) * 4);
      ctx.drawImage(this._dark, 0, 0);
      ctx.fillStyle = 'rgba(255,90,20,0.06)'; ctx.fillRect(0, 0, W, H);
    } else if (m.theme === 'woods') {
      ctx.fillStyle = 'rgba(10,30,40,0.22)'; ctx.fillRect(0, 0, W, H);
      const g = ctx.createRadialGradient(W / 2, H / 2, 40, W / 2, H / 2, 150);
      g.addColorStop(0, 'rgba(0,0,0,0)'); g.addColorStop(1, 'rgba(0,10,5,0.55)');
      ctx.fillStyle = g; ctx.fillRect(0, 0, W, H);
      this.particles(ctx, 'firefly');
    } else if (m.theme === 'town' || m.theme === 'field') {
      const warm = flag('ending');
      ctx.fillStyle = warm ? 'rgba(255,150,60,0.07)' : 'rgba(70,100,170,0.16)';
      ctx.fillRect(0, 0, W, H);
      this.particles(ctx, warm ? 'ember' : 'snow');
    } else if (m.theme === 'inside' && !flag('ending')) {
      ctx.fillStyle = 'rgba(40,60,120,0.12)'; ctx.fillRect(0, 0, W, H);
    }
  },

  particles(ctx, kind) {
    const W = VW * TS, H = VH * TS;
    if (this.flakes.length === 0) for (let i = 0; i < 50; i++) this.flakes.push({ x: Math.random() * W, y: Math.random() * H, s: rnd(0.4, 1), ph: Math.random() * 6 });
    const t = this.clock;
    for (const f of this.flakes) {
      let x, y;
      if (kind === 'snow') {
        y = (f.y + t * 14 * f.s) % H; x = (f.x + Math.sin(t + f.ph) * 6 - this.cam.x * 0.2 + W * 4) % W;
        ctx.fillStyle = `rgba(235,242,255,${0.5 + f.s * 0.4})`;
        ctx.fillRect(x, y, f.s > 0.8 ? 2 : 1, f.s > 0.8 ? 2 : 1);
      } else if (kind === 'ember') {
        y = H - ((f.y + t * 10 * f.s) % H); x = (f.x + Math.sin(t * 1.5 + f.ph) * 5 + W) % W;
        ctx.fillStyle = `rgba(255,${150 + f.s * 80 | 0},60,${0.3 + f.s * 0.4})`;
        ctx.fillRect(x, y, 1, 1);
      } else {
        x = (f.x + Math.sin(t * 0.7 + f.ph) * 14 + W) % W; y = (f.y + Math.cos(t * 0.5 + f.ph) * 10 + H) % H;
        const a = (Math.sin(t * 2 + f.ph * 3) + 1) / 2;
        if (f.s > 0.75) { ctx.fillStyle = `rgba(200,255,140,${a * 0.9})`; ctx.fillRect(x, y, 1.5, 1.5); }
      }
    }
  },
};

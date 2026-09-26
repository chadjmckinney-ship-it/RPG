'use strict';
// Input focus stack + DOM interface (dialogue, lists, menus, shop, title).

const Input = {
  held: { up: false, down: false, left: false, right: false },
  order: [],
  stack: [],
  push(h) { this.stack.push(h); },
  remove(h) { const i = this.stack.lastIndexOf(h); if (i >= 0) this.stack.splice(i, 1); },
  top() { return this.stack[this.stack.length - 1]; },
  press(k) { const h = this.top(); if (h) h(k); },
  hold(k, on) {
    this.held[k] = on;
    this.order = this.order.filter(d => d !== k);
    if (on) this.order.push(k);
  },
  dir() { return this.order.length ? this.order[this.order.length - 1] : null; },
  clear() { for (const k in this.held) this.held[k] = false; this.order = []; },
};

const $ = id => document.getElementById(id);
const esc = s => String(s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
const meter = (v, max, cls = '') => `<div class="meter ${cls}"><i style="width:${max > 0 ? clamp(v / max * 100, 0, 100) : 0}%"></i></div>`;

const UI = {
  _hideT: 0,

  // ---------- Dialogue ----------
  _type(name, text) {
    clearTimeout(this._hideT);
    const d = $('dialog'), sp = d.querySelector('.speaker'), tx = d.querySelector('.text'), more = d.querySelector('.more');
    d.hidden = false;
    sp.hidden = !name; sp.textContent = name || '';
    more.hidden = true;
    tx.textContent = '';
    return new Promise(resolve => {
      let i = 0;
      const finish = () => {
        clearInterval(tick);
        tx.textContent = text;
        Input.remove(handler);
        d.removeEventListener('click', click);
        resolve();
      };
      const tick = setInterval(() => {
        i += 2;
        tx.textContent = text.slice(0, i);
        if (i % 6 === 0) Sound.sfx('talk');
        if (i >= text.length) finish();
      }, 18);
      const handler = k => { if (k === 'a' || k === 'b') finish(); };
      const click = () => finish();
      d.addEventListener('click', click);
      Input.push(handler);
    });
  },

  async say(name, text) {
    await this._type(name, text);
    const d = $('dialog'), more = d.querySelector('.more');
    more.hidden = false;
    await new Promise(resolve => {
      const done = () => { Input.remove(handler); d.removeEventListener('click', done); resolve(); };
      const handler = k => { if (k === 'a' || k === 'b') { Sound.sfx('blip'); done(); } };
      d.addEventListener('click', done);
      Input.push(handler);
    });
    this._hideT = setTimeout(() => { $('dialog').hidden = true; }, 40);
  },

  async ask(name, text, options) {
    await this._type(name, text);
    const c = $('choices');
    c.hidden = false;
    c.innerHTML = '<div class="list"></div>';
    const i = await this.list(c.firstChild, options.map(o => ({ label: o })));
    c.hidden = true;
    $('dialog').hidden = true;
    return i < 0 ? options.length - 1 : i;
  },

  // ---------- Generic selectable list ----------
  // items: [{label, right, disabled, desc}] -> resolves index, or -1 on cancel
  list(container, items, opts = {}) {
    return new Promise(resolve => {
      const cols = opts.cols || 1;
      container.innerHTML = '';
      container.classList.toggle('cols2', cols === 2);
      if (!items.length) {
        container.innerHTML = `<div class="opt" style="cursor:default;color:var(--muted)">${esc(opts.empty || 'Nothing here.')}</div>`;
      }
      let idx = clamp(opts.start || 0, 0, Math.max(0, items.length - 1));
      const btns = items.map((it, i) => {
        const b = document.createElement('button');
        b.type = 'button';
        b.className = 'opt';
        b.innerHTML = `<span>${esc(it.label)}</span>${it.right != null ? `<span class="r">${esc(it.right)}</span>` : ''}`;
        if (it.disabled) b.setAttribute('aria-disabled', 'true');
        b.addEventListener('pointermove', () => { if (idx !== i) set(i, true); });
        b.addEventListener('click', e => { e.stopPropagation(); set(i); choose(); });
        container.appendChild(b);
        return b;
      });
      const set = (i, quiet) => {
        if (!btns.length) { opts.onMove && opts.onMove(-1, null); return; }
        if (i !== idx && !quiet) Sound.sfx('blip');
        idx = i;
        btns.forEach((b, j) => b.classList.toggle('sel', j === idx));
        const b = btns[idx];
        if (b.offsetTop < container.scrollTop) container.scrollTop = b.offsetTop;
        else if (b.offsetTop + b.offsetHeight > container.scrollTop + container.clientHeight) container.scrollTop = b.offsetTop + b.offsetHeight - container.clientHeight;
        opts.onMove && opts.onMove(idx, items[idx]);
      };
      const move = d => { if (btns.length) set((idx + d + btns.length) % btns.length); };
      const choose = () => {
        const it = items[idx];
        if (!it) return;
        if (it.disabled) { Sound.sfx('bump'); if (opts.onDisabled) opts.onDisabled(it); return; }
        Sound.sfx('select');
        done(idx);
      };
      const handler = k => {
        if (k === 'up') move(-cols);
        else if (k === 'down') move(cols);
        else if (k === 'left') { if (cols > 1) move(-1); }
        else if (k === 'right') { if (cols > 1) move(1); }
        else if (k === 'a') choose();
        else if ((k === 'b' || k === 'menu') && opts.cancel !== false) { Sound.sfx('cancel'); done(-1); }
      };
      const cancelClick = e => { if (e.target === container && opts.cancel !== false && !btns.length) { done(-1); } };
      const done = v => {
        Input.remove(handler);
        container.removeEventListener('click', cancelClick);
        btns.forEach(b => b.replaceWith(b.cloneNode(true)));
        resolve(v);
      };
      container.addEventListener('click', cancelClick);
      Input.push(handler);
      set(idx, true);
    });
  },

  toast(msg, ms = 1700) {
    const t = $('toast');
    t.textContent = msg;
    t.hidden = false;
    t.style.opacity = 1;
    clearTimeout(this._toastT);
    this._toastT = setTimeout(() => { t.style.opacity = 0; setTimeout(() => { t.hidden = true; }, 300); }, ms);
  },

  banner(name, sub) {
    const b = $('banner');
    b.innerHTML = `${esc(name)}${sub ? `<small>${esc(sub)}</small>` : ''}`;
    b.hidden = false;
    b.style.opacity = 1;
    clearTimeout(this._bannerT);
    this._bannerT = setTimeout(() => { b.style.opacity = 0; setTimeout(() => { b.hidden = true; }, 600); }, 1900);
  },

  _hudKey: '',
  hud(show) {
    const h = $('hud');
    h.hidden = !show;
    if (!show || !G) return;
    const s = Game.stats(), hero = G.hero;
    const key = `${hero.name}${hero.lv}${hero.hp}${s.mhp}${hero.mp}${s.mmp}`;
    if (key === this._hudKey) return;
    this._hudKey = key;
    h.innerHTML = `<div class="row"><span class="name">${esc(hero.name)}</span><span class="label">Lv ${hero.lv}</span></div>
      ${meter(hero.hp, s.mhp)}<div class="row num"><span class="label">HP</span><span>${hero.hp}/${s.mhp}</span></div>
      ${meter(hero.mp, s.mmp, 'mp')}<div class="row num"><span class="label">MP</span><span>${hero.mp}/${s.mmp}</span></div>`;
  },

  portrait(look, dir = 'down') {
    const c = document.createElement('canvas');
    c.width = 16; c.height = 16;
    c.getContext('2d').drawImage(Gfx.person(look, dir), 0, 0);
    return c;
  },

  // ---------- Pause menu ----------
  async openMenu() {
    Sound.sfx('select');
    const m = $('menu');
    m.hidden = false;
    m.innerHTML = `<div class="main win" id="m-main"></div>
      <div class="side"><div class="win"><div class="list" id="m-cmds"></div></div>
      <div class="win gold"><span class="label">Gold</span><span class="num" id="m-gold"></span></div></div>`;
    const cmds = ['Items', 'Skills', 'Equip', 'Status', 'Quests', 'Save', 'Close'];
    let start = 0;
    for (;;) {
      this.menuSummary();
      $('m-gold').textContent = G.gold;
      const i = await this.list($('m-cmds'), cmds.map(c => ({ label: c })), { start });
      if (i < 0 || cmds[i] === 'Close') break;
      start = i;
      await this['menu' + cmds[i]]();
    }
    m.hidden = true;
    this._hudKey = '';
  },

  menuSummary() {
    const s = Game.stats(), h = G.hero, need = xpToNext(h.lv);
    const main = $('m-main');
    const quest = QUESTS.main.step();
    main.innerHTML = `<div class="card"><div id="m-port"></div><div>
        <div class="pane-title"><span>${esc(h.name)}</span><span class="label">${CLASSES[h.cls].name} · Lv ${h.lv}</span></div>
        ${meter(h.hp, s.mhp)}<div class="pane-title num" style="color:var(--ink);font-weight:400"><span class="label">HP</span><span>${h.hp} / ${s.mhp}</span></div>
        ${meter(h.mp, s.mmp, 'mp')}<div class="pane-title num" style="color:var(--ink);font-weight:400"><span class="label">MP</span><span>${h.mp} / ${s.mmp}</span></div>
        ${meter(h.lv >= LEVEL_CAP ? 1 : h.xp, h.lv >= LEVEL_CAP ? 1 : need, 'xp')}<div class="pane-title num" style="color:var(--ink);font-weight:400"><span class="label">XP</span><span>${h.lv >= LEVEL_CAP ? 'MAX' : `${h.xp} / ${need}`}</span></div>
      </div></div>
      <div class="desc" style="margin-top:auto"><span class="label">Location</span><br>${esc(Game.map.name)}</div>
      <div class="desc"><span class="label">Objective</span><br>${esc(quest)}</div>
      <div class="desc num"><span class="label">Time</span> ${Game.fmtTime(G.time)} · <span class="label">Battles won</span> ${G.wins}</div>`;
    const port = this.portrait(CLASSES[h.cls].pal);
    $('m-port').appendChild(port);
  },

  pane(title, withDesc = true) {
    const main = $('m-main');
    main.innerHTML = `<div class="pane-title"><span>${esc(title)}</span><span class="label" id="m-note"></span></div>
      <div class="list" id="m-list" style="flex:1"></div>${withDesc ? '<div class="desc" id="m-desc"></div>' : ''}`;
    return { list: $('m-list'), desc: $('m-desc'), note: $('m-note') };
  },

  itemRows() {
    const order = { use: 0, weapon: 1, armor: 2, charm: 3, key: 4 };
    return Object.keys(G.inv).filter(id => G.inv[id] > 0).sort((a, b) => order[ITEMS[a].type] - order[ITEMS[b].type] || ITEMS[a].name.localeCompare(ITEMS[b].name));
  },

  async menuItems() {
    let start = 0;
    for (;;) {
      const p = this.pane('Items');
      const ids = this.itemRows();
      const rows = ids.map(id => ({ label: ITEMS[id].name, right: '×' + G.inv[id], id }));
      const i = await this.list(p.list, rows, { start, empty: 'Your pack is empty.', onMove: (j, it) => { p.desc.textContent = it ? ITEMS[it.id].desc : ''; } });
      if (i < 0) return;
      start = i;
      const id = ids[i], it = ITEMS[id];
      if (it.type !== 'use') { this.toast(it.type === 'key' ? 'Key items are used automatically.' : 'Equip this from the Equip menu.'); continue; }
      if (it.battleOnly || it.auto) { this.toast(it.auto ? 'This works on its own when you fall.' : 'Only useful in battle.'); continue; }
      const msg = Game.useItem(id);
      this.toast(msg);
      $('m-gold').textContent = G.gold;
    }
  },

  async menuSkills() {
    let start = 0;
    for (;;) {
      const p = this.pane('Skills');
      const h = G.hero;
      const ids = CLASSES[h.cls].skills;
      p.note.textContent = `MP ${h.mp}/${Game.stats().mmp}`;
      const rows = ids.map(id => {
        const s = SKILLS[id], known = h.lv >= s.lv;
        return { label: known ? s.name : '???', right: known ? `${s.mp} MP` : `Lv ${s.lv}`, disabled: !known || !s.field, id };
      });
      const i = await this.list(p.list, rows, {
        start,
        onMove: (j, it) => { const s = SKILLS[it.id]; p.desc.textContent = h.lv >= s.lv ? s.desc : `Learned at level ${s.lv}.`; },
        onDisabled: it => { if (h.lv >= SKILLS[it.id].lv) this.toast('Only usable in battle.'); },
      });
      if (i < 0) return;
      start = i;
      this.toast(Game.useSkillField(ids[i]));
    }
  },

  statDiff(slot, id) {
    const before = Game.stats();
    const saved = G.hero.equip[slot];
    G.hero.equip[slot] = id;
    const after = Game.stats();
    G.hero.equip[slot] = saved;
    const keys = [['atk', 'ATK'], ['def', 'DEF'], ['mag', 'MAG'], ['spd', 'SPD'], ['mhp', 'HP'], ['mmp', 'MP']];
    const parts = keys.filter(([k]) => after[k] !== before[k]).map(([k, n]) => {
      const d = after[k] - before[k];
      return `<span class="${d > 0 ? 'up' : 'down'}">${n} ${d > 0 ? '+' : ''}${d}</span>`;
    });
    return parts.length ? parts.join(' · ') : '<span style="color:var(--muted)">No stat change</span>';
  },

  async menuEquip() {
    const slots = [['weapon', 'Weapon'], ['armor', 'Armor'], ['charm', 'Charm']];
    let start = 0;
    for (;;) {
      const p = this.pane('Equipment');
      const rows = slots.map(([k, n]) => ({ label: n, right: G.hero.equip[k] ? ITEMS[G.hero.equip[k]].name : '—' }));
      const i = await this.list(p.list, rows, { start, onMove: (j) => { const id = G.hero.equip[slots[j][0]]; p.desc.textContent = id ? ITEMS[id].desc : 'Empty slot.'; } });
      if (i < 0) return;
      start = i;
      const slot = slots[i][0];
      const cands = Object.keys(G.inv).filter(id => G.inv[id] > 0 && ITEMS[id].type === slot && (!ITEMS[id].cls || ITEMS[id].cls.includes(G.hero.cls)));
      const opts = cands.map(id => ({ label: ITEMS[id].name, right: '×' + G.inv[id], id }));
      if (slot === 'charm' && G.hero.equip.charm) opts.push({ label: 'Remove charm', id: null });
      const q = this.pane(`Equip ${slots[i][1]}`);
      const j = await this.list(q.list, opts, {
        empty: 'Nothing you can equip here.',
        onMove: (k, it) => { if (it) q.desc.innerHTML = `${esc(it.id ? ITEMS[it.id].desc : 'Take it off.')}<br>${this.statDiff(slot, it.id)}`; },
      });
      if (j < 0) continue;
      Game.equip(slot, opts[j].id);
      Sound.sfx('buff');
    }
  },

  async menuStatus() {
    const s = Game.stats(), h = G.hero;
    const main = $('m-main');
    const eq = k => h.equip[k] ? ITEMS[h.equip[k]].name : '—';
    main.innerHTML = `<div class="pane-title"><span>${esc(h.name)} the ${CLASSES[h.cls].name}</span><span class="label">Lv ${h.lv}</span></div>
      <div class="stats num">
        <div><span>HP</span><span>${h.hp}/${s.mhp}</span></div><div><span>MP</span><span>${h.mp}/${s.mmp}</span></div><div><span>SPD</span><span>${s.spd}</span></div>
        <div><span>ATK</span><span>${s.atk}</span></div><div><span>DEF</span><span>${s.def}</span></div><div><span>MAG</span><span>${s.mag}</span></div>
      </div>
      <div class="desc"><span class="label">Weapon</span> ${esc(eq('weapon'))}<br><span class="label">Armor</span> ${esc(eq('armor'))}<br><span class="label">Charm</span> ${esc(eq('charm'))}</div>
      <div class="desc num"><span class="label">Critical</span> ${Math.round(s.crit * 100)}% · <span class="label">Fire resist</span> ${Math.round((1 - s.fireMul) * 100)}%<br>
      <span class="label">To next level</span> ${h.lv >= LEVEL_CAP ? '—' : xpToNext(h.lv) - h.xp} XP</div>
      <div class="desc" style="margin-top:auto">${esc(CLASSES[h.cls].blurb)}</div>`;
    await this.waitKey();
  },

  async menuQuests() {
    const main = $('m-main');
    const ids = Object.keys(G.quests);
    main.innerHTML = `<div class="pane-title"><span>Quests</span></div>` + ids.map(id => {
      const q = QUESTS[id], done = q.done();
      return `<div class="quest ${done ? 'done' : ''}"><b>${esc(q.name)}</b><span>${esc(q.step())}</span></div>`;
    }).join('');
    await this.waitKey();
  },

  async menuSave() {
    if (Game.save(true)) this.toast('Journey saved.');
    else this.toast('This browser blocked saving.');
  },

  waitKey() {
    return new Promise(resolve => {
      const main = $('m-main');
      const done = () => { Input.remove(h); main.removeEventListener('click', done); resolve(); };
      const h = k => { if (k === 'a' || k === 'b' || k === 'menu') { Sound.sfx('cancel'); done(); } };
      main.addEventListener('click', done);
      Input.push(h);
    });
  },

  // ---------- Shop ----------
  async shop(stock, title) {
    const m = $('menu');
    m.hidden = false;
    m.innerHTML = `<div class="main win" id="m-main"></div>
      <div class="side"><div class="win"><div class="list" id="m-cmds"></div></div>
      <div class="win gold"><span class="label">Gold</span><span class="num" id="m-gold"></span></div></div>`;
    let start = 0;
    for (;;) {
      $('m-gold').textContent = G.gold;
      $('m-main').innerHTML = `<div class="pane-title"><span>${esc(title)}</span></div><div class="desc" style="border:0">What'll it be?</div>`;
      const i = await this.list($('m-cmds'), [{ label: 'Buy' }, { label: 'Sell' }, { label: 'Leave' }], { start });
      if (i < 0 || i === 2) break;
      start = i;
      if (i === 0) await this.shopBuy(stock, title);
      else await this.shopSell(title);
    }
    m.hidden = true;
    this._hudKey = '';
  },

  shopDesc(id) {
    const it = ITEMS[id];
    const owned = (G.inv[id] || 0) + Object.values(G.hero.equip).filter(e => e === id).length;
    let s = `${esc(it.desc)} <span class="label">Owned ${owned}</span>`;
    if (['weapon', 'armor', 'charm'].includes(it.type)) s += `<br>${this.statDiff(it.type, id)}`;
    return s;
  },

  async shopBuy(stock, title) {
    let start = 0;
    for (;;) {
      const p = this.pane(`${title} · Buy`);
      const rows = stock.map(id => ({ label: ITEMS[id].name, right: ITEMS[id].price + 'g', disabled: G.gold < ITEMS[id].price, id }));
      const i = await this.list(p.list, rows, {
        start,
        onMove: (j, it) => { p.desc.innerHTML = this.shopDesc(it.id); },
        onDisabled: () => this.toast('Not enough gold.'),
      });
      if (i < 0) return;
      start = i;
      const id = stock[i];
      G.gold -= ITEMS[id].price;
      give(id, 1);
      Sound.sfx('buy');
      $('m-gold').textContent = G.gold;
      this.toast(`Bought ${ITEMS[id].name}.`);
    }
  },

  async shopSell(title) {
    let start = 0;
    for (;;) {
      const p = this.pane(`${title} · Sell`);
      const ids = this.itemRows().filter(id => ITEMS[id].type !== 'key');
      const val = id => Math.max(1, Math.floor((ITEMS[id].price || 40) / 2));
      const rows = ids.map(id => ({ label: `${ITEMS[id].name} ×${G.inv[id]}`, right: val(id) + 'g', id }));
      const i = await this.list(p.list, rows, { start, empty: 'Nothing to sell.', onMove: (j, it) => { p.desc.innerHTML = it ? this.shopDesc(it.id) : ''; } });
      if (i < 0) return;
      start = Math.max(0, Math.min(i, rows.length - 2));
      const id = ids[i];
      take(id, 1);
      G.gold += val(id);
      Sound.sfx('buy');
      $('m-gold').textContent = G.gold;
      this.toast(`Sold ${ITEMS[id].name}.`);
    }
  },

  // ---------- Title & creation ----------
  async title(hasSave) {
    const t = $('title');
    t.hidden = false;
    t.innerHTML = `<div class="sub">The Hearthfire of Hollowmere</div><h1>Emberfall</h1>
      <div class="win"><div class="list" id="t-list"></div></div>
      <div class="foot">Turn sound on with the button above · Progress saves in this browser</div>`;
    const rows = [{ label: 'New Journey' }, { label: 'Continue', disabled: !hasSave }];
    for (;;) {
      const i = await this.list($('t-list'), rows, { start: hasSave ? 1 : 0, cancel: false });
      if (i === 1) { t.hidden = true; return { action: 'continue' }; }
      t.hidden = true;
      const c = await this.create();
      if (c) return { action: 'new', ...c };
      t.hidden = false;
    }
  },

  create() {
    const el = $('create');
    el.hidden = false;
    const keys = Object.keys(CLASSES);
    el.innerHTML = `<div class="pane-title"><span>Who walks into Hollowmere tonight?</span><span class="label">Esc to go back</span></div>
      <div class="field"><label class="label" for="hero-name">Name</label><input id="hero-name" maxlength="10" value="Ash" autocomplete="off" spellcheck="false"></div>
      <div class="classes">${keys.map(k => {
        const c = CLASSES[k], b = c.base;
        return `<button type="button" class="win cls" data-k="${k}"><canvas width="16" height="16"></canvas><b>${c.name}</b><p>${esc(c.blurb)}</p>
          <div class="mini num"><span>HP<em>${b.hp}</em></span><span>MP<em>${b.mp}</em></span><span>ATK<em>${b.atk}</em></span><span>DEF<em>${b.def}</em></span><span>MAG<em>${b.mag}</em></span><span>SPD<em>${b.spd}</em></span></div></button>`;
      }).join('')}</div>
      <button type="button" class="win btn-go" id="go">Begin ▸</button>`;
    let sel = 0;
    const cards = [...el.querySelectorAll('.cls')];
    cards.forEach((c, i) => {
      c.querySelector('canvas').getContext('2d').drawImage(Gfx.person(CLASSES[keys[i]].pal, 'down'), 0, 0);
      c.addEventListener('click', () => set(i));
    });
    const set = i => { if (i !== sel) Sound.sfx('blip'); sel = i; cards.forEach((c, j) => c.classList.toggle('sel', j === sel)); };
    set(0);
    const input = $('hero-name');
    return new Promise(resolve => {
      const finish = v => { Input.remove(h); el.hidden = true; resolve(v); };
      const begin = () => {
        const name = (input.value || '').trim().replace(/[^\p{L}\p{N} '\-]/gu, '').slice(0, 10) || 'Ash';
        Sound.sfx('select');
        finish({ name, cls: keys[sel] });
      };
      const h = k => {
        if (k === 'left') set((sel + 2) % 3);
        else if (k === 'right') set((sel + 1) % 3);
        else if (k === 'a') begin();
        else if (k === 'b') { Sound.sfx('cancel'); finish(null); }
      };
      $('go').addEventListener('click', begin);
      Input.push(h);
    });
  },

  ending(stats) {
    const e = $('ending');
    e.hidden = false;
    e.innerHTML = `<div class="label">The Hearthfire returns</div><h2>Emberfall</h2>
      <p>The flame catches in the old stone hearth and runs along the rafters of every house in Hollowmere. Frost retreats from the windows. Somewhere, Pip is telling everyone it was the snowballs.</p>
      <div class="win stats num">${stats.map(([k, v]) => `<div><span>${esc(k)}</span><span>${esc(v)}</span></div>`).join('')}</div>
      <div class="win"><div class="list" id="e-list"></div></div>`;
    e.querySelector('.stats').style.gridTemplateColumns = '1fr 1fr';
    return this.list($('e-list'), [{ label: 'Keep exploring' }], { cancel: false }).then(() => { e.hidden = true; });
  },

  help(show) {
    const h = $('help');
    h.hidden = !show;
    if (!show) return;
    h.innerHTML = `<div class="pane-title"><span>How to play</span><span class="label">Press any key to close</span></div>
      <dl>
        <dt>Move</dt><dd>Arrow keys or WASD. On touch screens, the pad.</dd>
        <dt>Act</dt><dd>Enter, Space or Z. Talk, open chests, read signs, confirm.</dd>
        <dt>Back / Menu</dt><dd>Esc or X backs out. Opens the menu while exploring. M also opens it.</dd>
        <dt>Battle</dt><dd>Choose Attack, Skill, Item, Defend or Flee. Defend halves the next hit. Fire and ice matter.</dd>
        <dt>Saving</dt><dd>Save from the menu anytime, or rest at the inn. Saves live in this browser.</dd>
      </dl>
      <div class="desc" style="margin-top:auto">Tall grass hides monsters. Chests hide better things. Elder Maren in Hollowmere knows where to begin.</div>`;
  },
};

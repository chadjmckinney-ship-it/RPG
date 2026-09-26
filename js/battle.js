'use strict';
// Turn-based side-view battles.

const ELEM_COLOR = { fire: ['#ffb040', '#ff5a1a', '#fff0a0'], ice: ['#bff0ff', '#6ac8ff', '#ffffff'], arcane: ['#d8a0ff', '#8a5aff', '#ffffff'], none: ['#ffffff', '#ffe08a', '#d0d0d0'], heal: ['#b8ffb0', '#ffffff', '#6ae08a'], buff: ['#ffe070', '#fff4c0', '#f0a030'], poison: ['#c070ff', '#80ff80', '#a040d0'] };

const Battle = {
  active: false, enemies: [], hero: null, opts: {}, t: 0,
  floaters: [], parts: [], shake: 0, intro: 0, cursor: -1, targeting: null,
  heroFx: { lunge: 0, flash: 0 }, skip: false,

  async run(group, opts = {}) {
    this.opts = opts;
    this.theme = Game.map.theme;
    const counts = {};
    group.forEach(id => { counts[id] = (counts[id] || 0) + 1; });
    const seen = {};
    const xs = { 1: [88], 2: [62, 124], 3: [42, 94, 146] }[group.length] || [88];
    this.enemies = group.map((id, i) => {
      const d = ENEMIES[id];
      seen[id] = (seen[id] || 0) + 1;
      const name = counts[id] > 1 ? `${d.name} ${'ABC'[seen[id] - 1]}` : d.name;
      return { id, d, name, hp: d.hp, mhp: d.hp, atk: d.atk, def: d.def, mag: d.mag, spd: d.spd, buffs: [], status: {}, alive: true,
        x: xs[i], y: 98 + (group.length === 3 && i === 1 ? 6 : 0), scale: d.scale || 2, flash: 0, shakeT: 0, lunge: 0, dying: 0, enraged: false };
    });
    this.hero = { isHero: true, name: G.hero.name, buffs: [], status: {}, defending: false };
    this.floaters = []; this.parts = []; this.cursor = -1; this.targeting = null;
    this.active = true; this.t = 0;
    Sound.sfx('encounter');
    Sound.play(opts.music || 'battle');
    this.intro = 1;
    this.skipKey = k => { if (k === 'a') this.skip = true; };
    Input.push(this.skipKey);
    await sleep(650);
    $('battle-ui').hidden = false;
    $('battle-msg').hidden = false;
    this.renderStatus();
    const names = this.enemies.map(e => e.name).join(', ');
    await this.msg(opts.boss ? `${this.enemies[0].d.name} attacks!` : `${names} ${this.enemies.length > 1 ? 'appear' : 'appears'}!`, 900);

    let result = null;
    while (!result) result = await this.round();

    Input.remove(this.skipKey);
    $('battle-ui').hidden = true; $('battle-msg').hidden = true; $('battle-sub').hidden = true;
    await Game.fadeOut();
    this.active = false;
    if (result !== 'lose') await Game.fadeIn();
    return result;
  },

  // ---------- helpers ----------
  alive() { return this.enemies.filter(e => e.alive); },
  eff(u, stat) {
    let v = u.isHero ? Game.stats()[stat] : u[stat];
    for (const b of u.buffs) if (b.stat === stat && b.mult) v *= b.mult;
    if (stat === 'spd' && u.status.slow) v *= 0.5;
    return v;
  },
  eva(u) { return u.buffs.reduce((s, b) => s + (b.stat === 'eva' ? b.add : 0), 0); },
  hp(u) { return u.isHero ? G.hero.hp : u.hp; },

  wait(ms) {
    this.skip = false;
    return new Promise(resolve => {
      const t0 = performance.now();
      const tick = () => {
        if (this.skip || performance.now() - t0 >= ms) { this.skip = false; resolve(); }
        else requestAnimationFrame(tick);
      };
      tick();
    });
  },
  async msg(text, ms = 750) { $('battle-msg').textContent = text; await this.wait(ms); },

  float(x, y, text, color) { this.floaters.push({ x, y, text: String(text), color, t: 0 }); },
  burst(x, y, kind, n = 18) {
    const cols = ELEM_COLOR[kind] || ELEM_COLOR.none;
    for (let i = 0; i < n; i++) {
      const a = Math.random() * Math.PI * 2, sp = rnd(20, 70);
      const rise = kind === 'heal' || kind === 'buff';
      this.parts.push({ x: x + (rise ? rnd(-10, 10) : 0), y: y + (rise ? rnd(-4, 10) : 0), vx: rise ? rnd(-6, 6) : Math.cos(a) * sp, vy: rise ? -rnd(20, 45) : Math.sin(a) * sp, life: rnd(0.4, 0.8), t: 0, c: pick(cols), s: rnd(1, 2.5) });
    }
  },
  center(u) {
    if (u.isHero) return { x: 196, y: 82 };
    const size = 16 * u.scale;
    return { x: u.x, y: u.y - size / 2 };
  },

  renderStatus() {
    const s = Game.stats(), h = G.hero, u = this.hero;
    const tags = [];
    for (const k of Object.keys(u.status)) tags.push(`<span class="tag ${k}">${STATUS_INFO[k].name}</span>`);
    for (const b of u.buffs) tags.push(`<span class="tag buff">${b.stat === 'eva' ? 'Evade' : b.stat.toUpperCase()} ${b.mult && b.mult < 1 ? '▼' : '▲'}</span>`);
    if (u.defending) tags.push('<span class="tag buff">Guard</span>');
    $('battle-status').innerHTML = `<div class="row"><b>${esc(h.name)}</b><span class="label">Lv ${h.lv}</span></div>
      <div class="row num"><span class="label">HP</span><span>${h.hp} / ${s.mhp}</span></div>${meter(h.hp, s.mhp)}
      <div class="row num"><span class="label">MP</span><span>${h.mp} / ${s.mmp}</span></div>${meter(h.mp, s.mmp, 'mp')}
      <div class="tags">${tags.join('')}</div>`;
  },

  // ---------- player choice ----------
  async chooseTarget(single = true) {
    const al = this.alive();
    if (al.length === 1 || !single) return al[0];
    const cmds = $('battle-cmds');
    this.targeting = al;
    const i = await UI.list(cmds, al.map(e => ({ label: e.name })), { onMove: j => { this.cursor = this.enemies.indexOf(al[j]); } });
    this.targeting = null; this.cursor = -1;
    return i < 0 ? null : al[i];
  },

  onCanvasClick(lx, ly) {
    if (!this.targeting) return;
    const al = this.targeting;
    for (let j = 0; j < al.length; j++) {
      const e = al[j], size = 16 * e.scale;
      if (lx >= e.x - size / 2 && lx <= e.x + size / 2 && ly >= e.y - size && ly <= e.y) {
        const btn = $('battle-cmds').children[j];
        if (btn) btn.click();
        return;
      }
    }
  },

  async subList(title, rows, descOf) {
    const sub = $('battle-sub');
    sub.hidden = false;
    sub.innerHTML = `<div class="pane-title"><span>${esc(title)}</span><span class="label">MP ${G.hero.mp}</span></div><div class="list" style="flex:1"></div><div class="desc"></div>`;
    const list = sub.querySelector('.list'), desc = sub.querySelector('.desc');
    const i = await UI.list(list, rows, { cols: 2, empty: 'Nothing usable.', onMove: (j, it) => { desc.textContent = it ? descOf(it) : ''; } });
    sub.hidden = true;
    return i;
  },

  async chooseAction() {
    const cmds = [
      { label: 'Attack' }, { label: 'Skill' }, { label: 'Item' }, { label: 'Defend' },
      { label: 'Flee', disabled: !!this.opts.boss },
    ];
    let start = 0;
    for (;;) {
      $('battle-msg').textContent = `What will ${G.hero.name} do?`;
      const i = await UI.list($('battle-cmds'), cmds, { start, cancel: false, onDisabled: () => this.msg('There is no escaping this fight.', 10) });
      start = i;
      if (i === 0) { const t = await this.chooseTarget(); if (t) return { type: 'attack', target: t }; }
      else if (i === 1) {
        const ids = CLASSES[G.hero.cls].skills.filter(id => SKILLS[id].lv <= G.hero.lv);
        const rows = ids.map(id => ({ label: SKILLS[id].name, right: `${SKILLS[id].mp} MP`, disabled: G.hero.mp < SKILLS[id].mp, id }));
        const j = await this.subList('Skills', rows, it => SKILLS[it.id].desc);
        if (j < 0) continue;
        const sk = SKILLS[ids[j]];
        if (sk.target === 'enemy') { const t = await this.chooseTarget(); if (t) return { type: 'skill', id: ids[j], target: t }; }
        else return { type: 'skill', id: ids[j] };
      } else if (i === 2) {
        const ids = UI.itemRows().filter(id => ITEMS[id].type === 'use' && !ITEMS[id].auto);
        const rows = ids.map(id => ({ label: ITEMS[id].name, right: '×' + G.inv[id], id }));
        const j = await this.subList('Items', rows, it => ITEMS[it.id].desc);
        if (j < 0) continue;
        const it = ITEMS[ids[j]];
        if (it.dmg && !it.dmg.all) { const t = await this.chooseTarget(); if (t) return { type: 'item', id: ids[j], target: t }; }
        else return { type: 'item', id: ids[j] };
      } else if (i === 3) return { type: 'defend' };
      else if (i === 4) return { type: 'flee' };
    }
  },

  // ---------- round ----------
  async round() {
    const u = this.hero;
    let act = null;
    if (u.status.stun) {
      await this.msg(`${G.hero.name} is stunned and can't move!`);
      delete u.status.stun;
      this.renderStatus();
    } else {
      act = await this.chooseAction();
      $('battle-cmds').innerHTML = '';
    }
    if (act && act.type === 'defend') {
      u.defending = true; this.renderStatus();
      Sound.sfx('buff');
      await this.msg(`${G.hero.name} braces for the next blow.`, 600);
    }
    if (act && act.type === 'flee') {
      const avg = this.alive().reduce((s, e) => s + this.eff(e, 'spd'), 0) / this.alive().length;
      const chance = clamp(0.55 + (this.eff(u, 'spd') - avg) * 0.04, 0.25, 0.95);
      if (Math.random() < chance) { Sound.sfx('flee'); await this.msg('You slip away!', 700); return 'flee'; }
      await this.msg('You couldn\'t get away!', 700);
      act = null;
    }

    const order = [u, ...this.alive()].map(x => ({ x, s: this.eff(x, 'spd') * rnd(0.85, 1.15) })).sort((a, b) => b.s - a.s).map(o => o.x);
    for (const actor of order) {
      if (actor.isHero) {
        if (act && act.type !== 'defend') await this.heroAct(act);
      } else if (actor.alive) {
        if (actor.status.stun) { await this.msg(`${actor.name} is stunned!`, 550); delete actor.status.stun; continue; }
        await this.enemyAct(actor);
        if (actor.d.final && actor.enraged && actor.alive && G.hero.hp > 0 && Math.random() < 0.6) await this.enemyAct(actor);
      }
      const end = await this.checkEnd();
      if (end) return end;
    }
    u.defending = false;
    await this.tickStatuses();
    const end = await this.checkEnd();
    this.renderStatus();
    return end;
  },

  async checkEnd() {
    if (G.hero.hp <= 0) {
      if (has('feather')) {
        take('feather');
        const s = Game.stats();
        G.hero.hp = s.mhp; G.hero.mp = s.mmp; this.hero.status = {};
        const c = this.center(this.hero);
        Sound.sfx('heal'); this.burst(c.x, c.y, 'fire', 40);
        this.renderStatus();
        await this.msg('The Phoenix Feather bursts into flame! You rise again!', 1100);
        return null;
      }
      Sound.stopMusic(); Sound.sfx('gameover');
      await this.msg(`${G.hero.name} collapses...`, 1600);
      return 'lose';
    }
    if (this.alive().length === 0) { await this.victory(); return 'win'; }
    return null;
  },

  async victory() {
    const xp = this.enemies.reduce((s, e) => s + e.d.xp, 0);
    const gold = this.enemies.reduce((s, e) => s + e.d.gold, 0);
    G.wins++;
    this.hero.status = {}; this.hero.buffs = [];
    Sound.play('victory');
    await this.msg('Victory!', 900);
    G.gold += gold;
    await this.msg(xp ? `Gained ${xp} XP and ${gold} gold.` : `Gained ${gold} gold.`, 1100);
    for (const e of this.enemies) for (const [id, ch] of e.d.drops || []) {
      if (Math.random() < ch) { give(id); await this.msg(`${e.d.name} dropped ${ITEMS[id].name}.`, 900); }
    }
    for (const m of Game.gainXp(xp)) {
      Sound.sfx('levelup');
      this.renderStatus();
      const c = this.center(this.hero); this.burst(c.x, c.y, 'buff', 26);
      await this.msg(m, 1500);
    }
  },

  async tickStatuses() {
    for (const u of [this.hero, ...this.alive()]) {
      for (const k of ['poison', 'burn']) {
        if (!u.status[k]) continue;
        const max = u.isHero ? Game.stats().mhp : u.mhp;
        const dmg = Math.max(1, Math.round(max * STATUS_INFO[k].tick));
        const c = this.center(u);
        this.burst(c.x, c.y, k === 'burn' ? 'fire' : 'poison', 10);
        Sound.sfx('poison');
        await this.damage(u, dmg, k === 'burn' ? '#ff9a50' : '#d08aff');
        await this.msg(`${u.isHero ? G.hero.name : u.name} takes ${dmg} ${k === 'burn' ? 'burn' : 'poison'} damage.`, 600);
        if (!u.isHero && !u.alive) continue;
      }
      for (const k of ['poison', 'burn', 'slow']) if (u.status[k] && --u.status[k] <= 0) delete u.status[k];
      u.buffs = u.buffs.filter(b => --b.turns > 0);
    }
    this.renderStatus();
  },

  // ---------- resolution ----------
  calc(att, tgt, sk) {
    const power = sk.power || 1;
    let dmg;
    if (sk.kind === 'phys') dmg = this.eff(att, 'atk') * power * 1.25 - this.eff(tgt, 'def') * 0.6;
    else dmg = this.eff(att, 'mag') * power * 1.3 - (this.eff(tgt, 'def') * 0.3 + this.eff(tgt, 'mag') * 0.4);
    dmg = Math.max(1, dmg) * rnd(0.9, 1.1);
    let weak = false, resist = false, crit = false;
    if (sk.elem && !tgt.isHero) {
      if ((tgt.d.weak || []).includes(sk.elem)) { dmg *= 1.5; weak = true; }
      if ((tgt.d.resist || []).includes(sk.elem)) { dmg *= 0.5; resist = true; }
    }
    if (sk.elem === 'fire' && tgt.isHero) dmg *= Game.stats().fireMul;
    if (sk.kind === 'phys') {
      const cc = sk.crit != null ? sk.crit : (att.isHero ? Game.stats().crit : 0.04);
      if (Math.random() < cc) { dmg *= 1.6; crit = true; }
    }
    if (tgt.isHero && tgt.defending) dmg *= 0.5;
    return { dmg: Math.max(1, Math.round(dmg)), weak, resist, crit };
  },

  async damage(u, dmg, color) {
    const c = this.center(u);
    if (u.isHero) {
      G.hero.hp = Math.max(0, G.hero.hp - dmg);
      this.heroFx.flash = 0.3; this.shake = 0.25;
      this.float(c.x, c.y - 10, dmg, color || '#ff8a7a');
      this.renderStatus();
    } else {
      u.hp = Math.max(0, u.hp - dmg);
      u.flash = 0.25; u.shakeT = 0.3;
      this.float(c.x, c.y - 8, dmg, color || '#ffffff');
      if (u.hp <= 0 && u.alive) {
        u.alive = false; u.dying = 1;
        Sound.sfx('die');
        await this.wait(350);
        await this.msg(`${u.name} is defeated!`, 550);
      }
    }
  },

  applyStatus(tgt, st) {
    if (!st || Math.random() > st.chance) return null;
    if (tgt.status[st.id]) return null;
    if (tgt.d && tgt.d.boss && st.id === 'stun') return null;
    tgt.status[st.id] = st.turns;
    return st.id;
  },

  async strike(att, tgt, sk, label) {
    const c = this.center(tgt);
    if (sk.kind === 'phys' && Math.random() < 0.04 + this.eva(tgt)) {
      Sound.sfx('miss');
      this.float(c.x, c.y - 8, 'Miss', '#9ab0d0');
      await this.wait(350);
      return;
    }
    const r = this.calc(att, tgt, sk);
    const elem = sk.elem || 'none';
    if (sk.kind === 'mag') { Sound.sfx(elem === 'fire' ? 'fire' : elem === 'ice' ? 'ice' : 'magic'); this.burst(c.x, c.y, elem, 26); }
    else Sound.sfx(r.crit ? 'crit' : (tgt.isHero ? 'hurt' : 'hit'));
    if (sk.kind === 'phys') this.burst(c.x, c.y, 'none', r.crit ? 16 : 8);
    if (r.crit) this.shake = 0.3;
    await this.damage(tgt, r.dmg, r.crit ? '#ffe05a' : r.weak ? '#8ae0ff' : null);
    if (r.crit) await this.msg('A critical hit!', 450);
    if (r.weak) await this.msg('It\'s super effective!', 450);
    if (r.resist) await this.msg('It resists.', 400);
    if (sk.drain && !att.isHero) {
      const heal = Math.round(r.dmg * sk.drain);
      att.hp = Math.min(att.mhp, att.hp + heal);
      const ac = this.center(att); this.float(ac.x, ac.y - 8, '+' + heal, '#8aff8a');
    }
    const alive = tgt.isHero ? G.hero.hp > 0 : tgt.alive;
    if (alive) {
      let st = sk.status;
      if (!st && att.isHero && sk.kind === 'phys' && Game.stats().poison) st = { id: 'poison', chance: Game.stats().poison, turns: 3 };
      const got = this.applyStatus(tgt, st);
      if (got) { Sound.sfx('poison'); this.renderStatus(); await this.msg(`${tgt.isHero ? G.hero.name : tgt.name} is ${{ poison: 'poisoned', burn: 'burning', slow: 'slowed', stun: 'stunned' }[got]}!`, 600); }
    }
  },

  async heroAct(act) {
    const h = G.hero, u = this.hero;
    const retarget = t => (t && t.alive) ? t : this.alive()[0];
    if (act.type === 'attack') {
      const t = retarget(act.target);
      if (!t) return;
      this.heroFx.lunge = 0.3;
      await this.msg(`${h.name} attacks!`, 300);
      await this.strike(u, t, { kind: 'phys', power: 1 });
      return;
    }
    if (act.type === 'skill') {
      const sk = SKILLS[act.id];
      if (h.mp < sk.mp) { await this.msg('Not enough MP!'); return; }
      h.mp -= sk.mp;
      this.renderStatus();
      await this.msg(`${h.name} uses ${sk.name}!`, 450);
      if (sk.heal) {
        const s = Game.stats();
        const amt = sk.heal.pct ? Math.round(s.mhp * sk.heal.pct) : Math.round(this.eff(u, 'mag') * sk.heal.mag + sk.heal.flat);
        const before = h.hp; h.hp = Math.min(s.mhp, h.hp + amt);
        if (sk.cure) u.status = {};
        const c = this.center(u); this.burst(c.x, c.y, 'heal', 24); this.float(c.x, c.y - 10, '+' + (h.hp - before), '#8aff8a');
        Sound.sfx('heal'); this.renderStatus();
        await this.wait(500);
        return;
      }
      if (sk.buff) {
        u.buffs = u.buffs.filter(b => b.stat !== sk.buff.stat);
        u.buffs.push({ ...sk.buff });
        const c = this.center(u); this.burst(c.x, c.y, 'buff', 22);
        Sound.sfx('buff'); this.renderStatus();
        await this.wait(500);
        return;
      }
      if (sk.kind === 'phys') this.heroFx.lunge = 0.3;
      if (sk.target === 'all') {
        for (const t of this.alive()) await this.strike(u, t, sk);
      } else if (sk.target === 'random') {
        for (let i = 0; i < (sk.hits || 1); i++) { const al = this.alive(); if (!al.length) break; this.heroFx.lunge = 0.2; await this.strike(u, pick(al), sk); await this.wait(120); }
      } else {
        for (let i = 0; i < (sk.hits || 1); i++) {
          const t = retarget(act.target); if (!t) break;
          if (i) { this.heroFx.lunge = 0.2; await this.wait(150); }
          await this.strike(u, t, sk);
        }
      }
      return;
    }
    if (act.type === 'item') {
      const it = ITEMS[act.id];
      if (!has(act.id)) return;
      take(act.id);
      await this.msg(`${h.name} uses ${it.name}.`, 450);
      const s = Game.stats(), c = this.center(u);
      if (it.heal) { const b = h.hp; h.hp = Math.min(s.mhp, h.hp + it.heal); this.burst(c.x, c.y, 'heal', 20); this.float(c.x, c.y - 10, '+' + (h.hp - b), '#8aff8a'); Sound.sfx('heal'); }
      if (it.mp) { const b = h.mp; h.mp = Math.min(s.mmp, h.mp + it.mp); this.burst(c.x, c.y, 'buff', 16); this.float(c.x, c.y - 10, '+' + (h.mp - b) + ' MP', '#8ac4ff'); Sound.sfx('heal'); }
      if (it.cure) { u.status = {}; this.burst(c.x, c.y, 'heal', 12); Sound.sfx('heal'); }
      if (it.dmg) {
        const targets = it.dmg.all ? this.alive() : [retarget(act.target)].filter(Boolean);
        for (const t of targets) {
          let d = it.dmg.amt * rnd(0.9, 1.1);
          if ((t.d.weak || []).includes(it.dmg.elem)) d *= 1.5;
          if ((t.d.resist || []).includes(it.dmg.elem)) d *= 0.5;
          const tc = this.center(t);
          this.burst(tc.x, tc.y, it.dmg.elem, 24);
          Sound.sfx(it.dmg.elem === 'ice' ? 'ice' : 'fire');
          await this.damage(t, Math.round(d), (t.d.weak || []).includes(it.dmg.elem) ? '#8ae0ff' : null);
          await this.wait(200);
        }
      }
      this.renderStatus();
      await this.wait(400);
    }
  },

  async enemyAct(e) {
    const d = e.d;
    if (d.final && !e.enraged && e.hp < e.mhp * 0.5) {
      e.enraged = true;
      this.shake = 0.6;
      Sound.sfx('fire');
      const c = this.center(e); this.burst(c.x, c.y, 'fire', 50);
      await this.msg('The Ember Wyrm\'s scales blaze white-hot! It strikes faster now!', 1200);
    }
    let id = weighted(d.ai);
    let sk = EN_SKILLS[id];
    if (sk.self && e.buffs.some(b => b.stat === sk.buff.stat)) { id = 'attack'; sk = EN_SKILLS.attack; }
    if (sk.debuff && this.hero.buffs.some(b => b.stat === sk.debuff.stat && b.mult < 1)) { id = 'attack'; sk = EN_SKILLS.attack; }
    const u = this.hero;
    e.lunge = 0.3;
    await this.msg(id === 'attack' ? `${e.name} attacks!` : `${e.name} uses ${sk.name}!`, 450);
    if (sk.self) {
      e.buffs.push({ ...sk.buff });
      const c = this.center(e); this.burst(c.x, c.y, 'buff', 20); Sound.sfx('buff');
      await this.wait(400);
      return;
    }
    if (sk.debuff) {
      u.buffs = u.buffs.filter(b => b.stat !== sk.debuff.stat);
      u.buffs.push({ ...sk.debuff });
      Sound.sfx('poison'); this.renderStatus();
      await this.msg(`${G.hero.name}'s ${sk.debuff.stat.toUpperCase()} fell!`, 600);
      return;
    }
    await this.strike(e, u, sk);
  },

  // ---------- rendering ----------
  update(dt) {
    this.t += dt;
    this.intro = Math.max(0, this.intro - dt * 1.8);
    this.shake = Math.max(0, this.shake - dt);
    this.heroFx.lunge = Math.max(0, this.heroFx.lunge - dt);
    this.heroFx.flash = Math.max(0, this.heroFx.flash - dt);
    for (const e of this.enemies) {
      e.flash = Math.max(0, e.flash - dt); e.shakeT = Math.max(0, e.shakeT - dt); e.lunge = Math.max(0, e.lunge - dt);
      if (!e.alive) e.dying = Math.max(0, e.dying - dt * 1.6);
    }
    for (const f of this.floaters) f.t += dt;
    this.floaters = this.floaters.filter(f => f.t < 1);
    for (const p of this.parts) { p.t += dt; p.x += p.vx * dt; p.y += p.vy * dt; p.vy += 40 * dt; }
    this.parts = this.parts.filter(p => p.t < p.life);
  },

  drawBackdrop(ctx) {
    const W = 240, H = 176, hz = 72, th = this.theme;
    const sky = { field: ['#1c2850', '#6a5a8a'], town: ['#1c2850', '#6a5a8a'], woods: ['#07140f', '#1c3a2c'], cave: ['#120806', '#3a1408'] }[th] || ['#1c2850', '#6a5a8a'];
    let g = ctx.createLinearGradient(0, 0, 0, hz);
    g.addColorStop(0, sky[0]); g.addColorStop(1, sky[1]);
    ctx.fillStyle = g; ctx.fillRect(0, 0, W, hz);
    if (th === 'cave') {
      ctx.fillStyle = '#1e1210';
      for (let i = 0; i < 12; i++) { const x = i * 22 + 6, l = 10 + (i * 37 % 23); ctx.beginPath(); ctx.moveTo(x - 7, 0); ctx.lineTo(x + 7, 0); ctx.lineTo(x, l); ctx.fill(); }
      g = ctx.createLinearGradient(0, hz, 0, H);
      g.addColorStop(0, '#3a1c12'); g.addColorStop(1, '#1a0c08');
      ctx.fillStyle = g; ctx.fillRect(0, hz, W, H - hz);
      ctx.strokeStyle = `rgba(255,${110 + Math.sin(this.t * 3) * 30 | 0},30,0.7)`; ctx.lineWidth = 1;
      ctx.beginPath(); ctx.moveTo(0, 110); ctx.lineTo(40, 104); ctx.lineTo(70, 112); ctx.lineTo(120, 106); ctx.lineTo(170, 114); ctx.lineTo(240, 104); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(10, 90); ctx.lineTo(50, 86); ctx.lineTo(80, 92); ctx.stroke();
    } else if (th === 'woods') {
      for (let layer = 0; layer < 2; layer++) {
        ctx.fillStyle = layer ? '#0a1a12' : '#12291c';
        for (let i = -1; i < 14; i++) {
          const x = i * 20 + (layer ? 10 : 0), h = 40 + ((i * 53 + layer * 17) % 25);
          ctx.beginPath(); ctx.moveTo(x, hz + 4); ctx.lineTo(x + 10, hz - h + layer * 12); ctx.lineTo(x + 20, hz + 4); ctx.fill();
        }
      }
      ctx.fillStyle = '#1c3a24'; ctx.fillRect(0, hz, W, H - hz);
      ctx.fillStyle = '#244a2c'; for (let i = 0; i < 40; i++) ctx.fillRect((i * 67) % W, hz + 4 + (i * 29) % 90, 3, 1);
    } else {
      ctx.fillStyle = 'rgba(255,255,255,0.6)';
      for (let i = 0; i < 20; i++) ctx.fillRect((i * 97) % W, (i * 31) % 50, 1, 1);
      ctx.fillStyle = '#2a2e48';
      ctx.beginPath(); ctx.moveTo(0, hz); for (let x = 0; x <= W; x += 20) ctx.lineTo(x, hz - 10 - ((x * 7) % 18)); ctx.lineTo(W, hz); ctx.fill();
      g = ctx.createLinearGradient(0, hz, 0, H);
      g.addColorStop(0, '#3a6a3a'); g.addColorStop(1, '#244a26');
      ctx.fillStyle = g; ctx.fillRect(0, hz, W, H - hz);
      ctx.fillStyle = '#4a7a44'; for (let i = 0; i < 40; i++) ctx.fillRect((i * 67) % W, hz + 4 + (i * 29) % 90, 2, 1);
      if (!flag('ending')) {
        ctx.fillStyle = 'rgba(235,242,255,0.7)';
        for (let i = 0; i < 30; i++) ctx.fillRect((i * 83 + Math.sin(this.t + i) * 6 + 400) % W, (i * 41 + this.t * 16 * (0.5 + (i % 3) * 0.3)) % H, 1, 1);
      }
    }
  },

  render(ctx) {
    ctx.save();
    if (this.shake > 0) ctx.translate(rnd(-2, 2) * this.shake * 6, rnd(-2, 2) * this.shake * 4);
    this.drawBackdrop(ctx);
    // enemies
    this.enemies.forEach((e, i) => {
      if (!e.alive && e.dying <= 0) return;
      const size = 16 * e.scale;
      const bob = e.alive ? Math.sin(this.t * 2.2 + i * 1.7) * 1.2 : 0;
      const sx = e.x - size / 2 + (e.shakeT > 0 ? Math.sin(e.shakeT * 60) * 2 : 0) + (e.lunge > 0 ? Math.sin(e.lunge / 0.3 * Math.PI) * 10 : 0);
      const sy = e.y - size + bob - (e.alive ? 0 : (1 - e.dying) * 10);
      ctx.fillStyle = 'rgba(0,0,0,0.35)';
      ctx.beginPath(); ctx.ellipse(e.x, e.y - 1, size * 0.38, size * 0.09, 0, 0, Math.PI * 2); ctx.fill();
      ctx.globalAlpha = e.alive ? 1 : e.dying;
      const tint = e.flash > 0 && Math.floor(e.flash * 30) % 2 === 0 ? '#ffffff' : (!e.alive ? '#ff6040' : (e.enraged && Math.floor(this.t * 6) % 2 ? '#fff0c0' : null));
      ctx.drawImage(Gfx.sprite(e.d.sprite, e.d.pal, false, tint), sx, sy, size, size);
      ctx.globalAlpha = 1;
      // HP pip under each enemy
      if (e.alive) {
        const w = Math.min(40, size * 0.8);
        ctx.fillStyle = 'rgba(0,0,0,0.6)'; ctx.fillRect(e.x - w / 2 - 1, e.y + 2, w + 2, 3);
        ctx.fillStyle = e.hp / e.mhp > 0.5 ? '#72c774' : e.hp / e.mhp > 0.25 ? '#e9c24b' : '#de4a3c';
        ctx.fillRect(e.x - w / 2, e.y + 3, w * (e.hp / e.mhp), 1);
      }
      if (this.cursor === i && e.alive) {
        const cy = sy - 6 + Math.sin(this.t * 8) * 1.5;
        ctx.fillStyle = '#f2a43a';
        ctx.beginPath(); ctx.moveTo(e.x - 4, cy - 4); ctx.lineTo(e.x + 4, cy - 4); ctx.lineTo(e.x, cy + 1); ctx.fill();
      }
    });
    // hero
    const hx = 180 - Math.sin(this.heroFx.lunge / 0.3 * Math.PI) * 14, hy = 98 - 32;
    ctx.fillStyle = 'rgba(0,0,0,0.35)';
    ctx.beginPath(); ctx.ellipse(196, 97, 11, 3, 0, 0, Math.PI * 2); ctx.fill();
    const flash = this.heroFx.flash > 0 && Math.floor(this.heroFx.flash * 30) % 2 === 0;
    const pal = CLASSES[G.hero.cls].pal;
    const img = flash ? Gfx.sprite('side', pal, true, '#ffffff') : Gfx.person(pal, G.hero.hp <= 0 ? 'down' : 'left');
    ctx.drawImage(img, hx, hy + Math.sin(this.t * 2) * 0.8, 32, 32);
    if (this.hero.defending) {
      ctx.strokeStyle = `rgba(140,200,255,${0.5 + Math.sin(this.t * 6) * 0.2})`; ctx.lineWidth = 1;
      ctx.beginPath(); ctx.arc(196, 82, 18, 0, Math.PI * 2); ctx.stroke();
    }
    // particles
    for (const p of this.parts) {
      ctx.globalAlpha = 1 - p.t / p.life;
      ctx.fillStyle = p.c; ctx.fillRect(p.x, p.y, p.s, p.s);
    }
    ctx.globalAlpha = 1;
    // floaters
    ctx.font = '600 11px "Pixelify Sans", monospace';
    ctx.textAlign = 'center';
    for (const f of this.floaters) {
      const y = f.y - f.t * 18 - (f.t < 0.15 ? (0.15 - f.t) * 30 : 0);
      ctx.globalAlpha = f.t > 0.7 ? (1 - f.t) / 0.3 : 1;
      ctx.lineWidth = 3; ctx.strokeStyle = '#0a0a12'; ctx.strokeText(f.text, f.x, y);
      ctx.fillStyle = f.color; ctx.fillText(f.text, f.x, y);
    }
    ctx.globalAlpha = 1;
    ctx.restore();
    // intro wipe
    if (this.intro > 0) {
      const k = this.intro;
      ctx.fillStyle = '#000';
      for (let i = 0; i < 11; i++) {
        const w = 240 * Math.min(1, k * 1.3 - i * 0.02);
        if (w <= 0) continue;
        if (i % 2) ctx.fillRect(0, i * 16, w, 16); else ctx.fillRect(240 - w, i * 16, w, 16);
      }
    }
  },
};

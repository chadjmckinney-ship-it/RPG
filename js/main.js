'use strict';
// Boot, main loop, keyboard/touch wiring, title-screen scene.

(function () {
  const cv = $('cv');
  const ctx = cv.getContext('2d');
  cv.width = VW * TS * SCALE; cv.height = VH * TS * SCALE;

  // ---------- Keyboard ----------
  const KEYMAP = {
    ArrowUp: 'up', KeyW: 'up', ArrowDown: 'down', KeyS: 'down', ArrowLeft: 'left', KeyA: 'left', ArrowRight: 'right', KeyD: 'right',
    Enter: 'a', Space: 'a', KeyZ: 'a', Escape: 'b', KeyX: 'b', Backspace: 'b', KeyM: 'menu',
  };
  const isDir = k => k === 'up' || k === 'down' || k === 'left' || k === 'right';
  let helpOpen = false;

  window.addEventListener('keydown', e => {
    const typing = e.target && e.target.tagName === 'INPUT';
    const k = KEYMAP[e.code];
    if (helpOpen) { e.preventDefault(); toggleHelp(false); return; }
    if (!k) return;
    if (typing && !(k === 'a' && e.code === 'Enter') && !(k === 'b' && e.code === 'Escape')) return;
    e.preventDefault();
    if (isDir(k)) {
      if (!Input.held[k]) Input.hold(k, true);
      Input.press(k);
    } else if (!e.repeat) {
      Input.press(k);
    }
  });
  window.addEventListener('keyup', e => {
    const k = KEYMAP[e.code];
    if (k && isDir(k)) Input.hold(k, false);
  });
  window.addEventListener('blur', () => Input.clear());

  // ---------- Touch pad ----------
  document.querySelectorAll('.touch button').forEach(b => {
    const k = b.dataset.k;
    const down = e => {
      e.preventDefault();
      b.setPointerCapture && b.setPointerCapture(e.pointerId);
      b.classList.add('on');
      if (isDir(k)) Input.hold(k, true);
      Input.press(k);
      if (isDir(k)) startRepeat(k);
    };
    const up = e => {
      e.preventDefault();
      b.classList.remove('on');
      if (isDir(k)) { Input.hold(k, false); stopRepeat(k); }
    };
    b.addEventListener('pointerdown', down);
    b.addEventListener('pointerup', up);
    b.addEventListener('pointercancel', up);
    b.addEventListener('contextmenu', e => e.preventDefault());
  });
  // Held d-pad repeats menu navigation
  const repeats = {};
  function startRepeat(k) {
    stopRepeat(k);
    repeats[k] = setTimeout(function tick() {
      if (Input.top() !== Game.worldKey) Input.press(k);
      repeats[k] = setTimeout(tick, 110);
    }, 380);
  }
  function stopRepeat(k) { clearTimeout(repeats[k]); delete repeats[k]; }

  // Canvas taps pick battle targets
  cv.addEventListener('click', e => {
    const r = cv.getBoundingClientRect();
    const lx = (e.clientX - r.left) / r.width * VW * TS, ly = (e.clientY - r.top) / r.height * VH * TS;
    if (Battle.active) Battle.onCanvasClick(lx, ly);
  });

  // ---------- Top bar ----------
  const soundBtn = $('btn-sound');
  let soundOn = false;
  try { soundOn = localStorage.getItem('emberfall.sound') === '1'; } catch (e) { /* storage blocked */ }
  const paintSound = () => { soundBtn.textContent = soundOn ? 'Sound on' : 'Sound off'; soundBtn.setAttribute('aria-pressed', String(soundOn)); };
  paintSound();
  soundBtn.addEventListener('click', () => {
    soundOn = !soundOn;
    Sound.setEnabled(soundOn);
    try { localStorage.setItem('emberfall.sound', soundOn ? '1' : '0'); } catch (e) { /* storage blocked */ }
    paintSound();
    soundBtn.blur();
  });
  // Browsers only allow audio after a gesture: arm it on the first one.
  const arm = () => { if (soundOn && !Sound.enabled) Sound.setEnabled(true); window.removeEventListener('pointerdown', arm); window.removeEventListener('keydown', arm); };
  window.addEventListener('pointerdown', arm);
  window.addEventListener('keydown', arm);

  function toggleHelp(on) { helpOpen = on; UI.help(on); Input.clear(); }
  $('btn-help').addEventListener('click', e => { e.stopPropagation(); toggleHelp(!helpOpen); $('btn-help').blur(); });
  $('help').addEventListener('click', () => toggleHelp(false));

  // ---------- Title scene ----------
  const embers = Array.from({ length: 70 }, () => ({ x: Math.random() * 240, y: Math.random() * 176, s: rnd(0.3, 1), ph: Math.random() * 6 }));
  function renderTitle(t) {
    const W = 240, H = 176;
    let g = ctx.createLinearGradient(0, 0, 0, H);
    g.addColorStop(0, '#0b0a1c'); g.addColorStop(0.55, '#2a1630'); g.addColorStop(0.8, '#6a2a1c'); g.addColorStop(1, '#1a0c0a');
    ctx.fillStyle = g; ctx.fillRect(0, 0, W, H);
    ctx.fillStyle = 'rgba(255,255,255,0.7)';
    for (let i = 0; i < 40; i++) { const tw = (Math.sin(t * 2 + i) + 1) / 2; ctx.globalAlpha = 0.3 + tw * 0.6; ctx.fillRect((i * 97) % W, (i * 53) % 80, 1, 1); }
    ctx.globalAlpha = 1;
    // mountains
    ctx.fillStyle = '#1a1024';
    ctx.beginPath(); ctx.moveTo(0, 130);
    [[0, 110], [30, 86], [55, 100], [85, 70], [110, 92], [140, 78], [170, 98], [200, 74], [240, 104], [240, 130]].forEach(([x, y]) => ctx.lineTo(x, y));
    ctx.fill();
    // volcano glow
    const vg = ctx.createRadialGradient(200, 74, 2, 200, 74, 40);
    vg.addColorStop(0, 'rgba(255,120,40,0.55)'); vg.addColorStop(1, 'rgba(255,120,40,0)');
    ctx.fillStyle = vg; ctx.fillRect(150, 30, 100, 90);
    // village
    ctx.fillStyle = '#0e0a12';
    ctx.fillRect(0, 128, W, 48);
    const houses = [[20, 118, 22], [52, 122, 18], [150, 116, 26], [190, 121, 20]];
    for (const [x, y, w] of houses) {
      ctx.fillRect(x, y, w, 12);
      ctx.beginPath(); ctx.moveTo(x - 3, y); ctx.lineTo(x + w / 2, y - 10); ctx.lineTo(x + w + 3, y); ctx.fill();
      ctx.fillStyle = '#2a3450'; ctx.fillRect(x + 4, y + 4, 3, 3); ctx.fillStyle = '#0e0a12';
    }
    // pines
    for (let i = 0; i < 9; i++) {
      const x = 80 + i * 8, h = 14 + (i * 7) % 9;
      ctx.beginPath(); ctx.moveTo(x - 5, 130); ctx.lineTo(x, 130 - h); ctx.lineTo(x + 5, 130); ctx.fill();
    }
    // embers drifting up from the Hollow
    for (const e of embers) {
      const y = (e.y - t * 12 * e.s + H * 10) % H;
      const x = e.x + Math.sin(t + e.ph) * 6 * e.s;
      ctx.globalAlpha = 0.25 + e.s * 0.6;
      ctx.fillStyle = e.s > 0.7 ? '#ffd070' : '#ff7a30';
      ctx.fillRect(x, y, e.s > 0.8 ? 1.5 : 1, e.s > 0.8 ? 1.5 : 1);
    }
    ctx.globalAlpha = 1;
  }

  // ---------- Loop ----------
  let last = performance.now();
  function frame(now) {
    const dt = Math.min(0.05, (now - last) / 1000);
    last = now;
    ctx.setTransform(SCALE, 0, 0, SCALE, 0, 0);
    ctx.imageSmoothingEnabled = false;
    if (Game.mode === 'title') {
      Game.clock += dt;
      renderTitle(Game.clock);
    } else if (Battle.active) {
      Game.update(dt);
      Battle.update(dt);
      Battle.render(ctx);
    } else if (Game.map) {
      Game.update(dt);
      Game.render(ctx);
    }
    requestAnimationFrame(frame);
  }

  async function boot(data) {
    Gfx.buildTiles();
    requestAnimationFrame(frame);
    // Resume straight into the world after a live code update
    if (data && data.state && data.state.hero && CLASSES[data.state.hero.cls] && MAPS[data.state.map]) {
      Game.start(data.state, false);
      return;
    }
    Game.mode = 'title';
    Sound.play('title');
    const save = Game.readSave();
    const choice = await UI.title(!!save);
    await Game.fadeOut();
    if (choice.action === 'continue' && save) Game.start(save, false);
    else Game.start(Game.newState(choice.name, choice.cls), true);
    if (soundOn && Sound.enabled) Sound.play(Game.map.music);
  }

  const hot = window.claude && window.claude.hot;
  if (hot && typeof hot.snapshot === 'function') {
    try { hot.snapshot(() => Game.snapshot()); } catch (e) { /* hot reload unavailable */ }
  }
  const go = data => { (document.fonts && document.fonts.ready ? document.fonts.ready : Promise.resolve()).then(() => boot(data)); };
  if (hot && typeof hot.ready === 'function') hot.ready(go);
  else go(hot && hot.data ? hot.data : {});
})();

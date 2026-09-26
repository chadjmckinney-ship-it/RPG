'use strict';
// Tiny WebAudio chiptune player. Tracks are eighth-note steps; '-' holds silence.

const NOTE = (() => {
  const names = { C: 0, 'C#': 1, D: 2, 'D#': 3, E: 4, F: 5, 'F#': 6, G: 7, 'G#': 8, A: 9, 'A#': 10, B: 11 };
  return n => {
    const m = /^([A-G]#?)(\d)$/.exec(n);
    if (!m) return 0;
    return 440 * Math.pow(2, (names[m[1]] + (+m[2] + 1) * 12 - 69) / 12);
  };
})();

const TRACKS = {
  title: { bpm: 84, wave: 'triangle',
    lead: 'E4 - G4 - A4 - B4 - A4 - G4 - E4 - - - D4 - E4 - G4 - E4 - D4 - B3 - - - C4 - E4 - G4 - C5 - B4 - G4 - A4 - - - G4 - E4 - D4 - E4 - - - - - - -',
    bass: 'E2 - - - B2 - - - C3 - - - G2 - - - G2 - - - D3 - - - E2 - - - B2 - - - C3 - - - G2 - - - A2 - - - E2 - - - C3 - - - D3 - - - E2 - - - - - - -' },
  town: { bpm: 100, wave: 'triangle',
    lead: 'G4 - B4 - D5 - B4 - C5 - A4 - - - F#4 - A4 - C5 - A4 - B4 - G4 - - - E4 - G4 - B4 - G4 - A4 - F#4 - D4 - - - G4 - F#4 - G4 - - - - -',
    bass: 'G2 - D3 - G2 - D3 - A2 - E3 - A2 - E3 - D2 - A2 - D2 - A2 - G2 - D3 - G2 - D3 - C3 - G3 - C3 - G3 - D3 - A3 - D3 - A3 - G2 - D3 - G2 - - - - -' },
  field: { bpm: 128, wave: 'square',
    lead: 'A4 - C5 E5 - D5 C5 - B4 - G4 - A4 - - - C5 - E5 G5 - F5 E5 - D5 - B4 - C5 - - - A4 - C5 E5 - A5 G5 - E5 - D5 - C5 - B4 - G4 - B4 - C5 - A4 - - - - - - -',
    bass: 'A2 - A3 - A2 - A3 - G2 - G3 - G2 - G3 - F2 - F3 - F2 - F3 - E2 - E3 - E2 - E3 - A2 - A3 - A2 - A3 - F2 - F3 - G2 - G3 - E2 - E3 - E2 - E3 - A2 - - - - - - -' },
  woods: { bpm: 96, wave: 'triangle',
    lead: 'D4 - F4 - A4 - - G4 F4 - E4 - D4 - - - C4 - E4 - G4 - - F4 E4 - D4 - C#4 - - - D4 - F4 - A4 - D5 - C5 A4 - G4 - F4 - E4 - F4 - D4 - - - - - - -',
    bass: 'D2 - - - A2 - - - D2 - - - A2 - - - C2 - - - G2 - - - A2 - - - E2 - - - D2 - - - A2 - - - Bb2 - - - F2 - - - A2 - - - A2 - - - D2 - - - - - - -' },
  cave: { bpm: 76, wave: 'triangle',
    lead: 'E4 - - - F4 - - - E4 - - - - - - - D#4 - - - E4 - - - B3 - - - - - - - C4 - - - B3 - - - A3 - - - B3 - - - E4 - - - D#4 - - - E4 - - - - - - -',
    bass: 'E2 - E2 - E2 - E2 - F2 - F2 - F2 - F2 - E2 - E2 - E2 - E2 - B1 - B1 - B1 - B1 - C2 - C2 - C2 - C2 - A1 - A1 - B1 - B1 - E2 - E2 - E2 - - - - - -' },
  battle: { bpm: 150, wave: 'square',
    lead: 'E5 D5 E5 - B4 - G4 A4 B4 - - - E4 G4 A4 B4 C5 B4 C5 - G4 - E4 F#4 G4 - - - D5 C5 B4 A4 G4 - A4 B4 E5 - D5 - C5 - B4 - A4 - B4 - G4 - E4 - - -',
    bass: 'E2 E3 E2 E3 E2 E3 E2 E3 C2 C3 C2 C3 C2 C3 C2 C3 A1 A2 A1 A2 A1 A2 A1 A2 B1 B2 B1 B2 B1 B2 B1 B2 E2 E3 E2 E3 C2 C3 C2 C3 D2 D3 D2 D3 B1 B2 B1 B2' },
  boss: { bpm: 164, wave: 'sawtooth',
    lead: 'E4 - E5 - D5 - C5 - B4 - C5 - B4 A4 G#4 - A4 - - - E4 - B4 - C5 - D5 - E5 - F5 - E5 D5 C5 - B4 - - - F4 - A4 - C5 - F5 - E5 - C5 - A4 - G#4 - B4 - E5 - D5 - B4 - G#4 - E4 - - -',
    bass: 'A1 A2 A1 A2 A1 A2 A1 A2 E1 E2 E1 E2 E1 E2 E1 E2 A1 A2 A1 A2 G1 G2 G1 G2 E1 E2 E1 E2 E1 E2 E1 E2 F1 F2 F1 F2 F1 F2 F1 F2 E1 E2 E1 E2 E1 E2 E1 E2 E1 E2 E1 E2 E1 E2 E1 E2 E1 E2 E1 E2 E1 E2 E1 E2' },
  victory: { bpm: 150, wave: 'square', once: true,
    lead: 'C5 C5 C5 - C5 - G#4 - A#4 - C5 - A#4 C5 - - - - - -',
    bass: 'C3 - - - C3 - G#2 - A#2 - C3 - - - - - - - - -' },
  ending: { bpm: 90, wave: 'triangle',
    lead: 'C5 - E5 - G5 - E5 - F5 - A5 - G5 - - - E5 - C5 - D5 - E5 - F5 - D5 - C5 - - - A4 - C5 - F5 - E5 - D5 - C5 - B4 - G4 - C5 - - - - - - -',
    bass: 'C3 - G3 - C3 - G3 - F2 - C3 - F2 - C3 - A2 - E3 - A2 - E3 - G2 - D3 - G2 - D3 - F2 - C3 - F2 - C3 - G2 - D3 - G2 - D3 - C3 - G3 - C3 - - - - - -' },
};

const Sound = {
  ctx: null, master: null, musicGain: null, sfxGain: null,
  enabled: false, current: null, step: 0, nextTime: 0, timer: null,

  init() {
    if (this.ctx) return;
    const AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return;
    this.ctx = new AC();
    this.master = this.ctx.createGain(); this.master.gain.value = 0.5; this.master.connect(this.ctx.destination);
    this.musicGain = this.ctx.createGain(); this.musicGain.gain.value = 0.16; this.musicGain.connect(this.master);
    this.sfxGain = this.ctx.createGain(); this.sfxGain.gain.value = 0.35; this.sfxGain.connect(this.master);
  },

  setEnabled(on) {
    this.enabled = on;
    if (on) {
      this.init();
      if (!this.ctx) return;
      this.ctx.resume();
      const t = this.current; this.current = null;
      if (t) this.play(t);
    } else if (this.ctx) {
      this.stopMusic(true);
      this.ctx.suspend();
    }
  },

  tone(freq, t, dur, wave, gain, dest, slide = 0) {
    const o = this.ctx.createOscillator(), g = this.ctx.createGain();
    o.type = wave; o.frequency.setValueAtTime(freq, t);
    if (slide) o.frequency.exponentialRampToValueAtTime(Math.max(30, freq * slide), t + dur);
    g.gain.setValueAtTime(0.0001, t);
    g.gain.exponentialRampToValueAtTime(gain, t + 0.01);
    g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    o.connect(g); g.connect(dest);
    o.start(t); o.stop(t + dur + 0.02);
  },

  noise(t, dur, gain, hp = 800) {
    const len = Math.max(1, Math.floor(this.ctx.sampleRate * dur));
    const buf = this.ctx.createBuffer(1, len, this.ctx.sampleRate);
    const d = buf.getChannelData(0);
    for (let i = 0; i < len; i++) d[i] = (Math.random() * 2 - 1) * (1 - i / len);
    const s = this.ctx.createBufferSource(); s.buffer = buf;
    const f = this.ctx.createBiquadFilter(); f.type = 'highpass'; f.frequency.value = hp;
    const g = this.ctx.createGain(); g.gain.value = gain;
    s.connect(f); f.connect(g); g.connect(this.sfxGain);
    s.start(t);
  },

  play(name) {
    if (this.current === name && this.timer) return;
    this.stopMusic();
    this.current = name;
    if (!this.enabled || !this.ctx) return;
    const tr = TRACKS[name];
    if (!tr) return;
    const lead = tr.lead.split(/\s+/), bass = tr.bass.split(/\s+/);
    const len = Math.max(lead.length, bass.length);
    const stepDur = 60 / tr.bpm / 2;
    this.step = 0;
    this.nextTime = this.ctx.currentTime + 0.05;
    this.timer = setInterval(() => {
      while (this.nextTime < this.ctx.currentTime + 0.2) {
        const i = this.step % len;
        if (tr.once && this.step >= len) { this.stopMusic(); return; }
        const l = lead[i % lead.length], b = bass[i % bass.length];
        if (l && l !== '-') this.tone(NOTE(l), this.nextTime, stepDur * 1.6, tr.wave, 0.5, this.musicGain);
        if (b && b !== '-') this.tone(NOTE(b.replace('Bb', 'A#')), this.nextTime, stepDur * 1.8, 'triangle', 0.7, this.musicGain);
        this.nextTime += stepDur;
        this.step++;
      }
    }, 50);
  },

  stopMusic(keepName) {
    if (this.timer) clearInterval(this.timer);
    this.timer = null;
    if (!keepName) this.current = null;
  },

  sfx(name) {
    if (!this.enabled || !this.ctx) return;
    const t = this.ctx.currentTime, G = this.sfxGain;
    switch (name) {
      case 'blip': this.tone(880, t, 0.04, 'square', 0.25, G); break;
      case 'select': this.tone(660, t, 0.05, 'square', 0.3, G); this.tone(990, t + 0.05, 0.07, 'square', 0.3, G); break;
      case 'cancel': this.tone(440, t, 0.06, 'square', 0.3, G); this.tone(330, t + 0.06, 0.08, 'square', 0.3, G); break;
      case 'bump': this.tone(110, t, 0.06, 'square', 0.3, G); break;
      case 'talk': this.tone(520 + Math.random() * 80, t, 0.025, 'square', 0.12, G); break;
      case 'hit': this.noise(t, 0.12, 0.8, 600); this.tone(180, t, 0.1, 'square', 0.4, G, 0.5); break;
      case 'crit': this.noise(t, 0.2, 1, 400); this.tone(300, t, 0.2, 'sawtooth', 0.5, G, 0.3); break;
      case 'miss': this.tone(700, t, 0.12, 'sine', 0.2, G, 1.6); break;
      case 'hurt': this.noise(t, 0.18, 0.9, 200); this.tone(120, t, 0.18, 'sawtooth', 0.4, G, 0.5); break;
      case 'fire': this.noise(t, 0.4, 0.6, 300); this.tone(220, t, 0.35, 'sawtooth', 0.25, G, 2); break;
      case 'ice': for (let i = 0; i < 4; i++) this.tone(1400 + i * 300, t + i * 0.04, 0.12, 'sine', 0.25, G); break;
      case 'magic': this.tone(500, t, 0.3, 'sine', 0.3, G, 3); this.tone(750, t + 0.05, 0.3, 'triangle', 0.2, G, 2); break;
      case 'heal': [523, 659, 784, 1046].forEach((f, i) => this.tone(f, t + i * 0.06, 0.18, 'triangle', 0.3, G)); break;
      case 'buff': this.tone(400, t, 0.25, 'square', 0.2, G, 2); break;
      case 'poison': this.tone(300, t, 0.2, 'sawtooth', 0.2, G, 0.7); break;
      case 'chest': [392, 523, 659, 784].forEach((f, i) => this.tone(f, t + i * 0.07, 0.15, 'square', 0.25, G)); break;
      case 'door': this.noise(t, 0.08, 0.4, 1500); this.tone(160, t, 0.08, 'square', 0.3, G); break;
      case 'buy': this.tone(1318, t, 0.06, 'square', 0.25, G); this.tone(1760, t + 0.06, 0.12, 'square', 0.25, G); break;
      case 'encounter': for (let i = 0; i < 6; i++) this.tone(300 + i * 120, t + i * 0.04, 0.06, 'square', 0.3, G); break;
      case 'levelup': [523, 659, 784, 1046, 784, 1046].forEach((f, i) => this.tone(f, t + i * 0.09, 0.16, 'square', 0.3, G)); break;
      case 'die': this.tone(300, t, 0.3, 'square', 0.3, G, 0.25); break;
      case 'flee': for (let i = 0; i < 4; i++) this.tone(800 - i * 120, t + i * 0.05, 0.05, 'square', 0.25, G); break;
      case 'gameover': [392, 370, 349, 330].forEach((f, i) => this.tone(f, t + i * 0.25, 0.3, 'triangle', 0.4, G)); break;
    }
  },
};

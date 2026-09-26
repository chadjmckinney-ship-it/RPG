'use strict';
// Procedural pixel art: tiles are painted in code, sprites come from palette strings.

const SPR = {
  down: [
    '......kkkk......',
    '....kkhhhhkk....',
    '...khHHhhhhhk...',
    '..khhhhhhhhhhk..',
    '..khsssssssshk..',
    '..khsesssseshk..',
    '...kssssssssk...',
    '....kkbbbbkk....',
    '...kbbBbbBbbk...',
    '..kbbbBbbBbbbk..',
    '..ksbbBwwBbbsk..',
    '...kbbbbbbbbk...',
    '...kbBbbbbBbk...',
    '....kllkkllk....',
    '....kkk..kkk....',
    '................',
  ],
  up: [
    '......kkkk......',
    '....kkhhhhkk....',
    '...khHHhhhhhk...',
    '..khhhhhhhhhhk..',
    '..khhhhhhhhhhk..',
    '..khhhhhhhhhhk..',
    '...khhhhhhhhk...',
    '....kkbbbbkk....',
    '...kbbBbbBbbk...',
    '..kbbbBbbBbbbk..',
    '..ksbbBbbBbbsk..',
    '...kbbbbbbbbk...',
    '...kbBbbbbBbk...',
    '....kllkkllk....',
    '....kkk..kkk....',
    '................',
  ],
  side: [
    '......kkkk......',
    '....kkhhhhkk....',
    '...khHHhhhhhk...',
    '..khhhhhhhhhhk..',
    '..khhhhhssssk...',
    '..khhhhsssesk...',
    '...khhhssssk....',
    '....kkbbbbkk....',
    '....kbbBbbbk....',
    '....kbbBbbbsk...',
    '....kbbwwbbk....',
    '....kbbbbbbk....',
    '....kbBbbBbk....',
    '....kllkkllk....',
    '....kkk..kkk....',
    '................',
  ],
  slime: [
    '................',
    '................',
    '................',
    '................',
    '......kkkk......',
    '....kkAAaakk....',
    '...kAAaaaaaak...',
    '..kAaaaaaaaaak..',
    '..kaawaaaawaak..',
    '..kaaeaaaaeaak..',
    '.kaaaaaaaaaaaak.',
    '.kaaaaddddaaaak.',
    '.kdaaaaaaaaaadk.',
    '..kddddddddddk..',
    '...kkkkkkkkkk...',
    '................',
  ],
  rat: [
    '................',
    '................',
    '................',
    '................',
    '...kk...........',
    '..kAak..........',
    '..kaak.kkkkk....',
    '.kaeaakkaaaaakk.',
    'kwaaaaaaaaaaaadk',
    'kkaaaaaaaaaaadk.',
    '.kkdaaaaaaaadk.x',
    '...kdakkkdak.xx.',
    '...kk.k..kk.x...',
    '................',
    '................',
    '................',
  ],
  beetle: [
    '................',
    '.......ww.......',
    '....k..ww..k....',
    '.....k.kk.k.....',
    '......kkkk......',
    '....kkAAAAkk....',
    '...kAaaxxaaAk...',
    '..kaaaaxxaaaak..',
    '..kaeaaxxaaeak..',
    '.kdaaaaxxaaaadk.',
    '.kdaaaaxxaaaadk.',
    '..kddaaxxaaddk..',
    '..k.kddddddk.k..',
    '.k..k.k..k.k..k.',
    '................',
    '................',
  ],
  wolf: [
    '................',
    '................',
    '..k.k...........',
    '.kAkak..........',
    '.kaaaak.........',
    'kweaaaakkkkkk...',
    'kwaaaaaaaaaaakk.',
    '.kkaaaaAAAaaaaak',
    '..kdaaaaaaaaadk.',
    '...kaaaaaaaaak.k',
    '...kadkkkkkdak..',
    '...kak.....kak..',
    '...kak.....kak..',
    '...kk......kk...',
    '................',
    '................',
  ],
  fairy: [
    '................',
    '...kk......kk...',
    '..kxxk....kxxk..',
    '..kxxxk..kxxxk..',
    '...kxxkkkkxxk...',
    '....kkAAAAkk....',
    '....kAaaaaAk....',
    '....kaeaaeak....',
    '....kaaaaaak....',
    '.....kaaaak.....',
    '......kddk......',
    '.....kxddxk.....',
    '......kddk......',
    '.......kk.......',
    '................',
    '................',
  ],
  toad: [
    '................',
    '................',
    '................',
    '................',
    '....kk....kk....',
    '...kwek..kewk...',
    '..kAaakkkkaaAk..',
    '.kaaaaaaaaaaaak.',
    '.kaaAaaaaaaAaak.',
    '.kakkkkkkkkkkak.',
    '.kaaxxxxxxxxaak.',
    'kaadaaaaaaaadaak',
    'kaddkaaaaaakddak',
    '.kkk.kkkkkk.kkk.',
    '................',
    '................',
  ],
  bat: [
    '................',
    '................',
    '................',
    'k..............k',
    'kk....k..k....kk',
    'kak...kkkk...kak',
    'kaak.kaaaak.kaak',
    'kaaakaeaaeakaaak',
    '.kaaaaawwaaaaak.',
    '..kaaaaAAaaaak..',
    '...kak.kk.kak...',
    '....k..kk..k....',
    '................',
    '................',
    '................',
    '................',
  ],
  skeleton: [
    '................',
    '.....kkkkk......',
    '....kwwwwwk.....',
    '....kwekewk.....',
    '....kwwwwwk.....',
    '.....kwkwk......',
    '...kkkwwwkkk....',
    '..kwk.kwk.kwk...',
    '..kwkkwwwkkwkxx.',
    '..kk.kwwwk.kxxxk',
    '.....kwkwk..kxxk',
    '....kwk.kwk..kk.',
    '....kwk.kwk.....',
    '...kwwk.kwwk....',
    '...kkk...kkk....',
    '................',
  ],
  wraith: [
    '................',
    '.....kkkkk......',
    '....kaaaaak.....',
    '...kaAAaaaak....',
    '...kaxkaxkak....',
    '...kaaaaaaak....',
    '..kaaakkkaaak...',
    '..kaaaaaaaaak...',
    '.kaAaaaaaaAaak..',
    '.kaaaaaaaaaaak..',
    '.kdaaaaaaaaadk..',
    '..kdaadaadaadk..',
    '..kdk.kdk.kdk...',
    '...k...k...k....',
    '................',
    '................',
  ],
  wyrm: [
    '....k...........',
    '...kxk....k.....',
    '..kAAak..kxk....',
    '.kAaaaakkxxk....',
    'kweaaaaaaakk..k.',
    'kwwaaaakaaak.kxk',
    '.kkkaaakkaaakxxk',
    '..kwkaaaxaaaaak.',
    '...kkaaaxxaaaak.',
    '.....kaaaxxaaaak',
    '....kaakaaxxaadk',
    '...kaak.kaaaadk.',
    '...kak..kaakdk..',
    '..kdk..kdak.k...',
    '..kk...kkk......',
    '................',
  ],
};

const PALS = {
  knight:    { k: '#12141d', h: '#9aa7b8', H: '#e2e8f0', s: '#f1c7a0', e: '#1b1b24', b: '#2f5aa8', B: '#1f3d78', w: '#e0a43a', l: '#3a3a48' },
  mage:      { k: '#12101a', h: '#6b3fa0', H: '#a57ad8', s: '#f1c7a0', e: '#1b1b24', b: '#4a2f7a', B: '#33205a', w: '#e0a43a', l: '#2c2438' },
  rogue:     { k: '#10140f', h: '#3f7a4a', H: '#76b36e', s: '#e8b894', e: '#1b1b24', b: '#5a4632', B: '#3f3022', w: '#b0b8c0', l: '#2a2a2a' },
  guard:     { k: '#14100f', h: '#8a95a5', H: '#d0d8e0', s: '#e8b894', e: '#1b1b24', b: '#8a2e2a', B: '#5e1d1a', w: '#d6a43a', l: '#3a3030' },
  child:     { k: '#161010', h: '#d9a441', H: '#f0cf78', s: '#f5cfaa', e: '#1b1b24', b: '#d07a9a', B: '#a85a78', w: '#ffffff', l: '#5a4a6a' },
  elder:     { k: '#141214', h: '#d8d8d8', H: '#ffffff', s: '#e6bb98', e: '#1b1b24', b: '#7a4a2a', B: '#5a341c', w: '#c9a14a', l: '#3a2a20' },
  villager:  { k: '#15110d', h: '#8a5a2a', H: '#b07a40', s: '#e8b894', e: '#1b1b24', b: '#4f6e8a', B: '#37506a', w: '#e0d0a0', l: '#3a3028' },
  merchant:  { k: '#12100c', h: '#3a2a1a', H: '#6a4a2a', s: '#e8b894', e: '#1b1b24', b: '#2f7a6a', B: '#1f5a4a', w: '#d9a441', l: '#2a2a2a' },
  herbalist: { k: '#120f0c', h: '#b0502a', H: '#e07a48', s: '#f1c7a0', e: '#1b1b24', b: '#5a8a3a', B: '#3f6a2a', w: '#e8d890', l: '#3a3020' },
  ghost:     { k: '#1a2a3a', h: '#8ab0d0', H: '#d0e8ff', s: '#a8c8e0', e: '#1a2a3a', b: '#6a90b8', B: '#4a6a90', w: '#d0e8ff', l: '#4a6a90' },

  slime:  { k: '#13201a', a: '#5fbf5a', A: '#a6e68e', d: '#3a8a3e', w: '#ffffff', e: '#13201a' },
  magma:  { k: '#2a0e08', a: '#e0602a', A: '#ffb450', d: '#9a2a1a', w: '#fff0c0', e: '#2a0e08' },
  rat:    { k: '#1a1410', a: '#8a7a6a', A: '#b0a090', d: '#5a4a3e', e: '#e03030', w: '#f0e0d0', x: '#d08080' },
  beetle: { k: '#0d1020', a: '#3a5a9a', A: '#6a8ad0', d: '#1f3060', x: '#15182a', w: '#e8e0c8', e: '#f0d040' },
  wolf:   { k: '#101218', a: '#5a6070', A: '#8a90a0', d: '#3a3e4a', e: '#f0d040', w: '#f0f0f0' },
  alpha:  { k: '#0e140a', a: '#4a5a3a', A: '#86a860', d: '#2a3a20', e: '#ff5030', w: '#f4f0e0' },
  sprite: { k: '#10200e', a: '#8ad06a', A: '#c8f4a0', d: '#4a8a3a', x: '#f0a0d0', e: '#202020' },
  toad:   { k: '#141a0a', a: '#6a8a3a', A: '#9ab05a', d: '#4a5a24', x: '#d8c880', e: '#202020', w: '#f0f080' },
  bat:    { k: '#12060a', a: '#5a3040', A: '#8a4a60', d: '#3a1a28', e: '#ff8030', w: '#ffffff' },
  bones:  { k: '#1a1614', w: '#e8e0cc', e: '#ff4020', x: '#7a6a5a' },
  wraith: { k: '#121218', a: '#6a6a78', A: '#a4a4b4', d: '#3a3a48', x: '#ff7a30' },
  wyrm:   { k: '#1a0806', a: '#b8401e', A: '#ec7c3c', d: '#6a1e10', x: '#f4c450', e: '#fff080', w: '#fff8e0' },
};

const Gfx = {
  cache: new Map(),
  tiles: new Map(),

  sprite(tpl, pal, flip = false, tint = null) {
    const key = `${tpl}|${pal}|${flip}|${tint}`;
    let c = this.cache.get(key);
    if (c) return c;
    const rows = SPR[tpl], p = PALS[pal] || {};
    c = document.createElement('canvas');
    c.width = 16; c.height = 16;
    const x = c.getContext('2d');
    for (let j = 0; j < 16; j++) {
      const row = rows[j] || '';
      for (let i = 0; i < 16; i++) {
        const ch = row[i];
        if (!ch || ch === '.') continue;
        const col = tint || p[ch];
        if (!col) continue;
        x.fillStyle = col;
        x.fillRect(flip ? 15 - i : i, j, 1, 1);
      }
    }
    this.cache.set(key, c);
    return c;
  },

  person(look, dir) {
    const tpl = dir === 'up' ? 'up' : dir === 'down' ? 'down' : 'side';
    return this.sprite(tpl, look, dir === 'left');
  },

  // Deterministic per-tile noise
  hash(x, y, s = 0) {
    let h = (x * 374761393 + y * 668265263 + s * 2246822519) | 0;
    h = (h ^ (h >>> 13)) * 1274126177;
    return ((h ^ (h >>> 16)) >>> 0) / 4294967295;
  },

  mk(fn) {
    const c = document.createElement('canvas');
    c.width = 16; c.height = 16;
    const x = c.getContext('2d');
    x.imageSmoothingEnabled = false;
    fn(x);
    return c;
  },

  speck(x, colors, n, seed) {
    for (let i = 0; i < n; i++) {
      x.fillStyle = colors[i % colors.length];
      x.fillRect(Math.floor(this.hash(i, seed, 1) * 16), Math.floor(this.hash(seed, i, 2) * 16), 1, 1);
    }
  },

  // ground for a theme; variant v picks a speckle pattern
  ground(x, theme, v) {
    const g = {
      town: ['#5c9444', '#6aa24e', '#4c8038'],
      field: ['#5a9a46', '#6cab50', '#4a8238'],
      woods: ['#2f5a36', '#3a6a40', '#244a2c'],
    }[theme] || ['#5a9a46', '#6cab50', '#4a8238'];
    x.fillStyle = g[0]; x.fillRect(0, 0, 16, 16);
    this.speck(x, [g[1], g[2]], 10, 7 + v * 13);
    if (v === 1) { x.fillStyle = g[2]; x.fillRect(4, 9, 1, 2); x.fillRect(5, 8, 1, 2); x.fillRect(11, 3, 1, 2); }
  },

  buildTiles() {
    const themes = ['town', 'field', 'woods'];
    const T = this.tiles;
    for (const th of themes) {
      for (let v = 0; v < 3; v++) T.set(`.${th}${v}`, this.mk(x => this.ground(x, th, v)));
      T.set(`,${th}`, this.mk(x => {
        this.ground(x, th, 2);
        const dark = th === 'woods' ? '#1d3e22' : '#3a7a2c', lite = th === 'woods' ? '#4f8a4a' : '#8acb5a';
        for (let i = 0; i < 6; i++) {
          const bx = 1 + i * 2.6 | 0, by = 6 + (i % 2) * 5;
          x.fillStyle = dark; x.fillRect(bx, by, 1, 5); x.fillRect(bx + 1, by + 1, 1, 4);
          x.fillStyle = lite; x.fillRect(bx, by, 1, 1);
        }
      }));
      T.set(`*${th}`, this.mk(x => {
        this.ground(x, th, 0);
        const cols = ['#f4d04a', '#e8708a', '#ffffff', '#9ab8f0'];
        for (let i = 0; i < 5; i++) {
          const fx = 2 + Math.floor(this.hash(i, 3, 9) * 12), fy = 2 + Math.floor(this.hash(3, i, 9) * 12);
          x.fillStyle = '#2f6a2a'; x.fillRect(fx, fy + 1, 1, 2);
          x.fillStyle = cols[i % 4]; x.fillRect(fx - 1, fy, 3, 1); x.fillRect(fx, fy - 1, 1, 3);
          x.fillStyle = '#fff4a0'; x.fillRect(fx, fy, 1, 1);
        }
      }));
      T.set(`T${th}`, this.mk(x => {
        this.ground(x, th, 0);
        x.fillStyle = 'rgba(0,0,0,0.25)'; x.fillRect(3, 13, 10, 2);
        x.fillStyle = '#5a3a1e'; x.fillRect(7, 10, 2, 5);
        x.fillStyle = '#1f4a22'; x.beginPath(); x.arc(8, 7, 6.5, 0, Math.PI * 2); x.fill();
        x.fillStyle = '#2f6e2e'; x.beginPath(); x.arc(7, 6, 5, 0, Math.PI * 2); x.fill();
        x.fillStyle = '#4a9040'; x.fillRect(4, 3, 3, 2); x.fillRect(5, 2, 2, 1); x.fillRect(9, 5, 2, 1);
      }));
      T.set(`M${th}`, this.mk(x => {
        this.ground(x, th, 0);
        x.fillStyle = '#3a3a44'; x.fillRect(1, 5, 14, 10); x.fillRect(3, 2, 10, 3);
        x.fillStyle = '#6a6a78'; x.fillRect(2, 5, 12, 8); x.fillRect(4, 3, 8, 2);
        x.fillStyle = '#8e8ea0'; x.fillRect(4, 4, 5, 2); x.fillRect(3, 6, 3, 2);
        x.fillStyle = '#4a4a56'; x.fillRect(9, 9, 4, 3); x.fillRect(2, 12, 12, 1);
      }));
      T.set(`Z${th}`, this.mk(x => {
        this.ground(x, th, 0);
        x.fillStyle = '#6a4424'; x.fillRect(0, 6, 16, 2); x.fillRect(0, 11, 16, 2);
        x.fillStyle = '#8a5e34'; x.fillRect(2, 3, 3, 12); x.fillRect(11, 3, 3, 12);
        x.fillStyle = '#b07a44'; x.fillRect(2, 3, 3, 1); x.fillRect(11, 3, 3, 1);
      }));
      T.set(`P${th}`, this.mk(x => {
        this.ground(x, th, 0);
        x.fillStyle = '#5a5a66'; x.beginPath(); x.arc(8, 9, 7, 0, Math.PI * 2); x.fill();
        x.fillStyle = '#8a8a98'; x.beginPath(); x.arc(8, 8.5, 6, 0, Math.PI * 2); x.fill();
        x.fillStyle = '#1d3f6a'; x.beginPath(); x.arc(8, 8.5, 4, 0, Math.PI * 2); x.fill();
        x.fillStyle = '#5a3a1e'; x.fillRect(1, 1, 2, 9); x.fillRect(13, 1, 2, 9); x.fillRect(1, 1, 14, 2);
      }));
      T.set(`V${th}`, this.mk(x => {
        this.ground(x, th, 0);
        x.fillStyle = '#6a7a80'; x.beginPath(); x.arc(8, 8, 7, 0, Math.PI * 2); x.fill();
        x.fillStyle = '#3a9ad0'; x.beginPath(); x.arc(8, 8, 5.5, 0, Math.PI * 2); x.fill();
        x.fillStyle = '#9ae0ff'; x.fillRect(5, 6, 3, 1); x.fillRect(9, 9, 2, 1);
      }));
    }
    // Pines for the Gloamwood
    T.set('Y', this.mk(x => {
      this.ground(x, 'woods', 2);
      x.fillStyle = '#12281a'; x.beginPath(); x.moveTo(8, 0); x.lineTo(15, 13); x.lineTo(1, 13); x.fill();
      x.fillStyle = '#1e3e26'; x.beginPath(); x.moveTo(8, 1); x.lineTo(13, 10); x.lineTo(3, 10); x.fill();
      x.fillStyle = '#2f5a34'; x.fillRect(7, 3, 2, 2); x.fillRect(5, 7, 2, 1); x.fillRect(9, 6, 2, 1);
      x.fillStyle = '#3a2412'; x.fillRect(7, 13, 2, 3);
    }));
    // Water (2 frames)
    for (let f = 0; f < 2; f++) T.set(`~${f}`, this.mk(x => {
      x.fillStyle = '#2a64a8'; x.fillRect(0, 0, 16, 16);
      x.fillStyle = '#3478c0'; x.fillRect(0, 4, 16, 3); x.fillRect(0, 12, 16, 2);
      x.fillStyle = '#8ac4f0';
      const o = f * 4;
      x.fillRect((2 + o) % 16, 5, 3, 1); x.fillRect((10 + o) % 16, 9, 3, 1); x.fillRect((6 + o) % 16, 13, 2, 1);
    }));
    T.set('B', this.mk(x => {
      x.fillStyle = '#2a64a8'; x.fillRect(0, 0, 16, 16);
      x.fillStyle = '#8a5a30'; x.fillRect(0, 1, 16, 14);
      x.fillStyle = '#a8743e'; for (let i = 0; i < 16; i += 4) x.fillRect(i, 1, 3, 14);
      x.fillStyle = '#5a3a1e'; x.fillRect(0, 1, 16, 1); x.fillRect(0, 14, 16, 1);
    }));
    T.set(':', this.mk(x => {
      x.fillStyle = '#b8955e'; x.fillRect(0, 0, 16, 16);
      this.speck(x, ['#a68250', '#cbab74', '#94703f'], 14, 31);
    }));
    // Buildings
    T.set('R', this.mk(x => {
      x.fillStyle = '#9a3e30'; x.fillRect(0, 0, 16, 16);
      x.fillStyle = '#b8503c'; for (let j = 0; j < 16; j += 4) x.fillRect(0, j, 16, 2);
      x.fillStyle = '#6e281e'; for (let j = 3; j < 16; j += 4) x.fillRect(0, j, 16, 1);
      x.fillStyle = '#6e281e'; for (let j = 0; j < 16; j += 4) x.fillRect((j * 3) % 8, j, 1, 3), x.fillRect((j * 3) % 8 + 8, j, 1, 3);
    }));
    const wall = (x) => {
      x.fillStyle = '#e0d0ae'; x.fillRect(0, 0, 16, 16);
      x.fillStyle = '#6a4424'; x.fillRect(0, 0, 16, 2); x.fillRect(0, 14, 16, 2); x.fillRect(0, 0, 2, 16); x.fillRect(14, 0, 2, 16);
      x.fillStyle = '#c8b690'; x.fillRect(2, 2, 12, 1);
    };
    T.set('W', this.mk(x => { wall(x); x.fillStyle = '#6a4424'; x.beginPath(); x.moveTo(2, 2); x.lineTo(14, 14); x.lineTo(12, 14); x.lineTo(2, 4); x.fill(); }));
    T.set('O', this.mk(x => {
      wall(x);
      x.fillStyle = '#4a3018'; x.fillRect(4, 4, 8, 8);
      x.fillStyle = '#f0c860'; x.fillRect(5, 5, 6, 6);
      x.fillStyle = '#4a3018'; x.fillRect(7, 5, 2, 6); x.fillRect(5, 7, 6, 2);
    }));
    T.set('_', this.mk(x => {
      x.fillStyle = '#a8784a'; x.fillRect(0, 0, 16, 16);
      x.fillStyle = '#946438'; x.fillRect(0, 5, 16, 1); x.fillRect(0, 11, 16, 1);
      x.fillStyle = '#7a502c'; x.fillRect(5, 0, 1, 5); x.fillRect(12, 6, 1, 5); x.fillRect(3, 12, 1, 4);
      x.fillStyle = '#b88a58'; x.fillRect(8, 2, 3, 1); x.fillRect(1, 8, 3, 1);
    }));
    T.set('#', this.mk(x => {
      x.fillStyle = '#4a3a32'; x.fillRect(0, 0, 16, 16);
      x.fillStyle = '#5e4a3e'; x.fillRect(0, 0, 7, 7); x.fillRect(8, 8, 8, 7); x.fillRect(9, 0, 7, 7); x.fillRect(0, 8, 7, 7);
      x.fillStyle = '#3a2c26'; x.fillRect(0, 15, 16, 1);
    }));
    T.set('|', this.mk(x => {
      x.fillStyle = '#a8784a'; x.fillRect(0, 0, 16, 16);
      x.fillStyle = '#5a3a1e'; x.fillRect(0, 3, 16, 13);
      x.fillStyle = '#8a5a30'; x.fillRect(0, 3, 16, 4);
      x.fillStyle = '#b07a44'; x.fillRect(0, 3, 16, 1);
    }));
    T.set('E', this.mk(x => {
      x.fillStyle = '#a8784a'; x.fillRect(0, 0, 16, 16);
      x.fillStyle = '#5a3a1e'; x.fillRect(1, 0, 14, 16);
      x.fillStyle = '#f0ece0'; x.fillRect(3, 1, 10, 4);
      x.fillStyle = '#3a6ab0'; x.fillRect(2, 6, 12, 9);
      x.fillStyle = '#5a8ad0'; x.fillRect(2, 6, 12, 2);
    }));
    T.set('K', this.mk(x => {
      x.fillStyle = '#4a3a32'; x.fillRect(0, 0, 16, 16);
      x.fillStyle = '#5a3a1e'; x.fillRect(1, 1, 14, 15);
      x.fillStyle = '#2a1a0e'; x.fillRect(2, 2, 12, 5); x.fillRect(2, 9, 12, 5);
      const bk = ['#a83a3a', '#3a6aa8', '#d0a040', '#3a8a5a', '#8a4aa8'];
      for (let i = 0; i < 6; i++) { x.fillStyle = bk[i % 5]; x.fillRect(2 + i * 2, 3 + (i % 2), 2, 4 - (i % 2)); x.fillStyle = bk[(i + 2) % 5]; x.fillRect(2 + i * 2, 10, 2, 4); }
    }));
    // Cave
    T.set(';', this.mk(x => {
      x.fillStyle = '#4a3c38'; x.fillRect(0, 0, 16, 16);
      this.speck(x, ['#5a4a44', '#3a2e2a', '#6a5048'], 16, 57);
    }));
    T.set('X', this.mk(x => {
      x.fillStyle = '#1e1614'; x.fillRect(0, 0, 16, 16);
      x.fillStyle = '#2e2420'; x.fillRect(1, 1, 8, 6); x.fillRect(9, 8, 6, 6); x.fillRect(2, 9, 5, 5);
      x.fillStyle = '#3e302a'; x.fillRect(2, 1, 5, 2); x.fillRect(10, 8, 3, 2); x.fillRect(3, 9, 2, 1);
    }));
    for (let f = 0; f < 2; f++) T.set(`L${f}`, this.mk(x => {
      x.fillStyle = '#c83a14'; x.fillRect(0, 0, 16, 16);
      x.fillStyle = '#f07a20'; x.fillRect(f ? 2 : 6, 3, 6, 3); x.fillRect(f ? 9 : 1, 10, 6, 3);
      x.fillStyle = '#ffd060'; x.fillRect(f ? 4 : 8, 4, 2, 1); x.fillRect(f ? 11 : 3, 11, 2, 1);
    }));
    T.set('J', this.mk(x => {
      x.fillStyle = '#1e1614'; x.fillRect(0, 0, 16, 16);
      x.fillStyle = '#5a5a66'; for (let i = 1; i < 16; i += 3) x.fillRect(i, 0, 2, 16);
      x.fillStyle = '#8a8a98'; x.fillRect(0, 3, 16, 2); x.fillRect(0, 11, 16, 2);
      x.fillStyle = '#d9a441'; x.fillRect(7, 6, 3, 4);
      x.fillStyle = '#1e1614'; x.fillRect(8, 7, 1, 2);
    }));
    // Warp looks
    T.set('door', this.mk(x => {
      wall(x);
      x.fillStyle = '#3a2210'; x.fillRect(3, 2, 10, 14);
      x.fillStyle = '#6a4020'; x.fillRect(4, 3, 8, 13);
      x.fillStyle = '#8a5a30'; x.fillRect(4, 3, 3, 13);
      x.fillStyle = '#e0b040'; x.fillRect(10, 9, 1, 2);
    }));
    T.set('mat', this.mk(x => {
      x.fillStyle = '#a8784a'; x.fillRect(0, 0, 16, 16);
      x.fillStyle = '#8a2e2a'; x.fillRect(2, 3, 12, 10);
      x.fillStyle = '#c05040'; x.fillRect(3, 4, 10, 1); x.fillRect(3, 11, 10, 1);
    }));
    T.set('cave', this.mk(x => {
      x.fillStyle = '#6a6a78'; x.fillRect(0, 0, 16, 16);
      x.fillStyle = '#3a3a44'; x.fillRect(0, 0, 16, 3);
      x.fillStyle = '#0a0806'; x.beginPath(); x.arc(8, 16, 7, Math.PI, 0); x.fill(); x.fillRect(1, 12, 14, 4);
    }));
    T.set('light', this.mk(x => {
      x.fillStyle = '#4a3c38'; x.fillRect(0, 0, 16, 16);
      const g = x.createLinearGradient(0, 16, 0, 0); g.addColorStop(0, '#f8f0c8'); g.addColorStop(1, 'rgba(248,240,200,0)');
      x.fillStyle = g; x.fillRect(0, 0, 16, 16);
    }));
    for (const d of ['down', 'up']) T.set(d, this.mk(x => {
      x.fillStyle = '#1e1614'; x.fillRect(0, 0, 16, 16);
      for (let i = 0; i < 4; i++) {
        const shade = d === 'down' ? 110 - i * 24 : 40 + i * 24;
        x.fillStyle = `rgb(${shade},${shade * 0.8 | 0},${shade * 0.7 | 0})`;
        x.fillRect(1 + (d === 'down' ? i : 3 - i), i * 4, 14 - 2 * (d === 'down' ? i : 3 - i), 3);
      }
    }));
    T.set('S', this.mk(x => {
      x.fillStyle = '#5a3a1e'; x.fillRect(7, 8, 2, 8);
      x.fillStyle = '#3a2412'; x.fillRect(2, 2, 12, 8);
      x.fillStyle = '#b08050'; x.fillRect(3, 3, 10, 6);
      x.fillStyle = '#6a4a2a'; x.fillRect(4, 4, 8, 1); x.fillRect(4, 6, 6, 1);
    }));
    for (const open of [false, true]) T.set(open ? 'chestOpen' : 'chest', this.mk(x => {
      x.fillStyle = 'rgba(0,0,0,0.3)'; x.fillRect(2, 13, 12, 2);
      x.fillStyle = '#2a1608'; x.fillRect(1, 4, 14, 11);
      x.fillStyle = '#8a4e22'; x.fillRect(2, 7, 12, 7);
      if (open) { x.fillStyle = '#1a0e06'; x.fillRect(2, 4, 12, 3); x.fillStyle = '#6a3a18'; x.fillRect(2, 1, 12, 3); }
      else { x.fillStyle = '#a8622c'; x.fillRect(2, 5, 12, 3); x.fillStyle = '#d9a441'; x.fillRect(7, 7, 2, 3); }
      x.fillStyle = '#d9a441'; x.fillRect(2, 8, 12, 1);
    }));
  },

  // What tile image to draw for char ch in a map
  tileFor(map, ch, tx, ty, frame) {
    const th = map.theme === 'inside' || map.theme === 'cave' ? 'field' : map.theme;
    const T = this.tiles;
    switch (ch) {
      case '.': return T.get(`.${th}${Math.floor(this.hash(tx, ty) * 3)}`);
      case ',': case '*': case 'T': case 'M': case 'Z': case 'P': case 'V': return T.get(ch + th);
      case '~': return T.get(`~${frame % 2}`);
      case 'L': return T.get(`L${frame % 2}`);
      default: return T.get(ch);
    }
  },
};

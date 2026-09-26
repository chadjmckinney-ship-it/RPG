'use strict';
// Core game data: classes, skills, items, enemies, encounter math.

const TS = 16;          // tile size in logical pixels
const VW = 15, VH = 11; // viewport in tiles (240 x 176 logical)
const SCALE = 4;        // canvas backing-store scale

const CLASSES = {
  knight: {
    name: 'Knight', pal: 'knight',
    blurb: 'Heavy armor and a steady blade. Hard to put down.',
    base: { hp: 42, mp: 8, atk: 9, def: 7, mag: 2, spd: 4 },
    grow: { hp: 9, mp: 2, atk: 2.2, def: 1.8, mag: 0.6, spd: 0.8 },
    crit: 0.06,
    start: { weapon: 'rustsword', armor: 'tunic' },
    skills: ['strike', 'bulwark', 'cleave', 'secondwind', 'sunder'],
  },
  mage: {
    name: 'Mage', pal: 'mage',
    blurb: 'Fragile, but commands fire, frost and raw arcana.',
    base: { hp: 28, mp: 22, atk: 4, def: 3, mag: 10, spd: 5 },
    grow: { hp: 6.5, mp: 4.5, atk: 0.8, def: 1, mag: 2.6, spd: 1 },
    crit: 0.05,
    start: { weapon: 'oakstaff', armor: 'tunic' },
    skills: ['firebolt', 'mend', 'frost', 'inferno', 'nova'],
  },
  rogue: {
    name: 'Rogue', pal: 'rogue',
    blurb: 'Fast hands, poisoned edges, and a knack for criticals.',
    base: { hp: 34, mp: 12, atk: 8, def: 4, mag: 4, spd: 9 },
    grow: { hp: 7.8, mp: 2.8, atk: 2, def: 1.2, mag: 1, spd: 1.6 },
    crit: 0.14,
    start: { weapon: 'wdagger', armor: 'tunic' },
    skills: ['twin', 'venom', 'smoke', 'flurry', 'assassinate'],
  },
};

const SKILLS = {
  // Knight
  strike:     { name: 'Power Strike', lv: 1, mp: 3, target: 'enemy', kind: 'phys', power: 1.8, desc: 'A two-handed blow for 180% damage.' },
  bulwark:    { name: 'Bulwark', lv: 3, mp: 4, target: 'self', buff: { stat: 'def', mult: 1.7, turns: 3 }, desc: 'Raise Defense by 70% for 3 turns.' },
  cleave:     { name: 'Cleave', lv: 5, mp: 6, target: 'all', kind: 'phys', power: 1.1, desc: 'A wide swing that hits every foe.' },
  secondwind: { name: 'Second Wind', lv: 7, mp: 8, target: 'self', heal: { pct: 0.45 }, field: true, desc: 'Recover 45% of max HP. Usable outside battle.' },
  sunder:     { name: 'Sunder', lv: 10, mp: 12, target: 'enemy', kind: 'phys', power: 3.0, desc: 'Splits armor and bone. 300% damage.' },
  // Mage
  firebolt:   { name: 'Firebolt', lv: 1, mp: 3, target: 'enemy', kind: 'mag', power: 1.6, elem: 'fire', desc: 'Hurl a bolt of fire at one foe.' },
  mend:       { name: 'Mend', lv: 2, mp: 4, target: 'self', heal: { mag: 2.2, flat: 12 }, cure: true, field: true, desc: 'Heal wounds and cure poison and burns. Usable outside battle.' },
  frost:      { name: 'Frost Lance', lv: 4, mp: 5, target: 'enemy', kind: 'mag', power: 1.9, elem: 'ice', status: { id: 'slow', chance: 0.4, turns: 3 }, desc: 'Ice damage to one foe. May slow it.' },
  inferno:    { name: 'Inferno', lv: 6, mp: 9, target: 'all', kind: 'mag', power: 1.35, elem: 'fire', status: { id: 'burn', chance: 0.3, turns: 3 }, desc: 'Engulf every foe in flame. May burn.' },
  nova:       { name: 'Arcane Nova', lv: 10, mp: 16, target: 'all', kind: 'mag', power: 2.2, elem: 'arcane', desc: 'Pure force that no creature resists.' },
  // Rogue
  twin:        { name: 'Twin Fang', lv: 1, mp: 3, target: 'enemy', kind: 'phys', power: 0.85, hits: 2, desc: 'Two quick cuts at 85% each.' },
  venom:       { name: 'Venom Edge', lv: 3, mp: 4, target: 'enemy', kind: 'phys', power: 1.0, status: { id: 'poison', chance: 0.9, turns: 4 }, desc: 'A strike that almost always poisons.' },
  smoke:       { name: 'Smoke Step', lv: 5, mp: 5, target: 'self', buff: { stat: 'eva', add: 0.5, turns: 3 }, desc: 'Vanish in smoke. 50% evasion for 3 turns.' },
  flurry:      { name: 'Flurry', lv: 7, mp: 8, target: 'random', kind: 'phys', power: 0.7, hits: 4, desc: 'Four strikes at random foes.' },
  assassinate: { name: 'Assassinate', lv: 10, mp: 12, target: 'enemy', kind: 'phys', power: 2.2, crit: 1, desc: 'A guaranteed critical at 220% power.' },
};

// type: use | weapon | armor | charm | key
const ITEMS = {
  tonic:     { name: 'Tonic', type: 'use', price: 12, heal: 40, desc: 'Restores 40 HP.' },
  gtonic:    { name: 'Greater Tonic', type: 'use', price: 45, heal: 120, desc: 'Restores 120 HP.' },
  draught:   { name: 'Blue Draught', type: 'use', price: 28, mp: 15, desc: 'Restores 15 MP.' },
  remedy:    { name: 'Remedy Leaf', type: 'use', price: 8, cure: true, desc: 'Cures poison, burns and slow.' },
  flask:     { name: 'Fire Flask', type: 'use', price: 30, battleOnly: true, dmg: { amt: 34, elem: 'fire', all: true }, desc: 'Burst of flame on every foe. Battle only.' },
  frostvial: { name: 'Frost Vial', type: 'use', price: 36, battleOnly: true, dmg: { amt: 60, elem: 'ice' }, desc: 'Shatters ice over one foe. Battle only.' },
  feather:   { name: 'Phoenix Feather', type: 'use', auto: true, desc: 'Burns away if you fall in battle, restoring you to full.' },

  rustsword:  { name: 'Rusty Sword', type: 'weapon', cls: ['knight'], atk: 2, price: 10, desc: 'Pitted, but it still cuts.' },
  ironsword:  { name: 'Iron Sword', type: 'weapon', cls: ['knight'], atk: 6, price: 70, desc: 'A soldier\'s sword.' },
  steelblade: { name: 'Steel Blade', type: 'weapon', cls: ['knight'], atk: 11, price: 220, desc: 'Folded steel from the southern forges.' },
  emberbane:  { name: 'Emberbane', type: 'weapon', cls: ['knight'], atk: 18, def: 2, price: 0, desc: 'A warden\'s greatsword, cold to the touch.' },
  oakstaff:   { name: 'Oak Staff', type: 'weapon', cls: ['mage'], atk: 1, mag: 2, price: 10, desc: 'Good for walking, adequate for spells.' },
  willowrod:  { name: 'Willow Rod', type: 'weapon', cls: ['mage'], atk: 2, mag: 5, price: 70, desc: 'Channels magic smoothly.' },
  runedstaff: { name: 'Runed Staff', type: 'weapon', cls: ['mage'], atk: 3, mag: 10, mp: 6, price: 220, desc: 'Carved with focusing runes.' },
  starfire:   { name: 'Starfire Wand', type: 'weapon', cls: ['mage'], atk: 4, mag: 17, mp: 10, price: 0, desc: 'Holds a sliver of a fallen star.' },
  wdagger:    { name: 'Worn Dagger', type: 'weapon', cls: ['rogue'], atk: 2, spd: 1, price: 10, desc: 'Sharp enough.' },
  steeldirk:  { name: 'Steel Dirk', type: 'weapon', cls: ['rogue'], atk: 6, spd: 2, price: 70, desc: 'Balanced for quick work.' },
  serpent:    { name: 'Serpent Fang', type: 'weapon', cls: ['rogue'], atk: 10, spd: 2, poison: 0.25, price: 220, desc: 'Venom-grooved. 25% chance to poison.' },
  nightshade: { name: 'Nightshade', type: 'weapon', cls: ['rogue'], atk: 16, spd: 4, crit: 0.08, price: 0, desc: 'Black glass that finds the gaps.' },

  tunic:       { name: 'Cloth Tunic', type: 'armor', def: 1, price: 5, desc: 'Keeps the wind off.' },
  leather:     { name: 'Leather Vest', type: 'armor', def: 4, price: 55, desc: 'Boiled leather, stitched tight.' },
  scale:       { name: 'Scale Mail', type: 'armor', def: 8, hp: 10, price: 170, desc: 'Overlapping iron scales.' },
  wardenplate: { name: 'Warden\'s Plate', type: 'armor', def: 13, hp: 25, price: 0, desc: 'Armor of the old gate-wardens.' },

  swiftband:   { name: 'Swift Band', type: 'charm', spd: 3, price: 0, desc: 'A ring of braided reed. Speed +3.' },
  emberward:   { name: 'Ember Ward', type: 'charm', fireRes: 0.5, def: 1, price: 0, desc: 'Halves fire damage taken.' },
  sagependant: { name: 'Sage Pendant', type: 'charm', mag: 3, mp: 10, price: 0, desc: 'Magic +3, max MP +10.' },

  moonpetal:   { name: 'Moonpetal', type: 'key', desc: 'A pale flower that glows faintly. Wren wants these.' },
  wardenkey:   { name: 'Warden\'s Key', type: 'key', desc: 'Iron key etched with the wardens\' sigil.' },
  hearthember: { name: 'Hearthfire', type: 'key', desc: 'Hollowmere\'s stolen flame, cupped in obsidian.' },
};

const CLASS_RELIC = { knight: 'emberbane', mage: 'starfire', rogue: 'nightshade' };

const EN_SKILLS = {
  attack:  { name: 'Attack', kind: 'phys', power: 1.0 },
  gnaw:    { name: 'Gnaw', kind: 'phys', power: 0.9, status: { id: 'poison', chance: 0.25, turns: 3 } },
  gore:    { name: 'Horn Gore', kind: 'phys', power: 1.35 },
  harden:  { name: 'Harden Shell', self: true, buff: { stat: 'def', mult: 1.5, turns: 3 } },
  howl:    { name: 'Howl', self: true, buff: { stat: 'atk', mult: 1.3, turns: 3 } },
  thorns:  { name: 'Bramble Lash', kind: 'mag', power: 1.2 },
  spit:    { name: 'Toxic Spit', kind: 'mag', power: 0.8, status: { id: 'poison', chance: 0.7, turns: 4 } },
  rend:    { name: 'Rend', kind: 'phys', power: 1.5 },
  maul:    { name: 'Savage Maul', kind: 'phys', power: 1.1, status: { id: 'poison', chance: 0.5, turns: 4 } },
  splash:  { name: 'Magma Splash', kind: 'mag', power: 1.1, elem: 'fire', status: { id: 'burn', chance: 0.35, turns: 3 } },
  screech: { name: 'Screech', kind: 'debuff', debuff: { stat: 'def', mult: 0.75, turns: 3 } },
  bash:    { name: 'Shield Bash', kind: 'phys', power: 1.1, status: { id: 'stun', chance: 0.25, turns: 1 } },
  soulfire:{ name: 'Soulfire', kind: 'mag', power: 1.3, elem: 'fire' },
  drain:   { name: 'Ash Drain', kind: 'mag', power: 1.0, drain: 0.6 },
  claw:    { name: 'Rending Claw', kind: 'phys', power: 1.3 },
  breath:  { name: 'Ember Breath', kind: 'mag', power: 1.35, elem: 'fire', status: { id: 'burn', chance: 0.5, turns: 3 } },
  tail:    { name: 'Tail Sweep', kind: 'phys', power: 1.0, status: { id: 'stun', chance: 0.3, turns: 1 } },
  roar:    { name: 'Molten Roar', self: true, buff: { stat: 'atk', mult: 1.25, turns: 4 } },
};

// sprite: template in gfx.js; pal: palette name; scale: battle draw scale
const ENEMIES = {
  slime:  { name: 'Slime', hp: 16, atk: 8, def: 2, mag: 2, spd: 3, xp: 5, gold: 4, sprite: 'slime', pal: 'slime', ai: [['attack', 1]], drops: [['tonic', 0.12]] },
  rat:    { name: 'Burrow Rat', hp: 13, atk: 9, def: 1, mag: 0, spd: 8, xp: 5, gold: 3, sprite: 'rat', pal: 'rat', ai: [['attack', 3], ['gnaw', 1]], drops: [['remedy', 0.15]] },
  beetle: { name: 'Hornbeetle', hp: 26, atk: 10, def: 7, mag: 0, spd: 2, xp: 8, gold: 7, weak: ['fire'], sprite: 'beetle', pal: 'beetle', ai: [['attack', 3], ['gore', 1], ['harden', 1]], drops: [['tonic', 0.2]] },

  wolf:   { name: 'Gloam Wolf', hp: 36, atk: 15, def: 5, mag: 0, spd: 10, xp: 14, gold: 9, sprite: 'wolf', pal: 'wolf', ai: [['attack', 4], ['howl', 1]], drops: [['tonic', 0.2]] },
  sprite: { name: 'Thorn Sprite', hp: 26, atk: 7, def: 4, mag: 14, spd: 9, xp: 15, gold: 12, weak: ['fire'], sprite: 'fairy', pal: 'sprite', ai: [['thorns', 3], ['attack', 1]], drops: [['draught', 0.2]] },
  toad:   { name: 'Mire Toad', hp: 46, atk: 14, def: 8, mag: 10, spd: 3, xp: 16, gold: 10, sprite: 'toad', pal: 'toad', ai: [['attack', 2], ['spit', 2]], drops: [['remedy', 0.3]] },
  alpha:  { name: 'Thornback Alpha', boss: true, hp: 240, atk: 19, def: 9, mag: 8, spd: 11, xp: 130, gold: 90, weak: ['fire'], sprite: 'wolf', pal: 'alpha', scale: 3, ai: [['attack', 3], ['rend', 2], ['maul', 2], ['howl', 1]], drops: [] },

  bat:    { name: 'Cinder Bat', hp: 40, atk: 19, def: 6, mag: 8, spd: 14, xp: 21, gold: 12, weak: ['ice'], resist: ['fire'], sprite: 'bat', pal: 'bat', ai: [['attack', 3], ['screech', 1]], drops: [['tonic', 0.2]] },
  magma:  { name: 'Magma Slime', hp: 60, atk: 18, def: 11, mag: 17, spd: 4, xp: 27, gold: 16, weak: ['ice'], resist: ['fire'], sprite: 'slime', pal: 'magma', ai: [['attack', 2], ['splash', 2]], drops: [['draught', 0.2]] },
  bones:  { name: 'Bone Warden', hp: 74, atk: 24, def: 15, mag: 0, spd: 6, xp: 33, gold: 22, weak: ['fire', 'arcane'], sprite: 'skeleton', pal: 'bones', ai: [['attack', 3], ['bash', 2]], drops: [['gtonic', 0.15]] },
  wraith: { name: 'Ash Wraith', hp: 54, atk: 13, def: 8, mag: 24, spd: 12, xp: 35, gold: 25, weak: ['arcane'], resist: ['fire'], sprite: 'wraith', pal: 'wraith', ai: [['soulfire', 2], ['drain', 2], ['attack', 1]], drops: [['draught', 0.3]] },
  wyrm:   { name: 'Ember Wyrm', boss: true, final: true, hp: 620, atk: 28, def: 15, mag: 25, spd: 12, xp: 0, gold: 400, weak: ['ice'], resist: ['fire'], sprite: 'wyrm', pal: 'wyrm', scale: 4, ai: [['claw', 3], ['breath', 3], ['tail', 2], ['roar', 1]], drops: [] },
};

const STATUS_INFO = {
  poison: { name: 'Poison', tick: 0.07 },
  burn:   { name: 'Burn', tick: 0.08 },
  slow:   { name: 'Slow' },
  stun:   { name: 'Stun' },
};

const LEVEL_CAP = 20;
function xpToNext(lv) { return Math.floor(8 * Math.pow(lv, 1.5)) + 6; }

function rnd(a, b) { return a + Math.random() * (b - a); }
function rint(a, b) { return Math.floor(rnd(a, b + 1)); }
function pick(arr) { return arr[Math.floor(Math.random() * arr.length)]; }
function clamp(v, a, b) { return Math.max(a, Math.min(b, v)); }
function weighted(pairs) {
  const total = pairs.reduce((s, p) => s + p[1], 0);
  let r = Math.random() * total;
  for (const p of pairs) { r -= p[1]; if (r <= 0) return p[0]; }
  return pairs[pairs.length - 1][0];
}
const sleep = ms => new Promise(r => setTimeout(r, ms));

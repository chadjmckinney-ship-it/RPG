'use strict';
// World maps. Digits are warps, lowercase letters are NPC/boss markers,
// '@' is the starting tile. Chests ('C') and signs ('S') are filled in reading order.
//
// Tiles: . grass  , tall grass  T tree  Y pine  ~ water  : path  B bridge
//        M rock  * flowers  R roof  W wall  O window wall  _ floorboards
//        # interior wall  | counter  Z fence  X cave wall  ; cave floor
//        L lava  S sign  C chest  E bed  K bookshelf  P well  V spring  J iron gate

const QUESTS = {
  main: {
    name: 'The Stolen Hearthfire',
    step() {
      if (!flag('metElder')) return 'Speak with Elder Maren in her house in Hollowmere.';
      if (!has('wardenkey') && !flag('gateOpen')) return 'Find the Warden\'s Key in the Gloamwood, up the north road from the crossroads.';
      if (!flag('gateOpen')) return 'Unlock the sealed gate inside Cinder Hollow, south-east of the crossroads.';
      if (!flag('wyrmSlain')) return 'Descend to the Wyrm\'s Maw and take back the Hearthfire.';
      if (!flag('ending')) return 'Carry the Hearthfire home to Elder Maren.';
      return 'Hollowmere is warm again.';
    },
    done: () => flag('ending'),
  },
  herbs: {
    name: 'Moonpetals for Wren',
    step() {
      if (flag('herbsDone')) return 'Wren brewed her salve. The ward is yours.';
      const n = count('moonpetal');
      return `Gather 3 Moonpetals in the Gloamwood (${Math.min(n, 3)}/3), then bring them to Wren.`;
    },
    done: () => flag('herbsDone'),
  },
};

const NPC_PAL = {
  guard: 'guard', child: 'child', elder: 'elder', villager: 'villager', merchant: 'merchant', herbalist: 'herbalist',
};

const MAPS = {
  town: {
    name: 'Hollowmere', sub: () => flag('ending') ? 'Warm again' : 'A village gone cold', theme: 'town', music: 'town', floor: '.',
    rows: [
      'TTTTTTTTTTTTTTTTTTTTTTTTTT',
      'T*....T.....::.....T...*.T',
      'T.RRRRR.....::....RRRRRR.T',
      'T.RRRRR.....::....RRRRRR.T',
      'T.WOW2W.....::....WOW3OW.T',
      'T....:......::.......:...T',
      'T....:::::::::::::::::...T',
      'T.*.....a...::.......*...T',
      'T...ZZZZZ...::..P........T',
      'T...Z***Z...::...........T',
      'T...ZZZZZ...::......b....1',
      'T...........:::::::::::::1',
      'T.RRRR......::.....RRRRR.T',
      'T.RRRR......::.....RRRRR.T',
      'T.WW4W......::.....WO5OW.T',
      'T...:.......::.......:...T',
      'T...::::::::::::::::::...T',
      'T.*...c.....S.........*..T',
      'T.........@..............T',
      'TTTTTTTTTTTTTTTTTTTTTTTTTT',
    ],
    warps: {
      1: { to: 'field', at: '1', look: 'path', face: 'right' },
      2: { to: 'inn', at: '1', look: 'door', face: 'up' },
      3: { to: 'shop', at: '1', look: 'door', face: 'up' },
      4: { to: 'elder', at: '1', look: 'door', face: 'up' },
      5: { to: 'herbalist', at: '1', look: 'door', face: 'up' },
    },
    signs: ['HOLLOWMERE\nInn to the north-west, Tallow\'s Goods to the north-east.\nElder Maren lives south-west. East road leads to the river.'],
    npcs: {
      a: { name: 'Tobin', look: 'guard', wander: 2, async talk() {
        if (flag('ending')) return say('Tobin', 'Warm hands on the night watch. I\'d forgotten what that felt like.');
        if (!flag('metElder')) return say('Tobin', 'Three nights since the Hearthfire went out. Elder Maren has been asking for anyone with a sword. Her house is the one to the south-west.');
        await say('Tobin', 'Monsters thicken the further you go from the village. Tall grass is where they hide.');
        return say('Tobin', 'If you get hurt, the inn\'s cheap. Pell will even save your progress while you sleep.');
      } },
      b: { name: 'Pip', look: 'child', wander: 3, async talk() {
        if (flag('wyrmSlain')) return say('Pip', 'You beat the dragon? Did you use snowballs? I KNEW it!');
        return say('Pip', 'Mum says the thing in the Hollow breathes fire. I bet it hates snowballs. Everything made of fire hates snowballs.');
      } },
      c: { name: 'Old Hask', look: 'villager', async talk() {
        if (!has('wardenkey') && !flag('gateOpen')) return say('Old Hask', 'The wardens sealed Cinder Hollow before my grandfather was born. Their key went missing in the Gloamwood. Something big nests there now.');
        return say('Old Hask', 'Fire-things fear the cold, and a Frost Vial or two never hurt anyone who wasn\'t on fire.');
      } },
    },
  },

  inn: {
    name: 'The Banked Coal', theme: 'inside', music: 'town', floor: '_',
    rows: [
      '###########',
      '#E_E_E__KK#',
      '#_________#',
      '#____a____#',
      '#|||||||__#',
      '#_________#',
      '#_b_______#',
      '#####1#####',
    ],
    warps: { 1: { to: 'town', at: '2', look: 'mat', face: 'down' } },
    npcs: {
      a: { name: 'Pell', look: 'merchant', async talk() {
        const price = 8 + G.hero.lv * 2;
        const c = await ask('Pell', `A bed and a hot meal is ${price} gold. Sleeping here also saves your journey. Staying?`, [`Rest (${price}g)`, 'Not now']);
        if (c !== 0) return say('Pell', 'Door\'s always open.');
        if (G.gold < price) return say('Pell', 'That\'s a little short, friend. Come back when your purse is heavier.');
        G.gold -= price;
        await Game.rest();
        Game.save(true);
        return say('Pell', 'Morning! You look like a new person. Your journey is saved.');
      } },
      b: { name: 'Lute-player', look: 'villager', wander: 2, async talk() {
        await say('Lute-player', 'Want a tip from a man who writes songs about better people? Open the menu to equip what you find. Chests don\'t equip themselves.');
        return say('Lute-player', 'And save often. Songs about heroes who forgot to save are very short.');
      } },
    },
  },

  shop: {
    name: 'Tallow\'s Goods', theme: 'inside', music: 'town', floor: '_',
    rows: [
      '###########',
      '#KK__K__KK#',
      '#____a____#',
      '#|||||||__#',
      '#_________#',
      '#_________#',
      '#####1#####',
    ],
    warps: { 1: { to: 'town', at: '3', look: 'mat', face: 'down' } },
    npcs: {
      a: { name: 'Tallow', look: 'merchant', async talk() {
        const stock = ['tonic', 'draught', 'remedy', 'flask', 'frostvial', 'gtonic', 'leather'];
        const tier1 = { knight: 'ironsword', mage: 'willowrod', rogue: 'steeldirk' }[G.hero.cls];
        const tier2 = { knight: 'steelblade', mage: 'runedstaff', rogue: 'serpent' }[G.hero.cls];
        stock.push(tier1);
        if (flag('alphaSlain')) stock.push(tier2, 'scale');
        await say('Tallow', flag('alphaSlain') ? 'You took down the Thornback? Then you\'ve earned a look at the good shelf.' : 'Welcome, welcome. Everything\'s honest, most of it\'s sharp.');
        await UI.shop(stock, 'Tallow\'s Goods');
        return say('Tallow', 'Come back alive, that\'s the best way to come back.');
      } },
    },
  },

  elder: {
    name: 'Maren\'s House', theme: 'inside', music: 'town', floor: '_',
    rows: [
      '#########',
      '#K__E__K#',
      '#_______#',
      '#___a___#',
      '#_______#',
      '#_______#',
      '####1####',
    ],
    warps: { 1: { to: 'town', at: '4', look: 'mat', face: 'down' } },
    npcs: {
      a: { name: 'Elder Maren', look: 'elder', async talk() {
        if (flag('ending')) return say('Elder Maren', 'The Hearthfire has never burned brighter. Stay as long as you like. Hollowmere is your home now.');
        if (has('hearthember')) return Game.ending();
        if (!flag('metElder')) {
          await say('Elder Maren', `So you\'re the traveler. ${G.hero.name}, is it? You picked a poor week to visit.`);
          await say('Elder Maren', 'Three nights ago something crawled out of Cinder Hollow and stole our Hearthfire. That flame has kept this valley alive through two hundred winters.');
          await say('Elder Maren', 'The old wardens sealed the Hollow behind an iron gate. Their key was lost in the Gloamwood, north of the crossroads. A beast called the Thornback nests there now.');
          await say('Elder Maren', 'Find the key. Open the Hollow. Bring back our fire. Take these. They won\'t be enough, but they\'re what we have.');
          setFlag('metElder');
          give('tonic', 3); addGold(40);
          await say('', `Received 3 Tonics and 40 gold.`);
          return;
        }
        if (!flag('gateOpen') && !has('wardenkey')) return say('Elder Maren', 'The Gloamwood is north of the crossroads, past the river. Be careful of the Thornback.');
        if (!flag('gateOpen')) return say('Elder Maren', 'The wardens\' key! Cinder Hollow is south-east of the crossroads. The gate is deep inside.');
        return say('Elder Maren', 'The Wyrm\'s Maw lies below the gate. Whatever took our fire waits there. Frost will serve you better than flame.');
      } },
    },
  },

  herbalist: {
    name: 'Wren\'s Cottage', theme: 'inside', music: 'town', floor: '_',
    rows: [
      '#########',
      '#KK___EK#',
      '#_______#',
      '#__a____#',
      '#_______#',
      '#_______#',
      '####1####',
    ],
    warps: { 1: { to: 'town', at: '5', look: 'mat', face: 'down' } },
    npcs: {
      a: { name: 'Wren', look: 'herbalist', async talk() {
        if (flag('herbsDone')) return say('Wren', 'The ward will hold against dragonfire, or at least half of it. Mind the other half.');
        if (!flag('herbsGiven')) {
          await say('Wren', 'Oh! A visitor. Sorry about the smell, I\'m boiling nettles.');
          await say('Wren', 'If you\'re going into the Gloamwood, would you look for Moonpetals? They glow a little. I need three for a salve that turns aside fire.');
          const c = await ask('Wren', 'Would you gather them for me?', ['Of course', 'Maybe later']);
          if (c !== 0) return say('Wren', 'The offer stays open. So does the window, unfortunately.');
          setFlag('herbsGiven');
          Game.startQuest('herbs');
          return say('Wren', 'Wonderful! Three Moonpetals. They grow in hidden corners, so look off the path.');
        }
        if (count('moonpetal') >= 3) {
          take('moonpetal', 3);
          await say('Wren', 'Three perfect Moonpetals! Give me a moment...');
          await say('Wren', 'There. An Ember Ward, soaked in moonpetal salve. Wear it and fire will only half-burn you.');
          give('emberward', 1); addGold(60); setFlag('herbsDone');
          Game.completeQuest('herbs');
          return say('', 'Received the Ember Ward and 60 gold. Equip it from the menu.');
        }
        return say('Wren', `You have ${count('moonpetal')} of 3 Moonpetals. They hide in the corners of the Gloamwood.`);
      } },
    },
  },

  field: {
    name: 'Rivermarch', sub: 'The old east road', theme: 'field', music: 'field', floor: '.',
    rows: [
      'TTTTTTTTTTTTTT~~~TTTTTTTTTTTTT2TTTTTTTTT',
      'T..T.......T..~~~..T.......T..:...T....T',
      'T.............~~~..,,,,,,,,,..:........T',
      'T..,,,,,,,,...~~~..,,,,,,,,,..:..*.....T',
      'T..,,,,,,,,...~~~..,,,,,,,,,T.:........T',
      'T.T,,,,,,,,...~~~..,,,,,,,,,..:....T...T',
      'T..,,,,,,,,.*.~~~*.,,,,,,,,,..:........T',
      'T..,,,,,,,,...~~~..,,,,,,,,,..:..M.....T',
      'T..,,,,,,,,...~~~..........T..:..,,,,,,T',
      'T...........T.~~~.............:..,,,,C,T',
      'T..T..........~~~...*.........:..,,,,,,T',
      'T.............~~~......T......:..,,,,,,T',
      'T....*........~~~.............:..,,,,,,T',
      '1..........a..~~~.............:S.......T',
      '1:::::::::::::BBB::::::::::::::........T',
      'T.............~~~...........b.:........T',
      'T..T.......*..~~~.............:...T....T',
      'T..,,,,,,,,,..~~~.,,,,,,,,,,..:........T',
      'T..,,,,,,,,,..~~~.,,,,,,,,,,..:......T.T',
      'T..,,,,,,,,,..~~~.,,,,,,,,,,..:........T',
      'T..,C,,,,,,,..~~~.,,,,,,,,,,..:........T',
      'T..,,,,,,,,,..~~~.,,,,,,,,,,..:..MMMMMMT',
      'T..,,,,,,,,,..~~~.,,,,,,,,,,..:::::MMMMT',
      'T..,,,,,,,,,..~~~............MMMMM3MMMMT',
      'T.............~~~...........MMMMMMMMMMMT',
      'T..T......T...~~~..T.......MMMMMMMMMMMMT',
      'T.............~~~..........MMMMMMMMMMMMT',
      'TTTTTTTTTTTTTT~~~TTTTTTTTTTTTTTTTTTTTTTT',
    ],
    warps: {
      1: { to: 'town', at: '1', look: 'path', face: 'left' },
      2: { to: 'woods', at: '1', look: 'path', face: 'up' },
      3: { to: 'cave1', at: '1', look: 'cave', face: 'up' },
    },
    chests: [{ item: 'draught', n: 2 }, { item: 'tonic', n: 3 }],
    signs: ['CROSSROADS\nNorth: the Gloamwood.\nSouth-east: Cinder Hollow (sealed).\nWest: Hollowmere.'],
    enc: { rates: { ',': 0.1 }, groups: [['slime'], ['slime', 'slime'], ['rat'], ['rat', 'slime'], ['beetle'], ['rat', 'rat'], ['beetle', 'slime']] },
    npcs: {
      a: { name: 'Ser Aldric', look: 'guard', async talk() {
        await say('Ser Aldric', 'Hold, traveler. A word from an old soldier: Defend when a big blow is coming. It halves the damage.');
        return say('Ser Aldric', 'And the beetles here have shells like anvils, but they burn beautifully.');
      } },
      b: { name: 'Ottilie', look: 'merchant', async talk() {
        await say('Ottilie', 'Road-goods! Tonics, draughts, flasks. Cheaper than dying.');
        return UI.shop(['tonic', 'draught', 'remedy', 'flask', 'frostvial'], 'Ottilie\'s Cart');
      } },
    },
  },

  woods: {
    name: 'The Gloamwood', sub: 'Where the light gets lost', theme: 'woods', music: 'woods', floor: '.',
    rows: [
      'YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY',
      'YYYYYYYYYYYY.......YYYYYYYYYYYYY',
      'YYYYYYYYYYY..*...*..YYYYYYYYYYYY',
      'YYYYYYYYYYY....z....YYYYYYYYYYYY',
      'YYYYYYYYYYYY...:...YYYYYYYYYYYYY',
      'YYYYYYYYYYYYYY.:.YYYYYYYYYYYYYYY',
      'YYYYYYYYYYYYYY,:,YYYYYYYYYYYYYYY',
      'YYYYYYYYYYYYYY,:,YYYYYYYYCYYYYYY',
      'YYYYYYYYYYYYYY.:.YYYYYYY,,:,YYYY',
      'YYYYY..*V.YYYY.:.YYYYYYY,,:,YYYY',
      'YYYYY.::::::::::.,,,,,YY,,:,YYYY',
      'YYYYY,:,YYYYYY..,,,,,,YY,,:,YYYY',
      'YYYYY,:,YYYYYY...,,,C,YY,,:,YYYY',
      'YY,,,,:,YYYYYYYYYYYYYYYY,,:,YYYY',
      'YY,C,,:,YYYYYYYYYYYYYYYY,,:,YYYY',
      'YY,,,,:,YYYYYYYYYYYYYYYY,,:,YYYY',
      'YY....:.YYYYYYYYYYYYYYYY,,:,YYYY',
      'YY....:::::::::::::::::::::...YY',
      'YYYYY.,,,,,,,,,,:.,,,,,,,,,...YY',
      'YYYYYYY,,,,,,,,.:.,,,,,,,,,,..YY',
      'YYYYYYYY,,,,,,..:.,,,,,,,,,,.CYY',
      'YYYYYYYYY.......:a...YYYYYYYYYYY',
      'YYYYYYYYYYYYYYY.:.YYYYYYYYYYYYYY',
      'YYYYYYYYYYYYYYYY1YYYYYYYYYYYYYYY',
    ],
    warps: { 1: { to: 'field', at: '2', look: 'path', face: 'down' } },
    chests: [{ item: 'moonpetal', n: 1 }, { item: 'moonpetal', n: 1 }, { item: 'moonpetal', n: 1 }, { item: 'swiftband', n: 1 }],
    enc: { rates: { ',': 0.11, '.': 0.035, ':': 0.02 }, groups: [['wolf'], ['sprite'], ['toad'], ['wolf', 'sprite'], ['sprite', 'sprite'], ['wolf', 'wolf'], ['toad', 'sprite']] },
    npcs: {
      a: { name: 'Hunter Bryn', look: 'villager', async talk() {
        if (flag('alphaSlain')) return say('Hunter Bryn', 'The woods are quieter without the Thornback. Still wouldn\'t nap in them.');
        await say('Hunter Bryn', 'You\'re heading in? The Thornback Alpha has a den in the clearing at the far north end. It\'s poisoned three of my dogs.');
        if (!flag('brynGift')) {
          setFlag('brynGift'); give('remedy', 3);
          await say('', 'Received 3 Remedy Leaves.');
        }
        return say('Hunter Bryn', 'There\'s a clear spring off the west path. Drink from it and you\'ll feel new.');
      } },
      z: { name: 'Thornback Alpha', enemy: 'alpha', aggro: 2, hideIf: 'alphaSlain', async talk() {
        await say('', 'A wolf the size of a cart rises from a nest of bones. Thorns bristle down its spine.');
        const r = await Game.battle(['alpha'], { boss: true, music: 'boss' });
        if (r !== 'win') return;
        setFlag('alphaSlain');
        give('wardenkey', 1);
        await say('', 'Among the bones of its nest you find an iron key etched with the wardens\' sigil.');
        return say('', 'Obtained the Warden\'s Key.');
      } },
    },
  },

  cave1: {
    name: 'Cinder Hollow', sub: 'Sealed by the wardens', theme: 'cave', music: 'cave', floor: ';',
    rows: [
      'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX',
      'XXXXXXXXXXXXX;;;;XXXXXXXXXXXXX',
      'XXXXXXXXXXXXX;;2;XXXXXXXXXXXXX',
      'XXXXXXXXXXXXX;;;;XXXXXXXXXXXXX',
      'XXXXXXXXXXXX;;;;;;XXXXXXXXXXXX',
      'XXXXXXXXXXXX;;;;;;XXXXXXXXXXXX',
      'XXXXXXXXXXXXXXXJXXXXXXXXXXXXXX',
      'X;;;;;XXXXXXX;;;;;XXXXXX;;C;;X',
      'X;;;;;;;LLLL;;;;;;LLLL;;;;;;;X',
      'X;;;XX;;LLLL;;;;;;LLLL;;XX;;;X',
      'X;;;XX;;;LL;;;;;;;;LL;;;XX;;;X',
      'X;;;;;;;;;;;;XXXX;;;;;;;;;;;;X',
      'XXXXX;;;;;;;;XXXX;;;;;;;;XXXXX',
      'XC;;;;;LLL;;;;;;;;;;LLL;;;;;CX',
      'X;;;;;;LLL;;;XXXX;;;LLL;;;;;;X',
      'X;;XX;;;;;;;;;;;;;;;;;;;;XX;;X',
      'X;;XX;;;;LLLLLLLLLLLL;;;;XX;;X',
      'X;;;;;;;;;;;;;a;;;;;;;;;;;;;;X',
      'XXXXXXXXXXXXX;;;;XXXXXXXXXXXXX',
      'XXXXXXXXXXXXX;;;;XXXXXXXXXXXXX',
      'XXXXXXXXXXXXXX;;XXXXXXXXXXXXXX',
      'XXXXXXXXXXXXXXX1XXXXXXXXXXXXXX',
    ],
    warps: {
      1: { to: 'field', at: '3', look: 'light', face: 'down' },
      2: { to: 'cave2', at: '1', look: 'down', face: 'down' },
    },
    chests: [{ item: 'feather', n: 1 }, { relic: true }, { gold: 180 }],
    enc: { rates: { ';': 0.07 }, groups: [['bat'], ['magma'], ['bones'], ['bat', 'bat'], ['wraith'], ['bat', 'magma'], ['bones', 'bat'], ['wraith', 'bat']] },
    npcs: {
      a: { name: 'Warden\'s Echo', look: 'ghost', async talk() {
        await say('Warden\'s Echo', '...another one... come to wake it further...');
        await say('Warden\'s Echo', 'We sealed the Wyrm below with frost and iron. The frost failed. Only iron remains... and the key you may carry.');
        if (!has('wardenkey') && !flag('gateOpen')) return say('Warden\'s Echo', 'Without our key, the gate to the north will not yield.');
        return say('Warden\'s Echo', 'Strike it with cold. Guard against its breath. And do not let it roar unanswered.');
      } },
    },
  },

  cave2: {
    name: 'The Wyrm\'s Maw', sub: 'Heat rises from below', theme: 'cave', music: 'cave', floor: ';',
    rows: [
      'XXXXXXXXXXXXXXXXXXXXXXXX',
      'XXXXXXXXXC;;;;CXXXXXXXXX',
      'XXXXXXXX;;;;;;;;XXXXXXXX',
      'XXXXXX;;;;;;;;;;;;XXXXXX',
      'XXXXX;;LL;;;;;;LL;;XXXXX',
      'XXXXX;;LL;;;z;;LL;;XXXXX',
      'XXXXX;;;;;;;;;;;;;;XXXXX',
      'XXXXXX;;;;;;;;;;;;XXXXXX',
      'XXXXXXXXX;;;;;;XXXXXXXXX',
      'XXXXXXXXXX;;;;XXXXXXXXXX',
      'XXXXXXXXXX;;;;XXXXXXXXXX',
      'XXXXXXX;;;;;;;;;;XXXXXXX',
      'XXXXXXX;LL;;;;LL;XXXXXXX',
      'XXXXXXX;LL;;;;LL;XXXXXXX',
      'XXXXXXX;;;;;;;;;;XXXXXXX',
      'XXXXXXXXXX;;;;XXXXXXXXXX',
      'XXXXXXXXXXX;;XXXXXXXXXXX',
      'XXXXXXXXXXXX1XXXXXXXXXXX',
    ],
    warps: { 1: { to: 'cave1', at: '2', look: 'up', face: 'up' } },
    chests: [{ item: 'wardenplate', n: 1 }, { item: 'sagependant', n: 1 }],
    enc: { rates: { ';': 0.05 }, groups: [['bones', 'wraith'], ['magma', 'bat'], ['wraith', 'wraith'], ['bones']] },
    noEncIf: 'wyrmSlain',
    npcs: {
      z: { name: 'Ember Wyrm', enemy: 'wyrm', aggro: 3, hideIf: 'wyrmSlain', async talk() {
        await say('', 'The cavern floor shifts. What you took for a ridge of cooled lava opens one burning eye.');
        await say('Ember Wyrm', 'LITTLE FLAME-THIEF. YOU WALK INTO MY HEARTH AND SPEAK OF STEALING.');
        await say('Ember Wyrm', 'THE FIRE IS MINE. IT WAS ALWAYS MINE. COME AND BURN.');
        const r = await Game.battle(['wyrm'], { boss: true, music: 'boss', final: true });
        if (r !== 'win') return;
        setFlag('wyrmSlain');
        give('hearthember', 1);
        await say('', 'The Wyrm collapses into cinders. In the ashes, the Hearthfire still burns, cupped in a shard of obsidian.');
        await say('', 'Obtained the Hearthfire. Take it home to Elder Maren.');
        Game.setMusic('cave');
      } },
    },
  },
};

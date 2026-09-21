"""Monster recipes and explicit playtest tuning; independent Python rules."""
from . import dotra_shroud as shroud
from . import economy as e
from .copying import copy_data
VERSION = "U13_MONSTERS_V21_TUMLER_CHARGE"
ROSTER = {'Lemek': {'tier': 'Easy',
           'recipe': {'Penitent': 2},
           'attack': 5,
           'armor': 7,
           'speed': 2,
           'hp': 10,
           'ability': 'On death, leaves a slowing pool through the following round. Ground units '
                      'inside move at half speed. All Lemeks are immune, regardless of side.'},
 'Varn': {'tier': 'Easy',
          'recipe': {'Vulture': 2},
          'attack': 1,
          'armor': 0,
          'speed': 2,
          'hp': 4,
          'ability': 'Summons 3–5 bodies. Each damaging hit has a 10% chance to poison: 1 HP immediately, then twice more about 2 seconds apart. Bypasses Armor. Reapplication refreshes three remaining ticks without stacking or advancing the next tick.'},
 'Fyra': {'tier': 'Moderate',
          'recipe': {'Butcher': 2, 'Vulture': 2},
          'attack': 2,
          'armor': 1,
          'speed': 4,
          'hp': 10,
          'ability': 'Flies over ground hazards. Each hit has a 30% chance to charm a surviving '
                     'target for the rest of this round. Ownership returns before the next round.'},
 'Kopita': {'tier': 'Moderate',
            'recipe': {'Wright': 2, 'Penitent': 2},
            'attack': 2,
            'armor': 1,
            'speed': 2,
            'hp': 10,
            'ability': 'Pulses twice per active round: at the start and about 10 seconds in. If '
                       'any ally within 360, including herself, is wounded, heals nearby allies 1 '
                       'HP; otherwise deals 2 damage to nearby enemies. Slows near allied '
                       'front-line fighters to stay behind them.'},
 'Tumler': {'tier': 'Moderate',
            'recipe': {'Vulture': 2, 'Wright': 2},
            'attack': 2,
            'armor': 1,
            'speed': 3,
            'hp': 10,
            'ability': 'Hunts Sooge, then Kopita, Fyra, Vulture, then other enemies. At range 400, braces for about half a second with +5 temporary Armor, then charges through the crowd. Fear, retreat and charm cannot cancel the rush. If the target is lost, finishes at its last known position. Walls stop him. Pushes bystanders sideways, never the chosen target. Stays on a surviving victim, with +1 damage against it. No impact damage. Charge cooldown: 15 seconds. Unspent temporary Armor expires on landing. Cannot be taunted or intercepted during the rush. Keeps 50% evasion against direct attacks; poison cannot be dodged.'},
 'Kurchin': {'tier': 'Hard',
             'recipe': {'Penitent': 3, 'Wright': 1},
             'attack': 1,
             'armor': 6,
             'speed': 1,
             'hp': 15,
             'ability': 'Taunts enemies within 180, pulling them off engaged targets to approach '
                        'and attack him. Walls still block approach. While Armor remains, deflects '
                        '50% of direct attacks without losing Armor or HP. Landed hits deal normal '
                        'damage; deflection ends when Armor is depleted. Poison cannot be '
                        'deflected.'},
 'Muno': {'tier': 'Hard',
          'recipe': {'Wright': 3, 'Vulture': 1},
          'attack': 3,
          'armor': 1,
          'speed': 2,
          'hp': 10,
          'ability': 'Every 7.5 seconds while a target is in range, dashes to an enemy within 480 for one free melee '
                     'strike, then dashes back. The lingering afterimage cancels the next damaging hit before Armor is spent. Holds one charge until used; later lunges can replenish it.'},
 'Dotra': {'tier': 'Hard',
           'recipe': {'Butcher': 3, 'Vulture': 1},
           'attack': 2,
           'armor': 2,
           'speed': 2,
           'hp': 10,
           'ability': 'Once per summon, hides after his first 15 seconds on the field. Protected staging and birth hold do not count. Stalks at full speed while hidden until delivering a 5-damage ambush within 240. On emergence, remains visible and can fight but cannot be targeted for 5 seconds; area damage and existing poison still affect him. Exposes enemies within 360 for one full round: +1 incoming damage per hit, before Armor. Refreshes but never stacks. Blocks and evasion still prevent damage.'},
 'Sooge': {'tier': 'Very hard',
           'recipe': {'Butcher': 3, 'Wright': 2},
           'attack': 1,
           'armor': 2,
           'speed': 2,
           'hp': 5,
           'ability': 'Stays behind nearby allied front-line fighters while mobile. Root chance '
                      'starts at 25%, rising by 15 percentage points each active round it stays '
                      'mobile, up to 100%. Permanently becomes a turret: 3 Attack / 6 Armor / 0 '
                      'Speed. Charges before firing once per round at the nearest enemy. The '
                      'blue-white beam traces the ground to range 1800, then detonates shortly '
                      'afterward: 3 damage to enemies and 1 to allies in its path. One living copy '
                      'per player.'},
 'Sinodek': {'tier': 'Very hard',
             'recipe': {'Wright': 3, 'Vulture': 2},
             'attack': 1,
             'armor': 3,
             'speed': 1,
             'hp': 5,
             'ability': 'Stays behind nearby allied front-line fighters. Once each active round, '
                        'when a visible enemy unit is within 600, has a 25% chance to open a '
                        'portal on the nearest enemy for that Marching phase. Waits if no enemy is '
                        'in range. Nearby units flee; entering units, including allies beside the '
                        'target, are banished without death triggers or resurrection. Immune to '
                        "his own portal's fear and banishment. One living copy per player."}}

NAMES = tuple(ROSTER)


def configure(w):
    w['data']['monsters'] = dict(version=VERSION, unlocked=[list(NAMES),list(NAMES)], fields=[], pending_beams=[], death_ids=[], phase_round=0)

def enabled(w):
    return w.get('data',{}).get('monsters',{}).get('version') == VERSION

def profile(name,lane,pid,birth,ready,turret=False):
    r=ROSTER[name]
    a=dict(suit='Monster',monster_id=name,attack=3 if turret else r['attack'],armor=6 if turret else r['armor'],
                max_armor=6 if turret else r['armor'],step_fp=0 if turret else r['speed']*2,hp=r['hp'],max_hp=r['hp'],regen=1,
                armor_bypass=False,lane=lane,birth_round=birth,movement_ready_round=ready,x_fp=0 if pid==0 else 2400,
                y_fp=300,contact_tick=-1,direction=1 if pid==0 else -1,waiting=False,waiting_since_round=0,
                sprite_form='turret' if turret else 'mobile',flying=name=='Fyra')
    if name=='Muno':a.update(muno_ward=False,muno_next_tick=0)
    if name=='Sooge':a.update(sooge_root_attempts=0,sooge_root_round=0)
    return a

def root_chance(a):
    return min(100,TUNING['sooge_root_chance']+a.get('sooge_root_attempts',0)*TUNING['sooge_root_increase'])

def valid_unit(a):
    if not shroud.valid(a):return False
    if 'tumler_engaged_target' in a:
        if (a.get('monster_id') != 'Tumler' or type(a['tumler_engaged_target']) is not str
                or type(a.get('tumler_engaged_owner')) is not int):return False
        if ((not a['tumler_engaged_target'] and a['tumler_engaged_owner'] != -1)
                or (a['tumler_engaged_target'] and a['tumler_engaged_owner'] not in (0, 1))):return False
    elif 'tumler_engaged_owner' in a:return False
    for coordinate, maximum in [('tumler_charge_goal_x_fp', 2400), ('tumler_charge_goal_y_fp', 600)]:
        if coordinate in a and (type(a[coordinate]) is not int or not 0 <= a[coordinate] <= maximum):return False
    if 'poison_ticks_left' in a:
        if type(a['poison_ticks_left']) is not int or not 0<=a['poison_ticks_left']<=3:return False
        if type(a.get('poison_next_tick')) is not int or not 0<=a['poison_next_tick']<=9007199254740991:return False
        if a['poison_ticks_left']>0 and type(a.get('poison_source')) is not dict:return False
    if 'tumler_charge_phase' in a:
        if a.get('monster_id') != 'Tumler' or a['tumler_charge_phase'] not in ('','windup','charge') or type(a.get('tumler_charge_target','')) is not str:return False
        if a['tumler_charge_phase'] and (a.get('tumler_charge_owner',-1) not in (0,1) or any(k not in a for k in ('tumler_charge_ready_tick','tumler_charge_end_tick','tumler_charge_base_armor'))):return False
    if 'monster_id' not in a:return a.get('suit')!='Monster'
    for key in ('tumler_charge_next_tick','tumler_charge_motion_tick','tumler_charge_ready_tick','tumler_charge_end_tick','tumler_charge_base_armor','muno_next_tick','sooge_root_attempts','sooge_root_round','beam_next_tick','beam_charge_tick','beam_ready_tick','dotra_concealment_round','dotra_hide_at_tick','sinodek_portal_round','kopita_pulses','kopita_last_pulse_tick'):
        if key in a and (type(a[key]) is not int or not 0<=a[key]<=9007199254740991):return False
    return (a.get('suit')=='Monster' and a['monster_id'] in NAMES and a.get('sprite_form') in ('mobile','turret')
            and (a['sprite_form']!='turret' or a['monster_id']=='Sooge') and type(a.get('flying')) is bool)

def limited(name):return name in ('Sooge','Sinodek')

def living(rows,pid,name,except_id=''):
    return any(r['kind']=='marcher' and (r['owner']==pid or r['attributes'].get('charm_owner',-1)==pid) and r['id']!=except_id and r['attributes'].get('monster_id')==name for r in rows)

def qualifies(rows,card_ids,name):
    if name not in NAMES or len(set(card_ids))!=len(card_ids):return False
    counts={}
    for r in rows:
        if r['kind']=='card' and r['id'] in card_ids:
            suit=r['attributes']['suit'];counts[suit]=counts.get(suit,0)+1
    return all(counts.get(suit,0)>=amount for suit,amount in ROSTER[name]['recipe'].items())

def available(rows,card_ids,pid,unlocked=NAMES):
    return [name for name in NAMES if name in unlocked and qualifies(rows,card_ids,name)
            and (not limited(name) or not living(rows,pid,name))]

def reserves(w):
    return (list(w.get('data',{}).get('marcher_staging',{}).get('units',[])) +
            [u for tray in w.get('data',{}).get('game_staging',{}).get('lanes',{}).values() for u in tray['units']])


def validate_choice(w,pid,order):
    if 'monster_choice' in order:
        e.require(enabled(w) and order['monster_choice'] in available(w['entities']['entities']+reserves(w),order.get('card_ids',[]),pid,w['data']['monsters']['unlocked'][pid]),'monster_recipe_unavailable')

TUNING = {'tumler_charge_range': 400, 'tumler_charge_armor': 5, 'tumler_charge_windup_ticks': 7, 'tumler_charge_step_fp': 36, 'tumler_charge_max_ticks': 40, 'tumler_charge_cooldown_ticks': 200, 'tumler_evasion_chance': 50, 'tumler_hunt_bonus': 1,
 'kurchin_deflection_chance': 50, 'varn_poison_chance': 10, 'varn_poison_ticks': 3, 'varn_poison_interval_ticks': 27,
 'fyra_charm_chance': 30,
 'kopita_radius': 360,
 'kopita_second_pulse_tick': 133,
 'taunt_radius': 180,
 'muno_radius': 480, 'muno_interval_ticks': 100, 'kopita_damage': 2,
 'dotra_hide_delay_ticks': 200,
 'dotra_ambush_radius': 240, 'dotra_expose_radius': 360, 'dotra_expose_ticks': 200, 'dotra_shroud_ticks': 67,
 'sooge_root_chance': 25,
 'sooge_root_increase': 15,
 'beam_range': 1800,
 'beam_half_width': 70,
 'beam_interval_ticks': 200,
 'beam_charge_ticks': 32,
 'beam_blast_delay_ticks': 8,
 'sinodek_portal_chance': 25,
 'portal_target_range': 600,
 'portal_radius': 100,
 'portal_fear_radius': 300,
 'pool_radius': 200}

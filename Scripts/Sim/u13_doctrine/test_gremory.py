"""Ruin's delayed damage, disjoint card payments, and authority timing."""
import unittest

from u13_pysim import economy, full_match_inputs, power_components
from u13_pysim.copying import copy_data
from u13_pysim.power_rules import declaration
from .budget import Budget, Limits
from .common import CommonSmartCore, Weights
from .coordination import context, evaluate
from .facts import Facts, Proposal
from .lords.gremory import RuinPlans, discard_pair, ruin_value
from .observation import observe, Preview
from .test_common import planning
from .test_recipes_veil import hand


def fixture():
    v = observe(planning('Gremory'), 0)
    hand(v, [('Butcher', 4)]*3+[('Wright', 1)]*2)
    return v


def attack(f, target, n=3, action='Siege'):
    ids = [r['id'] for r in f.hand if r['attributes']['suit'] == 'Butcher'][:n]
    return dict(powers=[], order=dict(action=action, lane='Castle' if action == 'Siege' else 'Lord',
                target_id=target, card_ids=ids))


class GremoryTests(unittest.TestCase):
    def test_siege_spends_damage_before_delayed_ruin(self):
        f = Facts(fixture()); target = f.castles(1)[1]['id']
        empty = ruin_value(f, target, dict(powers=[], order={}))
        partial = ruin_value(f, target, attack(f, target, 2))
        exhausted = ruin_value(f, target, attack(f, target))
        self.assertEqual((9, 1, 0), (empty['damage'], partial['damage'], exhausted['damage']))
        self.assertEqual(5, exhausted['integrity_before_ruin'])
        self.assertEqual('own_damage_exhausts_ruin_target', exhausted['reason'])

    def test_hunt_keep_damage_counts_too(self):
        f = Facts(fixture()); keep = f.castles(1)[0]['id']
        value = ruin_value(f, keep, attack(f, f.lord[1]['id'], action='Hunt'))
        self.assertEqual(8, value['integrity_before_ruin'])
        self.assertEqual(0, value['score'])

    def test_locked_artillery_precedes_attack_and_unknown_target_is_not_invented(self):
        v = fixture(); f = Facts(v); target = f.castles(1)[1]
        target['attributes']['integrity'] = 11
        engine = f.castles(0)[3]
        engine['attributes'].update(status='standing', integrity=17, construction_state='active', artillery_target=target['id'])
        value = ruin_value(Facts(v), target['id'], attack(f, target['id'], 1))
        self.assertEqual(5, value['integrity_before_ruin'])
        self.assertEqual(2, value['projection']['artillery_hits'][0]['damage'])
        engine['attributes']['artillery_target'] = ''
        value = ruin_value(Facts(v), target['id'], dict(powers=[], order={}))
        self.assertEqual(11, value['integrity_before_ruin'])
        self.assertEqual(1, value['projection']['unknown_artillery'])

    def test_attack_after_artillery_destroys_target_does_not_hit_it_again(self):
        v = fixture(); f = Facts(v); target = f.castles(1)[1]
        target['attributes']['integrity'] = 2
        f.castles(0)[3]['attributes'].update(status='standing', integrity=17,
            construction_state='active', artillery_target=target['id'])
        value = ruin_value(Facts(v), target['id'], attack(f, target['id']))
        self.assertEqual(0, value['damage'])
        self.assertEqual({}, value['projection']['attack_hits'])

    def test_recipe_aware_payment_keeps_cheap_ingredients(self):
        v = fixture(); hand(v, [('Penitent', 1)]*2+[('Wright', 2), ('Butcher', 2)])
        f = Facts(v); pair = discard_pair(f, f.hand, Weights())
        self.assertEqual({'Wright', 'Butcher'}, {f.by_id[k]['attributes']['suit'] for k in pair})

    def test_no_targets_reserves_no_alternative_slots_and_settlement_has_no_future_credit(self):
        v=fixture(); f=Facts(v); target=f.castles(1)[1]['id']
        v['players'][0]['resources']['personal_tears']=20
        v['data']['neutral_tears']=20
        value=ruin_value(Facts(v),target,dict(powers=[],order={}))
        self.assertEqual('settlement_precedes_ruin',value['reason'])
        self.assertEqual(0,value['score'])
        for c in f.castles(1): c['attributes']['integrity']=8
        self.assertFalse(RuinPlans(Facts(v),Weights()).enabled)

    def test_retarget_preserves_attack_and_only_spends_uncommitted_cards(self):
        f = Facts(fixture()); target = f.castles(1)[1]['id']; p = attack(f, target)
        combat = Proposal('combat', 'Siege', p['order'], 60, 'test_attack', tuple(p['order']['card_ids']))
        candidate = dict(plan=p, selected=[combat], score=60)
        budget = Budget(); variants = list(RuinPlans(f, Weights()).alternatives([candidate], budget))
        self.assertEqual(1, len(variants)); self.assertIs(combat, variants[0][0])
        ruin = variants[0][-1]
        self.assertNotEqual(target, ruin.payload['target']['entity_id'])
        self.assertFalse(set(ruin.cards).intersection(combat.cards))
        self.assertEqual({'Wright'}, {f.by_id[k]['attributes']['suit'] for k in ruin.cards})
        self.assertLessEqual(budget.report()['used']['generated:gremory'], 16)

    def test_guard_pair_is_reserved_and_two_cards_are_required(self):
        v = fixture(); hand(v, [('Vulture', 4)]*2+[('Wright', 1)]*2); f = Facts(v)
        ids = tuple(r['id'] for r in f.hand if r['attributes']['suit'] == 'Vulture')
        moves = [dict(card_id=k, lane='Lord', slot=i) for i,k in enumerate(ids)]
        guard = Proposal('guards', 'Deploy', dict(guard_moves=moves), 40, 'test_pair', ids)
        c = dict(plan=dict(powers=[], order=guard.payload), selected=[guard], score=40)
        variants = list(RuinPlans(f, Weights()).alternatives([c], Budget()))
        self.assertTrue(variants)
        self.assertFalse(set(variants[0][-1].cards).intersection(ids))
        v['hand'] = [r for r in v['hand'] if r['id'] != variants[0][-1].cards[0]]
        self.assertEqual([], list(RuinPlans(Facts(v), Weights()).alternatives([c], Budget())))

    def test_coordination_removes_standalone_credit_and_pending_is_not_stacked(self):
        v = fixture(); f = Facts(v); target = f.castles(1)[1]['id']; p = attack(f, target)
        p['powers'] = [declaration(0, 1, 'InevitableRuin', dict(entity_id=target),
            discard_ids=[r['id'] for r in f.hand if r['attributes']['suit'] == 'Wright'])]
        value = evaluate(f, p)
        self.assertEqual(-45, value['score_delta'])
        self.assertEqual(0, value['powers'][0]['score'])
        v['pending'].append(dict(declaration=p['powers'][0], fire_round=2))
        self.assertEqual('target_already_pending_ruin', ruin_value(Facts(v), target, dict(powers=[], order={}))['reason'])

    def test_registry_order_inputs_and_small_budget_are_stable(self):
        v = fixture(); before = copy_data(v)
        first = CommonSmartCore().decide(v, lambda p: {'action':'legal'})
        self.assertEqual(before, v)
        v['board'].reverse(); v['hand'].reverse()
        self.assertEqual(first, CommonSmartCore().decide(v, lambda p: {'action':'legal'}))
        self.assertGreater(first['gremory']['alternatives'], 0)
        for key,count in first['budget']['used'].items():
            self.assertLessEqual(count, 16 if key.startswith('generated:') else 4 if key.startswith('retained:') else 32 if key == 'complete_plans' else 8)
        small = CommonSmartCore(limits=Limits(complete_plans=4, previews=2)).decide(v, lambda p: {'action':'legal'})
        self.assertLessEqual(small['budget']['used']['complete_plans'], 4)

    def test_authority_damage_and_fizzle_occur_next_round_after_own_siege(self):
        for hp in (17, 11):
            with self.subTest(integrity=hp):
                game = planning('Gremory'); w = game._state['world']
                economy.discard(w, 0, list(w['data']['card_zones']['hands'][0]))
                rows = w['entities']['entities']; cards = []; changes = []
                for suit,value in [('Butcher',4), ('Wright',1), ('Wright',1)]:
                    row = next(r for r in rows if r['kind']=='card' and r['id'] not in cards
                               and r['attributes']['suit']==suit and r['attributes']['value']==value)
                    cards.append(row['id']); changes.append(dict(kind='fixture_give',player_id=0,card_id=row['id']))
                target = Facts(observe(game,0)).castles(1)[1]['id']
                changes.append(dict(kind='fixture_patch',entity_id=target,attributes=dict(integrity=hp)))
                power_components.prepare(game,changes)
                f=Facts(observe(game,0)); p=dict(powers=[declaration(0,1,'InevitableRuin',dict(entity_id=target),discard_ids=cards[1:])],
                    order=dict(action='Siege',lane='Castle',target_id=target,card_ids=cards[:1]))
                predicted=ruin_value(f,target,p)
                self.assertEqual('legal',Preview(game,0)(p)['action'])
                def apply(op):
                    result=game.apply(op); self.assertNotEqual('invalid',result['action'],result)
                apply(dict(kind='submit',plans=[p,dict(powers=[],order={})]))
                while not game.clock.completed: apply(full_match_inputs.next_operation(game))
                self.assertEqual(hp-4,economy.entity(game._state['world'],target)['attributes']['integrity'])
                apply(dict(kind='next_round')); apply(dict(kind='step',hook='round_start_scheduled'))
                self.assertEqual(min(hp-4,8),economy.entity(game._state['world'],target)['attributes']['integrity'])
                hits=[r['event']['data'] for r in game._state['events']['rows'] if r['event']['type']=='CASTLE_DAMAGED'
                      and r['event']['data'].get('source')=='InevitableRuin']
                self.assertEqual(predicted['damage'],sum(h['damage'] for h in hits))


if __name__ == '__main__': unittest.main()

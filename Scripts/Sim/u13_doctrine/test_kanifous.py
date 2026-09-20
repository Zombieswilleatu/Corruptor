"""Wish timing, delayed liability, public uncertainty and bounded planning."""
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from u13_pysim import economy, monsters, power_components, recruitment, wishmaster
from u13_pysim.copying import copy_data
from u13_pysim.power_rules import declaration
from .budget import Budget, Limits
from .common import CommonSmartCore
from .coordination import context
from .facts import Facts, Proposal
from .kanifous_tactics import WISHES, WishPlans, choices, projected, price_value, wish_value
from .observation import observe, Preview
from .test_common import planning
from .test_recipes_veil import hand

EMPTY = dict(powers=[], order={})


def fixture():
    return observe(planning('Kanifous'), 0)


def unit(view, key, owner=0, x=500, lane='Castle', monster='', hp=None):
    a = (monsters.profile(monster, lane, owner, 0, 1) if monster
         else recruitment.profile('Butcher', lane, owner, 0, 1))
    a.update(x_fp=x, y_fp=300)
    if hp is not None: a['hp']=hp
    row=dict(id=key, kind='marcher', owner=owner, attributes=a)
    view['board'].append(row)
    return row


class KanifousTests(unittest.TestCase):
    def test_wealth_counts_only_unspent_cards_and_actual_capped_draw_distribution(self):
        v=fixture(); hand(v,[('Butcher',1)]*10); f=Facts(v)
        self.assertIn(('WishWealth',{}),list(choices(f)))
        for count,expected in ((0,0),(1,100),(2,180),(3,210),(5,210)):
            plan=dict(powers=[],order=dict(action='Ward',lane='Castle',card_ids=[r['id'] for r in f.hand[:count]]))
            value=wish_value(f,'WishWealth',{},plan)
            self.assertEqual(expected,value['expected_cards_hundredths'])
            self.assertEqual(10-count,value['hand_after_commitments'])
        ids=[r['id'] for r in f.hand[:3]]
        plan=dict(powers=[],order=dict(guard_moves=[dict(card_id=ids[0],lane='Lord',slot=0)],
            rites=dict(card_ids=ids[1:]),card_ids=ids[1:]))
        self.assertEqual(7,wish_value(f,'WishWealth',{},plan)['hand_after_commitments'])

    def test_longevity_is_reduced_by_own_work_and_values_operational_threshold(self):
        v=fixture(); hand(v,[('Butcher',1)]*2); f=Facts(v); castle=f.castles(0)[0]
        castle['attributes']['integrity']=6; target=dict(entity_id=castle['id']); f=Facts(v)
        value=wish_value(f,'WishLongevity',target,EMPTY)
        self.assertEqual((2,True,22),(value['healing'],value['restores_operation'],value['benefit']))
        plan=dict(powers=[],order=dict(castle_action=dict(action='Work',target_id=castle['id']),
            guard_moves=[dict(card_id=r['id'],lane='Lord',slot=i) for i,r in enumerate(f.hand)]))
        value=wish_value(f,'WishLongevity',target,plan)
        self.assertEqual((8,0,0),(value['integrity_after_work'],value['healing'],value['benefit']))

    def test_price_uses_category_weights_and_own_due_debt_without_sampling(self):
        v=fixture(); f=Facts(v); state=projected(f,EMPTY,context(f,EMPTY))
        base=price_value(f,state); pools=base['eligible_outcomes']
        self.assertEqual({'Cards','Stone','Ruin','Wishmaster'},set(pools))
        total=30+15+4+1
        expected=(30*pools['Cards']+15*pools['Stone']+4*pools['Ruin']+75+total-1)//total
        self.assertEqual(expected,base['current_asset_loss'])
        v['data']['kanifous_prices']=[dict(owner=1,due_round=1)]
        self.assertEqual(base,price_value(Facts(v),state))
        v['data']['kanifous_prices'].append(dict(owner=0,due_round=v['round']+3))
        later=price_value(Facts(v),state)
        v['data']['kanifous_prices'][-1]['due_round']=v['round']+1
        soon=price_value(Facts(v),state)
        self.assertEqual((10,14),(later['score']-base['score'],soon['score']-base['score']))
        state['castles'][0]['attributes']['integrity']=4
        brittle=price_value(Facts(v),state)
        self.assertGreater(brittle['eligible_outcomes']['Stone'],pools['Stone'])

    def test_death_values_material_and_accounts_for_friendly_fire(self):
        v=fixture(); unit(v,'foe',1,x=1000); own=unit(v,'own',0,x=1000,monster='Lemek')
        target=dict(lane='Castle',field_position=dict(x_fp=1000,y_fp=300))
        value=wish_value(Facts(v),'WishDeath',target,EMPTY)
        self.assertLess(value['benefit'],0)
        own['attributes']['x_fp']=1600
        self.assertGreater(wish_value(Facts(v),'WishDeath',target,EMPTY)['benefit'],0)

    def test_death_reserves_for_possible_friendly_spawns_and_excludes_spent_waiters(self):
        v=fixture(); hand(v,[('Butcher',3)]); unit(v,'foe',1,x=80)
        waiter=unit(v,'waiter',0,x=80); waiter['attributes']['waiting']=True
        f=Facts(v); target=dict(lane='Castle',field_position=dict(x_fp=80,y_fp=300))
        plan=dict(powers=[],order=dict(action='Siege',lane='Castle',target_id=f.castles(1)[0]['id'],card_ids=[f.hand[0]['id']]))
        value=wish_value(f,'WishDeath',target,plan)
        self.assertEqual([],value['friendly_victims'])
        self.assertEqual(1,value['planned_friendly_exposure_upper_bound'])
        self.assertEqual(6,value['benefit'])

    def test_resurrection_requires_reachable_danger_and_discounts_future_losses(self):
        v=fixture(); unit(v,'own',0,x=100,hp=1); foe=unit(v,'foe',1,x=2300)
        target=dict(lane='Castle')
        self.assertEqual([],wish_value(Facts(v),'WishResurrection',target,EMPTY)['exposed'])
        foe['attributes']['x_fp']=150
        value=wish_value(Facts(v),'WishResurrection',target,EMPTY)
        self.assertEqual([dict(id='own',discounted_value=12)],value['exposed'])
        f=Facts(v); plan=dict(powers=[],order=dict(rites=dict(waiter_spends=[dict(marcher_ids=['own'])])))
        self.assertEqual([],wish_value(f,'WishResurrection',target,plan)['exposed'])

    def test_resurrection_uses_current_round_losses_and_obeys_living_copy_limit(self):
        v=fixture(); lost=unit(v,'lost',0,monster='Sooge'); v['board'].remove(lost)
        v['data']['kanifous_losses']=[lost]
        target=dict(lane='Castle')
        self.assertNotIn('kanifous_loss_round',v['data'])
        self.assertEqual(['lost'],wish_value(Facts(v),'WishResurrection',target,EMPTY)['known_losses'])
        v['data']['kanifous_loss_round']=v['round']-1
        self.assertEqual([],wish_value(Facts(v),'WishResurrection',target,EMPTY)['known_losses'])
        v['data']['kanifous_loss_round']=v['round']; unit(v,'living',0,monster='Sooge')
        self.assertEqual([],wish_value(Facts(v),'WishResurrection',target,EMPTY)['known_losses'])
        v['board'].pop()
        plan=dict(powers=[],order=dict(monster_choice='Sooge',lane='Castle'))
        self.assertEqual([],wish_value(Facts(v),'WishResurrection',target,plan)['known_losses'])
        self.assertEqual([],wish_value(Facts(v),'WishResurrection',dict(lane='Lord'),EMPTY)['known_losses'])

    def test_power_uses_expected_material_and_subtracts_planned_recruitment(self):
        v=fixture(); hand(v,[('Butcher',4)]*3)
        for i in range(6): unit(v,'foe'+str(i),1,x=1000)
        f=Facts(v); target=dict(lane='Castle')
        base=wish_value(f,'WishPower',target,EMPTY)
        plan=dict(powers=[],order=dict(action='Ward',lane='Castle',card_ids=[r['id'] for r in f.hand]))
        after=wish_value(f,'WishPower',target,plan)
        self.assertEqual((63,39),(base['benefit'],after['benefit']))
        self.assertEqual(200,after['expected_bodies_hundredths'])
        self.assertEqual((1,'unknown'),(after['guaranteed_bodies'],after['extra_bodies']))

    def test_alternative_keeps_current_cards_and_respects_generation_budget(self):
        v=fixture(); hand(v,[('Butcher',1)]*10)
        # A detached scenario with cheap liabilities makes the opened hand space decisive.
        for r in v['board']:
            if r['owner']==0 and r['kind']=='castle': r['attributes']['status']='ruined'
        f=Facts(v); f.wish_profile='wealth'  # Isolate Wealth's spending-aware alternative.
        ids=tuple(r['id'] for r in f.hand[:7])
        order=dict(action='Ward',lane='Castle',card_ids=list(ids))
        combat=Proposal('combat','Ward',order,30,'test',ids)
        c=dict(plan=dict(powers=[],order=order),selected=[combat],score=30)
        budget=Budget(); variants=list(WishPlans(f).alternatives([c],budget))
        self.assertEqual(1,len(variants)); self.assertIs(combat,variants[0][0])
        self.assertEqual('WishWealth',variants[0][-1].term)
        self.assertLessEqual(budget.report()['used']['generated:kanifous'],16)

    def test_deterministic_legal_both_seats_private_independence_and_small_budget(self):
        for pid in (0,1):
            game=planning('Kanifous')
            if pid==1:
                world=game._state['world']; lord=next(r for r in world['entities']['entities'] if r['kind']=='lord' and r['owner']==1)
                lord['attributes']['lord_id']='Kanifous'; world['players'][1]['lord_id']='Kanifous'
            before=game.snapshot(); v=observe(game,pid)
            first=CommonSmartCore().decide(v,Preview(game,pid))
            self.assertEqual(before,game.snapshot())
            self.assertEqual('legal',Preview(game,pid)(first['plan'])['action'])
            self.assertLessEqual(sum(p['power_id'] in WISHES for p in first['plan']['powers']),1)
            v['board'].reverse();v['hand'].reverse()
            self.assertEqual(first,CommonSmartCore().decide(v,Preview(game,pid)))
            game._state['seed']='unknown different seed';game._state['world']['data']['card_zones']['deck'].reverse()
            self.assertEqual(first,CommonSmartCore().decide(observe(game,pid),Preview(game,pid)))
            small=CommonSmartCore(limits=Limits(complete_plans=4,previews=2)).decide(v,Preview(game,pid))
            self.assertLessEqual(small['budget']['used']['complete_plans'],4)

    def test_authority_empty_wealth_and_redundant_heal_do_not_schedule_price(self):
        game=planning('Kanifous'); w=game._state['world']; pid=0
        ids=list(economy.zones(w)['hands'][pid])
        extra=[r['id'] for r in w['entities']['entities'] if r['kind']=='card' and r['id'] not in ids][:10-len(ids)]
        power_components.prepare(game,[dict(kind='fixture_give',player_id=pid,card_id=k) for k in extra])
        w=game._state['world']
        b=SimpleNamespace(w=w,number=1,seed='fixed-test')
        s=declaration(0,1,'WishWealth',{})
        events=wishmaster.wish(b,s)
        self.assertEqual(0,events[-1]['event']['data']['count']);self.assertEqual([],w['data']['kanifous_prices'])
        economy.discard(w,0,list(economy.zones(w)['hands'][0])[:3])
        events=wishmaster.wish(b,s)
        self.assertIn(events[-1]['event']['data']['count'],(1,2,3))
        self.assertEqual(1,len(w['data']['kanifous_prices']))
        self.assertIn(w['data']['kanifous_prices'][0]['due_round'],(2,3,4))
        castle=next(r for r in w['entities']['entities'] if r['kind']=='castle' and r['owner']==0)
        castle['attributes']['integrity']=8
        wishmaster.wish(b,declaration(0,1,'WishLongevity',dict(entity_id=castle['id'])))
        self.assertEqual(1,len(w['data']['kanifous_prices']))

    def test_authority_death_includes_friendlies_and_resurrection_waits_until_next_round(self):
        game=planning('Kanifous'); w=game._state['world']; rows=w['entities']['entities']
        own=recruitment.create(w,'wish-test-own',0,0,recruitment.profile('Butcher','Castle',0,0,1))
        foe=recruitment.create(w,'wish-test-foe',0,1,recruitment.profile('Butcher','Castle',1,0,1))
        for r in (own,foe): r['attributes'].update(x_fp=1000,y_fp=300)
        b=SimpleNamespace(w=w,number=1,seed='fixed-test')
        events=wishmaster.wish(b,declaration(0,1,'WishDeath',dict(lane='Castle',field_position=dict(x_fp=1000,y_fp=300))))
        self.assertEqual({own['id'],foe['id']},{r['id'] for r in events[-1]['event']['data']['victims']})
        events=wishmaster.wish(b,declaration(0,1,'WishResurrection',dict(lane='Castle')))
        restored=next(e['event']['data']['unit'] for e in events if e['event']['type']=='MARCHER_RESURRECTED')
        self.assertEqual(2,restored['attributes']['movement_ready_round'])
        self.assertEqual(5,restored['attributes']['hp'])

    def test_authority_price_category_pool_matches_public_eligibility(self):
        game=planning('Kanifous'); w=game._state['world']; f=Facts(observe(game,0))
        price=price_value(f,projected(f,EMPTY,context(f,EMPTY)))
        calls=[]
        def first(seed,key,channel,index,bound): calls.append((channel,bound)); return 0
        with patch('u13_pysim.wishmaster.draw',first):
            _,events=wishmaster.price(SimpleNamespace(w=w,number=2,seed='fixed'),dict(id='debt',owner=0))
        self.assertEqual(('PRICE_OUTCOME',50),calls[0])
        self.assertEqual('Cards',events[-1]['event']['data']['outcome'])
        self.assertEqual(2,len(events[-1]['event']['data']['targets']))
        self.assertEqual({'Cards','Stone','Ruin','Wishmaster'},set(price['eligible_outcomes']))


if __name__=='__main__': unittest.main()

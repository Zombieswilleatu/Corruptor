"""Pair identity and accounting for the fixed comparison campaign."""
from collections import Counter,defaultdict
import unittest
from .kanifous_comparison import cases,aggregate,metrics,NAMESPACE


def record(variant,winner,seat=0,status='complete'):
    return dict(spec=dict(name='test__'+variant,pair_id='test',variant=variant,opponent='Gremory',repeat=0,focal_seat=seat),
        status=status,error=None if status=='complete' else 'failure',wall_seconds=1,trace=[],
        semantic=dict(rounds=5,outcome=dict(winner=winner),diagnostics=dict(wish_events=[],rejected_previews=[])))


class ComparisonTests(unittest.TestCase):
    def test_predeclared_pairs_differ_only_in_focal_policy_and_include_mirrors(self):
        rows=list(cases());self.assertEqual(72,len(rows));self.assertEqual(72,len({r['name'] for r in rows}))
        pairs=defaultdict(list);opponents=Counter()
        for r in rows:
            pairs[r['pair_id']].append(r);opponents[r['opponent']]+=1
            self.assertEqual('Kanifous',r['setup']['lords'][r['focal_seat']])
            self.assertEqual(r['opponent'],r['setup']['lords'][1-r['focal_seat']])
            self.assertTrue(r['setup']['seed'].startswith(NAMESPACE+':'))
        self.assertEqual(36,len(pairs));self.assertEqual({8},set(opponents.values()));self.assertEqual(9,len(opponents))
        for old,new in pairs.values():
            self.assertEqual(('old','new'),(old['variant'],new['variant']))
            self.assertEqual(old['setup'],new['setup'])

    def test_paired_result_tracks_focal_seat_and_does_not_count_failures_as_losses(self):
        summary=aggregate([record('old',0,seat=1),record('new',1,seat=1)])
        self.assertEqual(1,summary['paired']['new_only_wins']);self.assertEqual(1,summary['paired']['net_wins'])
        failed=aggregate([record('old',0),record('new',0,status='failed')])
        self.assertEqual(1,failed['totals']['new']['failed']);self.assertEqual(0,failed['paired']['complete_pairs'])
        self.assertEqual(0,failed['totals']['new']['completed'])

    def test_effects_distinguish_friendly_fire_breach_and_effectless_resurrection(self):
        r=record('new',1,seat=1)
        r['semantic']['diagnostics']['wish_events']=[
            dict(type='KANIFOUS_WISH_RESOLVED',data=dict(power='WishDeath',breach=True,count=3,
                victims=[dict(owner=1),dict(owner=0),dict(owner=-1)])),
            dict(type='KANIFOUS_WISH_RESOLVED',data=dict(power='WishResurrection',breach=False,count=0,victims=[])),
            dict(type='KANIFOUS_PRICE_SCHEDULED',data=dict(owner=1)),
            dict(type='KANIFOUS_PRICE_RESOLVED',data=dict(outcome='Blood'))]
        m=metrics(r)
        self.assertEqual((1,1,1),(m['death_friendly'],m['death_enemy'],m['death_neutral']))
        self.assertEqual((2,1,1,1),(m['wishes'],m['successful'],m['zero_effect'],m['breach_casts']))
        self.assertEqual(1,m['zero_effect:WishResurrection']);self.assertEqual(1,m['price:Blood'])


if __name__=='__main__':unittest.main()

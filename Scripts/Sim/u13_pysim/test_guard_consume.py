import copy,unittest
from .guard_consume import guards,route,choose,VELOCITIES

class GuardConsumeTests(unittest.TestCase):
    def rows(self):
        return [dict(id=f'{p}:{l}:{s}',kind='card',owner=p,attributes=dict(role='guard',lane=l,slot=s)) for p in (0,1) for l in ('Lord','Castle') for s in range(3)]
    def test_single_guard_always_reached(self):
        for row in self.rows():
            for vx,vy in VELOCITIES:
                for sx in (-1,1):
                    for sy in (-1,1):self.assertEqual(row['id'],route([row],vx*sx,vy*sy)['victim_id'])
    def test_mirrored_seats_have_identical_paths_and_victims(self):
        rows=self.rows();mirror=copy.deepcopy(rows)
        for r in mirror:
            r['owner']=1-r['owner']
            if r['attributes']['lane']=='Lord':r['attributes']['slot']=2-r['attributes']['slot']
        for seed in range(100):
            a=choose(dict(entities=dict(entities=rows)),0,str(seed),'mirror')
            b=choose(dict(entities=dict(entities=mirror)),1,str(seed),'mirror')
            self.assertEqual(a['victim_id'],b['victim_id'])
            self.assertEqual([[x,1000-y] for x,y in a['path']],b['path'])
    def test_seeded_repeat_and_empty_field(self):
        w=dict(entities=dict(entities=self.rows()));before=copy.deepcopy(w)
        self.assertEqual(choose(w,0,'same','same'),choose(w,0,'same','same'))
        self.assertEqual(w,before)
        self.assertEqual('',choose(dict(entities=dict(entities=[])),0,'empty','empty')['victim_id'])
    def test_guard_order_does_not_change_victim(self):
        rows=self.rows()
        for seed in range(20):
            self.assertEqual(choose(dict(entities=dict(entities=rows)),0,str(seed),'order'),choose(dict(entities=dict(entities=rows[::-1])),0,str(seed),'order'))
if __name__=='__main__':unittest.main()

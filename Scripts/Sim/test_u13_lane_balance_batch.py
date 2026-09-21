"""Accounting and incomplete-output gates for the local batch runner."""
import json
from pathlib import Path
import tempfile
import unittest
from run_u13_lane_balance_batch import aggregate, read_job, reports, SCHEMA


def unit(identity, name, hp, deployed=1, ticks=200):
    return dict(id=identity,name=name,kind='marcher',birth_owner=0,birth_round=1,builder_id='',alive_at_cutoff=False,staged_at_cutoff=False,
                counts=dict(bodies=1,deployed=deployed,active_ticks=ticks,enemy_hp_damage=hp))


def job(units):
    return dict(meta=dict(seed='fixed',swapped=False,roster=['Varn','Wright']),
                result=dict(ticks=200,rounds=1,units=units,totals=[dict(reached_goal=2,spawned=len(units)),dict(reached_goal=1,spawned=3)]),
                history=[dict(round=1,active=0,staged=0)])


class Reports(unittest.TestCase):
    def test_pooled_rates_and_swarm_denominator(self):
        rows, games, _ = aggregate([job([unit('a','Varn',9),unit('b','Varn',3,ticks=600),unit('c','Varn',0,deployed=0,ticks=0)])],['Varn'])
        varn=next(r for r in rows if r['name']=='Varn')
        self.assertEqual(varn['summon_groups'],1)
        self.assertEqual(varn['spawned'],3)
        self.assertEqual(varn['deployed_bodies'],2)
        self.assertEqual(varn['hp_per_deployed'],6)
        self.assertEqual(varn['hp_per_active_second'],.2)
        self.assertEqual(games[0]['goal_lead'],'home')
        self.assertEqual(varn['coverage'],'LOW')

    def test_absent_types_remain_visible(self):
        rows,_,_=aggregate([],['Muno'])
        self.assertEqual(rows[0]['coverage'],'NOT SEEN')
        self.assertIsNone(rows[0]['hp_per_deployed'])

    def test_complete_round_gate_and_damage_gate(self):
        with tempfile.TemporaryDirectory() as temp:
            p=Path(temp)/'run.jsonl'
            rows=[dict(kind='meta'),dict(kind='round',round=1),dict(kind='finished',ticks=200,units=[])]
            p.write_text('\n'.join(json.dumps(r) for r in rows))
            self.assertEqual(read_job(p,1)['result']['ticks'],200)
            with self.assertRaises(ValueError):read_job(p,2)
            p.write_text('\n'.join(json.dumps(r) for r in rows[:-1]))
            with self.assertRaises(ValueError):read_job(p,1)
            rows[-1]['units']=[dict(counts={'unaccounted_packets':1})]
            p.write_text('\n'.join(json.dumps(r) for r in rows))
            with self.assertRaises(ValueError):read_job(p,1)

    def test_partial_report_and_no_double_counting_support(self):
        with tempfile.TemporaryDirectory() as temp:
            actor=unit('a','Wright',5)
            actor['counts'].update(repair_hp=10,charmed_body_hp_damage=4)
            reports(Path(temp),dict(schema=SCHEMA,seeds=1,rounds=1,godot_version='test',fingerprint='abc'),[job([actor])])
            text=(Path(temp)/'report.md').read_text()
            self.assertIn('PARTIAL REPORT',text)
            summary=json.loads((Path(temp)/'summary.json').read_text())
            w=next(r for r in summary['units'] if r['name']=='Wright')
            self.assertEqual(w['enemy_hp_damage'],5)
            self.assertEqual(w['repair_hp'],10)
            self.assertTrue((Path(temp)/'report.html').exists())

if __name__=='__main__':unittest.main()

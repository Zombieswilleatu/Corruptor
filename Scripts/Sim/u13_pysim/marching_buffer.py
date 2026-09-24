"""Marcher-column adapter for the rare actor mutations and lamp spawns."""
from .copying import copy_data
from . import embolden
from .marching_columns import Columns, FIELDS
from .recruitment import create


class Buffer:
    def __init__(self,phase):self.phase=phase
    def rows(self):return self.phase.s.rows()
    def snapshot(self):return self.phase.s.snapshot()
    def restore(self,raw):self.phase.s=Columns(raw,keep_background=self.phase.keep_background)
    def has_ghost_wishes(self):
        s=self.phase.s
        return any(alive and extra and extra.get('ghost_wishes',0)!=0
                   for alive,extra in zip(s.alive,s.extra))
    def get(self,key):
        i=self.phase.s.live(key)
        return self.phase.s.row(i) if i is not None else {}
    def update(self,key,owner,a):
        s=self.phase.s;i=s.live(key)
        if i is None:raise ValueError('Marcher missing')
        if '_embolden_percent' in a:
            for field in embolden.FIELDS:
                if field in a:a[field]=embolden.number(float(a[field]))
        s.owner[i]=owner
        for field in FIELDS:getattr(s,field)[i]=a.get(field)
        s.extra[i]=copy_data({k:v for k,v in a.items() if k not in FIELDS}) or None
    def retire_id(self,key):
        i=self.phase.s.live(key)
        if i is not None:self.phase.s.retire(i)
    def spawn_near(self,origin,owner,a):
        s=self.phase.s;w=dict(entities=s.snapshot());r=create(w,origin,0,owner,a)
        for dx,dy in ((0,84),(0,-84),(84,0),(-84,0),(84,84),(-84,-84)):
            nx=max(0,min(2400,a['x_fp']+dx));ny=max(0,min(600,a['y_fp']+dy))
            if all(other['id']==r['id'] or other['kind']!='marcher' or other['owner']!=owner or other['attributes']['lane']!=a['lane'] or (nx-other['attributes']['x_fp'])**2+(ny-other['attributes']['y_fp'])**2>=84*84 for other in w['entities']['entities']):r['attributes'].update(x_fp=nx,y_fp=ny);break
        self.phase.s=Columns(w['entities'],keep_background=self.phase.keep_background)
        return copy_data(r)

"""Optional final-plan selection. No simulation RNG or hidden state is accepted."""
from dataclasses import asdict, dataclass
import math

from u13_pysim.copying import copy_data
from .diagnostics import fingerprint

VERSION = 'U13_PLAN_SELECTOR_V1'


@dataclass(frozen=True)
class SelectionSettings:
    temperature: float = 0.0
    max_score_gap: float = 0.0
    policy_seed: str = ''

    def __post_init__(self):
        for name in ('temperature', 'max_score_gap'):
            value = getattr(self, name)
            if type(value) not in (int, float) or value < 0:
                raise ValueError(name+' must be a finite nonnegative number')
            try: value = float(value)
            except OverflowError: raise ValueError(name+' must be a finite nonnegative number') from None
            if not math.isfinite(value): raise ValueError(name+' must be a finite nonnegative number')
            object.__setattr__(self, name, value)
        if type(self.policy_seed) is not str or (self.temperature > 0 and not self.policy_seed):
            raise ValueError('softmax requires an explicit, separate policy_seed string')


class PlanSelector:
    """Choose among already scored complete plans within the existing work cap.

    The caller supplies the established deterministic ranking. Greedy selection
    stops at the first legal plan. Softmax previews further plans within the
    score gap, then samples only the admitted pool. No extra preview budget is
    created and no failed preview enters the pool. Repeating a decision is pure:
    a domain-separated hash supplies its draw without advancing any RNG stream.
    """
    def __init__(self, settings=None):
        self.settings = settings if settings is not None else SelectionSettings()

    @property
    def policy_suffix(self):
        if self.settings.temperature == 0: return ''
        # Seed changes repetitions, not the identity of a difficulty policy.
        return '/'+VERSION+':'+fingerprint(dict(temperature=self.settings.temperature,
                                               max_score_gap=self.settings.max_score_gap))

    def select(self, ranked, preview, budget, *, round_number, seat):
        config = self.settings
        pool, entries, rejected = [], [], []
        truncated = False
        for rank, candidate in enumerate(ranked, 1):
            if pool and pool[0]['score']-candidate['score'] > config.max_score_gap: break
            if not budget.take('previews'):
                truncated = True
                break
            result = preview(copy_data(candidate['plan']))
            plan_hash = fingerprint(candidate['plan'])
            if result.get('action') != 'legal':
                rejected.append(dict(plan_sha256=plan_hash, result=result))
                continue
            pool.append(candidate)
            entries.append(dict(rank=rank, score=candidate['score'], plan_sha256=plan_hash))
            if config.temperature == 0: break
        if not pool:
            raise ValueError('No admitted plan within preview budget: '+repr(rejected))
        index, draw, draw_key = 0, None, None
        if config.temperature > 0 and len(pool) > 1:
            draw_key = fingerprint([VERSION, config.policy_seed, round_number, seat, entries])
            draw = int(draw_key, 16) >> (256-53)
            # Subtract the maximum before exponentiation; weights never exceed
            # one, so high absolute scores cannot overflow the softmax.
            weights = [math.exp((c['score']-pool[0]['score'])/config.temperature) for c in pool]
            threshold = (draw/(1 << 53))*math.fsum(weights)
            running = 0.0
            index = max(i for i, weight in enumerate(weights) if weight > 0)
            for i, weight in enumerate(weights):
                running += weight
                if threshold < running:
                    index = i
                    break
        chosen = pool[index]
        trace = dict(version=VERSION, mode='greedy' if config.temperature == 0 else 'softmax',
            settings=asdict(config), ranked_plans=len(ranked), legal_pool=entries,
            pool_truncated=truncated, best_legal_rank=entries[0]['rank'], chosen_rank=entries[index]['rank'],
            best_legal_score=pool[0]['score'], chosen_score=chosen['score'],
            score_gap=pool[0]['score']-chosen['score'], draw_uint53=draw, draw_key_sha256=draw_key)
        return chosen, rejected, trace

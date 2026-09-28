extends RefCounted

# Fractional-delay plucked string. The excitation is a deterministic picked
# noise burst; a lossy feedback loop lets its harmonics decay independently.
var _line := PackedFloat32Array()
var _pluck := PackedFloat32Array()
var _cursor: int=0
var _delay: float=1.0
var _previous: float=0.0
var _loss: float=.99
var _damping: float=.5
var _age: int=0
var _repick: int=0
var _attack: int=40

func setup(frequency: float, rate: int, settings: Dictionary, seed_value: int) -> void:
	var hz: float=clampf(frequency,8.0,float(rate)*.4)
	var muted: float=settings.guitar_mute/100.0
	_damping=lerpf(.22,.48,muted)
	_delay=maxf(2.0,float(rate)/hz-_damping)
	var length: int=ceili(_delay)+2
	_line.resize(length)
	_pluck.resize(length)
	var rng:=RandomNumberGenerator.new()
	rng.seed=seed_value
	var raw := PackedFloat32Array()
	raw.resize(length)
	for i in range(length): raw[i]=rng.randf_range(-1.0,1.0)
	var pick_offset: int=maxi(1,roundi(_delay*settings.guitar_pick/100.0))
	var mean: float=0.0
	for i in range(length):
		_pluck[i]=(raw[i]-raw[posmod(i-pick_offset,length)])*.5
		mean+=_pluck[i]
	mean/=length
	for i in range(length): _pluck[i]-=mean
	_line=_pluck.duplicate()
	var ring_time: float=maxf(.06,settings.guitar_sustain*lerpf(1.0,.06,muted))
	_loss=exp(-6.907755/(ring_time*hz))
	_repick=roundi(float(rate)/settings.guitar_pick_rate) if settings.guitar_pick_rate>0 else 0
	_attack=maxi(1,roundi(rate*.002))
	_cursor=0
	_previous=0.0
	_age=0

func next_sample() -> float:
	if _repick>0 and _age>=_repick:
		_line=_pluck.duplicate()
		_cursor=0
		_previous=0.0
		_age=0
	var read_pos: float=fposmod(float(_cursor)-_delay,float(_line.size()))
	var first: int=floori(read_pos)
	var sample: float=lerpf(_line[first],_line[(first+1)%_line.size()],read_pos-first)
	var filtered: float=lerpf(sample,_previous,_damping)
	_previous=sample
	_line[_cursor]=filtered*_loss
	_cursor=(_cursor+1)%_line.size()
	var envelope: float=minf(1.0,float(_age)/_attack)
	if _repick>0: envelope*=minf(1.0,float(_repick-_age)/_attack)
	_age+=1
	return sample*envelope

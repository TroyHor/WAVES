class_name WaveMath
extends RefCounted
## Pure, stateless operations on integer waveforms. No Node/UI dependencies.
## A waveform is a PackedInt32Array of amplitudes (+ crest, - trough, 0 empty).

const OFFTRACK_TRUNCATE := "truncate"
const OFFTRACK_WRAP := "wrap"
const OFFTRACK_FORBID := "forbid"


static func invert(wave: PackedInt32Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(wave.size())
	for i in wave.size():
		out[i] = -wave[i]
	return out


## Linear interpolation that keeps both endpoints: length n -> (n - 1) * k + 1.
## Values are rounded half away from zero. [2, 4] x2 -> [2, 3, 4].
## Single-sample waves are returned unchanged.
static func stretch(wave: PackedInt32Array, factor: int) -> PackedInt32Array:
	if factor <= 1 or wave.size() <= 1:
		return wave.duplicate()
	var out := PackedInt32Array()
	out.resize((wave.size() - 1) * factor + 1)
	for i in wave.size() - 1:
		var a := float(wave[i])
		var b := float(wave[i + 1])
		for r in factor:
			out[i * factor + r] = roundi(lerpf(a, b, float(r) / factor))
	out[out.size() - 1] = wave[wave.size() - 1]
	return out


## True if every sample of `wave` placed at `offset` lies inside the track.
static func fits(wave: PackedInt32Array, offset: int, length: int) -> bool:
	return offset >= 0 and offset + wave.size() <= length


## Returns a full-length track containing `wave` placed at `offset`.
## Samples outside the track are dropped (truncate/forbid) or wrapped around (wrap).
## `forbid` is enforced by callers via fits(); here it behaves like truncate.
static func place(wave: PackedInt32Array, offset: int, length: int, offtrack_mode := OFFTRACK_TRUNCATE) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(length)
	out.fill(0)
	for i in wave.size():
		var t := offset + i
		if offtrack_mode == OFFTRACK_WRAP:
			t = posmod(t, length)
		elif t < 0 or t >= length:
			continue
		out[t] += wave[i]
	return out


## Element-wise sum of equal-length tracks.
static func add(a: PackedInt32Array, b: PackedInt32Array) -> PackedInt32Array:
	assert(a.size() == b.size(), "WaveMath.add: length mismatch")
	var out := a.duplicate()
	for i in out.size():
		out[i] += b[i]
	return out


static func empty_track(length: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(length)
	out.fill(0)
	return out

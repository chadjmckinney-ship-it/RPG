extends TestCase
## Procedural audio produces real, non-silent, correctly looping streams.

func _peak(w: AudioStreamWAV) -> int:
	var peak := 0
	var d := w.data
	for i in range(0, d.size(), 64):
		peak = maxi(peak, absi(d.decode_s16(i)))
	return peak

func test_sfx_built() -> void:
	var audio: Node = tree.root.get_node("Audio")
	for name in ["hit", "swing", "bow", "heal", "coin", "click", "death", "gather", "alarm", "quest"]:
		check(audio.sfx.has(name), "missing sfx %s" % name)
		if audio.sfx.has(name):
			check(_peak(audio.sfx[name]) > 1000, "sfx %s is silent" % name)
			check(audio.sfx[name].data.size() / 2 < audio.RATE, "sfx %s longer than a second" % name)

func test_music_tracks() -> void:
	var audio: Node = tree.root.get_node("Audio")
	for i in 200:
		if audio.TRACKS.all(func(t): return audio.is_music_ready(t)):
			break
		await tree.create_timer(0.1).timeout
	for t in audio.TRACKS:
		check(audio.is_music_ready(t), "music %s not built after 20 s" % t)
		if audio.is_music_ready(t):
			var w: AudioStreamWAV = audio.music[t]
			var secs: float = w.data.size() / 2.0 / audio.RATE
			check(secs > 15.0 and secs < 60.0, "music %s is %.1f s" % [t, secs])
			check(w.loop_mode == AudioStreamWAV.LOOP_FORWARD, "music %s doesn't loop" % t)
			check(_peak(w) > 3000, "music %s is near-silent" % t)

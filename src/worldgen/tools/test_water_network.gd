extends SceneTree

# The water network (src/shared/water_network.gd; buildables plan section 6, Sonny's water rules, Steve's design note, 10 Nov 2026): pump and
# windlass rates from effort, open channels by their fall, closed pipes by head with no siphons, tees, tanks that fill and drain lazily with their
# next event known, plots that fill, loops and oversize networks refused, water quality by source and stagnation, and the time of one solve of a
# 256-piece network (printed for the gate report).
#   godot --headless --path . --script res://src/worldgen/tools/test_water_network.gd

const Network := preload("res://src/shared/water_network.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _channel(from: Vector3, to: Vector3, cap: float = 120.0) -> Dictionary:
	return {"role": "conduit", "inlet": from, "outlet": to, "cap_lpm": cap, "closed": false}


func _pipe(from: Vector3, to: Vector3, cap: float = 240.0) -> Dictionary:
	return {"role": "conduit", "inlet": from, "outlet": to, "cap_lpm": cap, "closed": true}


func _init() -> void:
	# Rates from effort (Sonny 1 and 2).
	check(is_equal_approx(Network.pump_lpm(0.8, 40.0, 2.0), 48.0), "a wooden hand pump over a 2 m table gives its 0.8 L/s cap: 48 L/min")
	check(absf(Network.pump_lpm(0.8, 40.0, 6.0) - 60.0 * 40.0 / (9.81 * 7.0)) < 0.01, "at 6 m the lift limits it (%.1f L/min)" % Network.pump_lpm(0.8, 40.0, 6.0))
	check(absf(Network.windlass_lpm(12.0, 8.0) - 480.0 / 22.0) < 0.01, "a 12 m well's windlass draws a full 8 L bucket each 22 s")

	# A hand pump into a channel falling 0.5 percent onto a plot.
	var net = Network.new()
	net.add(1, {"role": "source", "outlet": Vector3(0, 1.0, 0), "rate_lpm": 48.0, "cap_lpm": 48.0, "quality": "clean"})
	check(net.add(2, _channel(Vector3(0, 1.0, 0), Vector3(2, 0.99, 0))) == "", "a channel under the spout joins")
	net.add(3, {"role": "consumer", "inlet": Vector3(2, 0.98, 0), "room_l": 24.0})
	net.solve(0.0)
	check(is_equal_approx(net.inflow_lpm(3), 48.0) and net.quality(3) == "clean", "the plot gets the pump's 48 L/min of clean water (%.1f)" % net.inflow_lpm(3))
	check(is_equal_approx(net.next_event_s(), 30.0), "and is full in 30 s, the next event (%.1f)" % net.next_event_s())
	net.pieces[3]["room_l"] = 0.0
	net.solve(30.0)
	check(net.inflow_lpm(3) == 0.0 and net.outflow_lpm(1) == 0.0 and net.outflow_lpm(2) == 0.0, "a full plot is a closed branch: nothing flows, not even into the channel")

	# Falls: half rate from 0.1 percent, a level run trickles, an uphill run carries nothing; water never climbs between pieces.
	var falls = Network.new()
	falls.add(1, {"role": "source", "outlet": Vector3(0, 5.0, 0), "rate_lpm": 100.0, "cap_lpm": 100.0})
	falls.add(2, _channel(Vector3(0, 5.0, 0), Vector3(2, 4.996, 0)))
	falls.add(3, {"role": "consumer", "inlet": Vector3(2, 4.996, 0), "room_l": 1000.0})
	falls.solve(0.0)
	check(is_equal_approx(falls.inflow_lpm(3), 60.0), "a 0.2 percent fall carries half the 120 L/min cap (%.1f)" % falls.inflow_lpm(3))
	falls.pieces[2]["outlet"] = Vector3(2, 5.0, 0)
	falls.solve(1.0)
	check(is_equal_approx(falls.inflow_lpm(3), 5.0), "a level channel trickles 5 L/min (%.1f)" % falls.inflow_lpm(3))
	falls.pieces[2]["outlet"] = Vector3(2, 5.1, 0)
	falls.solve(2.0)
	check(falls.inflow_lpm(3) == 0.0, "a channel running uphill carries nothing")
	check(falls.check(_channel(Vector3(0, 5.1, 0), Vector3(2, 5.09, 0))) == "" and falls.add(9, _channel(Vector3(0, 5.1, 0), Vector3(2, 5.09, 0))) == "" and not falls.downstream(1).has(9), "an open inlet 10 cm above a spout is not fed (water does not climb)")

	# Loops and size.
	var loop = Network.new()
	loop.add(1, _channel(Vector3(0, 1.0, 0), Vector3(2, 1.0, 0)))
	loop.add(2, _channel(Vector3(2, 1.0, 0), Vector3(2, 1.0, 2)))
	check(loop.check(_channel(Vector3(2, 1.0, 2), Vector3(0, 1.0, 0))) == "loop", "a piece closing a loop is refused")
	check(loop.add(3, _channel(Vector3(2, 1.0, 2), Vector3(0, 1.0, 0))) == "loop" and loop.downstream(2).is_empty() and loop.downstream(3).is_empty(), "and joins nothing")

	# Closed pipes: a force pump's push gives head; with no push a pipe above the spout is dry (no siphon); head under 1 m gives part of the cap.
	var pipes = Network.new()
	pipes.add(1, {"role": "source", "outlet": Vector3(0, 1.0, 0), "rate_lpm": 60.0, "cap_lpm": 60.0, "closed": true, "push_m": 10.0})
	pipes.add(2, _pipe(Vector3(0, 1.0, 0), Vector3(2, 1.25, 0)))
	pipes.add(3, {"role": "consumer", "inlet": Vector3(2, 1.25, 0), "room_l": 1000.0})
	pipes.solve(0.0)
	check(is_equal_approx(pipes.inflow_lpm(3), 60.0), "a deep-well force pump pushes its 1 L/s up an iron pipe (%.1f)" % pipes.inflow_lpm(3))
	pipes.pieces[1]["push_m"] = 0.0
	pipes.pieces[2]["inlet"] = Vector3(0, 1.2, 0)
	pipes.solve(1.0)
	check(pipes.inflow_lpm(3) == 0.0, "without a push, a pipe whose inlet is above the spout stays dry (no siphon)")
	pipes.pieces[2]["inlet"] = Vector3(0, 1.0, 0)
	pipes.pieces[2]["outlet"] = Vector3(2, 0.5, 0)
	pipes.pieces[3]["inlet"] = Vector3(2, 0.5, 0)
	pipes.pieces[2]["cap_lpm"] = 100.0   # a narrow pipe, so its half cap is under the pump's 60 L/min
	pipes.solve(2.0)
	check(is_equal_approx(pipes.inflow_lpm(3), 50.0), "0.5 m of head below the spout gives half the cap: 50 of a 100 L/min pipe (%.1f)" % pipes.inflow_lpm(3))

	var raised = Network.new()
	raised.add(1, {"role": "tank", "inlet": Vector3(0, 4.0, 0), "outlet": Vector3(0, 2.0, 0), "litres_max": 2000.0})
	raised.add(2, _pipe(Vector3(0, 2.0, 0), Vector3(2, 0.5, 0)))
	raised.add(3, {"role": "consumer", "inlet": Vector3(2, 0.5, 0), "room_l": 1000.0})
	raised.set_litres(1, 1000.0)
	raised.solve(0.0)
	check(is_equal_approx(raised.inflow_lpm(3), 240.0), "a raised cistern 1.5 m over the outlet fills an iron pipe to its 240 L/min cap (%.1f)" % raised.inflow_lpm(3))

	# Tees split equally among open branches; a shut sluice is a closed branch.
	var tee = Network.new()
	tee.add(1, {"role": "source", "outlet": Vector3(0, 2.0, 0), "rate_lpm": 60.0, "cap_lpm": 60.0, "quality": "clean"})
	tee.add(2, _channel(Vector3(0, 2.0, 0), Vector3(2, 1.98, 0)))
	tee.add(3, _channel(Vector3(2, 1.98, 0), Vector3(4, 1.96, 0)))
	tee.add(4, _channel(Vector3(2, 1.98, 0), Vector3(2, 1.96, 2)))
	tee.add(5, {"role": "consumer", "inlet": Vector3(4, 1.96, 0), "room_l": 1000.0})
	tee.add(6, {"role": "consumer", "inlet": Vector3(2, 1.96, 2), "room_l": 1000.0})
	tee.solve(0.0)
	check(is_equal_approx(tee.inflow_lpm(5), 30.0) and is_equal_approx(tee.inflow_lpm(6), 30.0), "a tee splits 60 L/min into 30 and 30")
	tee.pieces[4]["open"] = false
	tee.solve(1.0)
	check(is_equal_approx(tee.inflow_lpm(5), 60.0) and tee.inflow_lpm(6) == 0.0, "a shut sluice sends it all down the other branch")
	tee.add(7, {"role": "source", "outlet": Vector3(2, 1.98, -0.1), "rate_lpm": 10.0, "cap_lpm": 10.0, "quality": "river"})
	tee.pieces[4]["open"] = true
	tee.solve(2.0)
	check(tee.quality(5) == "river", "river water mixed in makes the water below it river water")

	# Tanks: fill lazily, the next event is when full; a full tank with nowhere to send water closes its branch; a tank drains through a pipe
	# whose head is fixed from its base outlet; standing water goes still, any inflow makes it fresh again.
	var tanks = Network.new()
	tanks.still_after_s = 1000.0
	tanks.add(1, {"role": "source", "outlet": Vector3(0, 1.0, 0), "rate_lpm": 60.0, "cap_lpm": 60.0, "quality": "clean"})
	tanks.add(2, {"role": "tank", "inlet": Vector3(0, 0.9, 0), "litres_max": 100.0})
	tanks.solve(0.0)
	check(is_equal_approx(tanks.litres(2, 50.0), 50.0) and is_equal_approx(tanks.next_event_s(), 100.0), "a trough under a 60 L/min spout holds 50 L after 50 s and is full at 100 s")
	tanks.solve(100.0)
	check(is_equal_approx(tanks.litres(2, 100.0), 100.0) and tanks.outflow_lpm(1) == 0.0, "full, with no outlet, it backs the pump up")
	var cistern = Network.new()
	cistern.still_after_s = 1000.0
	cistern.add(1, {"role": "tank", "inlet": Vector3(0, 2.0, 0), "outlet": Vector3(0, 0.5, 0), "litres_max": 500.0})
	cistern.add(2, _pipe(Vector3(0, 0.5, 0), Vector3(2, -0.5, 0), 120.0))
	cistern.add(3, {"role": "consumer", "inlet": Vector3(2, -0.5, 0), "room_l": 10000.0})
	cistern.set_litres(1, 100.0)
	cistern.solve(0.0)
	check(is_equal_approx(cistern.inflow_lpm(3), 120.0) and is_equal_approx(cistern.next_event_s(), 50.0), "100 L drain through a pipe 1 m under the base at 120 L/min: empty at 50 s (%.1f)" % cistern.next_event_s())
	var barrel = Network.new()
	barrel.still_after_s = 1000.0
	barrel.add(1, {"role": "source", "outlet": Vector3(0, 1.0, 0), "rate_lpm": 0.0, "cap_lpm": 10.0, "quality": "clean"})
	barrel.add(2, {"role": "tank", "inlet": Vector3(0, 0.95, 0), "litres_max": 100.0})
	barrel.set_litres(2, 40.0)
	barrel.solve(0.0)
	check(barrel.quality(2) == "clean" and is_equal_approx(barrel.next_event_s(), 1000.0), "water standing in a barrel is due to go still at still_after_s")
	barrel.solve(1001.0)
	check(barrel.quality(2) == "still", "and is still after it")
	barrel.pieces[1]["rate_lpm"] = 10.0
	barrel.solve(1002.0)
	check(barrel.quality(2) == "clean", "any inflow makes it fresh again (coordinator ruling)")
	check(is_equal_approx(float(barrel.save_litres(1062.0)[2]), 50.0), "only tank litres are saved: 40 + 10 L in a minute")

	# Removing a piece cuts the flow below it.
	net.pieces[3]["room_l"] = 100.0
	net.remove(2)
	net.solve(60.0)
	check(net.inflow_lpm(3) == 0.0, "taking the channel away leaves the plot dry")

	# Size: 256 pieces is the most; one more is refused. The solve time of the full network is printed for the gate report.
	var big = Network.new()
	big.add(0, {"role": "source", "outlet": Vector3(0, 100.0, 0), "rate_lpm": 48.0, "cap_lpm": 48.0})

	for k in range(1, 255):
		var top: float = 100.0 - 0.01 * float(k - 1)
		big.add(k, _channel(Vector3(2.0 * float(k - 1), top, 0), Vector3(2.0 * float(k), top - 0.01, 0)))

	big.add(255, {"role": "consumer", "inlet": Vector3(508.0, 100.0 - 2.54, 0), "room_l": 1000.0})
	check(big.pieces.size() == 256 and big.check(_channel(Vector3(508.0, 97.46, 0), Vector3(510.0, 97.45, 0))) == "full", "a 257th piece is refused")
	var t0: int = Time.get_ticks_usec()
	big.solve(0.0)
	var solve_us: int = Time.get_ticks_usec() - t0
	check(is_equal_approx(big.inflow_lpm(255), 48.0), "water runs the whole 254-channel, 508 m run (%.1f L/min)" % big.inflow_lpm(255))
	print("water network: one solve of a 256-piece network took %d us (target under 1500 us)" % solve_us)
	check(solve_us < 10000, "the 256-piece solve stays far under 10 ms even on a loaded machine (%d us)" % solve_us)

	print("water network: %d failures" % failures)
	quit(1 if failures > 0 else 0)

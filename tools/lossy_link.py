#!/usr/bin/env python3
"""A simulated internet link between test clients and a local game server (robot play-testers, 23 Nov 2026).

Build 9257's first hour on Dave's server found faults that every one-machine test missed (animals teleporting, a remote
player's spear floating, the pack not updating): on one machine every packet arrives at once and in order. This relay sits
between the clients and the server and makes the link behave like the internet:

    UDP  127.0.0.1:LISTEN    -> SERVER_HOST:SERVER_PORT      (ENet: the game's RPCs) delay + jitter + loss
    TCP  127.0.0.1:LISTEN+1  -> SERVER_HOST:SERVER_PORT+1    (the block line: terrain) delay + jitter, no loss (TCP resends)

Each direction gets its own delay, so the round trip is about twice --delay-ms. One relay serves any number of clients: each client
address gets its own upstream socket, so the server sees separate peers. The client must be started with --port=LISTEN and
--block-port=LISTEN+1 (terrain_client.gd test flag) so its block line goes through the relay too.

    python3 tools/lossy_link.py --listen 25000 --server-port 24600 --delay-ms 50 --jitter-ms 25 --loss 0.02

Packets keep their order in each direction unless --reorder is given (internet routes rarely reorder; ENet copes either way).
Prints one "LINK" line at the start and a "LINK totals" line every 30 s and on exit (packets in, dropped, worst delay).
Standard library only (Python 3.8+), so it runs in the cloud, on Lane B and on Dave's PC alike.
"""
import argparse
import asyncio
import random
import signal
import sys
import time


class Stats:
	def __init__(self):
		self.packets = 0
		self.dropped = 0
		self.bytes = 0
		self.worst_ms = 0.0
		self.tcp_bytes = 0
		self.clients = 0

	def line(self, tag):
		return "LINK %s: %d udp packets, %d dropped (%.1f%%), %d udp bytes, %d tcp bytes, %d clients, worst one-way delay %.0f ms" % (
			tag, self.packets, self.dropped, 100.0 * self.dropped / max(1, self.packets), self.bytes, self.tcp_bytes, self.clients, self.worst_ms)


class Shaper:
	"""Delay for each packet of one direction; keeps order unless reorder is on."""

	def __init__(self, args, rng, stats):
		self.args = args
		self.rng = rng
		self.stats = stats
		self.last_due = 0.0

	def due(self):
		d = self.args.delay_ms + self.rng.uniform(-self.args.jitter_ms, self.args.jitter_ms)
		# A burst of loss now and then is likelier than evenly spread loss, but evenly spread is enough for ENet's resend path.
		d = max(0.0, d) / 1000.0
		at = time.monotonic() + d

		if not self.args.reorder:
			at = max(at, self.last_due + 1e-6)   # strictly later: the event loop does not keep the order of timers due at the same moment
			self.last_due = at

		self.stats.worst_ms = max(self.stats.worst_ms, (at - time.monotonic()) * 1000.0)
		return at

	def drop(self):
		return self.rng.random() < self.args.loss


_TASKS = set()   # asyncio keeps only weak references to tasks: an unkept one can be collected mid-flight


def spawn(loop, coro):
	t = loop.create_task(coro)
	_TASKS.add(t)
	t.add_done_callback(_TASKS.discard)
	return t


def later(loop, at, fn, *a):
	loop.call_at(loop.time() + max(0.0, at - time.monotonic()), fn, *a)


class Upstream(asyncio.DatagramProtocol):
	"""One client's socket toward the server; replies go back to the client through the listening socket."""

	def __init__(self, relay, client_addr):
		self.relay = relay
		self.client_addr = client_addr
		self.transport = None
		self.down = Shaper(relay.args, relay.rng, relay.stats)

	def connection_made(self, transport):
		self.transport = transport

	def datagram_received(self, data, addr):
		self.relay.stats.packets += 1

		if self.down.drop():
			self.relay.stats.dropped += 1
			return

		self.relay.stats.bytes += len(data)
		later(self.relay.loop, self.down.due(), self.relay.send_to_client, data, self.client_addr)


class UdpRelay(asyncio.DatagramProtocol):
	def __init__(self, args, rng, stats, loop):
		self.args = args
		self.rng = rng
		self.stats = stats
		self.loop = loop
		self.transport = None
		self.clients = {}   # client addr -> {"up": Upstream, "shaper": Shaper (toward the server), "pending": [(due, data)]}

	def connection_made(self, transport):
		self.transport = transport

	def send_to_client(self, data, addr):
		self.transport.sendto(data, addr)

	# Handled at once, in arrival order: each packet's send time is fixed as it comes in. A new client's first packets wait in its
	# pending list (in order) while its upstream socket opens.
	def datagram_received(self, data, addr):
		entry = self.clients.get(addr)

		if entry is None:
			entry = {"up": None, "shaper": Shaper(self.args, self.rng, self.stats), "pending": []}
			self.clients[addr] = entry
			self.stats.clients += 1
			spawn(self.loop, self._open(entry, addr))

		self.stats.packets += 1

		if entry["shaper"].drop():
			self.stats.dropped += 1
			return

		self.stats.bytes += len(data)
		at = entry["shaper"].due()

		if entry["up"] is None:
			entry["pending"].append((at, data))
		else:
			later(self.loop, at, entry["up"].transport.sendto, data)

	async def _open(self, entry, addr):
		_, proto = await self.loop.create_datagram_endpoint(lambda: Upstream(self, addr), remote_addr=(self.args.server_host, self.args.server_port))
		entry["up"] = proto

		for at, data in entry["pending"]:
			later(self.loop, at, proto.transport.sendto, data)

		entry["pending"].clear()


async def pipe(reader, writer, shaper, stats, loop):
	try:
		while True:
			data = await reader.read(65536)

			if not data:
				break

			stats.tcp_bytes += len(data)
			at = shaper.due()
			await asyncio.sleep(max(0.0, at - time.monotonic()))
			writer.write(data)
			await writer.drain()
	except (ConnectionError, OSError):
		pass
	finally:
		try:
			writer.close()
		except Exception:
			pass


async def main():
	p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
	p.add_argument("--listen", type=int, required=True, help="UDP port to listen on; the block line listens on this + 1")
	p.add_argument("--server-host", default="127.0.0.1")
	p.add_argument("--server-port", type=int, required=True, help="the server's UDP port; its block line is this + 1")
	p.add_argument("--delay-ms", type=float, default=50.0, help="one-way delay (round trip is about twice this)")
	p.add_argument("--jitter-ms", type=float, default=20.0, help="each packet's delay varies by up to this either way")
	p.add_argument("--loss", type=float, default=0.02, help="share of UDP packets dropped, each direction (0.02 = 2%%)")
	p.add_argument("--reorder", action="store_true", help="let jitter reorder packets")
	p.add_argument("--seed", type=int, default=1)
	p.add_argument("--seconds", type=float, default=0.0, help="quit after this long (0 = run until killed)")
	args = p.parse_args()
	loop = asyncio.get_running_loop()
	rng = random.Random(args.seed)
	stats = Stats()
	await loop.create_datagram_endpoint(lambda: UdpRelay(args, rng, stats, loop), local_addr=("127.0.0.1", args.listen))

	async def on_tcp(reader, writer):
		try:
			up_r, up_w = await asyncio.open_connection(args.server_host, args.server_port + 1)
		except OSError:
			writer.close()
			return

		spawn(loop, pipe(reader, up_w, Shaper(args, rng, stats), stats, loop))
		spawn(loop, pipe(up_r, writer, Shaper(args, rng, stats), stats, loop))

	await asyncio.start_server(on_tcp, "127.0.0.1", args.listen + 1)
	print("LINK up: udp %d -> %s:%d, tcp %d -> %d, delay %.0f ms +- %.0f ms each way, loss %.1f%%%s" % (
		args.listen, args.server_host, args.server_port, args.listen + 1, args.server_port + 1, args.delay_ms, args.jitter_ms,
		100.0 * args.loss, ", reordering" if args.reorder else ""), flush=True)
	stop = asyncio.Event()

	for sig in (signal.SIGINT, signal.SIGTERM):
		try:
			loop.add_signal_handler(sig, stop.set)
		except NotImplementedError:   # Windows
			pass

	start = time.monotonic()
	next_line = start + 30.0

	while not stop.is_set():
		try:
			await asyncio.wait_for(stop.wait(), timeout=1.0)
		except asyncio.TimeoutError:
			pass

		if time.monotonic() >= next_line:
			print(stats.line("so far"), flush=True)
			next_line += 30.0

		if args.seconds > 0 and time.monotonic() - start > args.seconds:
			break

	print(stats.line("totals"), flush=True)


if __name__ == "__main__":
	try:
		asyncio.run(main())
	except KeyboardInterrupt:
		sys.exit(0)

"""Paint the ten gear-slot ghosts (art brief row 20) as white alpha masks that art_kit.draw_glyph tints to GHOST and shadows itself.

Shapes are art_kit.glyph_shapes (unit square) so a painted ghost sits exactly where its placeholder did; on top of each, a few engraved
detail lines (seams, rivets, laces) in a darker grey that the tint turns into a deeper cut. Holes ("-" ops) are left clear.
Usage: python3 tools/paint_gear_ghosts.py assets/ui/inventory [preview.png]   (the out folder, then an optional preview sheet on the slot colour)
"""
import math
import sys

from PIL import Image, ImageDraw

OUT = 104          # 2x the 52 px it is drawn at, so it stays sharp on a scaled-up 2560 wide screen
SS = 8             # supersampling over OUT
N = OUT * SS
CUT = 150          # grey of an engraved detail line (tinted by GHOST it reads as a deeper cut)

SHAPES = {
	"head": [["chord", 0.16, 0.14, 0.84, 0.86, 180, 360], ["rect", 0.12, 0.48, 0.88, 0.58], ["rect", 0.46, 0.5, 0.54, 0.8]],
	"body": [["poly", 0.3, 0.1, 0.42, 0.1, 0.5, 0.2, 0.58, 0.1, 0.7, 0.1, 0.94, 0.32, 0.84, 0.46, 0.74, 0.38, 0.74, 0.92,
		0.26, 0.92, 0.26, 0.38, 0.16, 0.46, 0.06, 0.32]],
	"legs": [["poly", 0.24, 0.08, 0.76, 0.08, 0.84, 0.92, 0.58, 0.92, 0.5, 0.38, 0.42, 0.92, 0.16, 0.92]],
	"feet": [["poly", 0.28, 0.06, 0.58, 0.06, 0.58, 0.56, 0.86, 0.66, 0.9, 0.88, 0.2, 0.88, 0.24, 0.56]],
	"hands": [["rect", 0.26, 0.42, 0.74, 0.92], ["rect", 0.27, 0.18, 0.37, 0.5], ["rect", 0.39, 0.12, 0.49, 0.5],
		["rect", 0.51, 0.12, 0.61, 0.5], ["rect", 0.63, 0.18, 0.73, 0.5], ["poly", 0.26, 0.6, 0.1, 0.42, 0.16, 0.36, 0.3, 0.5]],
	"outer": [["poly", 0.36, 0.08, 0.64, 0.08, 0.7, 0.2, 0.9, 0.92, 0.1, 0.92, 0.3, 0.2], ["ell-", 0.42, 0.06, 0.58, 0.2]],
	# The belt keeps the placeholder's strap and buckle place, but the buckle is drawn as a frame with its prong, so the strap reads as one piece.
	"waist": [["rect", 0.06, 0.41, 0.94, 0.59], ["rect", 0.34, 0.3, 0.6, 0.7], ["rect-", 0.4, 0.36, 0.54, 0.64], ["rect", 0.4, 0.465, 0.62, 0.535]],
	"back": [["rect", 0.2, 0.2, 0.8, 0.92], ["arc", 0.34, 0.04, 0.66, 0.36, 180, 360, 0.07], ["rect-", 0.3, 0.5, 0.7, 0.74]],
	"right": [["line", 0.2, 0.88, 0.72, 0.18, 0.08], ["poly", 0.58, 0.08, 0.9, 0.3, 0.82, 0.46, 0.62, 0.34]],
	"left": [["poly", 0.16, 0.12, 0.84, 0.12, 0.84, 0.46, 0.5, 0.92, 0.16, 0.46], ["rect-", 0.46, 0.2, 0.54, 0.76]],
}

# Engraved detail, drawn in CUT over the filled shape and clipped to it: ["line", x0, y0, x1, y1, width] or ["dot", x, y, radius].
DETAIL = {
	"head": [["line", 0.14, 0.53, 0.86, 0.53, 0.02], ["dot", 0.24, 0.53, 0.025], ["dot", 0.76, 0.53, 0.025], ["line", 0.5, 0.16, 0.5, 0.47, 0.025]],
	"body": [["line", 0.27, 0.84, 0.73, 0.84, 0.025], ["line", 0.11, 0.37, 0.19, 0.43, 0.02], ["line", 0.81, 0.43, 0.89, 0.37, 0.02],
		["line", 0.5, 0.22, 0.5, 0.5, 0.02]],
	"legs": [["line", 0.24, 0.16, 0.76, 0.16, 0.025], ["line", 0.33, 0.3, 0.27, 0.86, 0.02], ["line", 0.67, 0.3, 0.73, 0.86, 0.02]],
	"feet": [["line", 0.21, 0.8, 0.89, 0.8, 0.025], ["line", 0.3, 0.2, 0.56, 0.24, 0.02], ["line", 0.3, 0.32, 0.56, 0.36, 0.02],
		["line", 0.3, 0.44, 0.56, 0.48, 0.02]],
	"hands": [["line", 0.26, 0.82, 0.74, 0.82, 0.025]],
	"outer": [["line", 0.4, 0.24, 0.26, 0.9, 0.02], ["line", 0.6, 0.24, 0.74, 0.9, 0.02], ["line", 0.5, 0.24, 0.5, 0.9, 0.018]],
	"waist": [["dot", 0.68, 0.5, 0.022], ["dot", 0.76, 0.5, 0.022], ["dot", 0.84, 0.5, 0.022]],
	"back": [["line", 0.2, 0.44, 0.8, 0.44, 0.025], ["line", 0.5, 0.2, 0.5, 0.44, 0.02], ["line", 0.2, 0.84, 0.8, 0.84, 0.02]],
	"right": [["line", 0.64, 0.24, 0.84, 0.38, 0.02]],
	"left": [["line", 0.22, 0.18, 0.78, 0.18, 0.02], ["line", 0.22, 0.18, 0.22, 0.44, 0.02], ["line", 0.78, 0.18, 0.78, 0.44, 0.02]],
}


def _p(x, y):
	return (x * N, y * N)


def _ellipse_points(x0, y0, x1, y1, a0, a1, steps):
	cx, cy, rx, ry = (x0 + x1) * 0.5, (y0 + y1) * 0.5, (x1 - x0) * 0.5, (y1 - y0) * 0.5
	return [_p(cx + math.cos(math.radians(a0 + (a1 - a0) * i / steps)) * rx, cy + math.sin(math.radians(a0 + (a1 - a0) * i / steps)) * ry) for i in range(steps + 1)]


def _thick(draw, points, width, fill):
	w = max(1, int(round(width * N)))
	draw.line(points, fill=fill, width=w, joint="curve")

	for end in (points[0], points[-1]):
		draw.ellipse([end[0] - w / 2, end[1] - w / 2, end[0] + w / 2, end[1] + w / 2], fill=fill)


def paint(slot):
	alpha = Image.new("L", (N, N), 0)
	shade = Image.new("L", (N, N), 255)
	a = ImageDraw.Draw(alpha)

	for op in SHAPES[slot]:
		kind = op[0]
		fill = 0 if kind.endswith("-") else 255
		kind = kind.rstrip("-")
		v = op[1:]

		if kind == "poly":
			a.polygon([_p(v[i], v[i + 1]) for i in range(0, len(v), 2)], fill=fill)
		elif kind == "rect":
			a.rectangle([_p(v[0], v[1]), _p(v[2], v[3])], fill=fill)
		elif kind == "ell":
			a.ellipse([_p(v[0], v[1]), _p(v[2], v[3])], fill=fill)
		elif kind == "chord":
			a.polygon(_ellipse_points(v[0], v[1], v[2], v[3], v[4], v[5], 48), fill=fill)
		elif kind == "arc":
			_thick(a, _ellipse_points(v[0], v[1], v[2], v[3], v[4], v[5], 32), v[6], fill)
		elif kind == "line":
			_thick(a, [_p(v[0], v[1]), _p(v[2], v[3])], v[4], fill)

	s = ImageDraw.Draw(shade)

	for op in DETAIL[slot]:
		if op[0] == "line":
			_thick(s, [_p(op[1], op[2]), _p(op[3], op[4])], op[5], CUT)
		else:
			r = op[3] * N
			s.ellipse([op[1] * N - r, op[2] * N - r, op[1] * N + r, op[2] * N + r], fill=CUT)

	alpha = alpha.resize((OUT, OUT), Image.LANCZOS)
	shade = shade.resize((OUT, OUT), Image.LANCZOS)
	return Image.merge("RGBA", (shade, shade, shade, alpha))


def main():
	out_dir = sys.argv[1]
	sheet = Image.new("RGBA", (OUT * 10 + 110, OUT + 20), (0x23, 0x1A, 0x12, 255))   # FIELD, as in the game

	for k, slot in enumerate(SHAPES):
		img = paint(slot)
		img.save("%s/ghost_%s.png" % (out_dir, slot))
		tinted = Image.new("RGBA", img.size, (0x4A, 0x3C, 0x2E, 255))
		r, g, b, al = img.split()
		tint = Image.merge("RGBA", [Image.eval(c, lambda x, t=t: x * t // 255) for c, t in zip((r, g, b), (0x4A, 0x3C, 0x2E))] + [al])
		shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
		shadow.putalpha(Image.eval(al, lambda x: int(x * 0.7)))
		x = 10 + k * (OUT + 10)
		sheet.alpha_composite(shadow, (x, 12))
		sheet.alpha_composite(tint, (x, 10))
		del tinted

	if len(sys.argv) > 2:
		sheet.save(sys.argv[2])


main()

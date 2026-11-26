// Flattens the stroke-based icon sources in dev/icons/source into the single
// filled paths the app paints (app/lib/design/icons.g.dart).
//
//   cd dev/tool/icons && npm install
//   node gen_icons.mjs            # rewrite every GhIcons entry that has a source
//   node gen_icons.mjs --verify   # also rasterise the flattened path against the
//                                 # stroke version and report the pixel mismatch
//
// A source is geometry only (see the draw-icons skill, references/source-format.md).
// Everything is drawn with one stroke width (STROKE) and round caps and joins.
// `data-role="silhouette"` shapes are filled and stroked, `data-role="detail"`
// strokes are cut out of the result, every other element is a plain stroke.
// File name `cloud-arrow-down.svg` becomes `GhIcons.cloudArrowDown`.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';
import paper from 'paper-jsdom';
import ClipperLib from 'clipper-lib';

const GRID = 24;
const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, '../../..');
// the stroke width is the one in icons.yaml, so the two never drift apart
const STROKE = Number(/^\s*stroke:\s*([\d.]+)/m.exec(fs.readFileSync(path.join(root, 'icons.yaml'), 'utf8'))?.[1]);
if (!(STROKE > 0)) throw new Error('could not read dna.stroke from icons.yaml');
const srcDir = path.join(root, 'dev/icons/source');
const dartFile = path.join(root, 'app/lib/design/icons.g.dart');
const verify = process.argv.includes('--verify');

paper.setup(new paper.Size(GRID, GRID));

function attrsOf(s) {
  const out = {};
  for (const m of s.matchAll(/([\w:-]+)\s*=\s*"([^"]*)"/g)) out[m[1]] = m[2];
  return out;
}

function toPathData(tag, a) {
  const n = (v, d = 0) => (v === undefined ? d : Number(v));
  switch (tag) {
    case 'path': return a.d;
    case 'line': return `M${a.x1} ${a.y1}L${a.x2} ${a.y2}`;
    case 'polyline':
    case 'polygon': {
      const p = a.points.trim().split(/[\s,]+/).map(Number);
      let d = '';
      for (let i = 0; i + 1 < p.length; i += 2) d += `${i ? 'L' : 'M'}${p[i]} ${p[i + 1]}`;
      return tag === 'polygon' ? `${d}Z` : d;
    }
    case 'circle': {
      const cx = n(a.cx), cy = n(a.cy), r = n(a.r);
      return `M${cx - r} ${cy}A${r} ${r} 0 1 0 ${cx + r} ${cy}A${r} ${r} 0 1 0 ${cx - r} ${cy}Z`;
    }
    case 'ellipse': {
      const cx = n(a.cx), cy = n(a.cy), rx = n(a.rx), ry = n(a.ry);
      return `M${cx - rx} ${cy}A${rx} ${ry} 0 1 0 ${cx + rx} ${cy}A${rx} ${ry} 0 1 0 ${cx - rx} ${cy}Z`;
    }
    case 'rect': {
      const x = n(a.x), y = n(a.y), w = n(a.width), h = n(a.height), r = Math.min(n(a.rx), w / 2, h / 2);
      if (!r) return `M${x} ${y}H${x + w}V${y + h}H${x}Z`;
      return `M${x + r} ${y}H${x + w - r}A${r} ${r} 0 0 1 ${x + w} ${y + r}V${y + h - r}A${r} ${r} 0 0 1 ${x + w - r} ${y + h}H${x + r}A${r} ${r} 0 0 1 ${x} ${y + h - r}V${y + r}A${r} ${r} 0 0 1 ${x + r} ${y}Z`;
    }
    default: throw new Error(`unsupported element <${tag}>`);
  }
}

function parseSource(text) {
  const out = [];
  for (const m of text.matchAll(/<(path|line|polyline|polygon|circle|ellipse|rect)\b([^>]*?)\/?>/g)) {
    const a = attrsOf(m[2]);
    out.push({ d: toPathData(m[1], a), role: a['data-role'] || 'stroke' });
  }
  return out;
}

// Geometry is flattened to polylines (0.02 units) and combined with Clipper:
// offsets for the strokes, union for the body, difference for the cut-outs.
const S = 1000;
const C = ClipperLib;

// a source path as a list of { pts: [[x, y]...], closed }
function polylines(d) {
  const cp = new paper.CompoundPath({ pathData: d });
  const subs = cp.children.length ? [...cp.children] : [cp];
  return subs.map((p) => {
    const q = p.clone();
    q.flatten(0.02);
    return { pts: q.segments.map((s) => [s.point.x, s.point.y]), closed: q.closed };
  });
}

const toClip = (pts) => pts.map(([x, y]) => ({ X: Math.round(x * S), Y: Math.round(y * S) }));

function union(paths) {
  const c = new C.Clipper();
  c.AddPaths(paths, C.PolyType.ptSubject, true);
  const out = new C.Paths();
  c.Execute(C.ClipType.ctUnion, out, C.PolyFillType.pftNonZero, C.PolyFillType.pftNonZero);
  return out;
}

function offset(pathsOrPath, endType, delta) {
  const co = new C.ClipperOffset(2, 3);
  const list = Array.isArray(pathsOrPath[0]) ? pathsOrPath : [pathsOrPath];
  for (const p of list) co.AddPath(p, C.JoinType.jtRound, endType);
  const out = new C.Paths();
  co.Execute(out, delta * S);
  return out;
}

// the ink of one stroked path (round caps and joins)
function strokeInk(d) {
  const out = [];
  for (const { pts, closed } of polylines(d)) {
    if (closed && pts.length > 1 && pts[0][0] === pts.at(-1)[0] && pts[0][1] === pts.at(-1)[1]) pts.pop();
    const lengthZero = pts.length < 2 || pts.every(([x, y]) => x === pts[0][0] && y === pts[0][1]);
    if (lengthZero) {
      // a dot: a round cap turns it into a circle of the stroke width
      const [x, y] = pts[0];
      out.push(...offset(toClip([[x, y], [x + 0.001, y]]), C.EndType.etOpenRound, STROKE / 2));
    } else if (closed) out.push(...offset(toClip(pts), C.EndType.etClosedLine, STROKE / 2));
    else out.push(...offset(toClip(pts), C.EndType.etOpenRound, STROKE / 2));
  }
  return union(out);
}

// the filled body, grown by half a stroke: it is filled and stroked
function silhouetteInk(d) {
  const body = [];
  for (const { pts } of polylines(d)) body.push(toClip(pts));
  const filled = union(body);
  return union([...filled, ...offset(filled, C.EndType.etClosedPolygon, STROKE / 2)]);
}

function flatten(elements) {
  let shape = [];
  for (const e of elements) {
    if (e.role === 'silhouette') shape = union([...shape, ...silhouetteInk(e.d)]);
    else if (e.role === 'stroke') shape = union([...shape, ...strokeInk(e.d)]);
  }
  for (const e of elements) {
    if (e.role !== 'detail') continue;
    const c = new C.Clipper();
    c.AddPaths(shape, C.PolyType.ptSubject, true);
    c.AddPaths(strokeInk(e.d), C.PolyType.ptClip, true);
    const out = new C.Paths();
    c.Execute(C.ClipType.ctDifference, out, C.PolyFillType.pftNonZero, C.PolyFillType.pftNonZero);
    shape = out;
  }
  return shape;
}

// Douglas-Peucker on a closed ring, so long straight edges stay single segments
function simplifyRing(pts, eps) {
  if (pts.length < 4) return pts;
  const keep = new Array(pts.length).fill(false);
  keep[0] = true;
  let far = 0, best = -1;
  for (let i = 1; i < pts.length; i++) {
    const d = Math.hypot(pts[i][0] - pts[0][0], pts[i][1] - pts[0][1]);
    if (d > best) { best = d; far = i; }
  }
  keep[far] = true;
  const rec = (a, b) => {
    let idx = -1, max = eps;
    const [ax, ay] = pts[a % pts.length], [bx, by] = pts[b % pts.length];
    const len = Math.hypot(bx - ax, by - ay) || 1;
    for (let i = a + 1; i < b; i++) {
      const [px, py] = pts[i % pts.length];
      const dist = Math.abs((bx - ax) * (ay - py) - (ax - px) * (by - ay)) / len;
      if (dist > max) { max = dist; idx = i; }
    }
    if (idx >= 0) { keep[idx % pts.length] = true; rec(a, idx); rec(idx, b); }
  };
  rec(0, far);
  rec(far, pts.length);
  return pts.filter((_, i) => keep[i]);
}

const num = (v) => {
  const r = Math.round(v * 100) / 100;
  return Object.is(r, -0) ? '0' : String(r);
};

// Optical centring: icons whose mass sits low in the box are lifted by this many
// units when flattened (their sources keep the drawn coordinates).
const NUDGE = { bug: -1, github: -1, gitlab: -1, trash: -1 };

function pathDataOf(shape, dy = 0) {
  let d = '';
  for (const ring of shape) {
    const pts = simplifyRing(ring.map((p) => [p.X / S, p.Y / S + dy]), 0.006);
    if (pts.length < 3) continue;
    d += `M${num(pts[0][0])} ${num(pts[0][1])}`;
    for (const [x, y] of pts.slice(1)) d += `L${num(x)} ${num(y)}`;
    d += 'Z';
  }
  return d;
}

function camel(name) {
  return name.replace(/-([a-z0-9])/g, (_, c) => c.toUpperCase());
}

const files = fs.readdirSync(srcDir).filter((f) => f.endsWith('.svg') && !f.includes('@')).sort();
let dart = fs.readFileSync(dartFile, 'utf8');
const added = [];
const report = [];

const require = createRequire(path.join(root, '.agents/skills/draw-icons/scripts/'));
let Resvg = null;
if (verify) Resvg = require('@resvg/resvg-js').Resvg;

for (const f of files) {
  const name = f.slice(0, -4);
  const text = fs.readFileSync(path.join(srcDir, f), 'utf8');
  const els = parseSource(text);
  const shape = flatten(els);
  const dy = NUDGE[name] ?? 0;
  const d = pathDataOf(shape, dy);
  const id = camel(name);
  const block = `  static const ${id} = FaIconData(\n    'gh',\n    '${name}',\n    ${GRID},\n    ${GRID},\n    '${d}',\n  );`;
  const re = new RegExp(`  static const ${id} = FaIconData\\([\\s\\S]*?\\n  \\);`);
  if (re.test(dart)) dart = dart.replace(re, () => block);
  else {
    // a new source: append its entry to the end of the GhIcons class
    dart = dart.replace(/\n}\s*$/, `\n${block}\n}\n`);
    added.push(id);
  }
  if (verify) {
    const raster = (svg) => new Resvg(svg, { fitTo: { mode: 'width', value: 96 }, background: '#fff' }).render().pixels;
    const built = fs.readFileSync(path.join(root, 'dev/icons', f), 'utf8').replace(/currentColor/g, '#000');
    const flat = raster(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${GRID} ${GRID}"><path fill="#000" fill-rule="nonzero" transform="translate(0 ${-dy})" d="${d}"/></svg>`);
    const ref = raster(built);
    let bad = 0;
    for (let i = 0; i < ref.length; i += 4) if (Math.abs(ref[i] - flat[i]) > 96) bad++;
    report.push(`${name}: ${((bad / (ref.length / 4)) * 100).toFixed(2)}% pixels differ`);
  }
}

if (added.length) console.log(`added ${added.length} new GhIcons entries: ${added.join(', ')}`);
fs.writeFileSync(dartFile, dart);
console.log(`flattened ${files.length} icons`);
if (report.length) console.log(report.join('\n'));

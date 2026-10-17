import json
RINGS = [("outpost", "Outpost", "warm and lit"), ("inner_ring", "Safe ring", "pale and calm"), ("ring_one", "Ring one", "grey-blue, wind"), ("ring_two", "Ring two", "blue-black, the blizzard")]
def c(r,g,b): return "#%02x%02x%02x" % (round(r*255), round(g*255), round(b*255))
OPTIONS = [
 dict(key="table", name="A. Violet dusk", rec=True, blurb="Peach dusk light on the snow, lilac shadows that turn indigo by ring two. The amber fire pools sit on the complementary colour, so they stand out most here. Snow still reads as snow in the safe ring.",
      cost="The outpost snow goes peach, not white. If you want snow that is always cool, pick B.",
      rings={"outpost": dict(tint=c(1.00,0.95,0.88), sun=c(1.00,0.80,0.60), amb=c(0.52,0.47,0.70), fog=c(0.54,0.46,0.60), fogd=80, snow=0.2),
             "inner_ring": dict(tint=c(0.93,0.94,1.00), sun=c(1.00,0.76,0.58), amb=c(0.46,0.45,0.72), fog=c(0.56,0.57,0.74), fogd=64, snow=0.4),
             "ring_one": dict(tint=c(0.82,0.86,0.97), sun=c(0.96,0.70,0.56), amb=c(0.38,0.42,0.70), fog=c(0.44,0.49,0.66), fogd=46, snow=0.65),
             "ring_two": dict(tint=c(0.60,0.63,0.78), sun=c(0.80,0.60,0.58), amb=c(0.28,0.30,0.50), fog=c(0.20,0.22,0.34), fogd=30, snow=1.0)}),
 dict(key="steel_blue", name="B. Steel blue", rec=False, blurb="Cooler and more neutral: pale gold sun, steel-blue shadows, snow that stays near white in the outpost and goes grey-blue outward. Closest to the brief's literal words (grey-blue, blue-black).",
      cost="Least mood of the three; the dusk reads as overcast afternoon in the inner rings, and the fire pools pop a little less.",
      rings={"outpost": dict(tint=c(1.00,0.95,0.88), sun=c(1.00,0.80,0.58), amb=c(0.55,0.62,0.78), fog=c(0.58,0.62,0.70), fogd=80, snow=0.2),
             "inner_ring": dict(tint=c(0.90,0.94,1.00), sun=c(1.00,0.76,0.56), amb=c(0.50,0.58,0.78), fog=c(0.60,0.66,0.78), fogd=64, snow=0.4),
             "ring_one": dict(tint=c(0.76,0.82,0.92), sun=c(0.94,0.70,0.56), amb=c(0.42,0.50,0.70), fog=c(0.46,0.53,0.64), fogd=46, snow=0.65),
             "ring_two": dict(tint=c(0.56,0.60,0.70), sun=c(0.78,0.62,0.58), amb=c(0.30,0.34,0.46), fog=c(0.20,0.24,0.31), fogd=30, snow=1.0)}),
 dict(key="ember_and_ink", name="C. Ember and ink", rec=False, blurb="Pushed hardest: a rose-amber sun, violet shadows everywhere, ring two near ink. The most stylised and the most 'dusk'.",
      cost="The outpost and safe ring go pink; telegraph cues and ore glints sit on a tinted ground, so readability costs a little. Easy to tire of.",
      rings={"outpost": dict(tint=c(1.00,0.93,0.84), sun=c(1.00,0.70,0.46), amb=c(0.50,0.40,0.72), fog=c(0.48,0.36,0.54), fogd=76, snow=0.2),
             "inner_ring": dict(tint=c(0.94,0.90,1.00), sun=c(1.00,0.62,0.40), amb=c(0.48,0.38,0.78), fog=c(0.54,0.48,0.74), fogd=60, snow=0.4),
             "ring_one": dict(tint=c(0.78,0.78,0.98), sun=c(0.94,0.56,0.42), amb=c(0.38,0.34,0.76), fog=c(0.38,0.38,0.64), fogd=42, snow=0.65),
             "ring_two": dict(tint=c(0.54,0.54,0.74), sun=c(0.80,0.50,0.46), amb=c(0.26,0.24,0.50), fog=c(0.16,0.15,0.30), fogd=26, snow=1.0)}),
]

def shots(prefix, cls=""):
    cells = []
    for key, label, note in RINGS:
        cells.append(f'''<figure class="shot {cls}"><img src="{prefix}_{key}.jpg" alt="{label}" loading="lazy" onclick="zoom(this)"><figcaption><b>{label}</b> <span>{note}</span></figcaption></figure>''')
    return "\n".join(cells)

def swatches(opt):
    rows = []
    for key, label, note in RINGS:
        r = opt["rings"][key]
        rows.append(f'''<div class="sw"><span class="sw-name">{label}</span>
<i title="sun {r['sun']}" style="background:{r['sun']}"></i><i title="shadows {r['amb']}" style="background:{r['amb']}"></i><i title="snow tint {r['tint']}" style="background:{r['tint']}"></i><i title="fog {r['fog']}" style="background:{r['fog']}"></i>
<span class="sw-meta">fog {r['fogd']} m · snow {int(r['snow']*100)}%</span></div>''')
    return "\n".join(rows)

options_html = ""
for o in OPTIONS:
    rec = '<span class="pill">Recommended</span>' if o["rec"] else ""
    options_html += f'''
<section class="option" id="opt-{o['key']}" data-key="{o['key']}">
  <header class="opt-head"><h2>{o['name']} {rec}</h2>
    <div class="legend"><i style="background:#f3c08a"></i>sun <i style="background:#7a6fb0"></i>shadows <i style="background:#e6e8f5"></i>snow tint <i style="background:#8a8fb5"></i>fog</div></header>
  <div class="opt-body">
    <div class="grid4">{shots(o['key'])}</div>
    <aside class="opt-notes">
      <p class="why">{o['blurb']}</p>
      <p class="cost"><b>Cost.</b> {o['cost']}</p>
      <div class="swatches">{swatches(o)}</div>
    </aside>
  </div>
</section>'''

html = f'''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><title>Frostmark ring palettes: pick one</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
@font-face {{ font-family: Cinzel; src: url(Cinzel.ttf); font-weight: 400 900; }}
@font-face {{ font-family: Inter; src: url(Inter.ttf); font-weight: 100 900; }}
*, *::before, *::after {{ box-sizing: border-box; }}
:where(.grid4, .opt-body, .legend, .sw, .decision-grid) > * {{ min-width: 0; }}
html {{ background: #0d131c; color: #dfe6f2; font: 15px/1.5 Inter, system-ui, sans-serif; }}
body {{ margin: 0; padding: 32px clamp(16px, 4vw, 56px) 96px; max-width: 1480px; margin-inline: auto; }}
h1, h2, h3 {{ font-family: Cinzel, serif; font-weight: 600; letter-spacing: .02em; color: #eef3ff; margin: 0; }}
h1 {{ font-size: 34px; }} h2 {{ font-size: 22px; }} h3 {{ font-size: 17px; }}
p {{ margin: .4em 0; overflow-wrap: anywhere; }}
.lede {{ color: #aab7cc; max-width: 70ch; }}
.frame {{ background: linear-gradient(180deg, #162030, #111a26); border: 1px solid #2a3a52; border-radius: 10px; box-shadow: 0 1px 0 #3b4e6a inset, 0 10px 30px #0006; }}
.topbar {{ display: flex; flex-wrap: wrap; gap: 16px 32px; align-items: end; justify-content: space-between; margin-bottom: 22px; }}
.toggle {{ display: inline-flex; gap: 10px; align-items: center; padding: 10px 14px; font-size: 14px; }}
.pill {{ display: inline-block; font: 600 11px/1 Inter, sans-serif; letter-spacing: .08em; text-transform: uppercase; color: #0d131c; background: #e9b96e; border-radius: 999px; padding: 6px 10px; vertical-align: middle; margin-left: 8px; }}
section.option, section.today, section.decision, section.fixed {{ margin: 26px 0; padding: 18px 20px 20px; }}
.opt-head {{ display: flex; flex-wrap: wrap; gap: 8px 20px; align-items: center; justify-content: space-between; margin-bottom: 12px; }}
.legend {{ display: flex; gap: 6px 14px; align-items: center; font-size: 12px; color: #aab7cc; }}
.legend i, .sw i {{ display: inline-block; width: 14px; height: 14px; border-radius: 3px; border: 1px solid #0008; vertical-align: -2px; margin-right: 4px; }}
.opt-body {{ display: grid; grid-template-columns: minmax(0, 3fr) minmax(0, 1fr); gap: 18px; }}
@media (max-width: 980px) {{ .opt-body {{ grid-template-columns: minmax(0, 1fr); }} }}
.grid4 {{ display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 10px; }}
@media (max-width: 760px) {{ .grid4 {{ grid-template-columns: repeat(2, minmax(0, 1fr)); }} }}
figure.shot {{ margin: 0; }}
figure.shot img {{ display: block; width: 100%; height: auto; border-radius: 6px; border: 1px solid #2a3a52; cursor: zoom-in; }}
figure.shot figcaption {{ font-size: 12.5px; color: #c4cfe0; margin-top: 6px; }} figure.shot figcaption span {{ color: #8c9bb5; }}
.toon img {{ filter: url(#toon); }}
.opt-notes {{ font-size: 14px; }}
.why {{ color: #dfe6f2; }} .cost {{ color: #e2b878; }}
.swatches {{ margin-top: 10px; display: grid; gap: 6px; }}
.sw {{ display: grid; grid-template-columns: 76px auto 1fr; align-items: center; gap: 6px; font-size: 12px; color: #aab7cc; }}
.sw-name {{ color: #dfe6f2; }} .sw-meta {{ text-align: right; white-space: nowrap; }}
.today .grid4 img {{ filter: none !important; }}
.decision-grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); gap: 16px; }}
fieldset {{ border: 1px solid #2a3a52; border-radius: 8px; padding: 12px 14px; margin: 0; }}
legend {{ font-family: Cinzel, serif; color: #eef3ff; padding: 0 6px; }}
label.choice {{ display: flex; gap: 10px; align-items: flex-start; padding: 8px 6px; border-radius: 6px; cursor: pointer; }}
label.choice:hover {{ background: #1b2738; }} label.choice small {{ color: #8c9bb5; display: block; }}
textarea {{ width: 100%; min-height: 84px; background: #0b1119; color: #dfe6f2; border: 1px solid #2a3a52; border-radius: 6px; padding: 8px; font: 14px Inter, sans-serif; }}
button.queue {{ font: 600 14px Inter, sans-serif; letter-spacing: .04em; background: #e9b96e; color: #0d131c; border: 0; border-radius: 8px; padding: 12px 18px; cursor: pointer; }}
button.queue:hover {{ background: #f3c98a; }}
.status {{ margin-left: 12px; color: #8fd19e; font-size: 13px; }}
.fixed ul {{ margin: 6px 0 0; padding-left: 18px; color: #c4cfe0; }} .fixed li {{ margin: 3px 0; }}
dialog {{ border: 0; background: transparent; max-width: 96vw; }} dialog img {{ max-width: 94vw; max-height: 92vh; border-radius: 8px; box-shadow: 0 20px 60px #000c; }}
dialog::backdrop {{ background: #000b; }}
kbd {{ font: 12px Inter; background: #1b2738; border: 1px solid #2a3a52; border-radius: 4px; padding: 1px 5px; }}
</style></head>
<body>
<svg width="0" height="0" style="position:absolute"><filter id="toon" color-interpolation-filters="sRGB">
  <feComponentTransfer><feFuncR type="discrete" tableValues="0.08 0.22 0.38 0.55 0.72 0.9"/><feFuncG type="discrete" tableValues="0.08 0.22 0.38 0.55 0.72 0.9"/><feFuncB type="discrete" tableValues="0.1 0.26 0.42 0.6 0.78 0.95"/></feComponentTransfer>
  <feConvolveMatrix order="3" kernelMatrix="-1 -1 -1 -1 8 -1 -1 -1 -1" result="edges" preserveAlpha="true"/>
  <feColorMatrix in="edges" type="matrix" values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  -3 -3 -3 0 1" result="ink"/>
  <feComponentTransfer in="SourceGraphic" result="bands"><feFuncR type="discrete" tableValues="0.08 0.22 0.38 0.55 0.72 0.9"/><feFuncG type="discrete" tableValues="0.08 0.22 0.38 0.55 0.72 0.9"/><feFuncB type="discrete" tableValues="0.1 0.26 0.42 0.6 0.78 0.95"/></feComponentTransfer>
  <feComposite in="bands" in2="ink" operator="over"/>
</filter></svg>

<div class="topbar">
  <div><h1>Ring palettes: pick one</h1>
  <p class="lede">Ticket #18. Every ring gets its own look from one table (sun, shadows, fog, snow tint, snow density, wind, aurora), blended over an 8 m band at each boundary. The sun, the fire pools, the aurora band and the grade are built; only the <b>colours</b> are the taste call. Three sets below, each rendered from the real scene at the same four spots with the HUD hidden. Click any image to enlarge.</p></div>
  <label class="toggle frame"><input type="checkbox" id="toon-toggle" onchange="document.body.classList.toggle('toon', this.checked)"> <span><b>Toon banding + outlines</b> preview<br><small style="color:#8c9bb5">An image filter over the renders, not the engine. Shows what posterised light and an ink edge would do.</small></span></label>
</div>

<section class="today frame">
  <header class="opt-head"><h2>Today, on main</h2><span style="color:#8c9bb5;font-size:13px">Chrome, same spots, HUD on. Noon of the day-night cycle, near-white snow, every ring the same.</span></header>
  <div class="grid4">{shots("today")}</div>
</section>

{options_html}

<section class="fixed frame">
  <h2>What is the same in all three</h2>
  <ul>
    <li><b>Fixed dusk.</b> One low sun (17° up, from the south-west), long shadows to the north-east. The 480 s day-night cycle and the breath puffs are gone.</li>
    <li><b>Blend band.</b> 8 m centred on each boundary; the look deep in a ring is exactly its table entry, and tests hold that colder and darker outward is monotonic.</li>
    <li><b>Fire pools.</b> Every fire and the brazier lay an amber disc out to the edge of its warmth radius (3 m past the footprint) plus a dynamic light; only the four fires nearest the player carry a light, the rest keep the disc.</li>
    <li><b>Aurora.</b> The camera never sees the sky at 55° pitch, so the aurora is a faint green-to-violet band of light across the top of the view, growing from nothing in the outpost to full in ring two.</li>
    <li><b>Grade.</b> One screen-space pass: split tone (shadows toward the ring's ambient, lights toward its sun), contrast 1.05, saturation 0.9.</li>
    <li><b>Toon.</b> My recommendation is <b>no</b>: flat shading already reads clean from this camera, banding posterises the snow's mottling, and outlines double the draw calls. The toggle above shows the idea if you want it anyway.</li>
  </ul>
</section>

<section class="decision frame">
  <h2>Your pick</h2>
  <form data-lavish-question="ring-palette" onsubmit="event.preventDefault(); const fd = new FormData(event.currentTarget); const pick = fd.get('palette'); if (!pick) {{ document.getElementById('status').textContent = 'Choose a palette first.'; return; }} const toon = fd.get('toon') || 'none'; const notes = (fd.get('notes') || '').trim(); const text = 'Ring palette pick: ' + pick + '. Toon/outlines: ' + toon + (notes ? '. Notes: ' + notes : ''); window.lavish.queuePrompt(text, {{ tag: 'choice', text: text, element: event.currentTarget, data: {{ question: 'ring-palette', palette: pick, toon: toon, notes: notes }} }}); document.getElementById('status').textContent = 'Queued. Press Send to Agent in the Lavish bar.';">
  <div class="decision-grid">
    <fieldset><legend>Palette</legend>
      <label class="choice"><input type="radio" name="palette" value="A violet dusk" checked> <span>A. Violet dusk <small>recommended</small></span></label>
      <label class="choice"><input type="radio" name="palette" value="B steel blue"> <span>B. Steel blue</span></label>
      <label class="choice"><input type="radio" name="palette" value="C ember and ink"> <span>C. Ember and ink</span></label>
    </fieldset>
    <fieldset><legend>Toon banding or outlines</legend>
      <label class="choice"><input type="radio" name="toon" value="none" checked> <span>None <small>recommended: flat shading as is</small></span></label>
      <label class="choice"><input type="radio" name="toon" value="banding only"> <span>Banding only</span></label>
      <label class="choice"><input type="radio" name="toon" value="banding and outlines"> <span>Banding and outlines</span></label>
    </fieldset>
    <fieldset><legend>Notes (optional)</legend>
      <textarea name="notes" placeholder="e.g. A, but keep the outpost snow whiter; or mix: A's inner rings with C's ring two."></textarea>
    </fieldset>
  </div>
  <p style="margin-top:14px"><button type="submit" class="queue">Queue this answer</button><span class="status" id="status"></span></p>
  <p style="color:#8c9bb5;font-size:13px">You can also annotate any image or line directly. Mixes are fine: the table is data, so a per-ring swap costs nothing.</p>
  </form>
</section>

<dialog id="zoom-box" onclick="this.close()"><img id="zoom-img" alt=""></dialog>
<script>
function zoom(img) {{ const d = document.getElementById('zoom-box'); const z = document.getElementById('zoom-img'); z.src = img.src; z.style.filter = getComputedStyle(img).filter; d.showModal(); }}
</script>
</body></html>'''
open('.lavish/ring-palette/board.html','w').write(html)
print(len(html))

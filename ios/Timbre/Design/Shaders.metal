// Timbre's signature effects, drawn by SwiftUI's `colorEffect` and `layerEffect` (wrappers in Design/Shaders.swift).
//
// Positions are in points, in the coordinate space of the view an effect is attached to. Each effect is a short
// moment written in closed form of its time argument: no state, a handful of multiply-adds and exps per pixel.
// The Swift side turns them off under Reduce Motion and in Low Power Mode, and only while their moment runs.

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

namespace timbre {

/// exp(-(x / w)^2): 1 at x = 0, falling off softly either side.
inline float bump(float x, float w) {
    float k = x / w;
    return exp(-k * k);
}

/// The point of the segment a→b nearest to p: its distance from p (x) and how far along the segment it lies, in points (y).
inline float2 nearest(float2 p, float2 a, float2 b) {
    float2 ab = b - a;
    float length2 = max(dot(ab, ab), 0.001);
    float u = clamp(dot(p - a, ab) / length2, 0.0, 1.0);
    return float2(distance(p, a + ab * u), u * sqrt(length2));
}

/// 1 inside the box (x, y, width, height) grown by `margin`, fading to 0 over its outer edge; 0 for an empty box.
inline float softBox(float2 p, float4 box, float margin) {
    if (box.z < 1.0 || box.w < 1.0) {
        return 0.0;
    }
    float2 extent = box.zw * 0.5 + margin;
    float2 q = abs(p - (box.xy + box.zw * 0.5)) / extent;
    return 1.0 - smoothstep(0.72, 1.0, max(q.x, q.y));
}

} // namespace timbre

/// The lock shimmer (`LockShimmer`), drawn over the stage and added to it: the moment a string locks, a flash and a
/// ring leave its peg, a band of light sweeps down the headstock to the nut, and a comet runs down the string from
/// its post past the nut, its trail cooling behind it. `head` is the headstock's box (x, y, width, height; empty:
/// no sweep), `t` the seconds since the lock (about 1.15 s in all), `tint` the in-tune mint.
[[ stitchable ]] half4 timbreLockShimmer(float2 position, half4 color,
                                         float2 peg, float2 post, float2 nut, float2 saddle,
                                         float4 head, float t, half4 tint) {
    float3 mint = float3(tint.rgb);
    float3 white = float3(1.0);
    float3 light = float3(0.0);

    // 1. The peg: a flash, and a ring that leaves it, thinning as it goes.
    float toPeg = distance(position, peg);
    light += mix(mint, white, float3(0.55)) * timbre::bump(toPeg, 20.0) * exp(-7.0 * t) * 0.9;
    float r = saturate(t / 0.8);
    float ringRadius = 14.0 + 110.0 * (1.0 - (1.0 - r) * (1.0 - r) * (1.0 - r));
    light += mint * timbre::bump(toPeg - ringRadius, 1.5 + 5.0 * r) * (1.0 - r) * (1.0 - r) * 0.8;

    // 2. The headstock: a glint-tilted band of light sweeps down it, from above the pegs to the nut.
    float2 top = float2(head.x + head.z * 0.5, head.y);
    float span = max(distance(nut, top), 1.0);
    float2 down = (nut - top) / span;
    float2 tilted = normalize(down + float2(-down.y, down.x) * 0.45);
    float sweep = saturate(t / 0.55);
    float band = timbre::bump(dot(position - top, tilted) - mix(-40.0, span + 40.0, sweep), 14.0);
    light += mix(mint, white, float3(0.35)) * band * timbre::softBox(position, head, 22.0) * sin(sweep * M_PI_F) * 0.32;

    // 3. The string: a comet from the post down past the nut toward the saddle.
    float2 upper = timbre::nearest(position, post, nut);
    float2 lower = timbre::nearest(position, nut, saddle);
    float headLength = distance(post, nut);
    float d = upper.x;
    float along = upper.y;
    if (lower.x < upper.x) {
        d = lower.x;
        along = headLength + lower.y;
    }
    float speed = max(560.0, headLength / 0.4);
    float behind = (t - 0.06) * speed - along;
    float trail = behind >= 0.0 ? exp(-behind / 90.0) : timbre::bump(behind, 9.0);
    trail *= step(0.06, t) * (1.0 - smoothstep(0.8, 1.15, t));
    float core = timbre::bump(d, 1.2);
    float glow = timbre::bump(d, 5.0) * 0.5;
    float wash = timbre::bump(d, 26.0) * timbre::bump(behind, 40.0) * 0.18;
    light += (white * core * 0.85 + mint * (glow + wash + core * 0.3)) * trail;

    light = min(light, float3(1.0));
    float alpha = max(light.r, max(light.g, light.b));
    return half4(half3(light), half(alpha));
}

/// The chromatic strobe disc as a liquid surface (`strobeRipple`): ripples run out through its rings when the pitch
/// is sharp (the strobe's `phase`, 0..<1, climbs) and in when it is flat, `depth` (0…1) deep as it is far off, still
/// in tune. `shock` (seconds since the lock; 0.9 or more: none) rolls one ring of `tint` light out across the disc.
/// The disc's outer ring sits at 0.43 of the shorter side from the centre. (`ChromaticStage`'s dial now takes only
/// the lock's ring from it, depth 0: from the hub out to the note wheel.)
[[ stitchable ]] half4 timbreStrobeRipple(float2 position, SwiftUI::Layer layer, float4 bounds,
                                          float phase, float depth, float shock, half4 tint) {
    float2 center = bounds.xy + bounds.zw * 0.5;
    float radius = max(min(bounds.z, bounds.w) * 0.43, 1.0);
    float2 offset = position - center;
    float r = length(offset);
    float2 outward = r > 0.5 ? offset / r : float2(0.0);
    float x = r / radius;

    // The ripple lives in the band of rings only.
    float ripple = depth * smoothstep(0.55, 0.7, x) * (1.0 - smoothstep(1.06, 1.22, x));
    float wave = sin((x * 9.0 - phase) * 2.0 * M_PI_F);

    // The lock: a ring of light from inside the disc out past its rings, gone in 0.9 s.
    float k = saturate(shock / 0.9);
    float ring = timbre::bump(x - mix(0.5, 1.15, 1.0 - (1.0 - k) * (1.0 - k)), 0.05) * (1.0 - k);

    half4 sampled = layer.sample(position - outward * (2.2 * ripple * wave + 6.0 * ring));
    float glow = ring * 0.6;
    float alpha = min(1.0, float(sampled.a) + glow);
    float3 rgb = float3(sampled.rgb) * (1.0 + 0.45 * ripple * wave) + float3(tint.rgb) * glow;
    return half4(half3(min(rgb, float3(alpha))), half(alpha));
}

/// The chromatic strobe disc's lamp (`strobeLamp`, ChromaticStage): the light behind the slotted disc spills a few
/// points round every lit slot (`glow`, 0…1), and while the disc turns its slots smear along their own circles as a
/// real strobe's do when it races, over `spin` radians centred on each point (a still disc: no smear). The disc turns
/// about the centre of `bounds`. Seven taps along the circle, sixteen for the bloom.
[[ stitchable ]] half4 timbreStrobeLamp(float2 position, SwiftUI::Layer layer, float4 bounds, float spin, float glow) {
    float2 center = bounds.xy + bounds.zw * 0.5;
    float2 offset = position - center;

    // The smear: the layer averaged along this point's circle.
    half4 base = half4(0.0h);
    for (int i = 0; i < 7; i++) {
        float a = spin * (float(i) / 6.0 - 0.5);
        float c = cos(a);
        float s = sin(a);
        base += layer.sample(center + float2(offset.x * c - offset.y * s, offset.x * s + offset.y * c));
    }
    base = base / 7.0h;

    // The bloom: two rings of taps round the point, near and (fainter) far.
    half4 halo = half4(0.0h);
    for (int i = 0; i < 8; i++) {
        float a = float(i) * (M_PI_F * 0.25) + 0.39;
        float2 d = float2(cos(a), sin(a));
        halo += layer.sample(position + d * 3.0) + layer.sample(position + d * 7.5) * 0.5h;
    }
    halo = halo / 12.0h;

    float g = saturate(glow) * 0.8;
    float alpha = min(1.0, float(base.a) + float(halo.a) * g);
    float3 rgb = float3(base.rgb) + float3(halo.rgb) * g;
    return half4(half3(min(rgb, float3(alpha))), half(alpha));
}

/// Heat glow on a reward star (`StarHeat`): it lands white-hot with its points glowing orange and its edge wavering
/// in the heat haze, cools to its own gold over about two seconds, and a glint crosses it on the way. `bounds` is
/// the star's frame, `t` the seconds since it landed.
[[ stitchable ]] half4 timbreHeatStar(float2 position, SwiftUI::Layer layer, float4 bounds, float t) {
    float2 uv = (position - bounds.xy) / max(bounds.zw, float2(1.0));
    float heat = exp(-2.6 * max(t, 0.0));
    float2 haze = float2(sin(position.y * 0.31 + t * 26.0), cos(position.x * 0.27 + t * 21.0)) * (1.6 * heat);
    half4 sampled = layer.sample(position + haze);
    float alpha = float(sampled.a);
    if (alpha < 0.002) {
        return half4(0.0h);
    }
    float3 gold = float3(sampled.rgb) / alpha;
    // White at the core, orange at the points, all of it cooling back to gold as the heat falls.
    float core = saturate(1.0 - length((uv - float2(0.5, 0.54)) * float2(1.0, 1.1)) * 1.7);
    float3 color = mix(gold, float3(1.0, 0.6, 0.2), float3(heat * (1.0 - core) * 0.55));
    color = mix(color, float3(1.0, 0.97, 0.86), float3(heat * (0.3 + 0.7 * core)));
    color *= 1.0 + 0.1 * heat * sin(t * 47.0 + uv.y * 13.0);
    // The glint: a diagonal sweep of light, top left to bottom right.
    float g = saturate((t - 0.45) / 0.7);
    color += timbre::bump(dot(uv, float2(0.83, 0.56)) - mix(-0.25, 1.65, g), 0.075) * sin(g * M_PI_F) * 0.75;
    return half4(half3(saturate(color) * alpha), half(alpha));
}

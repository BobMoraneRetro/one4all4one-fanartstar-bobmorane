// ecran_4coins.glsl : l image (vidéo ou capture) épouse exactement un quadrilatère de l écran (vraie perspective).
// Les 4 coins sont donnés en pixels d un décor plein écran de 1920 x 1080 (relevés dans le PNG du décor),
// quelle que soit la résolution réelle. L élément doit couvrir le quadrilatère (le plus simple : pos 0 0, size 1 1) ;
// rien n est dessiné en dehors.
// Réglages :
//   coinHG, coinHD, coinBD, coinBG   coins haut-gauche, haut-droit, bas-droit, bas-gauche (x y en pixels du décor)
//   proportions   0 = l image remplit le quadrilatère (défaut) ; 1 = l image garde ses proportions (bandes noires)
//   saturationEcran  1 = normale, 0 = noir et blanc (toujours le donner dans le XML : 0 si absent)
//   fondNoir      1 = le quadrilatère est rempli de noir là où il n y a pas d image (bandes) ; 0 = transparent
#if defined(VERTEX)

#if __VERSION__ >= 130
#define COMPAT_VARYING out
#define COMPAT_ATTRIBUTE in
#else
#define COMPAT_VARYING varying
#define COMPAT_ATTRIBUTE attribute
#endif

uniform mat4 MVPMatrix;
COMPAT_ATTRIBUTE vec2 VertexCoord;
COMPAT_ATTRIBUTE vec2 TexCoord;
COMPAT_ATTRIBUTE vec4 COLOR;

COMPAT_VARYING vec2 v_tex;
COMPAT_VARYING vec4 v_col;
COMPAT_VARYING vec2 v_pos;
COMPAT_VARYING vec2 v_ecran;

void main(void)
{
    gl_Position = MVPMatrix * vec4(VertexCoord.xy, 0.0, 1.0);
    v_tex = TexCoord;
    v_col = COLOR;
    v_pos = VertexCoord;
    // position à l écran : 0 0 = haut gauche, 1 1 = bas droite
    vec2 ndc = gl_Position.xy / gl_Position.w;
    v_ecran = vec2(0.5 * (ndc.x + 1.0), 0.5 * (1.0 - ndc.y));
}

#elif defined(FRAGMENT)

#if __VERSION__ >= 130
#define COMPAT_VARYING in
#define COMPAT_TEXTURE texture
out vec4 FragColor;
#else
#define COMPAT_VARYING varying
#define FragColor gl_FragColor
#define COMPAT_TEXTURE texture2D
#endif

#ifdef GL_ES
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif
#endif

uniform sampler2D u_tex;
uniform vec2  textureSize;
uniform vec2  coinHG;
uniform vec2  coinHD;
uniform vec2  coinBD;
uniform vec2  coinBG;
uniform float proportions;
uniform float saturationEcran;
uniform float fondNoir;

COMPAT_VARYING vec2 v_tex;
COMPAT_VARYING vec4 v_col;
COMPAT_VARYING vec2 v_pos;
COMPAT_VARYING vec2 v_ecran;

void main(void)
{
    vec2 D  = vec2(1920.0, 1080.0);
    vec2 p0 = coinHG / D, p1 = coinHD / D, p2 = coinBD / D, p3 = coinBG / D;

    // homographie carré unité -> quadrilatère : (0,0)->HG, (1,0)->HD, (1,1)->BD, (0,1)->BG
    float dx1 = p1.x - p2.x, dx2 = p3.x - p2.x, dx3 = p0.x - p1.x + p2.x - p3.x;
    float dy1 = p1.y - p2.y, dy2 = p3.y - p2.y, dy3 = p0.y - p1.y + p2.y - p3.y;
    float den = dx1 * dy2 - dx2 * dy1;
    if (abs(den) < 1e-9) den = 1e-9;
    float g = (dx3 * dy2 - dx2 * dy3) / den;
    float h = (dx1 * dy3 - dx3 * dy1) / den;
    float a = p1.x - p0.x + g * p1.x, b = p3.x - p0.x + h * p3.x, c = p0.x;
    float d = p1.y - p0.y + g * p1.y, e = p3.y - p0.y + h * p3.y, f = p0.y;

    // inverse (matrice adjointe) appliquée au point de l écran
    float A = e - f * h, B = c * h - b, C = b * f - c * e;
    float Dd = f * g - d, E = a - c * g, F = c * d - a * f;
    float G = d * h - e * g, H = b * g - a * h, I = a * e - b * d;
    vec2  s = v_ecran;
    float w = G * s.x + H * s.y + I;
    vec2  uv = vec2(A * s.x + B * s.y + C, Dd * s.x + E * s.y + F) / w;

    // bord net mais lissé : couverture d après la distance au bord en pixels d écran
    vec2  fw  = max(fwidth(uv), vec2(1e-6));
    vec2  ed  = min(uv, 1.0 - uv) / fw;
    float cov = clamp(min(ed.x, ed.y) + 0.5, 0.0, 1.0);
    if (cov <= 0.0) discard;

    // proportions gardées : l image est centrée dans le quadrilatère, bandes autour
    vec2 t = uv;
    float dedans = 1.0;
    if (proportions > 0.5 && textureSize.x > 0.0 && textureSize.y > 0.0) {
        vec2  lq  = vec2(length((p1 - p0) * D) + length((p2 - p3) * D), length((p3 - p0) * D) + length((p2 - p1) * D));
        float aQ  = lq.x / max(lq.y, 1.0);
        float aT  = textureSize.x / textureSize.y;
        vec2  k   = aT > aQ ? vec2(1.0, aQ / aT) : vec2(aT / aQ, 1.0);
        t = (uv - 0.5) / k + 0.5;
        vec2 et = min(t, 1.0 - t) / max(fwidth(t), vec2(1e-6));
        dedans = clamp(min(et.x, et.y) + 0.5, 0.0, 1.0);
    }

    // sens vertical de la texture (une vidéo et une image ne sont pas rangées dans le même sens)
    float sensT = dot(vec2(dFdx(v_tex.y), dFdy(v_tex.y)), vec2(dFdx(v_pos.y), dFdy(v_pos.y)));
    vec2  tc = clamp(vec2(t.x, sensT < 0.0 ? 1.0 - t.y : t.y), 0.0, 1.0);

    vec4 col = COMPAT_TEXTURE(u_tex, tc) * v_col;
    float sat = saturationEcran;
    if (sat < 0.999) {
        float l = dot(col.rgb, vec3(0.299, 0.587, 0.114));
        col.rgb = mix(vec3(l), col.rgb, clamp(sat, 0.0, 2.0));
    }
    vec4 fond = vec4(0.0, 0.0, 0.0, fondNoir > 0.5 ? v_col.a : 0.0);
    col = mix(fond, col, dedans);
    FragColor = vec4(col.rgb, col.a * cov);
}

#endif

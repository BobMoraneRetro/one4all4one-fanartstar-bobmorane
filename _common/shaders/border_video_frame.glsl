#if defined(VERTEX)

#if __VERSION__ >= 130
#define COMPAT_VARYING out
#define COMPAT_ATTRIBUTE in
#define COMPAT_TEXTURE texture
#else
#define COMPAT_VARYING varying 
#define COMPAT_ATTRIBUTE attribute 
#define COMPAT_TEXTURE texture2D
#endif

#ifdef GL_ES
#define COMPAT_PRECISION mediump
#else
#define COMPAT_PRECISION
#endif

uniform   mat4 MVPMatrix;
COMPAT_ATTRIBUTE vec2 VertexCoord;
COMPAT_ATTRIBUTE vec2 TexCoord;
COMPAT_ATTRIBUTE vec4 COLOR;
COMPAT_VARYING   vec2 v_tex;
COMPAT_VARYING   vec4 v_col;
COMPAT_VARYING   vec2 v_pos;

void main(void)                                     
{                                                   
    gl_Position = MVPMatrix * vec4(VertexCoord.xy, 0.0, 1.0);
    v_tex       = TexCoord;                           
    v_col       = COLOR;                           
    v_pos       = VertexCoord;
}

#elif defined(FRAGMENT)

// fwidth() requis pour l'antialiasing (GLSL ES 1.0)
#extension GL_OES_standard_derivatives : enable

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
#define COMPAT_PRECISION mediump
#else
#define COMPAT_PRECISION
#endif

// ─────────────────────────────────────────────────────────────
//  Valeurs par défaut des réglages (modifiables en XML, voir les uniforms plus bas)
// ─────────────────────────────────────────────────────────────
#define GLASS_DEFAULT     0.55                  // glassAmount : reflets du verre (formes 1 et 5)
#define GLOW_DEFAULT      1.5                   // glowAmount  : intensité de la lueur (forme 4)
#define ACCENT            vec3(0.10, 0.90, 1.00) // couleur d'accent par défaut des formes lumineuses (8, 9, 11)
// ─────────────────────────────────────────────────────────────

COMPAT_VARYING   vec4      v_col;
COMPAT_VARYING   vec2      v_tex;
COMPAT_VARYING   vec2      v_pos;

uniform sampler2D u_tex;
uniform vec2 textureSize;
uniform vec2 outputSize;
uniform vec2 outputOffset;

// Épaisseur du cadre (toutes les formes avec cadre). 0 = automatique.
// < 1 : fraction de la hauteur, >= 1 : pixels (comme avant).
uniform float borderSize;
// Couleur : lunette (1, 5), bois (2), métal (3, 6), papier (7), néon / HUD / LED (8, 9, 11), verre teinté (10).
// Alpha 0 = couleur par défaut de la forme.
uniform vec4  borderColor;

uniform float cornerRadius;         // 0 = automatique (forme 11 : taille des coins coupés)
uniform float innerShadowSize;      // ombre du rebord sur la vidéo, 0 = automatique
uniform vec4  innerShadowColor;     // couleur secondaire des formes 12 (cœur), 13, 17 (2e couleur) ; alpha 0 = valeur par défaut
uniform float outerShadowSize;      // zone réservée autour de la vidéo (0 = automatique) ; forme 4 : taille de la lueur
uniform vec4  outerShadowColor;     // couleur + opacité de l'ombre (alpha 0 = noir à 74 %) ;
                                    // forme 4 : couleur de lueur imposée si alpha > 0

// Ombre portée « façon Photoshop » (toutes les formes sauf 4, 8, 9) :
uniform float shadowAngle;          // angle de la lumière en degrés : 135 = lumière en haut à gauche, ombre en bas à droite
                                    // (0 = valeur par défaut, 135). 120 = angle par défaut de Photoshop, 90 = du dessus, 45 = en haut à droite...
                                    // La même lumière sert aux reflets et aux reliefs des cadres.
uniform float shadowDistance;       // décalage de l'ombre : plus il est grand, plus l'objet « flotte »
                                    // (0 = automatique ; < 1 : fraction de la hauteur, >= 1 : pixels)
uniform float shadowSize;           // taille du flou = largeur du dégradé de l'ombre (de 10 % à 90 % d'opacité), indépendante du décalage
                                    // (0 = automatique ; même unités que shadowDistance)
uniform float shadowSpread;         // étalement : > 0 épaissit l'ombre, < 0 la resserre (0 par défaut)
// Avec outerShadowSize à 0, la zone réservée à l'ombre s'adapte toute seule à shadowDistance + shadowSize.

// Réglages « effets » (0 = valeur par défaut ; pour supprimer un effet, mettre une valeur minuscule comme 0.001)
uniform float glassAmount;          // reflets du verre sur la vidéo, formes 1 et 5 (défaut 0.55 ; 1.0 = fort)
uniform float glowAmount;           // intensité de la lueur : forme 4 (défaut 1.5 ; 2.0 = forte). Pour les néons 8, 12, 17, la vitre 18 et
                                    // les flammes 19 : règle le halo autour du trait (1.5 = normal ; 0.001 = aucun halo, seulement le trait)
uniform float scanlineAmount;       // lignes de balayage de la TV (5) et de l'hologramme (9) : défaut 1.0 ; 0.5 = plus discrètes ; 0.001 = aucune
                                    // (les supprimer élimine tout moiré en forte perspective)
uniform vec4  accentColor;          // couleur principale des formes lumineuses ou dessinées (8, 9, 11 à 15, 17, 20), prioritaire
                                    // sur borderColor ; alpha 0 = non utilisée (défaut : cyan pour 8, 9, 11)
uniform float time;                // pour animer les flammes (forme 19) : à faire varier dans le temps ; 1.0 = un cycle complet.
                                    // Sans animation (0), les flammes restent figées.
uniform float saturation;
uniform bool  bilinearFiltering;

// Perspective (même principe et mêmes noms que ton shader de perspective)
uniform float tiltAngle;            // inclinaison autour de l'axe horizontal (degrés)
uniform float tiltAngleX;           // inclinaison autour de l'axe vertical (degrés)
uniform float perspectiveDepth;     // 0 = automatique : le cadre entier reste visible ; sinon comme dans ton shader (≈ 1.0 et moins)

// Forme du cadre :
//   0 = ombre portée seule (3 couches : contact, moyenne, lointaine) + fin liseré sur le bord
//   1 = lunette d'écran noire fine, verre brillant
//   2 = cadre en bois (tableau) : profil moulé, veinage, joints d'onglet
//   3 = cadre métal brossé (argent par défaut ; borderColor pour l'or, le noir...)
//   4 = écran lumineux : halo coloré par l'image + zone assombrie autour
//   5 = téléviseur cathodique réaliste : coque plastique, masque noir, écran bombé, scanlines, boutons, LED
//   6 = cadre de galerie : fin cadre, passe-partout blanc biseauté (borderColor : cadre doré, argenté...)
//   7 = photo instantanée (polaroïd) : papier, grande marge en bas
//   8 = néon : tube lumineux autour de la vidéo (borderColor : couleur)
//   9 = hologramme / HUD : coins de visée, repères, scanlines (borderColor : couleur)
//  10 = verre dépoli : lunette translucide à reflets (borderColor : teinte)
//  11 = carbone + LED : fibre de carbone, coins coupés, liseré lumineux (borderColor : couleur de la LED)
//  12 = néon double : halo coloré + cœur d'une autre couleur (borderColor = halo, innerShadowColor = cœur), coins arrondis
//  13 = cadre « gaming » : panneau sombre avec coins biseautés à hachures (borderColor : couleur des coins)
//  14 = traits de pinceau : quatre coups de pinceau irréguliers qui se croisent aux coins (borderColor : couleur)
//  15 = techno doré : bandes métalliques à circuits, rivets et fentes (borderColor : couleur du métal)
//  16 = techno argent : biseaux argent / noir, coins coupés, ornements haut et bas au centre
//  17 = néon électrique : tube déchiré, avec trous, deux couleurs (borderColor + innerShadowColor), lueur irrégulière
//  18 = vitre : reflets diagonaux sur la vidéo, liseré de verre, éclats lumineux aux coins
//  19 = flammes : le cadre brûle (statique)
//  20 = éclaboussures d'encre : bord noir irrégulier, taches (borderColor : couleur de l'encre)
// Pour désactiver l'ombre, mettre outerShadowSize à une valeur minuscule (0.001).
uniform int   frameType;
// 1 sur une image (capture) avec perspective : son axe vertical de texture est inversé par rapport à une vidéo
uniform float flipY;
bool g_flip = false;

// Taille d'un pixel d'écran en pixels « à plat » : 1 sans perspective, > 1 là où la perspective comprime l'image.
// Les largeurs de bord et de trait s'y adaptent pour rester nettes sans escalier.
float g_px = 1.0;

vec4 sampleTexture(sampler2D tex, vec2 texCoord) {
    return COMPAT_TEXTURE(tex, texCoord);
}

float getComputedValue(float value, float defaultValue) {
    if (value == 0.0)
        return defaultValue;
    if (value < 1.0)
        return abs(outputSize.y) * value;
    return value;
}

float hash21(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float vnoise2(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float sdBox(vec2 p, vec2 c, vec2 h) {
    vec2 d = abs(p - c) - h;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

float fbm2(vec2 p) {
    return 0.5 * vnoise2(p) + 0.3 * vnoise2(p * 2.03 + 7.1) + 0.2 * vnoise2(p * 4.01 + 3.3);
}

// Trait de pinceau irrégulier de a vers b, de largeur w (bords effilochés, épaisseur et trajectoire variables)
float brushStroke(vec2 p, vec2 a, vec2 b, float w, float seed) {
    vec2  dir = normalize(b - a);
    vec2  nrm = vec2(-dir.y, dir.x);
    float L   = length(b - a);
    float along = dot(p - a, dir);
    float perp  = dot(p - a, nrm);
    float wob = (fbm2(vec2(along * 0.012, seed)) - 0.5) * 0.9 * w;                          // le trait ondule
    float wid = w * (0.55 + 0.75 * fbm2(vec2(along * 0.035, seed + 4.0)));                   // épaisseur variable
    float rag = (vnoise2(vec2(along * 0.30, perp * 0.30 + seed)) - 0.5) * 0.30 * w;          // bords effilochés
    float d   = abs(perp - wob) - 0.5 * wid + rag;
    float eA  = vnoise2(vec2(perp * 0.22, seed + 9.0)) * 1.6 * w;                            // extrémités irrégulières
    float eB  = vnoise2(vec2(perp * 0.22, seed + 13.0)) * 1.6 * w;
    float ends = smoothstep(0.0, 0.9, along - eA) * smoothstep(0.0, 0.9, (L - along) - eB);
    float dry  = 0.78 + 0.22 * vnoise2(vec2(along * 0.045, perp * 0.9 + seed));              // pinceau un peu sec
    return (1.0 - smoothstep(-0.8 * g_px, 0.8 * g_px, d)) * ends * dry;
}

vec3 fireRamp(float x) {
    vec3 c = mix(vec3(0.85, 0.12, 0.0), vec3(1.0, 0.28, 0.02), smoothstep(0.08, 0.40, x));
    c = mix(c, vec3(1.0, 0.62, 0.08), smoothstep(0.38, 0.70, x));
    return mix(c, vec3(1.0, 0.96, 0.72), smoothstep(0.72, 1.0, x));
}

// Éclat lumineux en étoile centré en c, de rayon r
float starGlint(vec2 p, vec2 c, float r) {
    vec2 d = p - c;
    float g  = exp(-length(d) / (0.22 * r));
    g += 0.9 * exp(-abs(d.x) / (0.035 * r)) * exp(-abs(d.y) / r);
    g += 0.9 * exp(-abs(d.y) / (0.035 * r)) * exp(-abs(d.x) / r);
    return g;
}

// Impulsion périodique lissée : 1 quand x est à moins de halfw (en cycles) du centre `center`, 0 ailleurs.
// e = demi-largeur de la transition, en cycles (≈ pixel d'écran / période) : plus d'escalier sur les motifs répétés.
float pulse(float x, float center, float halfw, float e) {
    float d = abs(fract(x - center + 0.5) - 0.5);
    return 1.0 - smoothstep(halfw - e, halfw + e, d);
}

// Distance signée à un rectangle arrondi (négative à l'intérieur)
float sdRoundRect(vec2 p, vec2 c, vec2 halfSize, float r) {
    vec2 q = abs(p - c) - halfSize + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

// Rectangle à coins coupés (chanfreinés) : `cut` = taille de la coupe
float sdChamfer(vec2 p, vec2 c, vec2 halfSize, float cut) {
    vec2 q = abs(p - c) - halfSize;
    float box  = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
    float diag = (q.x + q.y + cut) * 0.70710678;
    return max(box, diag);
}

// Normale 2D sortante d'un rectangle arrondi
vec2 rrNormal(vec2 p, vec2 c, vec2 halfSize, float r) {
    vec2 d = p - c;
    vec2 q = abs(d) - halfSize + r;
    vec2 n;
    if (q.x > 0.0 && q.y > 0.0)
        n = normalize(q);
    else
        n = (q.x > q.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
    return n * vec2(d.x < 0.0 ? -1.0 : 1.0, d.y < 0.0 ? -1.0 : 1.0);
}

// Partie visible de l image (coordonnées de texture), renseignée au début de main ; image entière par défaut
vec2 g_artA = vec2(0.0);
vec2 g_artB = vec2(1.0);

// 1er point opaque en partant d un bord, le long de la ligne centrale (axeX) ou de la colonne centrale (recherche dichotomique)
float bordOpaque(bool axeX, bool depuisDebut)
{
    float lo = depuisDebut ? 0.0 : 0.5;
    float hi = depuisDebut ? 0.5 : 1.0;
    for (int i = 0; i < 10; i++) {
        float mid = 0.5 * (lo + hi);
        float o = sampleTexture(u_tex, axeX ? vec2(mid, 0.5) : vec2(0.5, mid)).a;
        if (depuisDebut) { if (o > 0.5) hi = mid; else lo = mid; }
        else             { if (o > 0.5) lo = mid; else hi = mid; }
    }
    return depuisDebut ? hi : lo;
}

// Échantillonnage de la vidéo (bilinéaire optionnel + saturation), sans v_col
vec4 sampleArt(vec2 uv)
{
    if (g_flip) uv.y = 1.0 - uv.y;
    uv = g_artA + uv * (g_artB - g_artA);
    vec4 c = sampleTexture(u_tex, uv);

    if (bilinearFiltering)
    {
        vec2 texelSize = 1.0 / textureSize;
        vec2 f = fract(uv);

        vec4 texel00 = sampleTexture(u_tex, uv);
        vec4 texel10 = sampleTexture(u_tex, uv + vec2(texelSize.x, 0.0));
        vec4 texel01 = sampleTexture(u_tex, uv + vec2(0.0, texelSize.y));
        vec4 texel11 = sampleTexture(u_tex, uv + texelSize);

        c = mix(mix(texel00, texel10, f.x), mix(texel01, texel11, f.x), f.y);
    }

    if (saturation != 1.0) {
        vec3 gray = vec3(dot(c.rgb, vec3(0.34, 0.55, 0.11)));
        c = vec4(mix(gray, c.rgb, saturation), c.a);
    }
    return c;
}

// ── État global (renseigné au début de main) ─────────────────
vec2  g_L2 = vec2(-0.5, -0.866);   // direction de la lumière dans le plan de l'écran (y vers le bas)
int   g_ft = 0;
vec2  g_cc, g_chh, g_wc, g_wh;
float g_rOut, g_rIn, g_cutW;

bool angular() { return (g_ft == 11 || g_ft == 13 || g_ft == 15 || g_ft == 16); }

float caseSD(vec2 p) {
    if (angular()) return sdChamfer(p, g_cc, g_chh, g_rOut);
    return sdRoundRect(p, g_cc, g_chh, g_rOut);
}
float winSD(vec2 p) {
    if (angular()) return sdChamfer(p, g_wc, g_wh, g_cutW);
    return sdRoundRect(p, g_wc, g_wh, g_rIn);
}
// normales sortantes de la forme extérieure et de la fenêtre
vec2 caseN(vec2 p) {
    if (angular()) {
        vec2 e = vec2(1.0, 0.0);
        return normalize(vec2(caseSD(p + e.xy) - caseSD(p - e.xy), caseSD(p + e.yx) - caseSD(p - e.yx)) + vec2(1e-5));
    }
    return rrNormal(p, g_cc, g_chh, g_rOut);
}
vec2 winN(vec2 p) {
    if (angular()) {
        vec2 e = vec2(1.0, 0.0);
        return normalize(vec2(winSD(p + e.xy) - winSD(p - e.xy), winSD(p + e.yx) - winSD(p - e.yx)) + vec2(1e-5));
    }
    return rrNormal(p, g_wc, g_wh, g_rIn);
}

// Environnement de studio : softbox du côté de la lumière + fine barre lumineuse à droite
vec3 envMap(vec3 R) {
    vec3 Sd = normalize(vec3(g_L2 * 0.655, 0.76));
    vec3 Sx = normalize(cross(vec3(0.0, 1.0, 0.0), Sd));
    vec3 Sy = cross(Sd, Sx);
    float d = dot(R, Sd) + 1e-6;
    float a = dot(R, Sx) / d;
    float b = dot(R, Sy) / d;
    float box = (1.0 - smoothstep(0.20, 0.36, abs(a))) * (1.0 - smoothstep(0.12, 0.24, abs(b))) * step(0.0, d);

    vec3 S2 = normalize(vec3(0.55, 0.05, 0.83));
    vec3 T2 = normalize(cross(vec3(0.0, 1.0, 0.0), S2));
    vec3 U2 = cross(S2, T2);
    float d2 = dot(R, S2) + 1e-6;
    float a2 = dot(R, T2) / d2;
    float b2 = dot(R, U2) / d2;
    float strip = (1.0 - smoothstep(0.025, 0.07, abs(a2))) * (1.0 - smoothstep(0.30, 0.55, abs(b2))) * step(0.0, d2);

    float amb = 0.05 + 0.12 * clamp(R.z, 0.0, 1.0);
    return vec3(5.5 * box + 1.8 * strip + amb) * vec3(1.0, 1.0, 1.02);
}

// Profil de hauteur d'un cadre symétrique, t = 0 (bord extérieur) → 1 (contre la vidéo)
float profileH(float t, int ft) {
    if (ft == 1)        // lunette d'écran : dessus arrondi qui redescend vers l'écran
        return 0.5 * smoothstep(0.0, 0.45, t) + 0.5 * smoothstep(0.15, 0.8, t) - 0.55 * smoothstep(0.75, 1.0, t);
    // cadre classique (bois / métal / galerie) : arrondi extérieur, dessus bombé, pente interne, petite gorge
    return 0.5 * smoothstep(0.0, 0.10, t) + 0.5 * smoothstep(0.10, 0.45, t)
         - 0.55 * smoothstep(0.62, 0.85, t) - 0.25 * smoothstep(0.88, 0.95, t);
}

// Dérivée de smoothstep(a, b, x)
float dss(float x, float a, float b) {
    float u = clamp((x - a) / (b - a), 0.0, 1.0);
    return 6.0 * u * (1.0 - u) / (b - a);
}

// Bouton rond (téléviseur) : renvoie la couleur et met le masque dans m
vec3 knob(vec2 p, vec2 c, float r, out float m) {
    float d  = length(p - c) - r;
    m = 1.0 - smoothstep(-0.7 * g_px, 0.7 * g_px, d);
    vec2  n  = (p - c) / max(r, 1.0);
    float lit = clamp(dot(n, g_L2) * 0.5 + 0.5, 0.0, 1.0);
    float rim = 1.0 - smoothstep(0.0, 0.18, 1.0 - length(n));
    vec3 col = mix(vec3(0.05), vec3(0.34), pow(lit, 1.5)) + 0.10 * rim;
    // petit repère clair sur le bouton
    col += 0.35 * (1.0 - smoothstep(0.0, 0.10 * r + 0.6, length(p - (c - g_L2 * 0.0 + vec2(0.0, -0.62 * r)))));
    return col;
}

// Couleur moyenne d'un bord de l'image en un point `a` (0..1 le long du bord) : 9 prises réparties
// sur trois profondeurs. edge : 0 gauche, 1 droite, 2 haut, 3 bas.
vec3 glowNode(float a, float edge) {
    vec3 c = vec3(0.0);
    for (int i = -1; i <= 1; i++) {
        for (int j = 1; j <= 3; j++) {
            float al = clamp(a + float(i) * 0.07, 0.0, 1.0);
            float dp = float(j) * 0.10;
            vec2 q;
            if (edge < 0.5)      q = vec2(dp, al);
            else if (edge < 1.5) q = vec2(1.0 - dp, al);
            else if (edge < 2.5) q = vec2(al, dp);
            else                 q = vec2(al, 1.0 - dp);
            if (g_flip) q.y = 1.0 - q.y;
            c += sampleTexture(u_tex, q).rgb;
        }
    }
    return c * (1.0 / 9.0);
}

// Interpolation douce entre des points espacés de 0.2 le long du bord : pas de stries
vec3 glowAlong(float a, float edge) {
    float f  = clamp(a, 0.0, 1.0) * 5.0;
    float n0 = min(floor(f), 4.0);
    float ff = smoothstep(0.0, 1.0, f - n0);
    return mix(glowNode(n0 * 0.2, edge), glowNode((n0 + 1.0) * 0.2, edge), ff);
}

// Calcule l'aspect du cadre au point (vtex, lp) de l'espace « à plat » : vtex = coordonnée de texture 0..1,
// lp = position en pixels dans la zone. Renvoie la couleur prémultipliée (déjà multipliée par v_col).
vec4 shade(vec2 vtex, vec2 lp)
{
    int ft = frameType;
    if (ft < 0 || ft > 20) ft = 0;
    vec2  size    = abs(outputSize);
    float W       = size.x;
    float H       = size.y;
    float minSide = min(W, H);

    // ── Valeurs automatiques selon la forme (en fraction du plus petit côté) ──
    float osA = 0.075; float fwA = 0.0;   float rA = 0.010; float rinA = 0.0;
    if (ft == 1)       { osA = 0.060; fwA = 0.016; rA = 0.016; rinA = 0.005; }
    else if (ft == 2 || ft == 3) { osA = 0.060; fwA = 0.050; rA = 0.004; rinA = 0.0015; }
    else if (ft == 4)  { osA = 0.150; fwA = 0.0;   rA = 0.012; }
    else if (ft == 5)  { osA = 0.060; fwA = 0.075; rA = 0.050; rinA = 0.045; }
    else if (ft == 6)  { osA = 0.060; fwA = 0.110; rA = 0.004; rinA = 0.002; }
    else if (ft == 7)  { osA = 0.060; fwA = 0.045; rA = 0.008; rinA = 0.002; }
    else if (ft == 8)  { osA = 0.0; fwA = 0.030; rA = 0.070; rinA = 0.040; }
    else if (ft == 9)  { osA = 0.0; fwA = 0.045; rA = 0.004; rinA = 0.004; }
    else if (ft == 10) { osA = 0.070; fwA = 0.040; rA = 0.050; rinA = 0.020; }
    else if (ft == 11) { osA = 0.070; fwA = 0.060; rA = 0.070; rinA = 0.0; }
    else if (ft == 12) { osA = 0.0; fwA = 0.032; rA = 0.082; rinA = 0.050; }
    else if (ft == 13) { osA = 0.0; fwA = 0.065; rA = 0.045; rinA = 0.0; }
    else if (ft == 14) { osA = 0.0; fwA = 0.032; rA = 0.004; rinA = 0.0; }
    else if (ft == 15) { osA = 0.0; fwA = 0.065; rA = 0.040; rinA = 0.0; }
    else if (ft == 16) { osA = 0.0; fwA = 0.065; rA = 0.050; rinA = 0.0; }
    else if (ft == 17) { osA = 0.0; fwA = 0.032; rA = 0.004; rinA = 0.0; }
    else if (ft == 18) { osA = 0.0; fwA = 0.012; rA = 0.057; rinA = 0.045; }
    else if (ft == 19) { osA = 0.0; fwA = 0.085; rA = 0.004; rinA = 0.0; }
    else if (ft == 20) { osA = 0.0; fwA = 0.060; rA = 0.004; rinA = 0.0; }

    // Ombre : décalage et longueur de traîne réglables séparément (valeurs par défaut en fraction du plus petit côté)
    float shD = getComputedValue(shadowDistance, 0.025 * minSide);
    float shB = getComputedValue(shadowSize,     0.015 * minSide);
    if (ft != 4 && ft != 8 && ft != 9 && ft < 12) osA = (shD + 0.9 * shB) / minSide + 0.004;   // zone automatique = décalage + flou

    float os   = getComputedValue(outerShadowSize, osA * minSide);
    float fw   = (fwA > 0.0) ? getComputedValue(borderSize, fwA * minSide) : 0.0;
    float rOut = min(getComputedValue(cornerRadius, rA * minSide), (ft == 11) ? 0.30 * minSide : 0.45 * minSide);
    float rIn  = (fw > 0.5) ? min(rinA * minSide * ((cornerRadius != 0.0) ? rOut / (rA * minSide) : 1.0), rOut) : rOut;   // cornerRadius = rayon extérieur ; le coin de la vidéo garde ses proportions

    // marges autour de la vidéo (gauche/haut, droite/bas) : plus épaisses en bas pour le téléviseur et le polaroïd
    vec2 inMin = vec2(fw);
    vec2 inMax = vec2(fw);
    if (ft == 5) inMax.y = fw * 1.5;
    if (ft == 7) inMax.y = fw * 3.6;
    if (ft == 15) { inMin = vec2(0.58 * fw, fw); inMax = vec2(0.58 * fw, fw); }

    vec2 cc   = 0.5 * size;
    vec2 chh  = cc - os;
    vec2 wMin = vec2(os) + inMin;
    vec2 wMax = size - vec2(os) - inMax;
    vec2 wc   = 0.5 * (wMin + wMax);
    vec2 wh   = max(0.5 * (wMax - wMin), vec2(1.0));
    vec2 winSz = wMax - wMin;

    float ang = ((shadowAngle == 0.0) ? 135.0 : shadowAngle) * 0.0174533;   // 135° = lumière en haut à gauche
    g_L2 = vec2(cos(ang), -sin(ang));
    vec2 L2 = g_L2;
    vec3 LD = normalize(vec3(L2 * 0.655, 0.76));
    vec2 dirS = -L2;                                   // l'ombre part à l'opposé de la lumière

    g_ft = ft; g_cc = cc; g_chh = chh; g_wc = wc; g_wh = wh; g_rOut = rOut; g_rIn = rIn;
    g_cutW = max(rOut - 0.586 * fw, 0.0);

    float dC = caseSD(lp);                             // forme extérieure
    float dW = winSD(lp);                              // fenêtre de la vidéo
    float wWin = 1.0 - smoothstep(-0.8 * g_px, 0.8 * g_px, dW);

    float haloS = ((glowAmount != 0.0) ? glowAmount : GLOW_DEFAULT) / GLOW_DEFAULT;   // halo des néons, de la vitre et des flammes : 1 = normal, ~0 = aucun
    vec3 accDef = ACCENT;
    vec3 acc2Def = vec3(1.0);
    if (ft == 12)      { accDef = vec3(1.00, 0.10, 0.04); acc2Def = vec3(1.00, 0.80, 0.20); }
    else if (ft == 13) { accDef = vec3(0.95, 0.22, 0.28); acc2Def = vec3(0.50, 0.08, 0.12); }
    else if (ft == 14 || ft == 18) accDef = vec3(1.0);
    else if (ft == 15) accDef = vec3(1.00, 0.74, 0.36);
    else if (ft == 17) { accDef = vec3(1.00, 0.12, 0.15); acc2Def = vec3(0.75, 0.15, 1.00); }
    else if (ft == 20) accDef = vec3(0.015);
    vec3 accent  = (accentColor.a > 0.0) ? accentColor.rgb : ((borderColor.a > 0.0) ? borderColor.rgb : accDef);
    vec3 accent2 = (innerShadowColor.a > 0.0) ? innerShadowColor.rgb : acc2Def;

    // ── Vidéo ──
    vec2 dMin = wMin / size;
    vec2 dMax = (size - wMax) / size;
    vec2 uvw  = (vtex - dMin) / max(vec2(1.0) - dMin - dMax, vec2(0.02));
    vec2 cwin = (lp - wc) / wh;                        // -1..1 dans la fenêtre
    float vig = 1.0;
    if (ft == 5) {                                     // écran bombé : barillet marqué + vignettage
        vec2  c0 = uvw * 2.0 - 1.0;
        float r2 = dot(c0, c0);
        vec2  c1 = c0 * (1.0 + 0.11 * r2) / 1.11;
        uvw = c1 * 0.5 + 0.5;
        vig = 1.0 - 0.40 * smoothstep(0.40, 1.25, sqrt(r2));
    } else if (ft == 7) {                              // émulsion photo : léger vignettage
        vig = 1.0 - 0.16 * smoothstep(0.55, 1.35, length(cwin));
    }
    vec4 vid = sampleArt(uvw);
    vid.rgb *= vig;

    if (ft == 5) {
        // lignes de balayage + masque de phosphores très léger + halo lumineux des zones claires
        float per = max(2.6, winSz.y / 210.0);
        float scanK = (scanlineAmount != 0.0) ? scanlineAmount : 1.0;
        float sl  = 0.90 + 0.10 * scanK * smoothstep(1.2 * g_px, 2.4 * g_px, per) * cos(6.2831853 * (lp.y - wMin.y) / per);   // estompé si les lignes deviennent trop fines (moiré)
        float px3 = 6.2831853 * (lp.x - wMin.x) / 3.0;
        vec3  ph  = vec3(1.0) + 0.05 * scanK * smoothstep(1.4 * g_px, 2.6 * g_px, 3.0) * vec3(cos(px3), cos(px3 + 2.094), cos(px3 + 4.188));
        vid.rgb = vid.rgb * sl * ph;
        vid.rgb += 0.20 * vid.rgb * vid.rgb;
        vid.rgb *= 1.04;
    } else if (ft == 9) {                              // hologramme : scanlines, teinte froide, bords colorés
        float scanK9 = (scanlineAmount != 0.0) ? scanlineAmount : 1.0;
        float sl = 0.93 + 0.07 * scanK9 * smoothstep(1.5 * g_px, 3.0 * g_px, 3.0) * cos(6.2831853 * (lp.y - wMin.y) / 3.0);   // estompé si les lignes deviennent trop fines (moiré)
        vid.rgb *= sl * vec3(0.94, 1.0, 1.05);
        vid.rgb += accent * 0.14 * exp(-max(-dW, 0.0) / (0.10 * min(winSz.x, winSz.y)));
    } else if (ft == 8 || ft == 12 || ft == 17) {      // le tube éclaire le bord de l'image
        vid.rgb += accent * 0.40 * exp(-max(-dW, 0.0) / (0.20 * fw + 2.0));
    } else if (ft == 19) {                             // les flammes éclairent le bord de l'image
        vid.rgb += vec3(1.0, 0.45, 0.08) * 0.35 * exp(-max(-dW, 0.0) / (0.30 * fw + 2.0));
    } else if (ft == 18) {                             // reflets diagonaux d'une vitre
        float sdv = dot((lp - cc) / size, -L2);
        float s1  = exp(-pow((sdv + 0.16) / 0.055, 2.0)) * 0.17;
        float s2  = exp(-pow((sdv + 0.03) / 0.020, 2.0)) * 0.12;
        float s3  = 0.09 * smoothstep(0.15, -0.45, sdv);
        vid.rgb += vec3(s1 + s2 + s3);
    }

    // ombre du rebord sur la vidéo (plus marquée du côté de la lumière)
    if (fw > 0.5 && (ft == 1 || ft == 2 || ft == 3 || ft == 5 || ft == 6 || ft == 11 || ft == 13 || ft == 15 || ft == 16)) {
        float aoSize = getComputedValue(innerShadowSize, (ft == 5) ? 0.018 * minSide : ((ft == 6) ? 0.07 * fw : max(0.30 * fw, 0.004 * minSide)));
        float depth  = max(-dW, 0.0);
        float k      = clamp(dot(winN(lp), L2) * 0.5 + 0.5, 0.0, 1.0);
        float shd    = pow(1.0 - smoothstep(0.0, aoSize, depth), 2.0) * mix(0.3, 1.0, k);
        vid.rgb *= 1.0 - ((ft == 5) ? 0.62 : 0.5) * shd;
    }

    // reflets du verre (lunette d'écran et téléviseur)
    vec3 cam = vec3(cc.x - 0.05 * W, cc.y - 0.12 * H, 2.4 * W);
    vec3 V   = normalize(cam - vec3(lp, 0.0));
    if (ft == 1 || ft == 5) {
        float curv = (ft == 5) ? 0.42 : 0.06;
        vec3  Ng   = normalize(vec3(cwin * curv + L2 * 0.19, 1.0));
        float NdVg = clamp(dot(Ng, V), 0.0, 1.0);
        vec3  Rg   = -V + 2.0 * NdVg * Ng;
        float Fg   = 0.04 + 0.96 * pow(1.0 - NdVg, 5.0);
        vid.rgb += ((glassAmount != 0.0) ? glassAmount : GLASS_DEFAULT) * ((ft == 5) ? 1.5 : 1.0) * Fg * envMap(Rg);
    }

    // ── Zone du cadre : couleur prémultipliée (rgb) + opacité (fa) ──
    vec3  fc = vec3(0.0);
    float fa = 1.0;
    float sOut = -dC;                                  // distance depuis le bord extérieur (px, positif dedans)
    vec2  nO   = caseN(lp);

    if (ft == 1 || ft == 2 || ft == 3) {
        float t  = clamp(sOut / fw, 0.0, 1.0);
        float e  = 0.01;
        float dP = (profileH(t + e, ft) - profileH(t - e, ft)) / (2.0 * e);
        float slopeAmp = (ft == 1) ? 0.8 : 1.1;
        vec3  N  = normalize(vec3(nO * (dP * slopeAmp) + L2 * 0.08, 1.0));
        float NdV = clamp(dot(N, V), 0.0, 1.0);
        vec3  Rf  = -V + 2.0 * NdV * N;
        float Fr  = 0.04 + 0.96 * pow(1.0 - NdV, 5.0);
        vec3  E   = envMap(Rf);
        float dif = clamp(dot(N, LD) / LD.z, 0.0, 1.5);
        float ndl = dot(nO, L2);

        if (ft == 1) {                                  // lunette noire laquée
            vec3 base = (borderColor.a > 0.0) ? borderColor.rgb : vec3(0.018, 0.018, 0.022);
            fc = base * (0.5 + 0.6 * dif) + Fr * E * 1.2
               + 0.10 * pow(clamp(abs(dP * slopeAmp), 0.0, 1.0), 1.2) * max(ndl, 0.0);
        } else {
            // sens du veinage / du brossage : le long de chaque côté (onglet à 45° aux coins)
            float dxo  = chh.x - abs(lp.x - cc.x);
            float dyo  = chh.y - abs(lp.y - cc.y);
            bool  side = (dxo < dyo);
            float along = side ? lp.y : lp.x;
            float perp  = side ? lp.x : lp.y;
            float sd    = (lp.x < cc.x ? 0.0 : 1.0) + (lp.y < cc.y ? 0.0 : 2.0);
            float fu    = fw / 40.0;
            if (ft == 2) {                              // bois
                float ring = 0.5 + 0.5 * sin(perp / (fu * 1.6) + 5.0 * vnoise2(vec2(along / (fu * 55.0) + sd * 7.0, perp / (fu * 7.0)))
                                          + 2.0 * vnoise2(vec2(along / (fu * 20.0), perp / (fu * 2.5))));
                float fine = vnoise2(vec2(along / (fu * 90.0) + sd * 3.0, perp / (fu * 0.7)));
                float g = clamp(0.62 * ring + 0.38 * fine, 0.0, 1.0);
                vec3 wood = (borderColor.a > 0.0) ? borderColor.rgb * (0.55 + 0.75 * g)
                                                  : mix(vec3(0.16, 0.08, 0.035), vec3(0.44, 0.25, 0.115), g);
                fc = wood * (0.40 + 0.70 * dif) + 0.30 * Fr * E;
            } else {                                    // métal brossé
                vec3 alb = (borderColor.a > 0.0) ? borderColor.rgb : vec3(0.80, 0.81, 0.84);
                float br = 0.92 + 0.16 * vnoise2(vec2(along / (fu * 140.0) + sd * 5.0, perp / (fu * 0.5)));
                vec3 E2  = E + vec3(0.62) * (0.6 + 0.4 * Rf.z);
                fc = clamp(alb * br * E2 * 0.9, 0.0, 1.5);
            }
            float inCorner = step(dxo, fw) * step(dyo, fw);
            float mit = (1.0 - smoothstep(0.3 * g_px, 1.3 * g_px, abs(dxo - dyo))) * inCorner;
            fc *= 1.0 - 0.45 * mit;
        }
        fc *= 0.55 + 0.45 * smoothstep(0.0, 0.10 * fw + 1.0, max(dW, 0.0));    // ombre contre la vidéo
    }
    else if (ft == 5) {
        // ── Téléviseur cathodique ──
        // hauteur = montée depuis le bord extérieur − descente vers l'écran (deux distances)
        float Hh   = 0.9 * fw;
        float riseD = Hh * (0.6 * dss(sOut, 0.0, 0.30 * fw) + 0.4 * dss(sOut, 0.20 * fw, 0.60 * fw));
        float dropD = 0.9 * Hh * dss(max(dW, 0.0), 0.0, 0.38 * fw);
        vec2  nW  = winN(lp);
        vec2  gh  = -riseD * nO + dropD * nW;
        vec3  N   = normalize(vec3(-gh + L2 * 0.08, 1.0));
        float NdV = clamp(dot(N, V), 0.0, 1.0);
        vec3  Rf  = -V + 2.0 * NdV * N;
        float Fr  = 0.04 + 0.96 * pow(1.0 - NdV, 5.0);
        vec3  E   = envMap(Rf);
        float dif = clamp(dot(N, LD) / LD.z, 0.0, 1.5);

        // coque beige : grain fin, légères salissures près de l'écran, jaunissement
        vec3 base = (borderColor.a > 0.0) ? borderColor.rgb : vec3(0.62, 0.58, 0.49);
        float grain = vnoise2(lp * 0.9) - 0.5;
        float mott  = vnoise2(lp * 0.03) - 0.5;
        vec3 shell = base * (0.40 + 0.65 * dif) * (1.0 + 0.10 * grain + 0.08 * mott) + 0.55 * Fr * E;
        shell *= 1.0 - 0.18 * (1.0 - smoothstep(0.0, 0.5 * fw, max(dW, 0.0)));

        // masque noir autour de l'écran (plastique noir brillant)
        float ringW = 0.17 * fw;
        vec3  mask  = vec3(0.012) + Fr * E * 1.1;
        float wm    = 1.0 - smoothstep(ringW * 0.65, ringW, max(dW, 0.0));
        fc = mix(shell, mask, wm);

        // boutons, haut-parleur et LED sur la mentonnière (partie basse plus épaisse)
        float chinY = wMax.y + 0.5 * (fw * 1.5);
        float m1 = 0.0; float m2 = 0.0;
        vec3 k1 = knob(lp, vec2(wMax.x - 0.12 * winSz.x, chinY), 0.30 * fw, m1);
        vec3 k2 = knob(lp, vec2(wMax.x - 0.21 * winSz.x, chinY), 0.30 * fw, m2);
        fc = mix(fc, k1, m1);
        fc = mix(fc, k2, m2);
        // plaque métallique du constructeur
        vec2  bp = vec2(wMin.x + 0.11 * winSz.x, chinY);
        float db = sdRoundRect(lp, bp, vec2(0.085 * winSz.x, 0.15 * fw), 0.05 * fw);
        float mb = 1.0 - smoothstep(-0.7 * g_px, 0.7 * g_px, db);
        vec3 plate = vec3(0.70, 0.70, 0.72) * (0.85 + 0.25 * (0.5 - (lp.y - (bp.y - 0.15 * fw)) / (0.30 * fw)))
                   + 0.12 * (vnoise2(lp * vec2(0.15, 1.5)) - 0.5);
        plate *= 1.0 - 0.45 * (1.0 - smoothstep(0.0 * g_px, 1.2 * g_px, -db));
        fc = mix(fc, plate, mb);
        // grille de haut-parleur : fines fentes sombres
        vec2  gp = vec2(wc.x + 0.02 * winSz.x, chinY);
        float dg = sdRoundRect(lp, gp, vec2(0.13 * winSz.x, 0.14 * fw), 0.04 * fw);
        float slot = (1.0 - smoothstep(-0.7 * g_px, 0.7 * g_px, dg)) * smoothstep(0.55, 0.75, 0.5 + 0.5 * cos(6.2831853 * lp.y / max(0.05 * fw, 1.6)));
        fc *= 1.0 - 0.55 * slot;
        // LED rouge avec halo
        vec2  lc = vec2(wMax.x - 0.04 * winSz.x, chinY);
        float dl = length(lp - lc);
        fc = mix(fc, vec3(1.0, 0.12, 0.08), 1.0 - smoothstep(0.10 * fw, 0.14 * fw, dl));
        fc += vec3(1.0, 0.15, 0.08) * 0.45 * exp(-dl / (0.35 * fw));
    }
    else if (ft == 6) {
        // ── Cadre de galerie : fin cadre + passe-partout biseauté ──
        float f1 = 0.20 * fw;
        if (sOut < f1) {
            float t  = clamp(sOut / f1, 0.0, 1.0);
            float e  = 0.01;
            float dP = (profileH(t + e, 2) - profileH(t - e, 2)) / (2.0 * e);
            vec3  N  = normalize(vec3(nO * (dP * 1.1) + L2 * 0.08, 1.0));
            float NdV = clamp(dot(N, V), 0.0, 1.0);
            vec3  Rf  = -V + 2.0 * NdV * N;
            float Fr  = 0.04 + 0.96 * pow(1.0 - NdV, 5.0);
            vec3  E   = envMap(Rf);
            float dif = clamp(dot(N, LD) / LD.z, 0.0, 1.5);
            if (borderColor.a > 0.0) {                  // cadre métallique teinté (doré, argenté...)
                float br = 0.94 + 0.12 * vnoise2(vec2(lp.x * 0.3, lp.y * 2.0));
                fc = clamp(borderColor.rgb * br * (E + vec3(0.62) * (0.6 + 0.4 * Rf.z)) * 0.9, 0.0, 1.5);
            } else {                                    // laque noire satinée
                fc = vec3(0.045, 0.042, 0.04) * (0.5 + 0.6 * dif) + Fr * E * 1.0;
            }
        } else {
            // passe-partout : papier blanc cassé, ombre du cadre en haut/à gauche, biseau à 45° autour de la fenêtre
            vec3 mat = vec3(0.94, 0.93, 0.89) * (0.98 + 0.03 * (vnoise2(lp * 0.8) - 0.5) + 0.02 * (vnoise2(lp * 0.04) - 0.5));
            float inner = sOut - f1;
            float castS = max(dot(-nO, dirS), 0.0) * (1.0 - smoothstep(0.0, 0.14 * fw, inner)) * 0.50;
            mat *= 1.0 - castS;
            float bw   = 0.055 * fw;
            float bev  = 1.0 - smoothstep(bw * 0.85, bw, max(dW, 0.0));
            float litB = clamp(dot(-winN(lp), L2), 0.0, 1.0);
            vec3  bcol = vec3(0.99, 0.99, 0.97) * (0.60 + 0.40 * litB);
            fc = mix(mat, bcol, bev);
            // fine ombre du biseau sur la vidéo : vue côté fenêtre (déjà dans l'ombre du rebord)
        }
    }
    else if (ft == 7) {
        // ── Photo instantanée : papier + marges ──
        vec3 paper = (borderColor.a > 0.0) ? borderColor.rgb : vec3(0.95, 0.94, 0.90);
        float fine = vnoise2(lp * 0.7) - 0.5;
        float mott = vnoise2(lp * 0.025) - 0.5;
        vec3 pc = paper * (1.0 + 0.04 * fine + 0.05 * mott);
        pc *= 1.0 - 0.07 * (1.0 - smoothstep(0.0, 0.05 * minSide, sOut));            // bords un peu vieillis
        pc += vec3(0.020, 0.012, 0.0) * (1.0 - smoothstep(0.0, 0.06 * minSide, sOut));
        float rim = 1.0 - smoothstep(0.0 * g_px, 1.6 * g_px, sOut);
        float ndl = dot(nO, L2);
        pc += 0.06 * rim * max(ndl, 0.0);
        pc *= 1.0 - 0.10 * rim * max(-ndl, 0.0);
        // fin liseré sombre autour de l'image (bord de l'émulsion)
        pc *= 0.84 + 0.16 * smoothstep(0.0 * g_px, 1.6 * g_px, max(dW, 0.0));
        fc = pc;
    }
    else if (ft == 10) {
        // ── Verre dépoli : lunette translucide ──
        vec3  tint = (borderColor.a > 0.0) ? borderColor.rgb : vec3(0.90, 0.95, 1.0);
        float sh   = clamp(0.5 + 0.5 * dot((lp - cc) / size, -L2) * 1.6, 0.0, 1.0);   // plus clair du côté de la lumière
        float a0   = 0.30 + 0.16 * (1.0 - sh);
        float ndl  = dot(nO, L2);
        float rim  = 1.0 - smoothstep(0.0 * g_px, 1.8 * g_px, sOut);
        float rim2 = 1.0 - smoothstep(0.0 * g_px, 1.4 * g_px, abs(dW));
        float sheen = exp(-pow((dot((lp - cc) / size, -L2) - 0.0) / 0.22, 2.0)) * 0.07;
        float frost = (hash21(floor(lp)) - 0.5) * 0.02;
        float hl = 0.55 * rim * (0.35 + 0.65 * max(ndl, 0.0)) + 0.35 * rim2 * max(dot(-winN(lp), L2), 0.0) + sheen + frost;
        fa = clamp(a0 + hl + 0.10 * rim2, 0.0, 1.0);
        fc = tint * fa * 0.95 + vec3(hl) * 0.35;
        fc *= 1.0 - 0.22 * (1.0 - smoothstep(0.0 * g_px, 1.6 * g_px, max(dW, 0.0))) * 0.0;
    }
    else if (ft == 11) {
        // ── Carbone + liseré LED, coins coupés ──
        float ps  = max(0.016 * minSide, 3.0);
        vec2  cl  = lp / ps;
        vec2  fr  = fract(cl);
        float par = mod(floor(cl.x) + floor(cl.y), 2.0);
        float wv  = (par < 0.5) ? sin(3.14159 * fr.y) : sin(3.14159 * fr.x);       // fibre cylindrique
        vec3 N    = normalize(vec3(nO * (1.0 - smoothstep(0.0, 0.10 * fw + 1.0, sOut)) * 0.9 + L2 * 0.06
                                   + ((par < 0.5) ? vec2(0.0, (fr.y - 0.5) * 0.30) : vec2((fr.x - 0.5) * 0.30, 0.0)), 1.0));
        float NdV = clamp(dot(N, V), 0.0, 1.0);
        vec3  Rf  = -V + 2.0 * NdV * N;
        float Fr  = 0.04 + 0.96 * pow(1.0 - NdV, 5.0);
        vec3  E   = envMap(Rf);
        vec3 carbon = vec3(0.020, 0.021, 0.026) * (0.55 + 0.9 * wv) + Fr * E * (0.55 + 0.9 * wv);
        float ndl = dot(nO, L2);
        float rim = 1.0 - smoothstep(0.0 * g_px, 1.6 * g_px, sOut);
        carbon += 0.18 * rim * max(ndl, 0.0);
        // liseré LED à mi-épaisseur du cadre, avec lueur sur le carbone
        float dLed = abs(sOut - 0.50 * fw);
        float lw   = max(0.065 * fw, 1.0);
        float core = 1.0 - smoothstep(lw * 0.5, lw, dLed);
        float halo = exp(-dLed / (0.22 * fw)) * 0.40;
        vec3 ledc  = mix(accent, vec3(1.0), 0.45 * core);
        fc = carbon * (1.0 - 0.5 * core) + ledc * (core * 1.1 + halo);
        // petite ombre contre la vidéo
        fc *= 0.50 + 0.50 * smoothstep(0.0, 0.10 * fw + 1.0, max(dW, 0.0));
    }
    else if (ft == 8 || ft == 12) {
        // ── Néon : tube autour de la vidéo (12 : tube plus épais, cœur d'une autre couleur) ──
        float rt   = max(((ft == 12) ? 0.15 : 0.10) * fw, 1.2);
        float dn   = rt * 1.2 + 1.0;               // le tube longe le bord de l'image
        float dist = abs(dW - dn);
        float core = 1.0 - smoothstep(rt * ((ft == 12) ? 0.20 : 0.35), rt * ((ft == 12) ? 0.55 : 0.9), dist);
        float body = 1.0 - smoothstep(rt * 0.9, rt * 1.8, dist);
        float cut  = 1.0 - smoothstep(0.14 * fw, 0.34 * fw, dist);     // le halo reste collé au tube
        float halo = exp(-dist / (rt * 1.8)) * 0.60 * cut * haloS;
        float wide = exp(-dist / (rt * 3.6)) * 0.10 * cut * haloS;
        vec3  coreC = (ft == 12) ? accent2 : vec3(1.0);
        float wb = body * 0.95 + halo + wide;
        float wc = core * 0.85;
        fc = (accent * wb + coreC * wc) / (wb + wc + 1e-3);      // teinte à pleine luminosité : le halo éclaire, il n'assombrit pas
        fa = clamp(0.95 * body + 0.9 * core + 0.60 * halo + 0.48 * wide, 0.0, 1.0);
    }
    else if (ft == 9) {
        // ── Hologramme / HUD : coins de visée, filet, repères ──
        float gb  = 0.12 * fw;
        float gb2 = 0.45 * fw;
        vec2  q1  = abs(lp - wc) - (wh + gb);
        float s1  = length(max(q1, 0.0)) + min(max(q1.x, q1.y), 0.0);
        // filet fin : au moins ~1,5 px d'écran de fondu (sinon il clignote / crénelle en perspective)
        float thin = (1.0 - smoothstep(0.5 * g_px, 1.8 * g_px, abs(s1))) * 0.38;
        vec2  q2  = abs(lp - wc) - (wh + gb2);
        float s2  = length(max(q2, 0.0)) + min(max(q2.x, q2.y), 0.0);
        float tb  = max(0.075 * fw, 1.6 * g_px);
        float La  = 0.20 * min(winSz.x, winSz.y);
        float onO = 1.0 - smoothstep(tb * 0.5 - 0.5 * g_px, tb * 0.5 + g_px, abs(s2));
        float dx  = abs(lp.x - wc.x);
        float dy  = abs(lp.y - wc.y);
        float nx  = smoothstep(wh.x + gb2 - La - 1.5 * g_px, wh.x + gb2 - La, dx);
        float ny  = smoothstep(wh.y + gb2 - La - 1.5 * g_px, wh.y + gb2 - La, dy);
        // bornes des coins de visée adoucies (step = bord dur, crénelé)
        float bx  = 1.0 - smoothstep(tb * 2.0 - g_px, tb * 2.0 + g_px, abs(q2.y));
        float by  = 1.0 - smoothstep(tb * 2.0 - g_px, tb * 2.0 + g_px, abs(q2.x));
        float brk = onO * max(nx * bx, ny * by);
        // petits carrés aux angles
        vec2  cq  = abs(abs(lp - wc) - (wh + gb2)) - vec2(0.17 * fw);
        float sq  = 1.0 - smoothstep(-0.9 * g_px, 0.9 * g_px, max(cq.x, cq.y));
        // repères sur les côtés haut et bas
        float tp   = max(5.0, 0.012 * W);
        float tickB = smoothstep(0.12 * fw - 0.5, 0.12 * fw, s2) * (1.0 - smoothstep(0.32 * fw, 0.32 * fw + 0.5, s2));
        float tickV = step(q2.x, q2.y) * step(0.0, max(q2.x, q2.y)) ;
        float tick  = tickB * tickV * pulse(lp.x / tp, 0.08, max(0.08, 0.6 * g_px / tp), 0.75 * g_px / tp) * smoothstep(3.0, 6.0, tp / g_px) * (1.0 - nx);   // repères : au moins 1 px d'écran, estompés s'ils deviennent trop serrés
        float lines = clamp(thin + brk + sq + tick * 0.7, 0.0, 1.0);
        float halo  = exp(-abs(s2) / (0.30 * fw)) * 0.10 * (0.4 + 0.6 * max(nx, ny));
        float wb = lines + halo;
        fc = (accent * wb + vec3(1.0) * brk * 0.30) / (wb + brk * 0.30 + 1e-3);
        fa = clamp(lines + 0.6 * halo, 0.0, 1.0);
    }

    else if (ft >= 13) {
        // distances au bord extérieur (coin le plus proche) : ax, ay ; ox = écart au centre horizontal
        float ax = chh.x - abs(lp.x - cc.x);
        float ay = chh.y - abs(lp.y - cc.y);
        vec2  aa = vec2(ax, ay);
        float ox = abs(lp.x - cc.x);
        float inCase = 1.0 - smoothstep(-0.8 * g_px, 0.8 * g_px, dC);
        float gradY  = clamp(1.0 - (lp.y - os) / max(H - 2.0 * os, 1.0), 0.0, 1.0);     // 1 en haut, 0 en bas

        if (ft == 13) {
            // ── Cadre gaming : panneau sombre + coins biseautés à hachures ──
            vec3 panel = vec3(0.030, 0.034, 0.048) * (0.85 + 0.35 * gradY + 0.25 * vnoise2(lp * 0.02));
            float lipL = 1.0 - smoothstep(0.4 * g_px, 1.6 * g_px, abs(dW));
            panel += vec3(0.18, 0.22, 0.30) * lipL * 0.50;
            panel += vec3(0.10, 0.12, 0.16) * (1.0 - smoothstep(0.4 * g_px, 1.4 * g_px, abs(min(ax, ay) - 0.84 * fw)));
            float m  = 0.10 * fw;
            float tb = 0.46 * fw;
            float Lv = 0.30 * winSz.y;
            float Lh = 0.17 * winSz.x;
            float dV = sdBox(aa, vec2(m + 0.5 * tb, 0.5 * Lv), vec2(0.5 * tb, 0.5 * Lv));
            dV = max(dV, (aa.y - Lv + (aa.x - m)) * 0.7071);
            float dH = sdBox(aa, vec2(0.5 * Lh, m + 0.5 * tb), vec2(0.5 * Lh, 0.5 * tb));
            dH = max(dH, (aa.x - Lh + (aa.y - m)) * 0.7071);
            float dB = min(dV, dH);
            float mB = 1.0 - smoothstep(-0.7 * g_px, 0.7 * g_px, dB);
            float grd = clamp(1.0 - (min(aa.x - m, aa.y - m)) / tb, 0.0, 1.0);
            vec3  br  = accent * (0.72 + 0.34 * grd) * (0.85 + 0.30 * gradY);
            br *= 0.55 + 0.45 * smoothstep(0.0 * g_px, 1.8 * g_px, -dB);                                // contour plus sombre
            // hachures sur l'extrémité des bras verticaux
            float hp = max(0.20 * fw, 3.0);
            float stripe = mix(0.5, pulse((aa.x + aa.y) / hp, 0.75, 0.25, 0.75 * g_px / hp), smoothstep(1.5, 3.5, hp / g_px));
            float hz = smoothstep(0.42 * Lv - 1.0, 0.42 * Lv, aa.y) * step(abs(aa.x - (m + 0.5 * tb)), 0.5 * tb);
            br = mix(br, accent2 * 0.9, hz * stripe * 0.85);
            fc = mix(panel, br, mB);
            fa = inCase * (1.0 - wWin);
        }
        else if (ft == 14) {
            // ── Traits de pinceau ──
            float gap = 0.40 * fw;            // les traits couvrent la bande, contre le bord de l'image
            float ext = 0.30 * fw;
            float w   = 0.50 * fw;
            vec2  a0  = wMin - vec2(gap);
            vec2  a1  = wMax + vec2(gap);
            float st = brushStroke(lp, vec2(a0.x - ext, a0.y), vec2(a1.x + ext, a0.y), w, 1.0);
            st = max(st, brushStroke(lp, vec2(a0.x - ext, a1.y), vec2(a1.x + ext, a1.y), w, 2.0));
            st = max(st, brushStroke(lp, vec2(a0.x, a0.y - ext), vec2(a0.x, a1.y + ext), w, 3.0));
            st = max(st, brushStroke(lp, vec2(a1.x, a0.y - ext), vec2(a1.x, a1.y + ext), w, 4.0));
            fc = accent;
            fa = st;
        }
        else if (ft == 15) {
            // ── Techno doré : bandes métalliques à circuits ──
            vec3 gold  = accent;
            vec3 brown = accent * vec3(0.34, 0.24, 0.16);
            float hb = 0.08 * fw;
            float tH = fw - hb;                       // bande haut/bas : jusqu'à la vidéo
            float tV = 0.58 * fw - hb;                // côtés plus fins, jusqu'à la vidéo
            float dTop  = abs(aa.y - (hb + 0.5 * tH)) - 0.5 * tH;
            float dSide = abs(aa.x - (hb + 0.5 * tV)) - 0.5 * tV;
            float dCorner = sdBox(aa, vec2(0.50 * fw), vec2(0.45 * fw));
            dCorner = max(dCorner, ((aa.x + aa.y) - 1.35 * fw) * 0.7071);
            float hwO = 0.13 * winSz.x - 0.55 * (aa.y - hb);
            float dOrn = max(ox - hwO, abs(aa.y - (hb + 0.55 * fw)) - 0.55 * fw);
            float dShape = min(min(dTop, dSide), min(dCorner, dOrn));
            float mS = 1.0 - smoothstep(-0.7 * g_px, 0.7 * g_px, dShape);
            vec3 mcol = gold * (0.78 + 0.30 * clamp(1.0 - (aa.y - hb) / fw, 0.0, 1.0)) * (0.88 + 0.22 * gradY);
            // fentes sur la bande du haut / du bas
            float inBand = step(abs(aa.y - (hb + 0.5 * tH)), 0.30 * tH) * step(0.20 * winSz.x, ox) * step(ox, 0.42 * winSz.x);
            float sp_ = max(0.045 * winSz.x, 3.0);
            float slot   = inBand * mix(0.55, pulse(ox / sp_, 0.275, 0.275, 0.75 * g_px / sp_), smoothstep(1.5, 3.5, sp_ / g_px));
            mcol = mix(mcol, brown, slot * 0.85);
            // rivets aux coins
            float dRv = length(aa - vec2(0.42 * fw)) - 0.14 * fw;
            mcol = mix(mcol, brown, (1.0 - smoothstep(-0.6 * g_px, 0.6 * g_px, abs(dRv) - 0.035 * fw)) * 0.9);
            mcol = mix(mcol, gold * 1.15, 1.0 - smoothstep(-0.6 * g_px, 0.6 * g_px, dRv + 0.05 * fw));
            // contour sombre et biseau
            float outl = 1.0 - smoothstep(0.0 * g_px, 1.6 * g_px, abs(dShape + 0.8));
            mcol = mix(mcol, brown * 0.7, 0.85 * outl);
            fc = mcol;
            fa = mS * inCase;
        }
        else if (ft == 16) {
            // ── Techno argent : biseaux argent / noir ──
            float t = sOut / fw;
            float sx = 0.5 + 0.5 * sin(lp.x / (0.30 * W) + 1.2 + 0.5 * lp.y / H);
            vec3 silver = mix(vec3(0.46), vec3(0.90), sx) * (0.85 + 0.20 * gradY)
                        * (0.96 + 0.08 * vnoise2(vec2(lp.x * 0.05, lp.y * 0.9)));
            vec3 cb = vec3(0.025);
            cb = mix(cb, silver, smoothstep(0.11, 0.14, t) * (1.0 - smoothstep(0.30, 0.33, t)));
            cb = mix(cb, vec3(0.085, 0.09, 0.10) * (0.8 + 0.4 * gradY), smoothstep(0.30, 0.34, t) * (1.0 - smoothstep(0.52, 0.55, t)));
            cb = mix(cb, silver * 0.80, smoothstep(0.52, 0.55, t) * (1.0 - smoothstep(0.60, 0.63, t)));
            cb = mix(cb, vec3(0.03, 0.032, 0.04), smoothstep(0.60, 0.64, t));
            // ornements trapézoïdaux au centre du haut et du bas
            float hwO = 0.14 * winSz.x - 0.60 * (aa.y - 0.10 * fw);
            float dOr = max(ox - hwO, abs(aa.y - (0.10 * fw + 0.52 * fw)) - 0.52 * fw);
            float mO  = 1.0 - smoothstep(-0.7 * g_px, 0.7 * g_px, dOr);
            vec3 ocol = silver * (0.80 + 0.35 * clamp(1.0 - (aa.y - 0.10 * fw) / (1.0 * fw), 0.0, 1.0));
            ocol *= 0.55 + 0.45 * smoothstep(0.0 * g_px, 1.8 * g_px, -dOr);
            float gq = max(0.03 * winSz.x, 3.0);
            float gw = mix(0.5, pulse(ox / gq, 0.75, 0.25, 0.75 * g_px / gq), smoothstep(1.5, 3.5, gq / g_px));
            ocol = mix(ocol, vec3(0.06), gw * 0.45 * smoothstep(0.55 * fw, 0.62 * fw, aa.y) * (1.0 - smoothstep(0.88 * fw, 0.95 * fw, aa.y)));
            fc = mix(cb, ocol, mO);
            fa = max(inCase * (1.0 - wWin), mO);
        }
        else if (ft == 17) {
            // ── Néon électrique : tube déchiré, trous, deux couleurs ──
            float rt = max(0.09 * fw, 1.2);
            float dn = rt * 1.2 + 1.0;
            vec2  qn = (lp - wc) / (wh + dn);
            float sPar = (abs(qn.x) > abs(qn.y)) ? ((qn.x > 0.0 ? 1.0 : 3.0) * 1000.0 + lp.y)
                                                  : ((qn.y > 0.0 ? 2.0 : 0.0) * 1000.0 + lp.x);
            float on     = smoothstep(0.30, 0.42, vnoise2(vec2(sPar * 0.012, 3.0)));          // trous dans le tube
            float colSel = smoothstep(0.45, 0.55, vnoise2(vec2(sPar * 0.007, 11.0)));
            vec3  segc   = mix(accent, accent2, colSel);
            float rag    = fbm2(lp * 0.06) - 0.5;
            float dist   = abs(dW - dn) + rag * 2.4 * rt;
            float flick  = 0.65 + 0.35 * vnoise2(vec2(sPar * 0.05, 21.0));
            float core = (1.0 - smoothstep(rt * 0.3, rt * 0.9, dist)) * on;
            float body = (1.0 - smoothstep(rt * 0.9, rt * 2.0, dist)) * on;
            float cut  = 1.0 - smoothstep(0.14 * fw, 0.34 * fw, dist);
            float halo = exp(-dist / (rt * (1.8 + 1.8 * flick))) * (0.25 + 0.75 * on) * 0.75 * cut * haloS;
            float wide = exp(-dist / (rt * 4.0)) * 0.14 * (0.3 + 0.7 * on) * cut * haloS;
            float wb = body * 0.9 + halo + wide;
            float wc = core * 0.7;
            fc = (segc * wb + mix(segc, vec3(1.0), 0.6) * wc) / (wb + wc + 1e-3);
            fa = clamp(0.9 * body + 0.8 * core + 0.60 * halo + 0.45 * wide, 0.0, 1.0);
        }
        else if (ft == 18) {
            // ── Vitre : liseré de verre + éclats ──
            float rim  = 1.0 - smoothstep(0.5 * g_px, 1.9 * g_px, abs(dW));
            float lit  = 0.40 + 0.60 * max(dot(winN(lp), L2), 0.0);
            float inG  = exp(-max(-dW, 0.0) / (0.35 * fw + 1.0)) * 0.10 * step(dW, 0.0) * haloS;
            float outG = exp(-max(dW, 0.0) / (0.22 * fw + 1.0)) * 0.07 * step(0.0, dW) * (1.0 - smoothstep(0.30 * fw, 0.70 * fw, dW)) * haloS;
            float g1 = starGlint(lp, vec2(wMin.x + 0.5 * rIn, wMin.y + 2.0), 0.035 * minSide) * 0.55;
            float g2 = starGlint(lp, vec2(wMax.x - 0.5 * rIn, wMax.y - 2.0), 0.060 * minSide) * 0.95;
            float tot = 0.80 * rim * lit + inG + outG + g1 + g2;
            fc = vec3(0.96, 0.98, 1.0);
            fa = clamp(tot, 0.0, 1.0);
        }
        else if (ft == 19) {
            // ── Flammes (statiques) ──
            float dn = 0.10 * fw;
            vec2  qn = (lp - wc) / (wh + dn);
            float sPar = (abs(qn.x) > abs(qn.y)) ? ((qn.x > 0.0 ? 1.0 : 3.0) * 1000.0 + lp.y)
                                                  : ((qn.y > 0.0 ? 2.0 : 0.0) * 1000.0 + lp.x);
            float dd = dW - dn;
            // animation : le bruit est entraîné vers l'extérieur ; deux phases décalées d'une demi-boucle sont
            // fondues l'une dans l'autre, la boucle (time = 0 → 1) est donc continue, sans saut
            float ph  = fract(time);
            float phB = fract(ph + 0.5);
            float wph = abs(2.0 * ph - 1.0);
            float rr  = max(dd, 0.0) * 0.012 + 5.0;                                 // langues allongées vers l'extérieur
            float n1  = mix(fbm2(vec2(sPar * 0.050 + ph  * 0.70, rr - ph  * 0.95)),
                            fbm2(vec2(sPar * 0.050 + phB * 0.70, rr - phB * 0.95)), wph);
            float r2  = dd * 0.030;
            float n2  = mix(fbm2(vec2(sPar * 0.090 + 9.0 + ph  * 1.10, r2 - ph  * 1.80)),
                            fbm2(vec2(sPar * 0.090 + 9.0 + phB * 1.10, r2 - phB * 1.80)), wph);
            float tw = (n2 - 0.5) * 0.45 * fw;                                          // les flammes ondulent
            float reach = fw * (0.14 + 0.78 * pow(n1, 1.5));       // les flammes restent dans la bande
            float I;
            if (dd >= 0.0) I = pow(clamp(1.0 - (dd + tw) / reach, 0.0, 1.0), 1.25) * (0.65 + 0.50 * n2);
            else           I = pow(clamp(1.0 + dd / (0.34 * fw * (0.5 + n2)), 0.0, 1.0), 1.6);
            I = clamp(I, 0.0, 1.0) * (0.94 + 0.06 * sin(12.566371 * time + sPar * 0.04));   // léger scintillement
            float glow = 0.20 * smoothstep(0.10, 0.70, I) * exp(-max(dd, 0.0) / (0.35 * fw)) * haloS;   // braise autour des flammes seulement (pas de voile)
            fc = fireRamp(I) + vec3(1.0, 0.35, 0.05) * glow;
            fa = clamp(smoothstep(0.08, 0.40, I) * 0.95 + glow * 0.20, 0.0, 1.0);
        }
        else {
            // ── Éclaboussures d'encre : bord noir irrégulier + taches ──
            float n  = fbm2(lp * 0.018);
            float n2 = vnoise2(lp * 0.22);
            float edge = fw * (0.97 + 0.75 * n) + (n2 - 0.5) * 0.10 * fw;
            float msk  = 1.0 - smoothstep(-0.8 * g_px, 0.8 * g_px, sOut - edge);
            float cell = 0.075 * minSide;
            vec2  ci   = floor(lp / cell);
            float splat = 0.0;
            for (int i = -1; i <= 1; i++) {
                for (int j = -1; j <= 1; j++) {
                    vec2  c2  = ci + vec2(float(i), float(j));
                    vec2  ctr = (c2 + vec2(hash21(c2 + 3.1), hash21(c2 + 7.7))) * cell;
                    float rad = (0.05 + 0.17 * hash21(c2 + 11.3)) * cell * (0.7 + 0.6 * vnoise2(lp * 0.15)) * step(0.50, hash21(c2));
                    float sC  = min(min(ctr.x, W - ctr.x), min(ctr.y, H - ctr.y));
                    float ok  = step(0.65 * fw, sC) * step(sC, 2.3 * fw);
                    splat = max(splat, (1.0 - smoothstep(-0.6 * g_px, 0.6 * g_px, length(lp - ctr) - rad)) * ok);
                }
            }
            fc = accent;
            fa = max(msk, splat);
        }
    }

    // Les halos (néons, vitre, hologramme, flammes) s'éteignent en douceur avant le bord de la zone :
    // sans cela ils sont coupés net par le bord du rectangle, ce qui dessine un cadre fantôme.
    if (ft == 8 || ft == 9 || ft == 12 || ft == 17 || ft == 18 || ft == 19) {
        float dEdge = min(min(lp.x - os, W - os - lp.x), min(lp.y - os, H - os - lp.y));
        fa *= smoothstep(0.0, max((ft == 9) ? 0.20 * fw : 0.60 * fw, 1.0), dEdge);
    }

    // ── Assemblage ──
    vec3  pm;
    float al;
    bool  lightOnly = (ft == 8 || ft == 9 || ft >= 12);
    float wCase = lightOnly ? 1.0 : (1.0 - smoothstep(-0.8 * g_px, 0.8 * g_px, dC));

    if (ft == 0) {
        // liseré du bord : haut gauche éclairé, bas droite légèrement assombri
        float rim = 1.0 - smoothstep(0.0 * g_px, 1.8 * g_px, sOut);
        float ndl = dot(nO, L2);
        vid.rgb += 0.16 * rim * max(ndl, 0.0);
        vid.rgb *= 1.0 - 0.28 * rim * max(-ndl, 0.0);
        pm = vid.rgb * wCase;
        al = vid.a * wCase;
    } else if (ft == 4) {
        // fin liseré sombre type verre + éclat discret du côté de la lumière
        float rim = 1.0 - smoothstep(0.0 * g_px, 1.6 * g_px, sOut);
        float ndl = dot(nO, L2);
        vid.rgb *= 1.0 - 0.30 * rim;
        vid.rgb += 0.08 * rim * max(ndl, 0.0);
        pm = vid.rgb * wCase;
        al = vid.a * wCase;
    } else if (ft >= 13) {
        // cadres « overlay » : dessinés par-dessus la vidéo
        pm = fc * fa + vid.rgb * wWin * (1.0 - fa);
        al = fa + vid.a * wWin * (1.0 - fa);
    } else {
        pm = mix(fc * fa, vid.rgb, wWin);
        al = mix(fa, vid.a, wWin);
        pm *= wCase;
        al *= wCase;
    }

    // ── Ombre portée à angle (3 couches : profondeur) ──
    bool noShadow = (ft == 4 || lightOnly);
    if (os > 0.0 && !noShadow) {
        // Ombre = forme du cadre décalée puis floutée (gaussienne, comme Photoshop) :
        // opacité pleine près du bord, puis dégradé régulier. Un léger contact très serré s'y ajoute.
        float D     = min(shD, 0.8 * os);
        float wS    = 0.82 * max(shB, 1.0);                 // demi-largeur du dégradé (shB = largeur de 10 % à 90 %)
        float sp    = (shadowSpread < 0.0) ? -getComputedValue(-shadowSpread, 0.0) : getComputedValue(shadowSpread, 0.0);
        float sdM   = caseSD(lp - dirS * D) - sp;
        float sdK   = caseSD(lp - dirS * (0.15 * D)) - sp;
        float aMain = 1.0 - smoothstep(-wS, wS, sdM);                        // dégradé en S, qui s'éteint nettement
        float aCont = 1.0 - smoothstep(-(0.35 * wS + 0.4), 0.35 * wS + 0.4, sdK);
        float opac  = (outerShadowColor.a > 0.0) ? outerShadowColor.a : 0.74;
        // le dégradé s'éteint en douceur avant le bord de la zone (pas de coupure nette)
        float dEdge = min(min(lp.x, W - lp.x), min(lp.y, H - lp.y));
        float fadeE = smoothstep(0.0, max(0.30 * shB, 2.0), dEdge);
        float aS = (opac * aMain + 0.08 * aCont * (1.0 - 0.5 * aMain)) * fadeE;
        vec3 shc = vec3(0.0);
        if (outerShadowColor.a > 0.0) shc = outerShadowColor.rgb;
        if (ft == 10) aS *= mix(0.25, 1.0, smoothstep(-2.0, 4.0, dC));   // sous un verre translucide : ombre légère
        aS = clamp(aS, 0.0, 0.94);
        pm += shc * aS * (1.0 - al);
        al += aS * (1.0 - al);
    }
    // ── Forme 4 : halo lumineux coloré par l'image, sur une zone assombrie ──
    else if (os > 0.0 && ft == 4 && wCase < 0.999) {
        float dG   = max(dC, 0.0);
        float fall = clamp(1.0 - dG / os, 0.0, 1.0);
        float glowK = (glowAmount != 0.0) ? glowAmount : GLOW_DEFAULT;
        float dark = 0.40 * pow(fall, 1.1) * clamp(glowK / GLOW_DEFAULT, 0.0, 1.0);   // zone assombrie : suit l'intensité de la lueur
        float g    = pow(fall, 1.4) * glowK;
        vec3 gcol;
        if (outerShadowColor.a > 0.0) {
            gcol = outerShadowColor.rgb;
        } else {
            float ox = max(abs(uvw.x - 0.5) - 0.5, 0.0) * winSz.x;
            float oy = max(abs(uvw.y - 0.5) - 0.5, 0.0) * winSz.y;
            float wx = ox / (ox + oy + 1e-4);
            vec3 cV = vec3(0.0);
            vec3 cH = vec3(0.0);
            if (wx > 0.01) cV = glowAlong(uvw.y, (uvw.x < 0.5) ? 0.0 : 1.0);
            if (wx < 0.99) cH = glowAlong(uvw.x, (uvw.y < 0.5) ? 2.0 : 3.0);
            gcol = mix(cH, cV, wx);
            if (saturation != 1.0) {
                vec3 gray = vec3(dot(gcol, vec3(0.34, 0.55, 0.11)));
                gcol = mix(gray, gcol, saturation);
            }
            // on renforce la saturation et la clarté de la lueur pour qu'elle se voie sur tout fond
            float lum = dot(gcol, vec3(0.34, 0.55, 0.11));
            gcol = clamp(mix(vec3(lum), gcol, 1.25) * 1.10 + 0.02, 0.0, 1.0);
        }
        float aG = clamp(dark + 0.38 * g, 0.0, 0.9);
        pm += gcol * g * 1.30 * (1.0 - al);
        al += aG * (1.0 - al);
    }

    return vec4(pm, al) * v_col;
}

// Déformation de perspective : coordonnées « à plat » (0..1) d'un point d'écran (0..1), comme dans ton shader
vec2 perspectiveUV(vec2 vt, float kY, float kX, float depth)
{
    vec2  c = vt - vec2(0.5);
    float dY = max(depth + c.y * kY, 0.05);
    float dX = max(depth + c.x * kX, 0.05);
    return vec2(c.x / dY, c.y / dX) + vec2(0.5);
}

void main(void)
{
    // Si on sort prématurément, il faut quand même appliquer v_col
    // Image déjà détourée (forme ronde : les 4 coins ET le milieu des 4 bords transparents) : affichée sans cadre.
    // Une capture avec des bandes transparentes (ex. 640x480 avec 25 px vides en haut et en bas) garde son cadre.
    float bordsT = max(max(max(sampleTexture(u_tex, vec2(0.0, 0.0)).a, sampleTexture(u_tex, vec2(1.0, 0.0)).a),
                           max(sampleTexture(u_tex, vec2(0.0, 1.0)).a, sampleTexture(u_tex, vec2(1.0, 1.0)).a)),
                       max(max(sampleTexture(u_tex, vec2(0.5, 0.0)).a, sampleTexture(u_tex, vec2(0.5, 1.0)).a),
                           max(sampleTexture(u_tex, vec2(0.0, 0.5)).a, sampleTexture(u_tex, vec2(1.0, 0.5)).a)));
    if (bordsT < 0.3) {                      // les 8 points transparents
        FragColor = sampleTexture(u_tex, v_tex) * v_col;
        return;
    }
    // Bandes transparentes (capture 640x480 avec l écran du jeu au milieu) : l image est étirée pour que sa partie
    // visible remplisse la fenêtre du cadre. Vidéos et images pleines : bords opaques, rien ne change.
    if (sampleTexture(u_tex, vec2(0.0, 0.5)).a < 0.5 || sampleTexture(u_tex, vec2(1.0, 0.5)).a < 0.5
     || sampleTexture(u_tex, vec2(0.5, 0.0)).a < 0.5 || sampleTexture(u_tex, vec2(0.5, 1.0)).a < 0.5) {
        vec2 A = vec2(bordOpaque(true, true), bordOpaque(false, true));
        vec2 B = vec2(bordOpaque(true, false), bordOpaque(false, false));
        if (B.x - A.x > 0.2 && B.y - A.y > 0.2) { g_artA = A; g_artB = B; }
    }

    vec2 size = abs(outputSize);
    vec2 dtx  = dFdx(v_tex);                 // variation de la texture par pixel d'écran (inclut une éventuelle rotation)
    vec2 dty  = dFdy(v_tex);
    bool persp = (tiltAngle != 0.0 || tiltAngleX != 0.0 || perspectiveDepth != 0.0);

    // ── Sans perspective ──
    if (!persp) {
        vec4 c = shade(v_tex, v_pos - outputOffset);
        // Si l'élément est tourné (propriété rotation du thème), le GPU dessine le bord du quad sans antialiasing :
        // on place le vrai bord de l'image 1 pixel à l'intérieur du quad et on l'antialiase par une couverture linéaire
        // (les pixels concernés sont tous dessinés par le GPU, plus d'effet d'escalier)
        if (abs(dty.x) * size.x + abs(dtx.y) * size.y > 0.02) {
            vec2  de = min(v_tex, vec2(1.0) - v_tex) * size;
            c *= clamp(min(de.x, de.y) - 0.5, 0.0, 1.0);
        }
        FragColor = c;
        return;
    }

    // ── Avec perspective : antialiasing par 4 échantillons + couverture analytique du bord ──
    float kY = 0.5 * tan(radians(tiltAngle));
    float kX = 0.5 * tan(radians(tiltAngleX));
    float depth = (perspectiveDepth != 0.0) ? perspectiveDepth : max(1.0 - 0.5 * max(abs(kY), abs(kX)), 0.2);
    g_flip = flipY > 0.5;
    vec2 vtx = g_flip ? vec2(v_tex.x, 1.0 - v_tex.y) : v_tex;

    // taille d'un pixel d'écran, exprimée en pixels « à plat », au centre du pixel (pour la couverture du bord)
    vec2  u0  = perspectiveUV(vtx, kY, kX, depth);
    vec2  d0v = min(u0, vec2(1.0) - u0) * size;
    float d0  = min(d0v.x, d0v.y);
    float gl  = max(length(vec2(dFdx(d0), dFdy(d0))), 1e-3);
    g_px = clamp(0.5 * (length(dFdx(u0 * size)) + length(dFdy(u0 * size))), 0.6, 4.0);   // pixels « à plat » par pixel d'écran

    vec4 acc = vec4(0.0);
    for (int i = 0; i < 4; i++) {
        vec2 off;
        if (i == 0)      off = vec2(-0.125, -0.375);       // grille tournée : 4 échantillons bien répartis
        else if (i == 1) off = vec2( 0.375, -0.125);
        else if (i == 2) off = vec2( 0.125,  0.375);
        else             off = vec2(-0.375,  0.125);
        vec2  vt = vtx + (off.x * dtx + off.y * dty) * vec2(1.0, g_flip ? -1.0 : 1.0);
        vec2  uq = perspectiveUV(vt, kY, kX, depth);
        vec2  dv = min(uq, vec2(1.0) - uq) * size;
        float cov = clamp(min(dv.x, dv.y) / gl + 0.5, 0.0, 1.0);   // couverture du bord de la zone, sur 1 pixel d'écran
        if (cov > 0.0)
            acc += shade(uq, uq * size) * cov;
    }
    FragColor = acc * 0.25;
}
#endif

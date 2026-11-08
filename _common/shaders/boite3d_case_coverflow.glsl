// boite3d_case_coverflow.glsl : boîte 3D avec boîtier de boite3d_case.glsl, pour un carrousel horizontal.
// FICHIER GÉNÉRÉ depuis boite3d_case.glsl : ne pas modifier à la main, régénérer après toute modification de l original.
// L angle n est plus fixe : u_angle = angle des boîtes de côté ; au centre de l écran la boîte est de face,
// à gauche elle tourne dans un sens, à droite dans l autre, et l angle change en douceur pendant le défilement.
// Réglages en plus de ceux de boite3d_case.glsl :
//   spread         distance au centre (fraction de demi-écran) où l angle maximal est atteint (défaut 0.22)
//   sens           1 ou -1 : sens de rotation des côtés (défaut 1)
//   centreX        position horizontale (0..1 de l écran) de la boîte de face (défaut 0.5)
//   pas            écart entre deux boîtes du carrousel, en fraction de la largeur d écran (= 1 / maxLogoCount, défaut 1/13)
//   jeu            espace entre deux boîtes de côté, en pixels (défaut 3 ; -1 = 0) : elles sont réduites pour ne jamais se chevaucher
//   zoomSelection  agrandissement de la sélection par le carrousel (= logoScale, défaut 1.35) : les voisines restent hors de la sélection
//   ecart          décalage minimal des boîtes de côté vers l extérieur, en largeur de boîte (défaut 0.25 ; -1 = aucun)
//   recadre        1 = image recadrée pour remplir la fenêtre de la jaquette (ex. fanart du système quand le jeu n a pas de boîte)
//   contenu        > 0 : image réduite à cette fraction de la fenêtre, centrée, proportions gardées, transparente autour
//   u_mode 4       = image seule dans la fenêtre de la face, sans boîtier (ex. marquee posé sur la face, avec contenu)
//   formatImage    1 = hauteur de la boîte selon le format de l image (largeur gardée) ; pas pour le logo de tranche
//   reflet         > 0 : reflet au sol de la boîte, de cette opacité, qui s efface vers le bas (élément en plus, sous la boîte)
//   u_mode 5       = halo autour de la boîte, seulement pour la boîte au centre (sélection) ; couleur haloColor (noire = teinte de la jaquette)
//   masqueX        les boîtes s effacent quand leur centre est à plus de masqueX (fraction d écran) du centre ; fonduX = largeur du fondu
//   assombrir      0..1 : les boîtes sont plus sombres à mesure qu elles s éloignent du centre
//   marge          >= 1 : l élément est marge fois plus grand que la boîte (place pour le halo) ; la boîte garde sa taille
// boite3d_case.glsl : boîte 3D retournable (d après boite3d_retourne.glsl) dont la face et le dos sont dessinés
// avec le boîtier de border_dvd_case.glsl (mêmes caseType et mêmes réglages de boîtier).
// Tous les éléments de la boîte ont la MÊME <size> et les mêmes réglages : la géométrie de la boîte (format du
// boîtier, épaisseur, coins arrondis) ne dépend que de la taille de l élément et des uniforms, jamais de l image.
//   u_mode 0     = face (jaquette dans le boîtier) + tranches, couvercles et arêtes arrondies pendant tout le tour
//   u_mode 1     = dos seul (boxback, charnière à droite) ; zIndex plus bas que la face, qui pose les tranches par-dessus
//   u_mode 3.x   : zIndex plus haut que la face (le logo est posé sur la tranche dessinée par la face)
//   u_mode 2     = inutilisé : la tranche est dessinée par les modes 0 et 1 (l élément peut rester dans le XML)
//   u_mode 3.0 / 3.2 / 3.3 = logo sur la tranche visible (bande haute / couché au milieu / bande basse)
// u_phase (animé par la vue, 0 -> 1 en boucle) : retournement face -> dos -> face ; 0 = angle fixe (u_angle).
// caseType 7 = pas de boîtier : comportement de boite3d_retourne (tranche u_spine_color, couvercles u_cap_color ;
//              sans ces couleurs : couleur du bord de l'image).
// Plastique transparent : mélangé à la teinte de l intérieur du boîtier (INTERIOR_COLOR) ; sur la face, le décor
// transparaît en partie (CLEAR_INTERIOR), seulement pour les types transparents et un borderColor semi-transparent.
// Tranches et couvercles toujours opaques.
// Patte d accroche Sega (types 2 et 4) : plaque plate à mi-épaisseur, derrière la boîte.
// Pas d ombre portée en 3D (outerShadowSize ignoré).
// Arêtes face / tranche arrondies selon le type (u_edge_round pour forcer : fraction de la demi-épaisseur, < 0 = vives).
// u_tranches 0 = logo + fond de jaquette sur la tranche charnière, système d ouverture de l autre côté ;
//            1 = logo + fond de jaquette sur les deux tranches (pas de clip ni de couvercle CD sur la tranche d ouverture).
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
uniform   vec2 outputSize;
uniform   float pas;
COMPAT_ATTRIBUTE vec2 VertexCoord;
COMPAT_ATTRIBUTE vec2 TexCoord;
COMPAT_ATTRIBUTE vec4 COLOR;
COMPAT_VARYING   vec2 v_tex;
COMPAT_VARYING   vec4 v_col;
COMPAT_VARYING   vec2 v_pos;
COMPAT_VARYING   float v_cx;
COMPAT_VARYING   float v_pas;

void main(void)
{
    gl_Position = MVPMatrix * vec4(VertexCoord.xy, 0.0, 1.0);
    v_tex       = TexCoord;
    v_col       = COLOR;
    v_pos       = VertexCoord;
    // centre et largeur de l élément à l écran (-1 = bord gauche, 1 = bord droit), mêmes valeurs depuis chaque coin
    float x0    = VertexCoord.x - TexCoord.x * abs(outputSize.x);
    vec4  cg    = MVPMatrix * vec4(x0, VertexCoord.y, 0.0, 1.0);
    vec4  cd    = MVPMatrix * vec4(x0 + abs(outputSize.x), VertexCoord.y, 0.0, 1.0);
    v_cx        = 0.5 * (cg.x / cg.w + cd.x / cd.w);
    v_pas       = 2.0 * (pas != 0.0 ? pas : 1.0 / 13.0) / max(abs(cd.x / cd.w - cg.x / cg.w), 1e-4);
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
#endif

// ─────────────────────────────────────────────────────────────
//  Réglages rapides (modifiables directement ici)
// ─────────────────────────────────────────────────────────────
// Couleur du plastique du boîtier (noir DVD classique)
#define CASE_COLOR        vec3(0.045, 0.045, 0.052)
// 1 = la couleur du boîtier vient de l'uniform borderColor (XML), si son alpha > 0. 0 = toujours CASE_COLOR.
#define USE_BORDER_COLOR  1
// Intensité des reflets (0.0 = mat, 1.0 = normal, 1.5 = très brillant)
#define GLOSS             1.0
// Passer à 1 si l'éclairage semble venir du bas au lieu du haut
#define FLIP_LIGHT_Y      0
// Taille de la boîte dans l'élément (marge pour la rotation)
#define BOX_SCALE         0.6
// Intérieur du boîtier, vu à travers le plastique transparent
#define INTERIOR_COLOR    vec3(0.06, 0.06, 0.07)
// Plastique transparent de la face : part de l'intérieur sombre gardée derrière (1.0 = opaque, 0.0 = on voit le décor)
#define CLEAR_INTERIOR    0.70// Échantillons d'antialiasing des tranches / couvercles / arêtes
#define AA_SAMPLES        8
// Pas de la recherche de la surface sur les arêtes arrondies
#define EDGE_STEPS        24
// ─────────────────────────────────────────────────────────────

COMPAT_VARYING   vec4      v_col;
COMPAT_VARYING   vec2      v_tex;
COMPAT_VARYING   vec2      v_pos;
COMPAT_VARYING   float     v_cx;
COMPAT_VARYING   float     v_pas;

uniform sampler2D u_tex;
uniform vec2 textureSize;
uniform vec2 outputSize;

// ── Boîtier (mêmes réglages que border_dvd_case.glsl) ──
uniform float borderSize;           // 0 = automatique ; < 1 : fraction de la hauteur, >= 1 : pixels
uniform vec4  borderColor;          // seulement si USE_BORDER_COLOR = 1
uniform float couleurBoiteJeu;      // 0 = borderColor du XML ; sinon couleur du jeu (collections), 6 bits par canal RVBA
vec4 couleurBoite() {
    if (couleurBoiteJeu < 0.5) return borderColor;
    float v = couleurBoiteJeu;
    return vec4(floor(v / 262144.0), mod(floor(v / 4096.0), 64.0), mod(floor(v / 64.0), 64.0), mod(v, 64.0)) / 63.0;
}
uniform float cornerRadius;         // 0 = automatique
uniform float innerShadowSize;      // ombre portée par le rebord sur l'image, 0 = automatique
uniform vec4  innerShadowColor;     // alpha 0 = noir 55%
uniform float saturation;
// Forme du boîtier : voir border_dvd_case.glsl (0 DVD, 1 slim, 2/3/4 Sega, 5 CD, 6 Mega-CD, 7 aucun, 8/9 carton,
// 10 DS, 11 3DS, 12 PSP, 13 PS3, 14 DVD PC, 15 3DO, 16 FMV, 17 Dreamcast, 18 cassette, 19 cassette noire, 20/21 chromé)
uniform int   caseType;

// ── Boîte 3D (mêmes réglages que boite3d_retourne.glsl) ──
uniform float u_angle;
uniform float u_phase;   // 0..1 animé par la vue (shader.u_phase) : retournement face -> dos -> face ; 0 = angle fixe
uniform float u_thickness;
uniform float u_mode;
uniform float u_pitch;
uniform float u_logo_scale;
uniform float u_shiny;
uniform vec4  u_cap_color;     // caseType 7 uniquement
uniform vec4  u_spine_color;   // caseType 7 uniquement
uniform float spread;
uniform float sens;
uniform float centreX;
uniform float ecart;
uniform float jeu;
uniform float zoomSelection;
uniform float recadre;
uniform float contenu;
uniform float formatImage;
uniform float reflet;
uniform vec4  haloColor;
uniform float masqueX;
uniform float fonduX;
uniform float assombrir;
float gRefA;
uniform float marge;
uniform float u_edge_round;    // arrondi des arêtes face / tranche : 0 = selon le type, > 0 = fraction de la demi-épaisseur, < 0 = vives
uniform float u_tranches;      // 0 = logo + fond sur la tranche charnière, ouverture de l autre côté ; 1 = logo + fond des deux côtés

// ─────────────────────────────────────────────────────────────
//  Disposition du boîtier (calculée par setupCase, identique pour tous les pixels de l'élément).
//  Repère « face » : pixels de l'élément à plat (W x H), y vers le bas, charnière à gauche.
// ─────────────────────────────────────────────────────────────
int   gType;
bool  gCut;                     // image détourée (boîtier déjà dessiné dans l'image)
float gSign;                    // +1 si v_tex.y croît vers le bas de l'écran, -1 sinon
vec2  gSize;
float gMinSide;
vec2  caseMin, caseMax, winMin, winMax;
vec4  gRad;                     // rayons des coins du boîtier : haut-gauche, haut-droit, bas-droit, bas-gauche
float rim, hinge, rOut, rIn, lipSh, rimR, rimB, rimT, tabH, topY;
float rollBase, glossK, grooveOn, spineOn, grainK, sleeveK, tabOn, glareOn, clearOn;
float spineOpaque, trayOn, dotsOn, milkA, latchOn, ribOn, tabsOn, spineGap, fmvOn, dcPanel, k7On;
vec3  caseBase, clearTint, plastic;
float frameA0;
// boîte dans le repère de l'élément (centré), coins éventuellement inversés pour le dos
vec2  gBMin, gBMax;
vec4  gRadE;
float gEdgeK, gEdgeMax;         // arrondi des arêtes face / tranche : fraction de la demi-épaisseur, plafond en pixels
float gEdge;                    // rayon de cet arrondi en pixels (0 = arêtes vives)
float gThickK;                  // épaisseur propre au type, multipliée par u_thickness (boîtiers CD plus fins)

vec4 sampleTexture(sampler2D tex, vec2 texCoord) {
    return COMPAT_TEXTURE(tex, texCoord);
}

float getComputedValue(float value, float defaultValue) {
    if (value == 0.0)
        return defaultValue;
    if (value < 1.0)
        return gSize.y * value;
    return value;
}

float hash21(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// Bruit 1D lissé (usure irrégulière des bords du carton)
float vnoise1(float x, float seed) {
    float i = floor(x), f = fract(x);
    float a = hash21(vec2(i, seed)), b = hash21(vec2(i + 1.0, seed));
    return mix(a, b, f * f * (3.0 - 2.0 * f));
}

// Bruit 2D lissé (frottements sur la face du carton)
float vnoise2(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    vec2 w = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), w.x),
               mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), w.x), w.y);
}

// Distance signée à un rectangle arrondi (négative à l'intérieur)
float sdRoundRect(vec2 p, vec2 c, vec2 halfSize, float r) {
    vec2 q = abs(p - c) - halfSize + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

// Normale 2D sortante (direction du gradient du SDF) d'un rectangle arrondi
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

// Fente de la patte d'accroche : rectangle arrondi + bosse en demi-cercle vers le haut
float sdTabHole(vec2 p, vec2 c, vec2 hf, float bumpR) {
    return min(sdRoundRect(p, c, hf, hf.y),
               length(p - (c - vec2(0.0, hf.y))) - bumpR);
}

// Rayon du coin le plus proche (r : haut-gauche, haut-droit, bas-droit, bas-gauche ; y vers le bas)
float cornerR(vec2 p, vec2 c, vec4 r) {
    return (p.x < c.x) ? ((p.y < c.y) ? r.x : r.w) : ((p.y < c.y) ? r.y : r.z);
}

vec2 rrNormal4(vec2 p, vec2 bMin, vec2 bMax, vec4 rad) {
    vec2 c = 0.5 * (bMin + bMax);
    return rrNormal(p, c, 0.5 * (bMax - bMin), cornerR(p, c, rad));
}

vec2 lightDir() {
    vec2 L = normalize(vec2(-0.55, -0.85));
#if FLIP_LIGHT_Y
    L.y = -L.y;
#endif
    return L;
}

// ─────────────────────────────────────────────────────────────
//  Disposition du boîtier
// ─────────────────────────────────────────────────────────────
void setupCase(vec2 size) {
    float W = size.x, H = size.y;
    gSize    = size;
    gMinSide = min(W, H);
    gType    = caseType;
    // 3DO dans un format nettement plus haut que large (long box carton) : sans boîtier, comme le type 7.
    // Décidé sur la taille de l'élément (commune à toute la boîte), pas sur l'image.
    if (caseType == 15 && H > 1.25 * W) gType = 7;
    gCut = (gType != 7) && (sampleTexture(u_tex, vec2(1.0)).a < 0.3 || sampleTexture(u_tex, vec2(0.0)).a < 0.3);

    rollBase = 0.45; glossK = GLOSS; grooveOn = 0.0; spineOn = 0.0;
    grainK = 0.014; sleeveK = 1.0; tabOn = 0.0; glareOn = 0.0; clearOn = 0.0;
    spineOpaque = 1.0; trayOn = 0.0; dotsOn = 0.0; milkA = 0.30;
    latchOn = 0.0; ribOn = 0.0; tabsOn = 0.0; spineGap = 0.0; fmvOn = 0.0; dcPanel = 0.0; k7On = 0.0;
    caseBase  = CASE_COLOR;
    clearTint = vec3(0.88, 0.90, 0.93);
    rim = 0.0; hinge = 0.0; rOut = 0.0; rIn = 0.0; lipSh = 0.0; rimR = 0.0; rimB = 0.0; rimT = 0.0;
    tabH = 0.0; topY = 0.0;
    caseMin = vec2(0.0); caseMax = size; winMin = caseMin; winMax = caseMax;

    plastic = caseBase;
    frameA0 = 1.0;
#if USE_BORDER_COLOR
    if (couleurBoite().a > 0.0) plastic = couleurBoite().rgb;
#endif

    gEdgeK = 0.0; gEdgeMax = 0.0;
    // CD jewel case ~10 mm pour 142 mm de large, DVD ~14 mm pour 135 mm ; Mega-CD Europe plus épais qu'un CD
    gThickK = 1.0;
    if (gType == 5 || gType == 15 || gType == 17) gThickK = 0.72;
    else if (gType == 6)                          gThickK = 0.85;
    if (gType == 7) {
        gRad = vec4(min(getComputedValue(cornerRadius, 0.0), 0.5 * gMinSide));
        return;
    }
    if (gType == 8 || gType == 9) {
        float wa = (gType == 9) ? 1.0 : 0.0;
        gRad = vec4(min(getComputedValue(cornerRadius, mix(0.0015, 0.005, wa) * gMinSide), 0.5 * gMinSide));
        // carton : arêtes vives, l'usure du bord de la jaquette fait le vieillissement
        return;
    }

    // Paramètres propres à chaque forme de boîtier (ajouter un `else if` pour une nouvelle forme)
    float rimAuto, hingeK, radK, rInK, lipK;
    float keepAspect = 0.0;
    float rightK = 1.0, bottomK = 1.0, topK = 1.0;
    if (gType == 1) {               // slim console : cadre sur 3 côtés, simple bande de dos à gauche
        rimAuto = 0.026; hingeK = 0.16; radK = 1.2; rInK = 0.3;
        rollBase = 0.55; glossK = GLOSS * 1.3; grooveOn = 0.0;
        spineOn = 1.0;   lipK = 0.3;
    } else if (gType >= 2 && gType <= 4) {   // Sega Mega Drive / Master System : cadre fin, film brillant
        rimAuto = 0.016; hingeK = 1.0; radK = 0.6; rInK = 0.15;
        rollBase = 0.60; glossK = GLOSS * 1.1; grooveOn = 0.0;
        spineOn = 0.0;   lipK = 0.8;
        grainK = 0.02;   sleeveK = 1.8;
        tabOn = (gType == 3) ? 0.0 : 1.0;
        keepAspect = 1.0;
        if (gType == 4) {                           // version brillante
            glossK = GLOSS * 1.9; sleeveK = 2.6; grainK = 0.008; glareOn = 1.0;
        }
    } else if (gType == 5) {        // CD jewel case : bords transparents, dos noir à gauche
        rimAuto = 0.026; hingeK = 4.0; radK = 0.25; rInK = 0.05;
        rollBase = 0.50; glossK = GLOSS;       grooveOn = 0.0;
        spineOn = 0.0;   lipK = 0.25;
        grainK = 0.01;   sleeveK = 1.6;
        keepAspect = 1.0; clearOn = 1.0;
        spineGap = 0.5;
    } else if (gType == 17) {       // Dreamcast EU : CD, dos bleu opaque avec panneau en relief
        rimAuto = 0.026; hingeK = 4.0; radK = 0.25; rInK = 0.05;
        rollBase = 0.50; glossK = GLOSS;       grooveOn = 0.0;
        spineOn = 0.0;   lipK = 0.25;
        grainK = 0.01;   sleeveK = 1.6;
        keepAspect = 1.0; clearOn = 1.0;
        spineGap = 0.5;
        caseBase = vec3(0.16, 0.30, 0.58);
        dcPanel = 1.0;
    } else if (gType == 18) {       // cassette audio : transparent fin, charnière à gauche, plateau noir haut / droite
        rimAuto = 0.016; hingeK = 1.8; radK = 0.4; rInK = 0.05;
        rollBase = 0.50; glossK = GLOSS;       grooveOn = 0.0;
        spineOn = 0.0;   lipK = 0.25;
        grainK = 0.0;    sleeveK = 1.8;
        keepAspect = 1.0; clearOn = 1.0;
        spineOpaque = 0.0;
        topK = 2.2;      rightK = 2.0;    bottomK = 1.1;
        k7On = 1.0;
    } else if (gType == 19) {       // cassette noire épaisse (Oric / IJK) : cadre noir mat, grain
        rimAuto = 0.075; hingeK = 0.75; radK = 0.55; rInK = 0.08;
        rollBase = 0.45; glossK = GLOSS * 0.7; grooveOn = 0.0;
        spineOn = 0.0;   lipK = 0.35;
        grainK = 0.035;  sleeveK = 1.6;
        keepAspect = 1.0;
        rightK = 1.13;   bottomK = 0.95;
        caseBase = vec3(0.035, 0.035, 0.04);
    } else if (gType == 6) {        // Mega-CD Europe : CD épais transparent, plateau noir, picots
        rimAuto = 0.020; hingeK = 1.3; radK = 0.25; rInK = 0.05;
        rollBase = 0.50; glossK = GLOSS;       grooveOn = 0.0;
        spineOn = 0.0;   lipK = 0.25;
        grainK = 0.01;   sleeveK = 1.6;
        keepAspect = 1.0; clearOn = 1.0;
        spineOpaque = 0.0; trayOn = 1.0; dotsOn = 1.0;
    } else if (gType == 10) {       // Nintendo DS : transparent laiteux, bord gauche fin
        rimAuto = 0.022; hingeK = 0.6; radK = 0.5; rInK = 0.1;
        rollBase = 0.50; glossK = GLOSS;       grooveOn = 0.0;
        spineOn = 0.0;   lipK = 0.20;
        grainK = 0.008;  sleeveK = 2.2;
        keepAspect = 1.0; clearOn = 1.0;
        spineOpaque = 0.0; milkA = 0.40;
    } else if (gType == 11) {       // Nintendo 3DS : plastique blanc opaque, bord gauche quasi nul
        rimAuto = 0.026; hingeK = 0.2; radK = 0.8; rInK = 0.1;
        rollBase = 0.55; glossK = GLOSS * 0.8; grooveOn = 0.0;
        spineOn = 0.0;   lipK = 0.35;
        grainK = 0.008;  sleeveK = 1.8;
        keepAspect = 1.0;
        caseBase = vec3(0.88, 0.88, 0.86);
    } else if (gType == 12) {       // PSP : transparent laiteux, droite et bas plus épais
        rimAuto = 0.024; hingeK = 0.0;  radK = 0.6; rInK = 0.1;
        rollBase = 0.50; glossK = GLOSS;       grooveOn = 0.0;
        spineOn = 0.0;   lipK = 0.20;
        grainK = 0.008;  sleeveK = 2.0;
        keepAspect = 1.0; clearOn = 1.0;
        spineOpaque = 0.0; milkA = 0.72;
        clearTint = vec3(0.93, 0.94, 0.95);
        rightK = 1.8;    bottomK = 1.8;
        latchOn = 1.0;
    } else if (gType == 13) {       // PS3 : transparent laiteux, large bandeau en haut
        rimAuto = 0.028; hingeK = 0.35; radK = 1.4; rInK = 0.1;
        rollBase = 0.50; glossK = GLOSS;       grooveOn = 0.0;
        spineOn = 0.0;   lipK = 0.20;
        grainK = 0.008;  sleeveK = 2.0;
        keepAspect = 1.0; clearOn = 1.0;
        spineOpaque = 0.0; milkA = 0.74;
        clearTint = vec3(0.94, 0.95, 0.96);
        rightK = 1.0;    bottomK = 1.3;    topK = 3.9;
    } else if (gType == 14) {       // boîtier DVD PC noir : cadre sombre haut / droite / bas, pas de cadre à gauche
        rimAuto = 0.031; hingeK = 0.0;  radK = 0.81; rInK = 0.05;
        rollBase = 0.50; glossK = GLOSS;       grooveOn = 0.0;
        spineOn = 0.0;   lipK = 0.0;
        grainK = 0.0;    sleeveK = 1.4;
        keepAspect = 1.0;
        rightK = 1.25;   bottomK = 0.68;
    } else if (gType == 15) {       // 3DO : CD classique, dos noir strié, attaches du livret
        rimAuto = 0.026; hingeK = 5.4; radK = 0.25; rInK = 0.05;
        rollBase = 0.50; glossK = GLOSS;       grooveOn = 0.0;
        spineOn = 0.0;   lipK = 0.25;
        grainK = 0.01;   sleeveK = 1.6;
        keepAspect = 1.0; clearOn = 1.0;
        ribOn = 1.0;     tabsOn = 1.0;     spineGap = 0.65;
        rightK = 1.85;
        caseBase = vec3(0.13, 0.11, 0.10);
    } else if (gType == 16) {       // FMV : plastique fumé gris, large bande gauche
        rimAuto = 0.020; hingeK = 5.6; radK = 1.5; rInK = 0.05;
        rollBase = 0.50; glossK = GLOSS;       grooveOn = 0.0;
        spineOn = 0.0;   lipK = 0.20;
        grainK = 0.0;    sleeveK = 1.4;
        keepAspect = 1.0; clearOn = 1.0;
        spineOpaque = 0.0; milkA = 0.50;
        clearTint = vec3(0.60, 0.60, 0.61);
        rightK = 1.33;   bottomK = 1.3;
        fmvOn = 1.0;
    } else if (gType == 20 || gType == 21) {   // 20 blanc chromé / 21 idem sans reflet intérieur
        rimAuto = 0.026; hingeK = 0.0;  radK = 1.0;  rInK = 0.05;
        rollBase = 0.50; glossK = GLOSS;       grooveOn = 0.0;
        spineOn = 0.0;   lipK = 0.0;
        grainK = 0.0;    sleeveK = 0.0;
        keepAspect = 1.0;
        topK = 0.85;     rightK = 1.0;    bottomK = 0.74;
    } else {                        // 0 : DVD
        rimAuto = 0.022; hingeK = 2.4; radK = 0.8; rInK = 0.1;
        rollBase = 0.45; glossK = GLOSS;       grooveOn = 1.0;
        spineOn = 0.0;   lipK = 0.6;
        keepAspect = 1.0;
    }

    plastic = caseBase;
#if USE_BORDER_COLOR
    if (couleurBoite().a > 0.0)
        plastic = couleurBoite().rgb;
    // alpha de borderColor = opacité du cadre ; sans effet pour les types qui dessinent leur propre cadre (14, 20, 21)
    if (couleurBoite().a > 0.0 && gType != 14 && gType != 20 && gType != 21)
        frameA0 = couleurBoite().a;
#endif

    rim   = min(getComputedValue(borderSize, rimAuto * gMinSide), 0.15 * gMinSide);
    hinge = rim * hingeK;
    rOut  = min(getComputedValue(cornerRadius, radK * rim), 0.5 * gMinSide);
    rIn   = rInK * rim;
    lipSh = getComputedValue(innerShadowSize, lipK * rim);
    rimR  = rim * rightK;
    rimB  = rim * bottomK;
    rimT  = rim * topK;
    tabH  = tabOn * 0.11 * H;

    // Proportions de la jaquette conservées : la fenêtre garde le rapport largeur/hauteur de l'élément
    float sideIn = 0.0, vIn = 0.0;
    if (keepAspect > 0.5) {
        float winHgt = H - tabH - rimT - rimB;
        float winWid = W - hinge - rimR;
        sideIn = max(0.0, 0.5 * (winWid - winHgt * W / H));
        vIn    = max(0.0, 0.5 * (winHgt - winWid * H / W));
    }
    topY    = vIn;
    caseMin = vec2(sideIn, topY + tabH);
    caseMax = vec2(W - sideIn, H - vIn);
    winMin  = vec2(caseMin.x + hinge, caseMin.y + rimT);
    winMax  = vec2(caseMax.x - rimR, caseMax.y - rimB);

    // slim (1) et PS3 (13) : coins côté charnière plus serrés ; DVD PC (14) : coins gauches haut ~0.75, bas ~0.60 du rayon ;
    // blanc chromé (20, 21) : 0.31 / 0.46
    float kT = 1.0, kB = 1.0;
    if (gType == 1 || gType == 13) { kT = 0.40; kB = 0.40; }
    if (gType == 14) { kT = 0.75; kB = 0.60; }
    if (gType == 20 || gType == 21) { kT = 0.31; kB = 0.46; }
    gRad = vec4(rOut * kT, rOut, rOut, rOut * kB);

    // Arêtes face / tranche : boîtiers moulés (slim, consoles portables) arrondis, DVD légèrement, boîtiers CD presque vifs.
    // Plafonné à la largeur du cadre pour que l'arrondi reste sur le plastique et ne morde pas la jaquette.
    if      (gType == 5 || gType == 6 || gType == 15 || gType == 17) gEdgeK = 0.08;
    else if (gType == 0 || gType == 14)                               gEdgeK = 0.25;
    else if (gType >= 2 && gType <= 4)                                gEdgeK = 0.35;
    else if (gType == 16 || gType == 18 || gType == 19)               gEdgeK = 0.25;
    else                                                              gEdgeK = 0.45;
    gEdgeMax = 0.6 * rim;
    if (gCut) gEdgeK = 0.0;
}

// ─────────────────────────────────────────────────────────────
//  Face du boîtier (jaquette + cadre), d'après border_dvd_case.glsl
//  lpS    : position sur la face en pixels (y vers le bas), telle qu'on la voit
// recadrage (recadre) ou réduction (contenu) de l image dans la fenêtre de la jaquette
vec4 sampleWindow(vec2 uw, vec2 wSz) {
    float aT = (textureSize.x > 0.0 && textureSize.y > 0.0) ? textureSize.x / textureSize.y : wSz.x / wSz.y;
    float aW = wSz.x / wSz.y;
    vec2  tc = uw;
    if (contenu > 0.0) {
        vec2 m = vec2(contenu);
        if (aT > aW) m.y = contenu * aW / aT; else m.x = contenu * aT / aW;
        tc = (uw - 0.5) / m + 0.5;
        if (tc.x < 0.0 || tc.x > 1.0 || tc.y < 0.0 || tc.y > 1.0) return vec4(0.0);
    } else if (recadre > 0.5) {
        vec2 cs = vec2(1.0);
        if (aT > aW) cs.x = aW / aT; else cs.y = aT / aW;
        tc = 0.5 + (uw - 0.5) * cs;
    }
    return sampleTexture(u_tex, clamp(tc, 0.0, 1.0));
}
//  mirror : dos du boîtier (charnière à droite) ; l'image n'est pas inversée
//  cov    : couverture du contour extérieur (antialiasing) ; la couleur renvoyée n'en tient pas compte
// ─────────────────────────────────────────────────────────────
vec4 caseShade(vec2 lpS, bool mirror, out float cov) {
    vec2  size    = gSize;
    float W       = size.x;
    float H       = size.y;
    float minSide = gMinSide;

    // ── Type 7 : sans bordure, simple anti-aliasing ──
    if (gType == 7) {
        float d7  = sdRoundRect(lpS, 0.5 * size, 0.5 * size, gRad.x);
        cov = clamp(0.5 - d7 / max(fwidth(d7), 1e-3), 0.0, 1.0);
        vec2 uv7 = lpS / size;
        if (gSign < 0.0) uv7.y = 1.0 - uv7.y;
        vec4 col7 = sampleTexture(u_tex, uv7);
        // image très réduite (pas de mipmaps) : moyenne de 5 échantillons pour lisser détails et contour alpha
        vec2 fp = fwidth(uv7);
        if (max(fp.x * textureSize.x, fp.y * textureSize.y) > 1.5) {
            vec2 o = 0.35 * fp;
            col7 = (col7 * 2.0
                  + sampleTexture(u_tex, uv7 + vec2( o.x,  o.y)) + sampleTexture(u_tex, uv7 + vec2(-o.x,  o.y))
                  + sampleTexture(u_tex, uv7 + vec2( o.x, -o.y)) + sampleTexture(u_tex, uv7 + vec2(-o.x, -o.y))) / 6.0;
        }
        if (saturation != 1.0) {
            vec3 gray7 = vec3(dot(col7.rgb, vec3(0.34, 0.55, 0.11)));
            col7.rgb = mix(gray7, col7.rgb, saturation);
        }
        return col7;
    }

    // ── Image détourée : affichée telle quelle sur la face du boîtier ──
    if (gCut) {
        vec2  cC = 0.5 * (caseMin + caseMax), cH = 0.5 * (caseMax - caseMin);
        float dD = sdRoundRect(lpS, cC, cH, cornerR(lpS, cC, mirror ? gRad.yxwz : gRad));
        cov = clamp(0.5 - dD / max(fwidth(dD), 1e-3), 0.0, 1.0);
        vec2 uvD = (lpS - caseMin) / max(caseMax - caseMin, vec2(1.0));
        if (gSign < 0.0) uvD.y = 1.0 - uvD.y;
        return sampleTexture(u_tex, clamp(uvD, 0.0, 1.0));
    }

    // ── Types 8 / 9 : boîte carton vue de face (9 = très usée) ──
    if (gType == 8 || gType == 9) {
        float wa  = (gType == 9) ? 1.0 : 0.0;
        vec2  lp8 = lpS;
        float px8 = max(length(fwidth(lp8)) * 0.7071, 0.5);
        vec2  fMin = vec2(0.0);
        vec2  fMax = size;
        vec2  gMax = fMax;
        vec2  gC = 0.5 * (fMin + gMax), gHf = 0.5 * (gMax - fMin);
        float r8  = gRad.x;
        float d8  = sdRoundRect(lp8, gC, gHf, r8);
        cov = clamp(0.5 - d8 / max(fwidth(d8), 1e-3), 0.0, 1.0);

        float ux   = clamp(lp8.x / W, 0.0, 1.0);
        float uyD  = clamp(lp8.y / H, 0.0, 1.0);
        vec4  col8 = sampleTexture(u_tex, vec2(ux, (gSign < 0.0) ? 1.0 - uyD : uyD));
        if (saturation != 1.0)
            col8.rgb = mix(vec3(dot(col8.rgb, vec3(0.34, 0.55, 0.11))), col8.rgb, saturation);

        vec2  L8  = normalize(vec2(-0.55, -0.85));
        float e   = -d8;                                         // distance au bord extérieur
        float u   = 0.0035 * minSide;
        vec2  n8  = rrNormal(lp8, gC, gHf, r8);
        float lit = dot(n8, L8);

        // Face : arête éclairée côté lumière, pli sombre juste à l'intérieur du bord
        vec3  c   = col8.rgb;
        vec3  paper = vec3(0.93, 0.92, 0.88);                    // carton mis à nu
        if (wa > 0.0) {                                          // couleurs passées : noirs délavés, un peu ternies
            vec3 faded = mix(vec3(dot(c, vec3(0.30, 0.59, 0.11))), c, 0.85) * 0.86 + vec3(0.075, 0.075, 0.08);
            c = mix(c, faded, wa);
            paper = vec3(0.80, 0.80, 0.78);
        }
        float bev = 1.0 - smoothstep(0.0, max(1.2 * u, 1.3 * px8), e);
        c = mix(c, c + 0.25 * max(lit, 0.0), bev * 0.8);
        c *= 1.0 - 0.35 * bev * max(-lit, 0.0);
        float fold = 1.0 - smoothstep(0.0, max(0.5 * u, 1.3 * px8), abs(e - 2.2 * u));
        c *= 1.0 - 0.18 * fold;
        float fr   = 1.0 - smoothstep(0.0, max(0.5 * u, 1.3 * px8), abs(lp8.x - (fMax.x - 3.5 * u)));
        c *= 1.0 - 0.12 * fr;
        // reflet du pelliculage (face seulement)
        vec2  np8 = lp8 / size;
        float ug8 = (np8.x * 0.85 + np8.y * 0.65 - 0.55) / 0.20;
        c = mix(c, vec3(1.0), 0.05 * GLOSS * exp(-ug8 * ug8));

        // Très usée : voile marbré, petits points blancs, fissures courtes et sinueuses près des bords
        if (wa > 0.0) {
            vec3  sdc  = sampleTexture(u_tex, vec2(0.37, 0.61)).rgb + sampleTexture(u_tex, vec2(0.71, 0.23)).rgb;
            float seed = fract(dot(sdc, vec3(12.9898, 78.233, 37.719)) + 0.137);
            float mot  = vnoise2(lp8 / (0.10 * minSide) + seed * 13.0) * 0.65
                       + vnoise2(lp8 / (0.035 * minSide) + seed * 7.0) * 0.35;
            c += vec3(0.07) * smoothstep(0.45, 0.85, mot);
            float cell = max(0.0045 * minSide, 1.5 * px8);
            float spk  = hash21(floor(lp8 / cell) + seed * 91.0);
            float nearE = 1.0 - smoothstep(0.0, 0.15 * minSide, -d8);
            c = mix(c, paper, 0.35 * step(0.996 - 0.012 * nearE, spk));
            float wl = max(0.0013 * minSide, 1.1 * px8);
            for (int k = 0; k < 6; k++) {
                float fk  = float(k);
                float h1  = hash21(vec2(seed, fk));
                float h2  = hash21(vec2(seed, fk + 10.0));
                float h3  = hash21(vec2(seed, fk + 20.0));
                float sideK = floor(h1 * 4.0);
                vec2  rel = vec2(h2, 0.04 + 0.16 * h3);
                if (sideK == 1.0) rel = vec2(h2, 1.0 - 0.04 - 0.16 * h3);
                if (sideK == 2.0) rel = vec2(0.03 + 0.12 * h3, h2);
                if (sideK == 3.0) rel = vec2(1.0 - 0.03 - 0.12 * h3, h2);
                vec2  p0  = fMin + (fMax - fMin) * rel;
                float ang = (sideK < 2.0 ? 1.5708 : 0.0) + (hash21(vec2(seed, fk + 30.0)) - 0.5) * 1.4;
                vec2  nk  = vec2(cos(ang), sin(ang));
                float hl  = (0.04 + 0.08 * hash21(vec2(seed, fk + 40.0))) * minSide;
                float tl  = dot(lp8 - p0, vec2(-nk.y, nk.x));
                float dl  = dot(lp8 - p0, nk)
                          + (vnoise1(tl / (0.025 * minSide), seed * 40.0 + fk) - 0.5) * 0.020 * minSide
                          + (vnoise1(tl / (0.006 * minSide), seed * 60.0 + fk) - 0.5) * 0.005 * minSide;
                float ends  = 1.0 - smoothstep(0.5 * hl, hl, abs(tl));
                float brk   = smoothstep(0.25, 0.5, vnoise1(tl / (0.010 * minSide), seed * 50.0 + fk));
                float crack = (1.0 - smoothstep(0.0, wl, abs(dl))) * brk * ends;
                c = mix(c, paper, 0.55 * crack * wa);
                c *= 1.0 - 0.10 * (1.0 - smoothstep(0.0, 2.5 * wl, abs(dl - 1.5 * wl))) * ends * wa;
            }
        }

        // Usure : bords blanchis par endroits, plus marquée dans les coins et en bas
        float along = (abs(n8.x) > abs(n8.y)) ? lp8.y : lp8.x;
        float side  = (abs(n8.x) > abs(n8.y)) ? sign(n8.x) : 2.0 + sign(n8.y);
        float nz    = vnoise1(along / (0.02 * minSide), side) * 0.7 + vnoise1(along / (0.006 * minSide), side + 7.0) * 0.3;
        vec2  dc    = min(lp8 - fMin, gMax - lp8);
        float corner = 1.0 - smoothstep(0.0, 0.05 * minSide, length(dc));
        float bottom = smoothstep(0.0, 0.9, n8.y);
        float ww    = u * (0.5 + 2.6 * smoothstep(0.55, 0.95, nz) + 3.6 * corner + 1.0 * bottom) * (1.0 + 1.8 * wa);
        float wear  = (1.0 - smoothstep(0.0, max(ww, px8), e)) * (mix(0.35, 0.6, wa) + 0.65 * smoothstep(0.4, 0.8, nz));
        c = mix(c, paper, clamp(wear * mix(0.85, 1.0, wa), 0.0, 1.0));
        if (wa > 0.0) {
            float nzc   = vnoise1(atan(dc.y, dc.x) * 5.0, side + 3.0);
            float crush = 1.0 - smoothstep(0.0, max(0.020 * minSide * (0.5 + nzc), px8), length(dc));
            c = mix(c, paper, 0.7 * crush * wa);
        }
        c += (hash21(floor(lp8)) - 0.5) * 0.012;                  // grain du carton
        return vec4(max(c, 0.0), col8.a);
    }

    // ── Boîtiers : géométrie dans le repère du boîtier (charnière à gauche) ──
    vec2 lp = mirror ? vec2(W - lpS.x, lpS.y) : lpS;

    vec2  wSz = max(winMax - winMin, vec2(1.0));
    float ugx = (lp.x - winMin.x) / wSz.x;
    float vdy = (lp.y - winMin.y) / wSz.y;
    vec4 sampledColor = sampleWindow(vec2(mirror ? 1.0 - ugx : ugx, (gSign > 0.0) ? vdy : 1.0 - vdy), wSz);

    if (saturation != 1.0) {
        vec3 gray = vec3(dot(sampledColor.rgb, vec3(0.34, 0.55, 0.11)));
        sampledColor = vec4(mix(gray, sampledColor.rgb, saturation), sampledColor.a);
    }

    // ── Géométrie (SDF) ─────────────────────────────────────────
    vec2  caseCenter = 0.5 * (caseMin + caseMax);
    vec2  caseHalf   = 0.5 * (caseMax - caseMin);
    float rUse  = cornerR(lp, caseCenter, gRad);
    float dCase = sdRoundRect(lp, caseCenter, caseHalf, rUse);

    vec2 winCenter = 0.5 * (winMin + winMax);
    vec2 winHalf   = 0.5 * (winMax - winMin);
    // Slim (type 1) : coin HAUT-DROIT de la jaquette plus arrondi
    float rW   = (gType == 1 && lp.y < winCenter.y && lp.x > winCenter.x) ? min(0.6 * rim, 0.5 * min(winHalf.x, winHalf.y)) : rIn;
    float dWin = sdRoundRect(lp, winCenter, winHalf, rW);

    float aa = max(fwidth(dCase), 1.0);
    cov = clamp(0.5 - dCase / aa, 0.0, 1.0);
    if (dCase > aa)
        return vec4(0.0);

    // ── Lumière : venue du haut à gauche de l'écran ─────────────
    vec2 L = lightDir();
    if (gType == 1) L.x = -L.x;     // slim : lumière venue du haut à droite
    if (mirror)     L.x = -L.x;     // dos : repère du boîtier inversé
    vec2 np = lpS / size;
#if FLIP_LIGHT_Y
    np.y = 1.0 - np.y;
#endif

    vec3  fcol   = vec3(0.0);
    float frameA = frameA0;
    vec2  nWin   = rrNormal(lp, winCenter, winHalf, rW);
    float sh     = np.x * 0.85 + np.y * 0.65;

    // Le cadre n'est visible que là où la fenêtre ne recouvre pas tout
    if (dWin > -aa) {
        fcol = plastic + vec3(0.03) * (1.0 - np.y);

        // Arête arrondie du boîtier : reflet côté lumière, plus large côté charnière
        vec2  nOut      = rrNormal(lp, caseCenter, caseHalf, rUse);
        float ndl       = dot(nOut, L);
        float edgeDepth = -dCase;
        float rollW     = rollBase * rim * (1.0 + 0.9 * smoothstep(0.3, 0.9, (gType == 1) ? nOut.x : -nOut.x));
        float roll      = clamp(1.0 - edgeDepth / rollW, 0.0, 1.0);
        roll = roll * roll;
        fcol += vec3(0.55 * glossK) * pow(max(ndl, 0.0), 2.0) * roll;
        fcol *= 1.0 - 0.45 * max(-ndl, 0.0) * roll;

        // Fine nervure moulée sur le pourtour
        float ridge = 1.0 - smoothstep(0.0, max(0.07 * rim, 1.0), abs(edgeDepth - 0.55 * rim));
        fcol += vec3(0.04 + 0.10 * max(ndl, 0.0)) * ridge;

        // Rainure de la charnière : paroi gauche sombre, paroi droite éclairée
        float lx = lp.x - caseMin.x;
        float gx = rim * 1.3;
        float gw = max(0.16 * rim, 1.0);
        float ym = grooveOn * smoothstep(rOut * 0.6, rOut * 1.6 + 1.0, min(lp.y - caseMin.y, caseMax.y - lp.y));
        float gDark = (1.0 - smoothstep(0.0, gw, abs(lx - gx))) * ym;
        float gLite = (1.0 - smoothstep(0.0, gw, abs(lx - gx - gw * 1.5))) * ym;
        fcol = fcol * (1.0 - 0.85 * gDark) + vec3(0.22 * glossK) * gLite;

        // Rebord de la fenêtre : tranche éclairée en bas / à droite de l'ouverture
        float ndlLip = dot(-nWin, L);
        float lipW   = max(0.22 * rim, 1.0);
        float lip    = 1.0 - smoothstep(0.0, lipW + aa, max(dWin, 0.0));
        fcol += vec3(0.28 * glossK) * lip * max(ndlLip, 0.0);

        // Reflet diagonal doux sur le plastique + grain
        float u1  = (sh - 0.55) / 0.14;
        fcol += vec3(0.06 * glossK) * exp(-u1 * u1);
        fcol += (hash21(floor(lp)) - 0.5) * grainK;

        // Bande de dos (slim) : tranche claire à gauche de la jaquette
        if (spineOn > 0.5) {
            float yIn = smoothstep(winMin.y - aa, winMin.y + aa, lp.y)
                      * (1.0 - smoothstep(winMax.y - aa, winMax.y + aa, lp.y));
            float xIn = 1.0 - smoothstep(winMin.x - aa, winMin.x + aa, lp.x);
            float lxn = clamp((lp.x - caseMin.x) / max(hinge, 1.0), 0.0, 1.0);
            vec3 spine = mix(vec3(0.28), vec3(0.58, 0.60, 0.62), smoothstep(0.0, 0.35, lxn))
                       * mix(1.0, 0.82, lxn);
            fcol = mix(fcol, spine, yIn * xIn);
        }
        // DVD PC (type 14) : profil de la photo, côté le plus proche (haut / droite / bas)
        if (gType == 14) {
            float tT = (lp.y - caseMin.y) / max(rimT, 1.0);
            float tR = (caseMax.x - lp.x) / max(rimR, 1.0);
            float tB = (caseMax.y - lp.y) / max(rimB, 1.0);
            float tP = clamp(min(tT, min(tR, tB)), 0.0, 1.0);
            float pxP = aa / max(min(rimT, min(rimR, rimB)), 1.0);
            float onR = step(tR, min(tT, tB));
            float v  = mix(0.34, 0.11, smoothstep(0.0, 0.60, tP));
            float ln = 1.0 - smoothstep(0.0, max(0.03, pxP), abs(tP - 0.60));
            v = mix(v, 0.05, ln);
            float lipZ = smoothstep(0.60, 0.62 + pxP, tP);
            float lipV = 0.35 + 0.06 * (1.0 - smoothstep(0.62, 0.62 + 3.0 * max(0.03, pxP), tP));
            v = mix(v, lipV, lipZ);
            float pxR = aa / max(rimR, 1.0);
            float vR = mix(0.40, 0.11, smoothstep(0.0, 0.56, tP));
            float lzR = smoothstep(0.71 - 0.5 * pxR, 0.71 + 0.5 * pxR, tP);
            float lpR = 0.345 + 0.025 * (1.0 - smoothstep(0.71, 0.71 + 2.0 * pxR, tP));
            vR = mix(vR, lpR, lzR);
            v = mix(v, vR, onR);
            fcol = vec3(v);
        }
        // Blanc chromé (types 20 / 21) : profils mesurés (gris 0..1)
        if (gType == 20 || gType == 21) {
            float tT = (lp.y - caseMin.y) / max(rimT, 1.0);
            float tR = (caseMax.x - lp.x) / max(rimR, 1.0);
            float tB = (caseMax.y - lp.y) / max(rimB, 1.0);
            float tP = clamp(min(tT, min(tR, tB)), 0.0, 1.0);
            float onR = step(tR, min(tT, tB));
            float onB = step(tB, min(tT, tR)) * (1.0 - onR);
            // coins droits : le tube se courbe (profil radial autour du centre du coin)
            float rc = max(rOut, 1.0);
            bool  inTR = lp.x > caseMax.x - rc && lp.y < caseMin.y + rc;
            bool  inBR = lp.x > caseMax.x - rc && lp.y > caseMax.y - rc;
            vec2  dv = vec2(0.0);
            if (inTR || inBR) {
                vec2  cc = vec2(caseMax.x - rc, inTR ? caseMin.y + rc : caseMax.y - rc);
                dv = lp - cc;
                float wH = abs(dv.x) / max(abs(dv.x) + abs(dv.y), 1e-3);
                float th = mix(inTR ? rimT : rimB, rimR, wH);
                tP  = clamp((rc - length(dv)) / max(th, 1.0), 0.0, 1.0);
                onR = wH;
                onB = inBR ? 1.0 - wH : 0.0;
            }
            float q;
            q = (tP - 0.11) / 0.060; float gA = exp(-q * q);
            q = (tP - 0.66) / 0.040; float gB = exp(-q * q);
            q = (tP - 0.47) / 0.080; float hA = exp(-q * q);
            q = (tP - 0.78) / 0.050; float hB = exp(-q * q);
            float vT = clamp(0.70 + 0.28 * hA + 0.27 * hB - 0.72 * gA - 0.72 * gB, 0.0, 1.0);
            q = (tP - 0.22) / 0.050; float pR = exp(-q * q);
            q = (tP - 0.31) / 0.042; float cR = exp(-q * q);
            float vR = mix(0.99, 0.62, smoothstep(0.56, 1.0, tP));
            vR = mix(vR, 0.98, pR) - 0.58 * cR;
            vR = mix(0.08, vR, smoothstep(0.03, 0.17, tP));
            q = (tP - 0.17) / 0.070; float b1 = exp(-q * q);
            q = (tP - 0.31) / 0.040; float b2 = exp(-q * q);
            q = (tP - 0.63) / 0.110; float b3 = exp(-q * q);
            q = (tP - 0.83) / 0.040; float b4 = exp(-q * q);
            float vB = clamp(0.66 - 0.21 * b1 - 0.42 * b2 + 0.28 * b3 - 0.25 * b4, 0.0, 1.0);
            fcol = vec3(mix(mix(vT, vB, onB), vR, onR));
            if (inTR || inBR) {
                float sn  = clamp(2.0 * abs(dv.x * dv.y) / max(dot(dv, dv), 1.0), 0.0, 1.0);
                q = (tP - 0.33) / 0.06;
                float arc = exp(-q * q) * smoothstep(0.15, 0.75, sn);
                fcol = mix(fcol, vec3(0.03), 0.90 * arc);
            }
        }
        fcol = max(fcol, 0.0);

        // Boîtier CD : plastique transparent partout sauf le dos (bande noire opaque à gauche)
        if (clearOn > 0.5) {
            vec2  spMin = vec2(caseMin.x + 0.25 * rim, caseMin.y + 0.45 * rim);
            vec2  spMax = vec2(winMin.x - 1.0 - spineGap * rim, caseMax.y - 0.45 * rim);
            float spR   = (ribOn > 0.5 || spineGap > 0.0) ? 0.15 * rim : 0.9 * rim;
            float dSp   = sdRoundRect(lp, 0.5 * (spMin + spMax), 0.5 * (spMax - spMin), spR);
            float spine = (1.0 - smoothstep(-aa, aa, dSp)) * spineOpaque;

            // Bords transparents : teinte très légère + deux liserés brillants
            float lw    = max(0.07 * rim, 1.3 * aa);
            float e1    = 1.0 - smoothstep(0.0, lw, abs(edgeDepth - 0.10 * rim));
            float e2    = 1.0 - smoothstep(0.0, lw, abs(edgeDepth - 0.60 * rim));
            float lines = max(e1, 0.6 * e2) * (0.35 + 0.40 * max(ndl, 0.0));
            vec3  clearRGB = mix(clearTint, vec3(1.0), lines);
            float clearA   = milkA + 0.45 * lines + 0.10 * exp(-u1 * u1);

            // Dos : plastique noir, reflets atténués
            float lx2 = (lp.x - spMin.x) / max(spMax.x - spMin.x, 1.0);
            float ug  = (lx2 - 0.12) / 0.07;
            vec3  sp  = mix(plastic, fcol, 0.4) + vec3(0.07 * glossK) * exp(-ug * ug);
            if (dcPanel > 0.5) {               // panneau en relief (Dreamcast)
                float spw = spMax.x - spMin.x, sph = spMax.y - spMin.y;
                vec2  pc  = vec2(spMin.x + 0.52 * spw, spMin.y + 0.51 * sph);
                vec2  ph  = vec2(0.36 * spw, 0.165 * sph);
                float dP  = sdRoundRect(lp, pc, ph, 0.45 * ph.x);
                float inP = 1.0 - smoothstep(-aa, aa, dP);
                float edP = 1.0 - smoothstep(0.0, 1.3 * lw, abs(dP));
                float litP = dot(rrNormal(lp, pc, ph, 0.45 * ph.x), vec2(mirror ? -0.8 : 0.8, -0.6));
                sp = mix(sp, sp * 1.18 + vec3(0.02), inP);
                sp = mix(sp, (litP > 0.0) ? sp + vec3(0.18) : sp * 0.6, 0.8 * edP);
            }
            if (ribOn > 0.5) {                 // stries verticales du dos (3DO)
                float per = max(0.008 * W, 3.0 * aa);
                float rib = 0.5 + 0.5 * cos(6.2832 * (lp.x - spMin.x) / per);
                sp = sp * (1.0 - 0.35 * (1.0 - rib)) + vec3(0.06, 0.055, 0.05) * rib * rib;
            }
            if (spineGap > 0.0) {              // double ligne de la charnière du couvercle
                float gx1 = spMax.x + 0.30 * spineGap * rim;
                float gx2 = spMax.x + 0.70 * spineGap * rim;
                float hl2 = max(1.0 - smoothstep(0.0, lw, abs(lp.x - gx1)), 1.0 - smoothstep(0.0, lw, abs(lp.x - gx2)));
                float inGapY = smoothstep(caseMin.y + 0.5 * rim, caseMin.y + rim, lp.y) * (1.0 - smoothstep(caseMax.y - rim, caseMax.y - 0.5 * rim, lp.y));
                clearRGB = mix(clearRGB, vec3(1.0), 0.55 * hl2 * inGapY);
                clearA   = min(clearA + 0.35 * hl2 * inGapY, 1.0);
            }

            // Barre d'ouverture (PSP)
            if (latchOn > 0.5) {
                vec2  lc   = vec2(caseMax.x - 0.48 * rimR, 0.5 * (caseMin.y + caseMax.y));
                vec2  lh   = vec2(max(0.32 * rimR, 1.5), 0.30 * (caseMax.y - caseMin.y));
                float dL   = sdRoundRect(lp, lc, lh, lh.x);
                float inL  = 1.0 - smoothstep(-0.6 * lh.x, aa, dL);
                float edgL = 1.0 - smoothstep(0.0, 1.5 * lw, abs(dL));
                float litL = dot(rrNormal(lp, lc, lh, lh.x), L);
                clearRGB = mix(clearRGB, vec3(1.0), 0.7 * inL);
                clearRGB = mix(clearRGB, (litL > 0.0) ? vec3(1.0) : vec3(0.75), 0.25 * edgL);
                clearA   = min(clearA + 0.20 * inL + 0.10 * edgL, 1.0);
            }

            // Bandeau du haut (PS3)
            if (rimT > 1.5 * rim) {
                float inBand = (1.0 - smoothstep(winMin.y - aa, winMin.y + aa, lp.y))
                             * smoothstep(caseMin.y + 0.5 * rim, caseMin.y + rim, lp.y);
                float clipL  = 1.0 - smoothstep(0.0, lw, abs(lp.y - (winMin.y - 0.35 * rim)));
                clearA   = min(clearA + 0.08 * inBand + 0.30 * clipL * inBand, 1.0);
                clearRGB = mix(clearRGB, vec3(1.0), 0.6 * clipL * inBand);
            }

            // 3DO : plateau noir à droite avec les deux attaches du livret
            if (tabsOn > 0.5) {
                float tx0 = winMax.x, tx1 = caseMax.x - 0.6 * rim;
                float inTx = smoothstep(tx0 - 0.5 * aa, tx0 + 0.5 * aa, lp.x) * (1.0 - smoothstep(tx1 - aa, tx1 + aa, lp.x));
                float inTy = smoothstep(caseMin.y + 0.9 * rim, caseMin.y + 0.9 * rim + aa, lp.y)
                           * (1.0 - smoothstep(caseMax.y - 0.9 * rim - aa, caseMax.y - 0.9 * rim, lp.y));
                float tr = inTx * inTy;
                vec3  trc = vec3(0.07, 0.07, 0.08) + vec3(0.05) * max(ndl, 0.0);
                clearRGB = mix(clearRGB, trc, tr);
                clearA   = mix(clearA, 0.93, tr);
                float hgt = caseMax.y - caseMin.y;
                float rx  = mix(tx0, tx1, 0.40);
                float rw  = max(0.12 * rim, 0.7 * aa);
                for (int k = 0; k < 2; k++) {
                    float y0 = caseMin.y + hgt * ((k == 0) ? 0.17 : 0.56);
                    float y1 = caseMin.y + hgt * ((k == 0) ? 0.43 : 0.82);
                    vec2  rc = vec2(rx, 0.5 * (y0 + y1));
                    float dR = sdRoundRect(lp, rc, vec2(rw, 0.5 * (y1 - y0)), rw);
                    float rod = 1.0 - smoothstep(-0.5 * aa, 0.5 * aa + 0.3 * lw, dR);
                    clearRGB = mix(clearRGB, vec3(0.78), 0.65 * rod * tr);
                    vec2  ch = vec2(max(1.8 * rw, 0.8 * aa), max(1.2 * rw, 0.8 * aa));
                    float dC = min(sdRoundRect(lp, vec2(rx, y0 + ch.y), ch, 0.3 * ch.x),
                                   sdRoundRect(lp, vec2(rx, y1 - ch.y), ch, 0.3 * ch.x));
                    float cap = 1.0 - smoothstep(-0.5 * aa, 0.5 * aa, dC);
                    clearRGB = mix(clearRGB, vec3(0.85), 0.35 * cap * tr);
                }
            }

            // FMV : panneau translucide à gauche, rainure, encoche en « D »
            if (fmvOn > 0.5) {
                float hw   = winMin.x - caseMin.x;
                float lxf  = clamp((lp.x - caseMin.x) / max(hw, 1.0), 0.0, 1.0);
                float onL  = 1.0 - smoothstep(winMin.x - aa, winMin.x + aa, lp.x);
                float gxf  = smoothstep(0.0, 0.45, lxf);
                vec3  pc   = vec3(mix(0.64, 0.80, gxf));
                float pa   = mix(0.58, 0.14, gxf);
                float grv  = 1.0 - smoothstep(0.0, lw, abs(lp.x - (caseMin.x + 0.20 * hw)));
                pc = mix(pc, vec3(0.45), 0.5 * grv);
                float chh = caseMax.y - caseMin.y;
                vec2  eMin = vec2(caseMin.x - hw, caseMin.y + 0.32 * chh);
                vec2  eMax = vec2(caseMin.x + 0.45 * hw, caseMin.y + 0.68 * chh);
                vec2  ec  = 0.5 * (eMin + eMax), eh = 0.5 * (eMax - eMin);
                float dE  = sdRoundRect(lp, ec, eh, 0.40 * hw);
                float inE = 1.0 - smoothstep(-aa, aa, dE);
                float edE = 1.0 - smoothstep(0.0, 1.2 * lw, abs(dE + 0.5 * lw));
                pc = mix(pc, vec3(0.74), inE);
                pa = mix(pa, 0.62, inE);
                pc = mix(pc, vec3(0.30), 0.6 * edE);
                pa = mix(pa, 0.55, 0.6 * edE);
                clearRGB = mix(clearRGB, pc, onL);
                clearA   = mix(clearA, pa, onL);
                float jl  = (1.0 - smoothstep(0.0, lw, abs(lp.x - winMin.x + 0.6 * lw))) * onL;
                clearRGB = mix(clearRGB, vec3(0.10), 0.6 * jl);
                clearA   = mix(clearA, 0.55, jl);
                float ow  = 1.0 - smoothstep(0.0, lw, edgeDepth - 0.3 * lw);
                float od  = 1.0 - smoothstep(0.0, lw, abs(edgeDepth - 1.6 * lw));
                clearRGB = mix(clearRGB, vec3(0.18), 0.6 * od);
                clearA   = mix(clearA, 0.75, 0.6 * od);
                clearRGB = mix(clearRGB, vec3(1.0), 0.7 * ow);
                clearA   = mix(clearA, 0.6, ow);
            }

            // Cassette : plateau noir en haut et à droite, charnière transparente à gauche
            if (k7On > 0.5) {
                float tTop = smoothstep(caseMin.y + 0.85 * rim - aa, caseMin.y + 0.85 * rim + aa, lp.y)
                           * (1.0 - smoothstep(winMin.y - aa, winMin.y + aa, lp.y))
                           * smoothstep(caseMin.x + 0.6 * rim, caseMin.x + 0.6 * rim + aa, lp.x)
                           * (1.0 - smoothstep(caseMax.x - 0.85 * rim - aa, caseMax.x - 0.85 * rim + aa, lp.x));
                float tRgt = smoothstep(winMax.x - aa, winMax.x + aa, lp.x)
                           * (1.0 - smoothstep(caseMax.x - 0.85 * rim - aa, caseMax.x - 0.85 * rim + aa, lp.x))
                           * smoothstep(caseMin.y + 0.85 * rim - aa, caseMin.y + 0.85 * rim + aa, lp.y)
                           * (1.0 - smoothstep(winMax.y - aa, winMax.y + aa, lp.y));
                float tr = max(tTop, tRgt);
                clearRGB = mix(clearRGB, vec3(0.06, 0.06, 0.07) + vec3(0.06) * max(ndl, 0.0), tr);
                clearA   = mix(clearA, 0.92, tr);
                float hx1 = caseMin.x + 0.55 * hinge, hx2 = caseMin.x + 0.80 * hinge;
                float hl  = max(1.0 - smoothstep(0.0, lw, abs(lp.x - hx1)), 1.0 - smoothstep(0.0, lw, abs(lp.x - hx2)));
                float onLh = 1.0 - smoothstep(winMin.x - aa, winMin.x + aa, lp.x);
                clearRGB = mix(clearRGB, vec3(1.0), 0.5 * hl * onLh);
                clearA   = min(clearA + 0.30 * hl * onLh, 1.0);
            }

            // Plateau noir vu à travers le couvercle (Mega-CD)
            float tray = trayOn * smoothstep(0.55 * rim - aa, 0.55 * rim + aa, edgeDepth);
            clearRGB = mix(clearRGB, vec3(0.10, 0.10, 0.11) + vec3(0.10) * lines, tray);
            clearA   = mix(clearA, 0.92, tray);

            fcol   = mix(clearRGB, sp, spine);
            frameA = mix(clearA, 1.0, spine);
        }
    }

    // ── Pochette (image) derrière le film plastique ─────────────
    vec3 art = sampledColor.rgb;

    // Ombre du rebord sur l'image, plus marquée côté lumière
    float depth  = max(-dWin, 0.0);
    float k      = clamp(dot(nWin, L) * 0.5 + 0.5, 0.0, 1.0);
    float shadow = 1.0 - smoothstep(0.0, lipSh, depth);
    shadow = shadow * shadow * mix(0.3, 1.0, k);
    vec4 isc = (innerShadowColor.a > 0.0) ? innerShadowColor : vec4(0.0, 0.0, 0.0, 0.55);
    art = mix(art, isc.rgb, isc.a * shadow);

    // Reflets du film plastique transparent (large bande + fine bande)
    float u2 = (sh - 0.50) / 0.17;
    float u3 = (sh - 0.78) / 0.035;
    float gloss = (0.07 * exp(-u2 * u2) + 0.04 * exp(-u3 * u3)) * GLOSS * sleeveK;
    if (glareOn > 0.5) {
        float wy    = (lp.y - winMin.y) / max(winMax.y - winMin.y, 1.0);
        float wx    = (lpS.x - (mirror ? W - winMax.x : winMin.x)) / max(winMax.x - winMin.x, 1.0);
        float sheen = (1.0 - smoothstep(0.0, 0.38, wy)) * (1.0 - 0.6 * wx);
        float u4 = (sh - 0.46) / 0.030;
        float u5 = (sh - 0.54) / 0.012;
        gloss += (0.17 * sheen + 0.22 * exp(-u4 * u4) + 0.17 * exp(-u5 * u5)) * GLOSS;
    }
    art = mix(art, vec3(1.0), gloss);

    // FMV : quatre attaches translucides qui chevauchent les bords gauche et droit de la jaquette
    if (fmvOn > 0.5) {
        float ww = winMax.x - winMin.x, wh = winMax.y - winMin.y;
        vec2  chs = vec2(0.030 * ww, 0.034 * wh);
        for (int k = 0; k < 4; k++) {
            float cx = (k == 0 || k == 2) ? winMin.x + 0.020 * ww : winMax.x - 0.020 * ww;
            float cy = (k < 2) ? winMin.y + 0.085 * wh : winMax.y - 0.115 * wh;
            float dC  = sdRoundRect(lp, vec2(cx, cy), chs, 0.45 * chs.x);
            float inC = 1.0 - smoothstep(-aa, aa, dC);
            float edC = 1.0 - smoothstep(0.0, 1.2 * aa, abs(dC));
            art = mix(art, vec3(1.0), 0.10 * inC);
            art = mix(art, vec3(0.60), 0.20 * edC);
        }
    }

    // DVD PC (type 14) : bande de reflet blanche sur le bord de l'image côté charnière
    if (gType == 14) {
        float cwd = caseMax.x - caseMin.x;
        float dx  = lp.x - winMin.x;
        float gl  = smoothstep(0.0, 0.004 * cwd, dx) * (1.0 - smoothstep(0.008 * cwd, 0.025 * cwd, dx));
        art = mix(art, vec3(0.95), 0.92 * gl);
    }
    // Blanc chromé (types 20 / 21) : bande blanche puis voile gris côté charnière
    if (gType == 20 || gType == 21) {
        float cwd = max(caseMax.x - caseMin.x, 1.0);
        float dx  = (lp.x - winMin.x) / cwd;
        float aS  = 0.90 * smoothstep(0.0014, 0.0049, dx) * (1.0 - smoothstep(0.0070, 0.0267, dx));
        vec3  cS  = vec3(mix(0.94, 0.26, smoothstep(0.0084, 0.0225, dx)));
        art = mix(art, cS, aS);
    }
    // DVD PC (14) / blanc chromé (20) : voile blanc depuis le coin haut côté charnière, assombrissement du coin opposé
    if (gType == 14 || gType == 20) {
        float cw2 = max(caseMax.x - caseMin.x, 1.0);
        float u   = clamp((lp.x - caseMin.x) / cw2, 0.0, 1.0);
        float vv  = clamp((lp.y - caseMin.y) / cw2, 0.0, 2.0);
        float vy  = clamp((lp.y - caseMin.y) / max(caseMax.y - caseMin.y, 1.0), 0.0, 1.0);
        float wA  = 0.70 * exp(-(u / 0.45 + vv / 0.28));
        float dA  = 0.25 * smoothstep(0.45, 1.0, vy) * (0.3 + 0.7 * u);
        if (gType == 20) {
            float e = u / 0.619 + vv / 0.453;
            wA = 0.474 * exp(-e * e);
            dA = 0.238 * smoothstep(0.50, 1.0, vy) * (0.11 + 0.89 * u);
        }
        art = mix(art, vec3(1.0), wA);
        art = mix(art, vec3(0.0), dA);
    }

    // Picots en relief du couvercle (Mega-CD) : deux colonnes décalées côté charnière
    if (dotsOn > 0.5) {
        float cw   = caseMax.x - caseMin.x;
        float ch   = caseMax.y - caseMin.y;
        float per  = 0.048 * ch;
        float rad  = max(0.0085 * ch, 1.0);
        float yOk  = smoothstep(winMin.y + 0.4 * per, winMin.y + 0.6 * per, lp.y)
                   * (1.0 - smoothstep(winMax.y - 0.6 * per, winMax.y - 0.4 * per, lp.y));
        float dots = 0.0, dl = 0.0;
        for (int i = 0; i < 2; i++) {
            float cx  = caseMin.x + ((i == 0) ? 0.045 : 0.11) * cw;
            float yy  = lp.y - winMin.y - ((i == 0) ? 0.0 : 0.5 * per);
            vec2  q   = vec2(lp.x - cx, yy - per * (floor(yy / per) + 0.5));
            float d   = length(q);
            float m   = 1.0 - smoothstep(rad - aa, rad + aa, d);
            dots = max(dots, m);
            dl   = max(dl, m * clamp(dot(-q / max(d, 0.001), L) * 0.5 + 0.5, 0.0, 1.0));
        }
        art = mix(art, vec3(0.24) + vec3(0.12) * dl, 0.55 * dots * yOk);
    }

    float wWin = 1.0 - smoothstep(-aa, aa, dWin);
    return mix(vec4(fcol, frameA), vec4(art, sampledColor.a), wWin);
}

// ─────────────────────────────────────────────────────────────
//  Patte d'accroche Sega (plaque plate, repère « face », y vers le bas)
// ─────────────────────────────────────────────────────────────
vec4 tabShade(vec2 lp) {
    float W      = gSize.x;
    float tabW   = 0.38 * (caseMax.x - caseMin.x);
    float tabR   = 0.14 * tabH;
    vec2  tabC   = vec2(0.5 * W, 0.5 * (topY + caseMin.y + 3.0 * rim));
    vec2  tabHf  = vec2(0.5 * tabW, 0.5 * (caseMin.y + 3.0 * rim - topY));
    vec2  holeHf = vec2(0.30 * tabW, 0.11 * tabH);
    vec2  holeC  = vec2(0.5 * W, topY + 0.60 * tabH);
    float bumpR  = 0.12 * tabW;
    float dOut   = sdRoundRect(lp, tabC, tabHf, tabR);
    float dTab   = max(dOut, -sdTabHole(lp, holeC, holeHf, bumpR));
    float wTab   = clamp(0.5 - dTab / max(fwidth(dTab), 1e-3), 0.0, 1.0);

    vec2  L    = lightDir();
    vec3  tcol = plastic * 0.85 + vec3(0.02);
    float edge = 1.0 - smoothstep(0.0, max(0.06 * tabH, 1.0), -dTab);   // pourtour (extérieur + fente)
    vec2  nT   = rrNormal(lp, tabC, tabHf, tabR);
    // tranche extérieure éclairée en haut / à gauche, paroi de la fente éclairée en bas
    float litOut  = max(dot(nT, L), 0.0);
    float litHole = smoothstep(holeC.y - holeHf.y, holeC.y + holeHf.y, lp.y);
    bool  nearOuter = dOut > dTab - 0.5;
    tcol += vec3(0.30 * glossK) * edge * (nearOuter ? litOut : litHole);
    tcol += vec3(0.03 * glossK) * (1.0 - (lp.y - topY) / max(tabH, 1.0));
    tcol += (hash21(floor(lp)) - 0.5) * grainK;
    // Ombre du boîtier sur le bas de la patte
    tcol *= 1.0 - 0.5 * (1.0 - smoothstep(0.0, 0.25 * tabH, caseMin.y - lp.y));
    return vec4(max(tcol, 0.0), wTab);
}

// ─────────────────────────────────────────────────────────────
//  Lancer de rayon sur la boîte (extrusion d'un rectangle arrondi sur l'épaisseur)
//  Repère de l'élément : X vers la droite, Y vers le bas, Z vers l'observateur sur la face avant.
//  Écran : sx = X c + Z s ; sy = Y + Pd (-X s + Z c). Rayon : P0 + l v, l = profondeur vers l'observateur.
// ─────────────────────────────────────────────────────────────

// Intervalle [a, b] du paramètre de la droite O + l D à l'intérieur du rectangle arrondi (vide si a > b)
vec2 rrInterval(vec2 O, vec2 D, vec2 bMin, vec2 bMax, vec4 rad) {
    float a = -1e9, b = 1e9;
    if (abs(D.x) < 1e-7) {
        if (O.x < bMin.x || O.x > bMax.x) return vec2(1.0, -1.0);
    } else {
        float t1 = (bMin.x - O.x) / D.x, t2 = (bMax.x - O.x) / D.x;
        a = max(a, min(t1, t2)); b = min(b, max(t1, t2));
    }
    if (abs(D.y) < 1e-7) {
        if (O.y < bMin.y || O.y > bMax.y) return vec2(1.0, -1.0);
    } else {
        float t1 = (bMin.y - O.y) / D.y, t2 = (bMax.y - O.y) / D.y;
        a = max(a, min(t1, t2)); b = min(b, max(t1, t2));
    }
    if (a > b) return vec2(1.0, -1.0);

    // entrée puis sortie : dans le carré d'un coin, hors de son disque, la vraie limite est le cercle du coin
    // (forme convexe : si la droite manque ce disque, elle manque la forme)
    vec2  cc = 0.5 * (bMin + bMax);
    float A  = dot(D, D);
    for (int k = 0; k < 2; k++) {
        float tk = (k == 0) ? a : b;
        vec2  p  = (abs(tk) < 1e8) ? O + tk * D : O;
        float r  = cornerR(p, cc, rad);
        if (r <= 0.0) continue;
        vec2  ck = vec2((p.x < cc.x) ? bMin.x + r : bMax.x - r, (p.y < cc.y) ? bMin.y + r : bMax.y - r);
        vec2  dp = p - ck;
        bool  inSq = ((p.x < cc.x) ? dp.x < 0.0 : dp.x > 0.0) && ((p.y < cc.y) ? dp.y < 0.0 : dp.y > 0.0);
        if (!inSq || dot(dp, dp) <= r * r) continue;
        if (A < 1e-12) return vec2(1.0, -1.0);
        vec2  oc = O - ck;
        float B  = dot(D, oc);
        float disc = B * B - A * (dot(oc, oc) - r * r);
        if (disc < 0.0) return vec2(1.0, -1.0);
        float sq = sqrt(disc);
        if (k == 0) a = (-B - sq) / A;
        else        b = (-B + sq) / A;
    }
    return vec2(a, b);
}

// Distance signée au contour de la boîte vu de face (repère centré)
float sdPlan(vec2 p) {
    vec2 cc = 0.5 * (gBMin + gBMax);
    return sdRoundRect(p, cc, 0.5 * (gBMax - gBMin), cornerR(p, cc, gRadE));
}

// Boîte entière : contour extrudé sur [-t, t], arêtes face / tranche arrondies de rayon gEdge
float sdBox3(vec3 p, float t) {
    vec2 w = vec2(sdPlan(p.xy) + gEdge, abs(p.z) - t + gEdge);
    return min(max(w.x, w.y), 0.0) + length(max(w, 0.0)) - gEdge;
}

vec3 boxNormal3(vec3 p, float t) {
    vec2  n2 = rrNormal4(p.xy, gBMin, gBMax, gRadE);
    vec2  w  = vec2(sdPlan(p.xy) + gEdge, abs(p.z) - t + gEdge);
    float sz = (p.z < 0.0) ? -1.0 : 1.0;
    if (w.x > 0.0 && w.y > 0.0) return normalize(vec3(n2 * w.x, sz * w.y));
    return (w.x > w.y) ? vec3(n2, 0.0) : vec3(0.0, 0.0, sz);
}

// 0 = rien, 1 = face plane (Z = +t), 2 = tranche / couvercle / arête arrondie (hitXY, hitN = point touché, normale)
float castBox(vec2 q, float c, float s, float Pd, float t, out vec2 hitXY, out vec3 hitN, out float hitZ) {
    hitXY = vec2(0.0);
    hitN  = vec3(0.0, 0.0, 1.0);
    hitZ  = 0.0;
    vec2  O  = vec2(q.x * c, q.y);
    float Z0 = q.x * s;
    vec2  D  = vec2(-s, -Pd);
    float zl = -1e9, zh = 1e9;
    if (c > 1e-6) {
        zl = (-t - Z0) / c;
        zh = ( t - Z0) / c;
    } else if (abs(Z0) > t) {
        return 0.0;
    }
    vec2  ri = rrInterval(O, D, gBMin, gBMax, gRadE);
    float lo = max(zl, ri.x), hi = min(zh, ri.y);
    if (lo >= hi) return 0.0;
    if (gEdge <= 0.0) {
        if (zh <= ri.y) return 1.0;
        hitXY = O + ri.y * D;
        hitZ  = Z0 + ri.y * c;
        hitN  = vec3(rrNormal4(hitXY, gBMin, gBMax, gRadE), 0.0);
        return 2.0;
    }
    // arêtes arrondies : la boîte arrondie est contenue dans la boîte à arêtes vives ; on avance depuis le point
    // d'entrée de celle-ci vers l'arrière jusqu'à la surface (l = profondeur vers l'observateur)
    vec3  P0 = vec3(O, Z0), V = vec3(D, c);
    float iv = 1.0 / length(V);
    float l  = hi, d = 1e9;
    for (int i = 0; i < EDGE_STEPS; i++) {
        d = sdBox3(P0 + l * V, t);
        if (d < 0.02 || l < lo) break;
        l -= d * iv;
    }
    if (d > 0.3 || l < lo) return 0.0;
    vec3 P = P0 + l * V;
    hitN = boxNormal3(P, t);
    if (hitN.z > 0.9999) return 1.0;
    hitXY = P.xy;
    hitZ  = P.z;
    return 2.0;
}

// Carton (8 / 9) : usure de la tranche dans le prolongement de celle de la face et du dos (mêmes bruits, mêmes
// graines par bord, mêmes largeurs). lpE : point de la tranche dans le repère de la jaquette de face ;
// zF : profondeur (+t = arête de la face, -t = arête du dos) ; nxT, ny : normale (nxT dans le repère de la jaquette)
vec3 cartonSide(vec3 c, vec2 lpE, float zF, float t, bool vert, float nxT, float ny) {
    float wa      = (gType == 9) ? 1.0 : 0.0;
    float minSide = gMinSide;
    float u       = 0.0035 * minSide;
    vec3  paper   = vec3(0.93, 0.92, 0.88);
    if (wa > 0.0) {
        vec3 faded = mix(vec3(dot(c, vec3(0.30, 0.59, 0.11))), c, 0.85) * 0.86 + vec3(0.075, 0.075, 0.08);
        c = mix(c, faded, wa);
        paper = vec3(0.80, 0.80, 0.78);
    }
    float len    = vert ? gSize.y : gSize.x;
    float bottom = vert ? 0.0 : smoothstep(0.0, 0.9, ny);
    for (int k = 0; k < 2; k++) {
        bool  fr    = (k == 0);                  // arête côté face, puis côté dos (repère du dos : x inversé)
        float side  = vert ? (fr ? sign(nxT) : -sign(nxT)) : 2.0 + sign(ny);
        float along = vert ? lpE.y : (fr ? lpE.x : gSize.x - lpE.x);
        float e     = fr ? t - zF : t + zF;
        float nz    = vnoise1(along / (0.02 * minSide), side) * 0.7 + vnoise1(along / (0.006 * minSide), side + 7.0) * 0.3;
        float dEnd  = min(along, len - along);
        float dc    = length(vec2(dEnd, e));
        float corner = 1.0 - smoothstep(0.0, 0.05 * minSide, dc);
        float ww    = u * (0.5 + 2.6 * smoothstep(0.55, 0.95, nz) + 3.6 * corner + 1.0 * bottom) * (1.0 + 1.8 * wa);
        float wear  = (1.0 - smoothstep(0.0, max(ww, 1.0), e)) * (mix(0.35, 0.6, wa) + 0.65 * smoothstep(0.4, 0.8, nz));
        c = mix(c, paper, clamp(wear * mix(0.85, 1.0, wa), 0.0, 1.0));
        if (wa > 0.0) {
            float nzc   = vnoise1(along / (0.03 * minSide), side + 3.0);
            float crush = 1.0 - smoothstep(0.0, max(0.020 * minSide * (0.5 + nzc), 1.0), dc);
            c = mix(c, paper, 0.7 * crush * wa);
        }
    }
    // frottements irréguliers le long de la tranche ; très usée : voile marbré et petits points blancs
    vec2  sp  = vec2(vert ? lpE.y : lpE.x, zF);
    float rub = smoothstep(0.55, 0.9, vnoise2(sp / vec2(0.06 * minSide, max(0.5 * t, 1.0)) + (vert ? 3.0 : 9.0)));
    c = mix(c, paper, (0.10 + 0.20 * wa) * rub);
    if (wa > 0.0) {
        float mot = vnoise2(sp / (0.10 * minSide) + 5.0) * 0.65 + vnoise2(sp / (0.035 * minSide) + 3.0) * 0.35;
        c += vec3(0.07) * smoothstep(0.45, 0.85, mot);
        float spk = hash21(floor(sp / max(0.0045 * minSide, 1.5)) + 17.0);
        c = mix(c, paper, 0.35 * step(0.99, spk));
    }
    c += (hash21(floor(sp)) - 0.5) * 0.012;      // grain du carton
    return max(c, 0.0);
}

// Boîtiers sans système d'ouverture sur la tranche : jaquette enroulée sur les deux tranches
bool sansOuverture() { return (gType == 2 || gType == 3 || gType == 4 || gType == 12 || gType == 16 || gType == 18 || gType == 19 || gType == 20 || gType == 21); }
// Jaquette qui fait le tour du dos (couleur du bord de la jaquette sur la tranche charnière)
bool jaquetteEnroulee() { return gType == 0 || gType == 1 || gType == 13 || gType == 14 || sansOuverture(); }

// Tranche, couvercles et arêtes arrondies : plastique du boîtier éclairé selon la normale
//  texFlip : repère du dos alors que la texture est la jaquette de face (gauche / droite inversées)
//  n3 : normale 3D dans le repère de la boîte (arêtes arrondies comprises)
//  aS : opacité de la paroi (< 1 sur le plastique transparent)
//  pz, t : profondeur du point touché et demi-épaisseur (usure du carton)
vec3 sideShade(vec2 p, vec3 n3, float pz, float t, float c, float s, bool mirror, bool texFlip, out float aS) {
    vec2  n   = rrNormal4(p, gBMin, gBMax, gRadE);
    float wV  = n.x * n.x;                       // 1 = tranche verticale, 0 = couvercle
    vec2  lpE = p + 0.5 * gSize;
    if (texFlip) lpE.x = gSize.x - lpE.x;
    vec3  base;
    float specK = glossK;
    aS = 1.0;
    if (gType == 7) {
        // sans couleur imposée : couleur du bord de l'image de ce côté, en dégradé vertical doux (moyennes prises
        // à des hauteurs fixes puis interpolées, comme les DVD) ; couvercles : moyenne du bord haut / bas
        vec3 sc = u_spine_color.rgb, cc = u_cap_color.rgb;
        if (u_spine_color.a <= 0.0) {
            bool  leftE = (n.x < 0.0) != texFlip;
            float uS  = leftE ? 0.015 : 0.985;
            float uS2 = leftE ? 0.045 : 0.955;
            float vS  = clamp(lpE.y / gSize.y, 0.0, 1.0);
            if (gSign < 0.0) vS = 1.0 - vS;
            float vN  = clamp(vS, 1.0 / 12.0, 11.0 / 12.0);
            vec4  art = vec4(0.0);
            float wSum = 0.0;
            for (int i = 0; i < 6; i++) {
                float vi = (float(i) + 0.5) / 6.0;
                float wi = smoothstep(0.0, 1.0, max(1.0 - abs(vN - vi) * 6.0, 0.0));
                vec4  ci = vec4(0.0);
                for (int k = 0; k < 4; k++) {
                    float vk = vi + (float(k) - 1.5) * 0.04;
                    vec4 a1 = sampleTexture(u_tex, vec2(uS, vk)), a2 = sampleTexture(u_tex, vec2(uS2, vk));
                    ci += vec4(a1.rgb * a1.a + a2.rgb * a2.a, a1.a + a2.a);
                }
                art  += wi * ci;
                wSum += wi;
            }
            vec3 eS = art.rgb / max(art.a, 1e-4) * 0.95 + vec3(0.02);
            sc = mix(vec3(0.95), eS, smoothstep(0.1, 0.5, art.a / max(8.0 * wSum, 1e-4)));
        }
        if (u_cap_color.a <= 0.0) {
            float vC = (n.y < 0.0) ? 0.015 : 0.985;
            if (gSign < 0.0) vC = 1.0 - vC;
            vec4 cap = vec4(0.0);
            for (int k = 0; k < 8; k++) {
                vec4 a1 = sampleTexture(u_tex, vec2((float(k) + 0.5) / 8.0, vC));
                cap += vec4(a1.rgb * a1.a, a1.a);
            }
            vec3 eC = cap.rgb / max(cap.a, 1e-4) * 0.95 + vec3(0.02);
            cc = mix(vec3(0.95), eC, smoothstep(0.1, 0.5, cap.a / 8.0));
        }
        base = mix(cc, sc, wV);
    } else if ((gType == 8 || gType == 9) && !gCut) {
        // carton : bord de l'image replié sur la tranche
        vec2 tV = vec2(((n.x < 0.0) != texFlip) ? 0.02 : 0.98, clamp(lpE.y / gSize.y, 0.02, 0.98));
        vec2 tH = vec2(clamp(lpE.x / gSize.x, 0.02, 0.98), (n.y < 0.0) ? 0.02 : 0.98);
        if (gSign < 0.0) { tV.y = 1.0 - tV.y; tH.y = 1.0 - tH.y; }
        base  = mix(sampleTexture(u_tex, tH).rgb, sampleTexture(u_tex, tV).rgb, wV) * 0.92;
        base  = cartonSide(base, lpE, texFlip ? -pz : pz, t, wV > 0.5, texFlip ? -n.x : n.x, n.y);
        specK = (gType == 9) ? 0.15 : 0.4;
    } else if (gType == 20 || gType == 21) {
        base = vec3(0.86);
    } else if (gType == 14) {
        base = vec3(0.16);
    } else if (clearOn > 0.5) {
        // tranches opaques : vue de profil en fin de rotation, une paroi translucide laisse voir le décor
        base = mix(INTERIOR_COLOR, clearTint, milkA);
        // côté charnière d'un boîtier CD : le dos opaque se voit à travers
        float hingeSide = (u_tranches > 0.5) ? abs(n.x) : (mirror ? n.x : -n.x);
        if (spineOpaque > 0.5) base = mix(base, plastic, smoothstep(0.5, 0.9, hingeSide));
    } else {
        base = mix(INTERIOR_COLOR, plastic, frameA0);
    }

    // DVD, slim, PS3, DVD PC (et boîtiers sans ouverture, sur les deux tranches) : la jaquette fait le tour du dos sous
    // la pochette transparente. Sur la tranche charnière,
    // le dos (dessous) pose la couleur du bord de sa jaquette, la face pose la sienne par-dessus en fondu vers l'arrière
    bool backTex = (mirror != texFlip);
    if (backTex) aS = 0.0;
    if (jaquetteEnroulee() && !gCut) {
        bool  deux = u_tranches > 0.5 || sansOuverture();
        float hingeSide = deux ? abs(n.x) : (mirror ? n.x : -n.x);
        float zF   = texFlip ? -pz : pz;
        float yIn  = smoothstep(winMin.y - 1.0, winMin.y + 1.0, lpE.y) * (1.0 - smoothstep(winMax.y - 1.0, winMax.y + 1.0, lpE.y));
        float wArt = smoothstep(0.5, 0.9, hingeSide) * yIn;
        float vS   = clamp((lpE.y - winMin.y) / max(winMax.y - winMin.y, 1.0), 0.0, 1.0);
        if (gSign < 0.0) vS = 1.0 - vS;
        // couleur du bord de la jaquette en dégradé vertical doux : moyennes prises à des hauteurs fixes
        // (indépendantes du pixel, sinon un détail net du bord se répète en stries), interpolées entre elles
        float uS   = backTex ? 0.985 : 0.015;
        float uS2  = backTex ? 0.955 : 0.045;
        // u_tranches 1, tranche d ouverture : bord de l image du côté de l ouverture
        if (deux && (mirror ? -n.x : n.x) > 0.0) { uS = 1.0 - uS; uS2 = 1.0 - uS2; }
        float vN   = clamp(vS, 1.0 / 12.0, 11.0 / 12.0);
        vec3  art  = vec3(0.0);
        float wSum = 0.0;
        for (int i = 0; i < 6; i++) {
            float vi = (float(i) + 0.5) / 6.0;
            float wi = smoothstep(0.0, 1.0, max(1.0 - abs(vN - vi) * 6.0, 0.0));
            vec3  ci = vec3(0.0);
            for (int k = 0; k < 4; k++) {
                float vk = vi + (float(k) - 1.5) * 0.04;
                ci += sampleTexture(u_tex, vec2(uS, vk)).rgb + sampleTexture(u_tex, vec2(uS2, vk)).rgb;
            }
            art  += wi * ci * 0.125;
            wSum += wi;
        }
        base = mix(base, art / max(wSum, 1e-4) * 0.95 + vec3(0.02), wArt);
        aS   = backTex ? wArt : 1.0 - wArt * (1.0 - smoothstep(-0.95 * t, -0.6 * t, zF));
    }

    // boîtiers plastique à clip : jonction des deux coques au milieu de l'épaisseur (tranche d'ouverture, couvercles
    // haut / bas et coins, jusqu'à la charnière) + encoche allongée du clip un peu sous le milieu de la tranche d'ouverture
    if ((gType == 0 || gType == 1 || gType == 10 || gType == 11 || gType == 13 || gType == 14) && !gCut) {
        float openSide = mirror ? -n.x : n.x;
        if (u_tranches > 0.5) openSide = -abs(openSide);
        float yA    = lpE.y - caseMin.y;
        float H     = max(caseMax.y - caseMin.y, 1.0);
        float wOpen = smoothstep(0.5, 0.9, openSide) * smoothstep(gEdge, gEdge + 3.0, min(yA, H - yA));
        float wSeam = 1.0 - smoothstep(0.3, 0.8, -openSide);
        float aa    = 1.0 / max(abs(s), 0.2);
        // jonction des coques : fine rainure sombre, arête éclairée juste à côté
        float sw     = max(0.04 * t, 0.6);
        float groove = (1.0 - smoothstep(0.3 * sw, sw + aa, abs(pz))) * wSeam;
        float seamHl = (1.0 - smoothstep(0.0, aa + 0.5 * sw, abs(pz + 1.6 * sw + aa))) * wSeam;
        // encoche du clip : capsule verticale creusée, languette d'accroche en bas
        float hw   = 0.30 * t;
        float hh   = 0.18 * H;
        float yc   = 0.52 * H;
        float d    = length(vec2(pz, max(abs(yA - yc) - (hh - hw), 0.0))) - hw;
        float slot = (1.0 - smoothstep(-aa, aa, d)) * wOpen;
        float yS   = clamp((yA - (yc - hh)) / (2.0 * hh), 0.0, 1.0);
        float ring = (1.0 - smoothstep(0.0, 1.5 * aa, abs(d - aa))) * wOpen;
        float tabY = yc + 0.62 * hh;
        float tabM = slot * (1.0 - smoothstep(0.035 * H, 0.035 * H + aa, abs(yA - tabY)))
                          * (1.0 - smoothstep(0.55 * hw, 0.55 * hw + aa, abs(pz)));
        vec3  cl   = base * (1.0 - 0.6 * groove * (1.0 - slot)) + vec3(0.10) * seamHl * (1.0 - slot);
        cl = mix(cl, base * (0.30 + 0.35 * yS), slot);
        cl += vec3(0.16) * ring * (yA > yc ? 1.0 : 0.25);
        cl = mix(cl, base * 1.05 + vec3(0.06), tabM);
        base = cl;
    }

    // CD (jewel case), tranche d'ouverture seulement : couvercle transparent à l'avant, fond à l'arrière laissant voir
    // le plateau noir, jonction entre les deux
    if (gType == 5 || gType == 6 || gType == 15 || gType == 17) {
        float openSide = mirror ? -n.x : n.x;
        if (u_tranches > 0.5) openSide = -abs(openSide);
        float yA    = lpE.y - caseMin.y;
        float H     = max(caseMax.y - caseMin.y, 1.0);
        float wOpen = smoothstep(0.5, 0.9, openSide) * smoothstep(gEdge, gEdge + 3.0, min(yA, H - yA));
        float zF    = texFlip ? -pz : pz;
        float aa    = 1.0 / max(abs(s), 0.2);
        // couvercle ~ 1/5 de l'épaisseur, fond transparent fin à l'arrière, plateau noir entre les deux
        float zL    = 0.56 * t;
        float zB    = -0.90 * t;
        float lid   = smoothstep(zL - 0.5 * aa, zL + 0.5 * aa, zF);
        float floorM = 1.0 - smoothstep(zB - 0.5 * aa, zB + 0.5 * aa, zF);
        vec3  glassT  = clearTint * vec3(0.92, 0.98, 1.0);
        vec3  clearC  = mix(INTERIOR_COLOR, glassT, 0.62);
        vec3  trayC   = mix(vec3(0.035), clearTint, 0.10);
        // tranche du couvercle en cristal : plus claire vers ses bords (lumière canalisée), reflet net vers l'avant
        float zLid    = clamp((zF - zL) / max(t - zL, 1e-3), 0.0, 1.0);
        vec3  lidC    = clearC * (0.80 + 0.35 * (1.0 - 4.0 * zLid * (1.0 - zLid)));
        lidC += glassT * 0.22 * (1.0 - smoothstep(0.0, 0.10 + aa / max(t - zL, 1.0), abs(zLid - 0.72)));
        lidC *= 1.0 - 0.18 * (1.0 - smoothstep(0.0, 0.08 + aa / max(t - zL, 1.0), abs(zLid - 0.55)));
        // plateau noir vu à travers la paroi du fond : léger reflet de la paroi, arête du plateau
        float zTr     = clamp((zF - zB) / max(zL - zB, 1e-3), 0.0, 1.0);
        trayC += glassT * 0.05 * smoothstep(0.2, 0.9, zTr);
        float trayLip = 1.0 - smoothstep(0.0, aa + 0.6, abs(zF - (zL - 0.10 * t)));
        vec3  col  = mix(trayC + vec3(0.09) * trayLip, lidC, lid);
        col = mix(col, clearC * 0.95, floorM);
        float seam = 1.0 - smoothstep(0.3, aa + 0.8, abs(zF - zL));
        col  = col * (1.0 - 0.55 * seam);
        col += vec3(0.10) * (1.0 - smoothstep(0.0, aa + 0.6, abs(zF - zL - 1.2 - aa)));
        col += vec3(0.06) * (1.0 - smoothstep(0.0, aa + 0.6, abs(zF - zB - 1.0 - aa)));
        base = mix(base, col, wOpen);
    }

    vec3  Nv   = normalize(vec3(n3.x * c + n3.z * s, n3.y, -n3.x * s + n3.z * c));
    vec3  Lv   = normalize(vec3(-0.45, -0.55, 0.70));
#if FLIP_LIGHT_Y
    Lv.y = -Lv.y;
#endif
    float diff = max(dot(Nv, Lv), 0.0);
    float spec = pow(max(dot(Nv, normalize(Lv + vec3(0.0, 0.0, 1.0))), 0.0), 24.0) * 0.25 * specK;
    return base * (0.32 + 0.68 * diff) + vec3(spec);
}

// Reflet plastique de la face (boite3d_retourne)
float getSpecular(float angle, vec2 uv) {
    float lightPos = 0.5;
    float refAngle = angle + lightPos;
    float spec = pow(max(0.0, cos(refAngle)), 10.0);
    float sheen = smoothstep(0.4, 0.6, sin(angle + uv.x * 3.0 + uv.y * 2.0));
    return (spec + sheen * 0.2) * u_shiny;
}

void mainCase(void)
{

    // Sens de l'axe vertical de la texture (comparaison des gradients écran, insensible à une rotation)
    float gTex = dot(vec2(dFdx(v_tex.y), dFdy(v_tex.y)), vec2(dFdx(v_pos.y), dFdy(v_pos.y)));
    gSign = (gTex < 0.0) ? -1.0 : 1.0;

    float mg    = max(marge, 1.0);
    vec2 sizeE = max(abs(outputSize), vec2(1.0)) / mg; // taille de l élément (sans la marge)
    vec2 size  = sizeE;                                  // repère de la boîte (hauteur selon l image si formatImage)
    setupCase(size);
    if (formatImage > 0.5 && (u_mode < 2.5 || u_mode > 4.5) && textureSize.x > 0.0 && textureSize.y > 0.0) {
        vec2  w0 = max(winMax - winMin, vec2(1.0));
        size.y *= clamp((w0.x / w0.y) / (textureSize.x / textureSize.y), 0.5, 1.0 / BOX_SCALE);
        setupCase(size);
    }

    // retournement : face jusqu'à 35 % du cycle, demi-tour jusqu'à 50 %, dos jusqu'à 85 %, demi-tour jusqu'à 100 %
    // place de la boîte à l écran : k = -1 à gauche, 0 au centre, 1 à droite
    float spr = spread != 0.0 ? spread : 0.22;
    float cX  = (centreX != 0.0 ? centreX : 0.5) * 2.0 - 1.0;
    float k   = clamp((v_cx - cX) / spr, -1.0, 1.0);
    k = sign(k) * smoothstep(0.0, 1.0, abs(k));
    float sg  = sens != 0.0 ? sens : 1.0;
    float angDeg = u_angle * k * sg;
    if (u_phase > 0.0) {
        float p = fract(u_phase);
        angDeg += 180.0 * (smoothstep(0.35, 0.5, p) + smoothstep(0.85, 1.0, p));
    }
    // à plat au repos (face ou dos de pleine face) : la plongée n'apparaît que pendant la rotation
    float P = u_pitch * abs(sin(radians(angDeg)));
    float radAngle = radians(angDeg);

    bool isBack = (u_mode > 0.5 && u_mode < 1.5);
    bool isWin  = (u_mode > 3.5);
    bool isLogo = (u_mode > 2.5 && !isWin);
    if (u_mode > 1.5 && u_mode < 2.5) discard;

    // Le dos est dessiné comme une face avant dans un repère tourné d'un demi-tour
    float c = cos(radAngle), s = sin(radAngle);
    // Les tranches sont dessinées par la face (mode 0) pendant tout le tour, pour garder la couleur de la jaquette de face :
    // quand le dos est visible, la face ne dessine plus que les tranches, dans le repère du dos
    bool sidesOnly = (!isBack && !isLogo && c < 0.0);
    // dos caché : le dos ne dessine plus que la tranche charnière (sous celle de la face), dans le repère de la face
    bool backSides = (isBack && c >= 0.0);
    bool flipFrame = (isBack && !backSides) || sidesOnly;
    if (flipFrame) { c = -c; s = -s; radAngle += 3.14159265; }

    // Repère de l'élément en pixels « face » (la boîte occupe BOX_SCALE de l'élément), y vers le bas
    vec2  q   = vec2(v_tex.x - 0.5, gSign * (v_tex.y - 0.5)) * sizeE * mg / BOX_SCALE;
    // tailles à l écran (pixels) : boîte de face (bwp), écart entre deux cases (S), boîte tournée face + épaisseur (Wpx)
    float bwq  = caseMax.x - caseMin.x;
    float thq  = u_thickness * gThickK * size.x;
    float Wpx  = (abs(cos(radians(angDeg))) * bwq + abs(sin(radians(angDeg))) * thq) * BOX_SCALE;
    float bwp  = bwq * BOX_SCALE;
    float Scf  = v_pas * size.x;
    float gap  = jeu == 0.0 ? 3.0 : max(jeu, 0.0);
    // boîtes de côté réduites pour tenir dans une case (elles se frôlent sans se chevaucher)
    float red  = mix(1.0, min(1.0, (Scf - gap) / max(Wpx, 1.0)), abs(k));
    // décalage vers l extérieur : au moins ecart, et assez pour rester hors de la sélection agrandie (même format supposé)
    float zs   = zoomSelection != 0.0 ? zoomSelection : 1.35;
    float ec   = ecart == 0.0 ? 0.25 : max(ecart, 0.0);
    float dMin = abs(k) * max(0.5 * bwp * zs + gap - Scf + 0.5 * Wpx * red, 0.0);
    float decp = min(max(ec * abs(k) * bwp, dMin), max(0.5 * size.x - 0.5 * Wpx * red - 2.0, 0.0));
    q.x = (q.x - sign(k) * decp / BOX_SCALE) / red;
    q.y /= red;
    // reflet au sol : point symétrique par rapport au bas de la boîte (même profondeur), effacé vers le bas
    if (reflet > 0.0) {
        float ybR = caseMax.y - 0.5 * size.y;
        float dr  = max(q.y - ybR, 0.0);
        gRefA = reflet * pow(clamp(1.0 - dr / (0.35 * (caseMax.y - caseMin.y)), 0.0, 1.0), 2.0);
        if (gRefA <= 0.0) discard;
        q.y = 2.0 * ybR - q.y;
    }
    vec2  dqx = dFdx(q), dqy = dFdy(q);
    float Pd  = P * sizeE.y / sizeE.x * gSign;
    if (reflet > 0.0) Pd = -Pd;
    float t   = 0.5 * u_thickness * gThickK * size.x;
    vec2  uvS = (v_tex - 0.5) / BOX_SCALE;

    gBMin = caseMin - 0.5 * size;
    gBMax = caseMax - 0.5 * size;
    gRadE = flipFrame ? gRad.yxwz : gRad;
    if (u_edge_round > 0.0)      gEdge = min(u_edge_round, 0.95) * t;
    else if (u_edge_round < 0.0) gEdge = 0.0;
    else                         gEdge = min(gEdgeK * t, gEdgeMax);

    // ── Halo autour de la sélection (u_mode 5) ──
    if (u_mode > 4.5) {
        float sel = 1.0 - smoothstep(0.05, 0.5, abs(k));
        if (sel <= 0.0) discard;
        vec2  bc = 0.5 * (gBMin + gBMax), bh = 0.5 * (gBMax - gBMin);
        float hH = gBMax.y - gBMin.y;
        float d  = sdRoundRect(q, bc, bh, 0.12 * min(bh.x, bh.y));
        // lueur diffuse : liseré lumineux près de la boîte + halo large et doux, nul avant le bord de l élément (marge)
        float dd = max(d, 0.0);
        float gl = 0.55 * exp(-dd / (0.025 * hH)) + 0.45 * exp(-dd / (0.09 * hH));
        gl *= 1.0 - smoothstep(0.18 * hH, 0.27 * hH, dd);
        // couleur : celle de haloColor, ou si elle est noire, la teinte moyenne de la jaquette (ravivée)
        vec3  amb = vec3(0.0);
        for (int i = 0; i < 3; i++)
            for (int j = 0; j < 3; j++)
                amb += sampleTexture(u_tex, vec2(0.2 + 0.3 * float(i), 0.2 + 0.3 * float(j))).rgb;
        amb /= 9.0;
        amb = clamp(mix(vec3(dot(amb, vec3(0.30, 0.59, 0.11))), amb, 1.6) * 1.35 + 0.08, 0.0, 1.0);
        vec4  hc = haloColor.a > 0.0 ? haloColor : vec4(0.0, 0.0, 0.0, 0.5);
        vec3  col = dot(hc.rgb, vec3(1.0)) > 0.01 ? hc.rgb : amb;
        float a  = hc.a * sel * gl;
        if (a <= 0.003) discard;
        FragColor = vec4(col, a) * v_col;
        return;
    }

    // ── Image seule dans la fenêtre de la face (u_mode 4) ──
    if (isWin) {
        if (c <= 1e-4 || sidesOnly) discard;
        vec2 Dw  = vec2(-s, -Pd);
        vec2 lpW = vec2(q.x * c, q.y) + ((t - q.x * s) / c) * Dw + 0.5 * size;
        vec2 wSz = max(winMax - winMin, vec2(1.0));
        vec2 uw  = (lpW - winMin) / wSz;
        if (uw.x < 0.0 || uw.x > 1.0 || uw.y < 0.0 || uw.y > 1.0) discard;
        vec4 col = sampleWindow(vec2(uw.x, (gSign > 0.0) ? uw.y : 1.0 - uw.y), wSz);
        if (col.a <= 0.0) discard;
        FragColor = vec4(col.rgb * (0.5 + 0.5 * abs(c)), col.a) * v_col;
        return;
    }

    // ── Logo sur la tranche visible (u_mode 3.x) ──
    if (isLogo) {
        // logo sur la tranche charnière (à gauche en vue de face) ; u_tranches 1 : aussi sur la tranche d ouverture
        bool  leftSide = s > 0.0;
        if (abs(s) < 1e-3 || (!leftSide && u_tranches < 0.5)) discard;
        float Xs = leftSide ? gBMin.x : gBMax.x;
        float Zs = (q.x - Xs * c) / s;
        float Ys = q.y - (-Xs * s + Zs * c) * Pd;
        float aZ = max(fwidth(Zs), 1e-4), aY = max(fwidth(Ys), 1e-4);
        // logo limité à la partie plane de la tranche (hors arêtes et coins arrondis)
        float alphaZ = clamp(0.5 - (abs(Zs) - (t - gEdge)) / aZ, 0.0, 1.0);
        float yA = gBMin.y + max(leftSide ? gRad.x : gRad.y, gEdge);
        float yB = gBMax.y - max(leftSide ? gRad.w : gRad.z, gEdge);
        float alphaY = clamp(0.5 + (Ys - yA) / aY, 0.0, 1.0) * clamp(0.5 + (yB - Ys) / aY, 0.0, 1.0);

        float texX = Zs / max(2.0 * t, 1e-4) + 0.5;
        if (!leftSide) texX = 1.0 - texX;
        float yd   = (Ys - gBMin.y) / max(gBMax.y - gBMin.y, 1.0);
        float yPos = (gSign > 0.0) ? yd : 1.0 - yd;

        float startY, endY;
        bool rotate = false;
        if (u_mode < 3.15)      { startY = 0.80; endY = 0.98; rotate = false; }
        else if (u_mode < 3.25) { startY = 0.15; endY = 0.85; rotate = true;  }
        else                    { startY = 0.02; endY = 0.20; rotate = false; }
        float localY = (yPos - startY) / (endY - startY);
        float scale  = (u_logo_scale > 0.01) ? u_logo_scale : 1.0;
        float finalY = (localY - 0.5) / scale + 0.5;
        if (finalY < 0.0 || finalY > 1.0) discard;
        vec2 finalTexCoord = rotate ? vec2(finalY, 1.0 - texX) : vec2(texX, finalY);

        vec4  texColor = sampleTexture(u_tex, finalTexCoord);
        float light = 0.5 + 0.5 * abs(s);
        float spec  = 0.0;
        if (u_shiny > 0.01) spec = getSpecular(radAngle + 1.5708, uvS) * abs(sin(radians(angDeg)));
        float a = texColor.a * alphaZ * alphaY;
        if (a <= 0.0) discard;
        FragColor = vec4(texColor.rgb * light + vec3(spec), a) * v_col;
        return;
    }

    // ── Face (mode 0) ou dos (mode 1) : visibles chacun sur une moitié du tour, sans recouvrement ──
    if (backSides && !jaquetteEnroulee()) discard;

    // Point de la face (Z = +t) vu par ce pixel, en pixels « face »
    vec2 Dv  = vec2(-s, -Pd);
    vec2 lpF = vec2(1e5);
    if (c > 1e-4) lpF = vec2(q.x * c, q.y) + ((t - q.x * s) / c) * Dv + 0.5 * size;

    float wFace;
    vec4  face = caseShade(lpF, isBack, wFace);
    // partie plane de la face : la bande de largeur gEdge du pourtour appartient à l'arête arrondie
    float dFlat = sdPlan(lpF - 0.5 * size) + gEdge;
    float wFlat = clamp(0.5 - dFlat / max(fwidth(dFlat), 1e-3), 0.0, 1.0);
    if (gEdge > 0.0) wFace *= wFlat;
    if (sidesOnly || backSides) wFace = 0.0;
    // plastique transparent / jaquette non opaque : on voit l'intérieur du boîtier
    // (le décor transparaît en partie à travers le plastique transparent et un borderColor semi-transparent)
    if (gType != 7 && !gCut) {
        float kIn = (clearOn > 0.5 || frameA0 < 0.999) ? CLEAR_INTERIOR : 1.0;
        float aIn = face.a + (1.0 - face.a) * kIn;
        face.rgb  = (face.rgb * face.a + INTERIOR_COLOR * (1.0 - face.a) * kIn) / max(aIn, 1e-4);
        face.a    = aIn;
    }

    // Éclairage de la face (boite3d_retourne)
    float light = 0.5 + 0.5 * abs(c);
    float spec  = 0.0;
    if (u_shiny > 0.01) spec = getSpecular(radAngle, uvS) * abs(sin(radians(angDeg)));
    face.rgb = face.rgb * light + vec3(spec);

    // ── Tranches, couvercles et arêtes : sur-échantillonnage du lancer de rayon ──
    float nf = 0.0, ns = 0.0;
    vec2  sideXY = vec2(0.0), hxy;
    vec3  sideN = vec3(0.0, 0.0, 1.0), hn;
    float sideZ = 0.0, hz;
    bool  haveSide = false;
    // de face, à plat, l'arête arrondie reste visible tout autour de la face
    bool  sidesVisible = abs(s) > 1e-5 || abs(Pd) > 1e-5 || gEdge > 0.0;
    if (sidesVisible) {
        // point et normale de la tranche = moyenne des échantillons qui la touchent (arête arrondie de 1-2 px :
        // éclairée en un seul point, son reflet sauterait d'un pixel à l'autre en pointillé)
        vec2  sumXY = vec2(0.0); vec3 sumN = vec3(0.0); float sumZ = 0.0, nHit = 0.0;
        if (castBox(q, c, s, Pd, t, hxy, hn, hz) > 1.5) { haveSide = true; sumXY += hxy; sumN += hn; sumZ += hz; nHit += 1.0; }
        for (int i = 0; i < AA_SAMPLES; i++) {
            float fi = float(i);
            vec2  o  = vec2((fi + 0.5) / float(AA_SAMPLES) - 0.5,
                            (mod(fi * 3.0, float(AA_SAMPLES)) + 0.5) / float(AA_SAMPLES) - 0.5);
            float h  = castBox(q + dqx * o.x + dqy * o.y, c, s, Pd, t, hxy, hn, hz);
            if (h > 1.5) {
                ns += 1.0;
                haveSide = true; sumXY += hxy; sumN += hn; sumZ += hz; nHit += 1.0;
            } else if (h > 0.5) {
                nf += 1.0;
            }
        }
        if (nHit > 0.0) {
            sideXY = sumXY / nHit; sideZ = sumZ / nHit;
            sideN  = (dot(sumN, sumN) > 1e-8) ? normalize(sumN) : hn;
        }
    }
    float sideA;
    vec3  sideCol = sideShade(sideXY, sideN, sideZ, t, c, s, flipFrame, sidesOnly || backSides, sideA);
    float wSide   = ns / float(AA_SAMPLES);

    // Face par-dessus la paroi latérale (boîte convexe : la face visible est toujours devant)
    float aF  = face.a * wFace;
    float aS  = sideA * wSide;
    float A, edgeA = 0.0;
    vec3  rgb;
    // pixel à cheval sur l'arête face / tranche : couverture totale donnée par les échantillons (pas de fond qui transparaît)
    if (aF > 0.0 && wSide > 0.0)
        edgeA = (nf * face.a + ns * sideA) / float(AA_SAMPLES);
    {
        // le dos ne dessine que la tranche charnière des boîtiers à jaquette enroulée (aS = 0 ailleurs) :
        // la face pose les tranches par-dessus (zIndex du dos plus bas que celui de la face)
        A   = aF + aS;
        rgb = (face.rgb * aF + sideCol * aS) / max(A, 1e-4);
        // à cheval sur l'arête : couleurs pondérées par les échantillons (comme la couverture edgeA)
        float wE = nf * face.a + ns * sideA;
        if (edgeA > 0.0 && wE > 1e-4) rgb = (face.rgb * nf * face.a + sideCol * ns * sideA) / wE;
        A   = max(A, edgeA);
    }
    A = min(A, 1.0);

    // ── Patte d'accroche Sega : plaque à mi-épaisseur, derrière la boîte ──
    if (tabOn > 0.5 && c > 1e-3 && !sidesOnly && !backSides) {
        vec2 lpT = vec2(q.x * c, q.y) + (-q.x * s / c) * Dv + 0.5 * size;
        vec4 tb  = tabShade(lpT);
        tb.rgb  *= light;
        float outA = A + tb.a * (1.0 - A);
        rgb = (rgb * A + tb.rgb * tb.a * (1.0 - A)) / max(outA, 1e-4);
        A   = outA;
    }

    if (A <= 0.001) discard;
    FragColor = vec4(rgb, A) * v_col;
}

// fondu vers les bords, assombrissement loin du centre et opacité du reflet, appliqués à tout ce que dessine mainCase
void main(void)
{
    gRefA = 1.0;
    mainCase();
    float cXe = (centreX != 0.0 ? centreX : 0.5) * 2.0 - 1.0;
    float dx  = abs(v_cx - cXe);
    float fdX = fonduX > 0.0 ? fonduX : 0.02;
    float vis = masqueX > 0.0 ? 1.0 - smoothstep(2.0 * max(masqueX - fdX, 0.0), 2.0 * masqueX, dx) : 1.0;
    FragColor.rgb *= (1.0 - assombrir * clamp(dx, 0.0, 1.0)) * (reflet > 0.0 ? 0.85 : 1.0);
    FragColor.a   *= gRefA * vis;
}
#endif

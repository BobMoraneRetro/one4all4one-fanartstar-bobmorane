// Boîte en perspective selon sa place à l'écran (carrousel horizontal) :
// au centre de l'écran la boîte est de face, à gauche elle pivote dans un sens, à droite dans l'autre.
// L'angle est calculé à partir de la position de la boîte à l'écran : il change en douceur pendant le défilement.
// Réglages (XML, dans <shader>) :
//   maxAngle   angle des boîtes sur les côtés, en degrés (défaut 55)
//   spread     distance au centre (en fraction de demi-écran) où l'angle maximal est atteint (défaut 0.22)
//   recul      éloignement de la caméra, en largeurs de boîte : plus petit = perspective plus marquée (défaut 2.2)
//   sens       1 = bord intérieur (côté centre) en arrière, -1 = bord extérieur en arrière (défaut 1)
//   assombrir  assombrissement des boîtes sur les côtés, 0 à 1 (défaut 0.35)
//   centreX    position horizontale (0..1 de l'écran) de la boîte de face (défaut 0.5)
//   largeurCase largeur de l'élément en nombre de cases du carrousel (défaut 2.6). Carrousel horizontal : une case
//              = largeur du carrousel / maxLogoCount, donc largeurCase = (1re valeur de size) x logoSize.x x maxLogoCount / size.x du carrousel ;
//              les boîtes de côté sont réduites pour tenir dans une case (jamais de chevauchement)
//   jeu        espace laissé entre deux boîtes de côté, en pixels (défaut 2 ; -1 = 0)
//   ratioBoite format de boîte imposé (largeur / hauteur, 0 = celui de l'image) : l'image est recadrée pour remplir la boîte
//              (ex. fanart du système en forme de boîtier quand le jeu n'a pas de jaquette)
//   masqueX    les boîtes dont le centre est à plus de masqueX (fraction de la largeur d'écran) du centre disparaissent
//              en fondu : permet d'avoir un carrousel plus large que la rangée visible, sans boîte coupée au bout (0 = aucun)
//   contenu    0 = l'image remplit la boîte ; > 0 = l'image est réduite à cette fraction de la boîte, centrée, proportions
//              gardées, transparente autour (ex. marquee posé sur la face, avec ratioBoite)
//   fonduX     largeur du fondu avant masqueX (fraction de la largeur d'écran, défaut 0.02 ; plus grand = plus doux)
//   formatMax  format (largeur / hauteur) de la boîte la plus large du système (0 = celui de la boîte) : l'écart
//              autour de la sélection est prévu pour elle quand les formats sont mélangés (ex. boîtes SNES US et JP)
//   zoomSelection agrandissement de la boîte sélectionnée par le carrousel (= logoScale, défaut 1.35) :
//              les voisines sont décalées au moins assez pour ne jamais être recouvertes par la sélection
//   ecart      décalage des boîtes de côté vers l'extérieur, en largeur de boîtier DVD (défaut 0.35 ; -1 = aucun),
//              limité automatiquement pour que la boîte ne soit jamais coupée
// L'élément peut être plus large que la boîte (size dans le XML) : la boîte garde ses proportions (textureSize),
// centrée en hauteur, et la place libre sert au décalage.

#if defined(VERTEX)

#if __VERSION__ >= 130
#define COMPAT_VARYING out
#define COMPAT_ATTRIBUTE in
#else
#define COMPAT_VARYING varying
#define COMPAT_ATTRIBUTE attribute
#endif

uniform mat4 MVPMatrix;
uniform vec2 outputSize;
COMPAT_ATTRIBUTE vec2 VertexCoord;
COMPAT_ATTRIBUTE vec2 TexCoord;
COMPAT_ATTRIBUTE vec4 COLOR;

COMPAT_VARYING vec2 v_tex;
COMPAT_VARYING vec4 v_col;
COMPAT_VARYING float v_cx;

void main(void)
{
    gl_Position = MVPMatrix * vec4(VertexCoord.xy, 0.0, 1.0);
    v_tex = TexCoord;
    v_col = COLOR;
    // centre de l'élément à l'écran (-1 = bord gauche, 1 = bord droit), calculé depuis chaque coin : même valeur partout
    vec4 cc = MVPMatrix * vec4(VertexCoord.x + (0.5 - TexCoord.x) * abs(outputSize.x), VertexCoord.y, 0.0, 1.0);
    v_cx = cc.x / cc.w;
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
precision highp float;
#endif

uniform sampler2D u_tex;
uniform vec2  outputSize;
uniform vec2  textureSize;
uniform float ecart;
uniform float largeurCase;
uniform float jeu;
uniform float zoomSelection;
uniform float masqueX;
uniform float ratioBoite;
uniform float formatMax;
uniform float contenu;
uniform float fonduX;
uniform float maxAngle;
uniform float spread;
uniform float recul;
uniform float sens;
uniform float assombrir;
uniform float centreX;

COMPAT_VARYING vec2 v_tex;
COMPAT_VARYING vec4 v_col;
COMPAT_VARYING float v_cx;

float val(float v, float d) { return v != 0.0 ? v : d; }

void main(void)
{
    float angMax = val(maxAngle, 55.0);
    float spr    = val(spread, 0.22);
    float D      = val(recul, 2.2);
    float sg     = val(sens, 1.0);
    float dark   = assombrir == 0.0 ? 0.35 : clamp(assombrir, 0.0, 1.0);
    float cX     = val(centreX, 0.5) * 2.0 - 1.0;

    float k  = clamp((v_cx - cX) / spr, -1.0, 1.0);
    k = sign(k) * smoothstep(0.0, 1.0, abs(k));
    float th = radians(angMax) * k * sg;
    float s = sin(th), c = cos(th);

    // taille de la boîte (proportions de l'image) dans l'élément, en pixels
    vec2  Q   = abs(outputSize);
    float aspT = (textureSize.x > 0.0 && textureSize.y > 0.0) ? textureSize.x / textureSize.y : Q.x / max(Q.y, 1.0);
    float asp  = ratioBoite > 0.0 ? ratioBoite : aspT;
    // recadrage de l'image dans la boîte imposée (remplissage, centré)
    vec2  cs   = vec2(1.0);
    if (ratioBoite > 0.0) { if (aspT > asp) cs.x = asp / aspT; else cs.y = aspT / asp; }
    float bh  = Q.y;
    float bw  = bh * asp;
    if (bw > Q.x) { bw = Q.x; bh = bw / asp; }
    float H   = bh / bw;
    float ec  = ecart == 0.0 ? 0.35 : max(ecart, 0.0);
    // boîtes de côté réduites pour que leur largeur à l'écran tienne dans une case du carrousel (elles se frôlent sans se chevaucher)
    float S    = Q.x / (largeurCase != 0.0 ? largeurCase : 2.6);
    float gap  = jeu == 0.0 ? 2.0 : max(jeu, 0.0);
    float xa   = -0.5 * c * D / (D - 0.5 * s);
    float xb   =  0.5 * c * D / (D + 0.5 * s);
    float wEcr = (xb - xa) * ((D - 0.5 * abs(s)) / D) * bw;
    float red  = mix(1.0, min(1.0, (S - gap) / max(wEcr, 1.0)), abs(k));
    float bw0  = bw;                         // largeur avant réduction (= celle de la sélection, même format supposé)
    bw *= red;
    bh *= red;
    // décalage vers l'extérieur (k < 0 à gauche, > 0 à droite), compté en largeur de boîtier DVD (0.7 x hauteur) :
    // même écart quel que soit le format, limité pour que la boîte inclinée reste entière dans l'élément
    // largeur à l'écran de la boîte inclinée : la perspective agrandit le bord qui avance, la boîte n'est donc pas
    // centrée sur son point de rotation ; on la recentre (plus bas) pour qu'elle reste dans sa case, quel que soit son format
    float fitR = (D - 0.5 * abs(s)) / D;
    float wDem = 0.5 * (xb - xa) * fitR * bw;           // demi-largeur à l'écran
    float lim = max(0.5 * Q.x - wDem - 2.0, 0.0);
    // décalage minimal : le bord de la boîte côté centre doit rester au-delà du bord de la sélection agrandie
    float zs   = zoomSelection != 0.0 ? zoomSelection : 1.35;
    float ext  = wDem;                                   // demi-largeur côté centre (boîte recentrée)
    // largeur de la sélection : la plus large du système si formatMax est donné (formats de boîtes mélangés)
    float wSel = formatMax > 0.0 ? max(bw0, min(Q.y * formatMax, Q.x)) : bw0;
    float dMin = abs(k) * max(0.5 * wSel * zs + gap - S + ext, 0.0);
    float dec  = clamp(sign(k) * max(abs(ec * k * 0.7 * bh), dMin), -lim, lim);
    dec -= 0.5 * (xa + xb) * fitR * bw;                  // recentrage : bords symétriques autour du centre de la case
    // réduction pour que le bord qui avance (plus grand) tienne dans la hauteur ; 1 pour la boîte de face
    float fit = (D - 0.5 * abs(s)) / D;
    // point de l'écran dans le repère de la boîte (largeur 1, hauteur H), puis inverse de la projection d'un plan tourné
    float sx = ((v_tex.x - 0.5) * Q.x - dec) / bw / fit;
    float sy = (v_tex.y - 0.5) * Q.y / bw / fit;
    float den = c * D - sx * s;
    bool derriere = den <= 0.25 * c * D;     // très loin derrière la boîte (ou derrière la caméra) : rien à dessiner
    float u = sx * D / max(den, 1e-4);
    float z = u * s;
    float v = sy * (D + z) / D;
    vec2 uv = vec2(u + 0.5, v / H + 0.5);

    // bords adoucis (1 pixel d'écran)
    vec2 fw = max(fwidth(uv), vec2(1e-5));
    vec2 e  = min(uv, 1.0 - uv) / fw;
    float cov = clamp(min(e.x, e.y) + 0.5, 0.0, 1.0);
    // hors de la boîte (au-delà d'une marge d'anticrénelage) : transparent, même si la perspective diverge
    bool dehors = uv.x < -0.02 || uv.x > 1.02 || uv.y < -0.02 || uv.y > 1.02;
    if (derriere || dehors || cov <= 0.0) { FragColor = vec4(0.0); return; }

    vec2 uvT = vec2(0.5) + (clamp(uv, 0.0, 1.0) - vec2(0.5)) * cs;
    float horsContenu = 0.0;
    if (contenu > 0.0) {
        // image réduite et centrée sur la face (proportions de l'image gardées)
        float mw = contenu, mh = contenu * H;
        if (aspT > mw / mh) mh = mw / aspT; else mw = mh * aspT;
        uvT = vec2((uv.x - 0.5) / mw + 0.5, (uv.y - 0.5) * H / mh + 0.5);
        horsContenu = (uvT.x < 0.0 || uvT.x > 1.0 || uvT.y < 0.0 || uvT.y > 1.0) ? 1.0 : 0.0;
        uvT = clamp(uvT, 0.0, 1.0);
    }
    vec4 col = COMPAT_TEXTURE(u_tex, uvT) * v_col * (1.0 - horsContenu);
    // les parties qui s'éloignent sont un peu plus sombres, et les boîtes de côté aussi
    float loin  = abs(s) > 1e-3 ? clamp(z / abs(s) + 0.5, 0.0, 1.0) : 0.5;   // 0 = bord proche, 1 = bord éloigné
    float ombre = 1.0 - dark * abs(k) * (0.6 + 0.4 * loin);
    col.rgb *= ombre;
    float fdX = fonduX > 0.0 ? fonduX : 0.02;
    float vis = masqueX > 0.0 ? 1.0 - smoothstep(2.0 * max(masqueX - fdX, 0.0), 2.0 * masqueX, abs(v_cx - cX)) : 1.0;
    FragColor = col * cov * vis;
}

#endif

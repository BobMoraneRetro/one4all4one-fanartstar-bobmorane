// support_umd.glsl : support UMD (PSP) dont seul le disque intérieur tourne, la coque reste fixe.
// Centre, moyeu « UMD » et bord du disque sont mesurés sur chaque image (le cadrage varie selon le scrap) ;
// u_centreX/u_centreY (point de départ), u_rayon et u_rayonCentre servent de valeurs de secours. u_angle (degrés) est animé par le thème (shader.u_angle).
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

uniform mat4 MVPMatrix;
COMPAT_ATTRIBUTE vec2 VertexCoord;
COMPAT_ATTRIBUTE vec2 TexCoord;
COMPAT_ATTRIBUTE vec4 COLOR;

COMPAT_VARYING vec2 v_tex;
COMPAT_VARYING vec4 v_col;

void main(void) {
    gl_Position = MVPMatrix * vec4(VertexCoord.xy, 0.0, 1.0);
    v_tex = TexCoord;
    v_col = COLOR;
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
precision mediump float;
#endif

uniform sampler2D u_tex;
uniform vec2  textureSize;
uniform float u_angle;
uniform float u_centreX;
uniform float u_centreY;
uniform float u_rayon;
uniform float u_rayonCentre;        // centre fixe de l UMD (moyeu « UMD »), fraction de la largeur : valeur de secours si la détection échoue

COMPAT_VARYING vec2 v_tex;
COMPAT_VARYING vec4 v_col;

// couleur posée sur fond blanc (le moyeu est souvent semi-transparent)
vec3 surBlanc(vec2 uv) {
    vec4 t = COMPAT_TEXTURE(u_tex, uv);
    return t.rgb * t.a + vec3(1.0 - t.a);
}

// une passe de mesure du moyeu autour du centre supposé c : 10 directions vers le haut et le bas (loin du texte « UMD »),
// départ à r = 0.15 (dans le moyeu), bord = premier changement net de couleur ;
// les bords trop éloignés de la moyenne sont ramenés à ±0.03 puis on ajuste un cercle (centre corrigé + rayon)
vec3 passeMoyeu(vec2 c, float k) {
    float r[10];
    float somme = 0.0;
    for (int i = 0; i < 10; i++) {
        float a = radians(i < 5 ? 50.0 + 20.0 * float(i) : 230.0 + 20.0 * float(i - 5));
        vec2  dir = vec2(cos(a), sin(a) / k);
        vec3  ref = surBlanc(c + 0.15 * dir);
        float b = 0.33;
        for (int j = 1; j <= 45; j++) {
            float rr = 0.15 + float(j) * 0.004;
            vec3  q  = abs(surBlanc(c + rr * dir) - ref);
            if (max(q.r, max(q.g, q.b)) > 0.12) { b = rr; break; }
        }
        r[i] = b;
        somme += b;
    }
    float m = somme / 10.0;
    float sx = 0.0; float sy = 0.0; float cc = 0.0; float ss = 0.0; float rm = 0.0;
    for (int i = 0; i < 10; i++) {
        float a  = radians(i < 5 ? 50.0 + 20.0 * float(i) : 230.0 + 20.0 * float(i - 5));
        float ri = clamp(r[i], m - 0.03, m + 0.03);
        sx += ri * cos(a); sy += ri * sin(a);
        cc += cos(a) * cos(a); ss += sin(a) * sin(a);
        rm += ri;
    }
    return vec3(c.x + sx / cc, c.y + (sy / ss) / k, rm / 10.0);
}

void main(void) {
    float k   = (textureSize.x > 0.0) ? textureSize.y / textureSize.x : 1.0;   // hauteur / largeur de l image
    vec4  col = COMPAT_TEXTURE(u_tex, v_tex);
    vec2  c0  = vec2(u_centreX, u_centreY);
    vec2  cm  = vec2(0.5, 0.5);                                            // départ de la mesure : milieu de l image (identique que l axe V soit inversé ou non)
    if (length((v_tex - cm) * vec2(1.0, k)) < u_rayon + 0.06) {
        // centre et moyeu propres à l image (le scrap peut décaler le disque dans la coque) : 3 passes ;
        // si la mesure est aberrante, on garde les valeurs du thème
        vec3  m1 = passeMoyeu(cm, k);
        vec3  m2 = passeMoyeu(m1.xy, k);
        m2 = passeMoyeu(m2.xy, k);
        bool  ok = m2.z > 0.10 && m2.z < 0.30 && length((m2.xy - cm) * vec2(1.0, k)) < 0.07;
        vec2  c  = ok ? m2.xy : c0;
        float rc = ok ? m2.z - 0.008 : u_rayonCentre;          // limite un peu dans le moyeu : du blanc qui tourne sur du blanc ne se voit pas
        float re = ok ? clamp(m2.z * 2.06, 0.40, 0.47) : u_rayon;         // bord du disque ≈ 2.1 x le moyeu (mesuré sur 102 images)
        vec2  p  = (v_tex - c) * vec2(1.0, k);                             // repère en fractions de la largeur
        float d  = length(p);
        if (d < re && d > rc) {
            float a  = radians(-u_angle);                                  // sens des aiguilles d une montre
            float ca = cos(a), sa = sin(a);
            vec2  q  = vec2(ca * p.x + sa * p.y, -sa * p.x + ca * p.y);
            vec4  rot = COMPAT_TEXTURE(u_tex, c + q / vec2(1.0, k));
            // fondus sur le bord du disque (4 % du rayon) et contre le centre fixe (0.008) : un léger écart de cadrage ne fait pas de cassure nette
            float w = smoothstep(rc, rc + 0.008, d) * (1.0 - smoothstep(0.96 * re, re, d));
            col = mix(col, rot, w);
        }
    }
    FragColor = col * v_col;
}
#endif

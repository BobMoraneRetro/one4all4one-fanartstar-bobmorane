// support_tourne.glsl : affiche l image du support selon sa forme.
// Détection : les 4 coins de l image sont transparents => support rond (disque) ; sinon carte, cartouche, boîtier.
// u_rond = 1 : n affiche que les supports ronds (élément qui tourne) ; u_rond = 0 : n affiche que les autres (élément fixe).
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
uniform float u_rond;

COMPAT_VARYING vec2 v_tex;
COMPAT_VARYING vec4 v_col;

void main(void) {
    // coins pris un peu à l intérieur (marges d antialiasing des détourages)
    float c = 0.06;
    float coins = COMPAT_TEXTURE(u_tex, vec2(c, c)).a + COMPAT_TEXTURE(u_tex, vec2(1.0 - c, c)).a
                + COMPAT_TEXTURE(u_tex, vec2(c, 1.0 - c)).a + COMPAT_TEXTURE(u_tex, vec2(1.0 - c, 1.0 - c)).a;
    bool rond = coins < 0.4;
    if (rond != (u_rond > 0.5)) {
        FragColor = vec4(0.0);
        return;
    }
    vec2 uv = v_tex;
    FragColor = COMPAT_TEXTURE(u_tex, uv) * v_col;
}
#endif

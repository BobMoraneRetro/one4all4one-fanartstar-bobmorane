// fanart_bord_repete.glsl : fanart nette au centre ; autour, le BORD de l'image est répété en miroir (aller-retour sur une bande
// de « bande » x la taille de l'image) au lieu d'une copie agrandie de toute l'image. Ce fond est flouté (flou, en pixels, 16 points
// en spirale comme fanart_etendu), puis assombri et désaturé progressivement en s'éloignant de l'image ; vignettage vers les bords.
// Transition douce de « transition » pixels à l'intérieur des bords gauche, droit et bas de l'image nette (pas en haut).
// Paramètres : hauteur (0.8), decalageHaut (0), bande (0.12), flou (32), assombrir (0.3), distanceFond (350),
//   saturationFond (0.8), transition (70), vignettage (0.25).
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
// dFdy requis pour détecter le sens de la texture (GLSL ES 1.0)
#extension GL_OES_standard_derivatives : enable
			
#if __VERSION__ >= 130
#define COMPAT_VARYING in
#define COMPAT_TEXTURE texture
#ifdef GL_ES
out mediump vec4 FragColor;
#else
out vec4 FragColor;
#endif
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
			
COMPAT_VARYING   vec4      v_col;
COMPAT_VARYING   vec2      v_tex;
COMPAT_VARYING   vec2      v_pos;

uniform   sampler2D u_tex;
uniform   vec2      resolution;
uniform   vec2      textureSize;
uniform   vec2      outputSize;
uniform   vec2      outputOffset;

uniform   float      hauteur;
uniform   float      decalageHaut;
uniform   float      bande;
uniform   float      flou;
uniform   float      assombrir;
uniform   float      saturationFond;
uniform   float      transition;
uniform   float      distanceFond;
uniform   float      vignettage;
uniform   float      flouCentre;   // flou de l image centrale (pixels, 0 = nette) : option « Flou des fanarts »

#define TAPS 16
#define GOLDEN_ANGLE 2.39996323

vec2 tc(vec2 u, bool inv) {
	return vec2(u.x, inv ? 1.0 - u.y : u.y);
}
// aller-retour : 0..b..0..b... (miroir répété de la bande du bord)
float pingpong(float d, float b) {
	float t = mod(d, 2.0 * b);
	return (t < b) ? t : 2.0 * b - t;
}
// coordonnée de l'image (peut sortir de 0..1) -> coordonnée lue : dedans inchangée, dehors miroir répété de la bande du bord
float replie(float u, float b) {
	if (u < 0.0) return pingpong(-u, b);
	if (u > 1.0) return 1.0 - pingpong(u - 1.0, b);
	return u;
}
vec2 replie2(vec2 u, float b) {
	return vec2(replie(u.x, b), replie(u.y, b));
}

void main(void)
{
	vec2  S    = vec2(abs(outputSize.x), abs(outputSize.y));
	float A    = textureSize.x / max(textureSize.y, 1.0);
	vec2  q    = clamp((v_pos - outputOffset) / S, 0.0, 1.0);
	bool  inv  = dFdy(v_tex.y) * dFdy(v_pos.y) < 0.0;
	float h    = (hauteur > 0.0) ? hauteur : 0.8;
	float b    = (bande > 0.0) ? bande : 0.12;

	float wc   = h * S.y * A / S.x;
	float x0   = (1.0 - wc) * 0.5;
	vec2  uv   = vec2((q.x - x0) / wc, (q.y - decalageHaut) / h);
	float dl   = (q.x - x0) * S.x;
	float dr   = (x0 + wc - q.x) * S.x;
	float db   = (decalageHaut + h - q.y) * S.y;
	float T    = (transition > 0.0) ? transition : 70.0;
	float m    = smoothstep(0.0, T, dl) * smoothstep(0.0, T, dr) * smoothstep(0.0, T, db) * step(0.0, (q.y - decalageHaut) * S.y);

	vec4 net = vec4(0.0);
	if (m > 0.0) {
		net = COMPAT_TEXTURE(u_tex, tc(clamp(uv, 0.0, 1.0), inv));
		if (flouCentre > 0.5) {
			vec2  pxc = 1.0 / (vec2(wc, h) * S);
			vec4  acc = vec4(0.0);
			float ws  = 0.0;
			for (int i = 0; i < 64; i++) {
				float fi = float(i) + 0.5;
				float d  = sqrt(fi / 64.0);
				float a  = fi * 2.39996323;
				float w  = exp(-2.0 * d * d);
				acc += COMPAT_TEXTURE(u_tex, tc(clamp(uv + vec2(cos(a), sin(a)) * d * flouCentre * pxc, 0.0, 1.0), inv)) * w;
				ws  += w;
			}
			net = acc / ws;
		}
	}
	vec4 col = net;
	if (m < 0.999) {
		// fond : bord répété en miroir, flouté
		float r   = (flou > 0.0) ? flou : 32.0;
		vec2  px  = 1.0 / (vec2(wc, h) * S);
		vec4  acc = COMPAT_TEXTURE(u_tex, tc(replie2(uv, b), inv));
		float ws  = 1.0;
		for (int i = 0; i < TAPS; i++) {
			float fi = float(i) + 0.5;
			float d  = sqrt(fi / float(TAPS));
			float a  = fi * GOLDEN_ANGLE;
			float w  = exp(-2.0 * d * d);
			acc += COMPAT_TEXTURE(u_tex, tc(replie2(uv + vec2(cos(a), sin(a)) * d * r * px, b), inv)) * w;
			ws  += w;
		}
		acc /= ws;
		// assombrissement et désaturation progressifs : nuls au raccord, complets à « distanceFond » pixels de l'image
		float dOut = max(max(-dl, -dr), -db);
		float pg   = smoothstep(0.0, (distanceFond > 0.0) ? distanceFond : 350.0, dOut);
		vec3 gris  = vec3(dot(acc.rgb, vec3(0.34, 0.55, 0.11)));
		float sat  = mix(1.0, (saturationFond > 0.0) ? saturationFond : 0.8, pg);
		acc.rgb    = mix(gris, acc.rgb, sat) * (1.0 - clamp(assombrir, 0.0, 1.0) * pg);
		float ev   = smoothstep(0.3, 0.85, length((q - vec2(0.5, 0.4)) * vec2(1.25, 1.0)));
		acc.rgb   *= 1.0 - clamp(vignettage, 0.0, 1.0) * ev;
		acc.a      = 1.0;
		col = mix(acc, net, m);
	}
	FragColor = vec4(col.rgb, 1.0) * v_col;
}
#endif

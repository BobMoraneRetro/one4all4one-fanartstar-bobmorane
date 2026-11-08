// border_cadre_ombre.glsl : variante de border_cadre.glsl (d après :/shaders/border.glsl d EmulationStation, licence MIT)
// avec une OMBRE PORTÉE DÉCALÉE (direction réglable, bord doux) au lieu de l ombre uniforme tout autour.
// Paramètres : borderSize, borderColor, cornerRadius (comme border.glsl ; < 1 = fraction de la hauteur, >= 1 = pixels),
//   outerShadowSize = marge réservée autour de l image pour l ombre, outerShadowColor,
//   shadowOffsetX / shadowOffsetY = décalage de l ombre (X négatif = à gauche, Y positif = en bas),
//   shadowBlurX / shadowBlurY = flou (écart-type) horizontal / vertical ; mêmes unités,
//   saturation. L image est réduite de outerShadowSize de chaque côté pour laisser la place à l ombre.
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

uniform   float      borderSize;
uniform   vec4       borderColor;
uniform   float      cornerRadius;
uniform   float      outerShadowSize;
uniform   vec4       outerShadowColor;
uniform   float      shadowOffsetX;
uniform   float      shadowOffsetY;
uniform   float      shadowBlurX;
uniform   float      shadowBlurY;
uniform   float      saturation;
uniform   float      garderProportions; // 1 = image entière dans un cadre de taille fixe (bandes sombres sur les côtés ou en haut / bas)
uniform   float      degradeBas;        // 0 = aucun ; sinon part de la hauteur de l image assombrie en bas (fond des infos)

float getComputedValue(float value, float defaultValue) {
	if (value == 0.0)
		return defaultValue;
	if (abs(value) < 1.0)
		return abs(outputSize.y) * value;
	return value;
}

// erf(x), approximation de Winitzki (erreur < 1e-3)
vec2 erfApprox(vec2 x) {
	vec2 x2 = x * x;
	vec2 t  = 0.147 * x2;
	return sign(x) * sqrt(1.0 - exp(-x2 * (1.27323954 + t) / (1.0 + t)));
}

// distance signée à un rectangle arrondi (négative à l intérieur)
float sdRoundRect(vec2 p, vec2 halfSize, float r) {
	vec2 q = abs(p) - halfSize + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void main(void)
{
	vec2 size = vec2(abs(outputSize.x), abs(outputSize.y));
	float border = getComputedValue(borderSize, 0.0);
	float marge  = getComputedValue(outerShadowSize, 0.0);
	float radius = getComputedValue(cornerRadius, 0.0);
	vec2  off    = vec2(getComputedValue(shadowOffsetX, 0.0), getComputedValue(shadowOffsetY, 0.0));

	// image réduite de « marge » de chaque côté
	vec2 d  = vec2(marge) / size;
	vec2 uv = (v_tex - d) / (1.0 - 2.0 * d);
	// cadre de taille fixe : l image (vidéo) garde ses proportions, centrée ; le reste du cadre est sombre
	bool horsImage = false;
	if (garderProportions > 0.0 && textureSize.x > 1.0 && textureSize.y > 1.0) {
		vec2  zone = size - 2.0 * vec2(marge);
		float ai   = textureSize.x / textureSize.y;
		float az   = zone.x / zone.y;
		vec2  k    = (ai < az) ? vec2(az / ai, 1.0) : vec2(1.0, ai / az);
		uv = (uv - 0.5) * k + 0.5;
		horsImage = uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0;
	}
	vec4 col = horsImage ? vec4(0.043, 0.051, 0.063, 1.0) : COMPAT_TEXTURE(u_tex, uv);
	if (saturation != 1.0) {
		vec3 gray = vec3(dot(col.rgb, vec3(0.34, 0.55, 0.11)));
		col = vec4(mix(gray, col.rgb, saturation), col.a);
	}
	col *= v_col;
	// présence de l image : alpha du centre de la texture x opacité de l élément. Quand la vidéo s efface (ou n a pas encore démarré),
	// le liseré et l ombre s effacent avec elle au lieu de rester affichés seuls.
	float presence = COMPAT_TEXTURE(u_tex, vec2(0.5)).a * v_col.a;

	vec2 p        = v_pos - outputOffset - size / 2.0;     // repère centré
	vec2 halfImg  = size / 2.0 - vec2(marge);
	// dégradé sombre en bas de l image (dessiné avec l image : il apparaît et disparaît exactement avec elle)
	if (degradeBas > 0.0) {
		float fy = clamp((p.y + halfImg.y) / (2.0 * halfImg.y), 0.0, 1.0);   // 0 en haut, 1 en bas
		float k  = smoothstep(1.0 - degradeBas, 1.0, fy);
		col.rgb  = mix(col.rgb, vec3(0.03, 0.04, 0.055), 0.88 * pow(k, 0.8));
	}
	float dImg    = sdRoundRect(p, halfImg, radius);

	if (dImg <= 0.0) {
		if (dImg > -border) {                               // liseré
			vec4 b = borderColor;
			col = vec4(mix(col.rgb, b.rgb, b.a), max(col.a, b.a * presence));
		}
		float aa = 1.0 - smoothstep(-1.0, 0.0, dImg);       // bord net anticrénelé
		FragColor = vec4(col.rgb, col.a * aa);                 // couleur non prémultipliée (comme border.glsl) : pas de liseré sombre sur le bord blanc
		return;
	}
	// Ombre = rectangle de l image décalé de (shadowOffsetX, shadowOffsetY), flouté par une gaussienne d écart-type
	// shadowBlurX à l horizontale et shadowBlurY à la verticale (produit de deux marches floutées, fonction erf).
	// Modèle ajusté sur l ombre du cadre du panneau Big Art (deck/cadre_panneau.png, erreur moyenne 4/255) :
	//   décalage -0.016 / +0.0083, flou 0.0109 / 0.0054 (fractions de la hauteur), intensité 0.74.
	vec2 sig = max(vec2(getComputedValue(shadowBlurX, 0.0), getComputedValue(shadowBlurY, 0.0)), vec2(0.5)) * 1.41421356;
	vec2 lo  = (p - off + halfImg) / sig;
	vec2 hi  = (p - off - halfImg) / sig;
	vec2 F   = 0.5 * (erfApprox(lo) - erfApprox(hi));
	float a  = outerShadowColor.a * F.x * F.y * presence;
	if (a <= 0.001)
		discard;
	FragColor = vec4(outerShadowColor.rgb, a);
}
#endif

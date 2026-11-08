// flou_image.glsl : flou gaussien en spirale dense (64 points) d une image, pour l option « Flou des fanarts ».
// Paramètre : flou (rayon en pixels d écran).
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

uniform   float      flou;

#define GOLDEN_ANGLE 2.39996323

void main(void)
{
	vec4 c = COMPAT_TEXTURE(u_tex, v_tex);
	if (flou > 0.5) {
		vec2  px = vec2(abs(dFdx(v_tex.x)) + abs(dFdy(v_tex.x)), abs(dFdx(v_tex.y)) + abs(dFdy(v_tex.y)));
		vec4  acc = vec4(0.0);
		float ws  = 0.0;
		for (int i = 0; i < 64; i++) {
			float fi = float(i) + 0.5;
			float d  = sqrt(fi / 64.0);
			float a  = fi * 2.39996323;
			float w  = exp(-2.0 * d * d);
			acc += COMPAT_TEXTURE(u_tex, clamp(v_tex + vec2(cos(a), sin(a)) * d * flou * px, 0.0, 1.0)) * w;
			ws  += w;
		}
		c = acc / ws;
	}
	FragColor = c * v_col;
}
#endif

#version 450

in vec3 color;
in vec4 lightPos;

out vec4 fragColor;

uniform sampler2D shadowMap;

float shadowCompare(const vec2 uv, const float compare){
	float depth = texture(shadowMap, uv).r;
	return step(compare, depth);
}

float shadowLerp(const vec2 uv, const float compare, const vec2 smSize){
	const vec2 texelSize = vec2(1.0) / smSize;
	vec2 f = fract(uv * smSize + 0.5);
	vec2 centroidUV = floor(uv * smSize + 0.5) / smSize;
	float lb = shadowCompare(centroidUV, compare);
	float lt = shadowCompare(centroidUV + texelSize * vec2(0.0, 1.0), compare);
	float rb = shadowCompare(centroidUV + texelSize * vec2(1.0, 0.0), compare);
	float rt = shadowCompare(centroidUV + texelSize, compare);
	float a = mix(lb, lt, f.y);
	float b = mix(rb, rt, f.y);
	float c = mix(a, b, f.x);
	return c;
}

float PCF(const vec2 uv, const float compare, const vec2 smSize) {
	float result = shadowLerp(uv + (vec2(-1.0, -1.0) / smSize), compare, smSize);
	result += shadowLerp(uv + (vec2(-1.0, 0.0) / smSize), compare, smSize);
	result += shadowLerp(uv + (vec2(-1.0, 1.0) / smSize), compare, smSize);
	result += shadowLerp(uv + (vec2(0.0, -1.0) / smSize), compare, smSize);
	result += shadowLerp(uv, compare, smSize);
	result += shadowLerp(uv + (vec2(0.0, 1.0) / smSize), compare, smSize);
	result += shadowLerp(uv + (vec2(1.0, -1.0) / smSize), compare, smSize);
	result += shadowLerp(uv + (vec2(1.0, 0.0) / smSize), compare, smSize);
	result += shadowLerp(uv + (vec2(1.0, 1.0) / smSize), compare, smSize);
	return result / 9.0;
}

void main() {

	vec3 lPos = lightPos.xyz / vec3(lightPos.w);
    const float shadowsBias = 0.001;

    const vec2 shadowmapSize = vec2(16384, 16384);
    const vec2 smSize = shadowmapSize;
    float visibility = max(PCF(lPos.xy, lPos.z - shadowsBias, smSize), 0.45);

    // float visibility = max(float((texture(shadowMap, lPos.xy).x + shadowsBias) > lPos.z), 0.45);

	fragColor = vec4(color * visibility, 1.0);
}

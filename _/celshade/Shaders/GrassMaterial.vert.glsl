#version 450

in vec3 pos;
in vec3 nor;
in vec3 off;

uniform mat4 WVP;
uniform mat4 LWVP;
uniform float time;

out vec3 color;
out vec4 lightPos;

void main() {

	// Instance
	vec4 mPos = vec4(pos + off, 1.0);

	// Wind
	mPos.x += (sin(time * 2.0 + cos(mPos.x / 2))) * ((pos.z + 0.3) / 8.0);
	mPos.y += (cos(time * 2.0 + sin(mPos.x / 2))) * ((pos.z + 0.3) / 16.0);

	lightPos = LWVP * mPos;
	gl_Position = WVP * mPos;

	// Color
	color = vec3(0.1, 0.3, 0.05);
	color *= (pos.z + 0.2) * 2.0;
}
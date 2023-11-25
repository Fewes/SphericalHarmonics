#ifndef SH_INCLUDED
#define SH_INCLUDED

////////////////////////////////////////////////////////////////////////////////////////////////////
// Spherical harmonics math
////////////////////////////////////////////////////////////////////////////////////////////////////

#define PI 3.14159265359

#define Y0 0.282095
#define Y1 0.488603

#define L0(d) Y0
#define L1N(d) (-Y1 * d.y)
#define L10(d) ( Y1 * d.z)
#define L1P(d) (-Y1 * d.x)

struct SH3
{
	float3 L0;
	float3 L1N, L10, L1P;

	void AddRadiance(float3 dir, float3 radiance)
	{
		L0 += radiance * L0(dir);
		L1N += radiance * L1N(dir);
		L10 += radiance * L10(dir);
		L1P += radiance * L1P(dir);
	}

	void AddRadiance(SH3 other)
	{
		L0 += other.L0;
		L1N += other.L1N;
		L10 += other.L10;
		L1P += other.L1P;
	}

	void Scale(float f)
	{
		L0 *= f;
		L1N *= f;
		L10 *= f;
		L1P *= f;
	}

	float3 Evaluate(float3 dir)
	{
		float3 irradiance = 
			L0 * L0(dir) +
			L1N * L1N(dir) +
			L10 * L10(dir) +
			L1P * L1P(dir);
		return max(0.0, irradiance) * PI;
	}

	float3 EvaluateNonLinear(float3 dir)
	{
		const float epsilon = 1e-4;

		dir = dir.yzx;
		float3 R0 = L0.xyz;
		float3 R1_r = 0.5 * float3(-L1N.x, L10.x, -L1P.x);
		float3 R1_g = 0.5 * float3(-L1N.y, L10.y, -L1P.y);
		float3 R1_b = 0.5 * float3(-L1N.z, L10.z, -L1P.z);
		float3 lenR1 = sqrt(float3(dot(R1_r, R1_r), dot(R1_g, R1_g), dot(R1_b, R1_b)));

		R0    = max(epsilon, R0);
		lenR1 = max(epsilon, lenR1);

		float3 q = 0.5 * (1.0 + float3(dot(R1_r / lenR1.r, dir), dot(R1_g / lenR1.g, dir), dot(R1_b / lenR1.b, dir)));

		float3 p = 1.0 + 2.0 * lenR1 / R0;
		float3 a = (1.0 - lenR1 / R0) / (1.0 + lenR1 / R0);

		return max(0.0, R0 * (a + (1.0 - a) * (p + 1.0) * pow(q, p)));
	}

	float3 GetDominantDirection(out float focus)
	{
		float3 dir = 0.0;

		dir += float3(L1P.r, L1N.r, L10.r) * 0.3 + float3(L1P.r, L1N.g, L10.g) * 0.59 + float3(L1P.r, L1N.b, L10.b) * 0.11;

		dir.xy *= -1;

		focus = length(dir);
		return dir / focus;
	}
};

SH3 CreateSH(float3 L0, float3 L1N, float3 L10, float3 L1P)
{
	SH3 sh;
	sh.L0 = L0;
	sh.L1N = L1N;
	sh.L10 = L10;
	sh.L1P = L1P;
	return sh;
}

SH3 ProjectSH(float3 dir, float3 color)
{
	SH3 sh;
	sh.L0 = L0(dir) * color;
	sh.L1N = L1N(dir) * color;
	sh.L10 = L10(dir) * color;
	sh.L1P = L1P(dir) * color;
	return sh;
}

SH3 LerpSH(SH3 a, SH3 b, float t)
{
	float omt = 1.0 - t;
	a.L0 = a.L0 * omt + b.L0 * t;
	a.L1N = a.L1N * omt + b.L1N * t;
	a.L10 = a.L10 * omt + b.L10 * t;
	a.L1P = a.L1P * omt + b.L1P * t;
	return a;
}

////////////////////////////////////////////////////////////////////////////////////////////////////
// Spherical harmonics pack/unoacking
////////////////////////////////////////////////////////////////////////////////////////////////////

SH3 UnpackSH(float4 col0, float4 col1, float4 col2)
{
	SH3 sh;
	sh.L0 = col0.xyz;
	sh.L1N = col1.xyz;
	sh.L10 = col2.xyz;
	sh.L1P = float3(col0.w, col1.w, col2.w);
	return sh;
}

void PackSH(SH3 sh, out float4 col0, out float4 col1, out float4 col2)
{
	col0 = float4(sh.L0.xyz, sh.L1P.x);
	col1 = float4(sh.L1N.xyz, sh.L1P.y);
	col2 = float4(sh.L10.xyz, sh.L1P.z);
}

////////////////////////////////////////////////////////////////////////////////////////////////////
// 12 channel texture macros
////////////////////////////////////////////////////////////////////////////////////////////////////

#define SH_TEXTURE3D(i) Texture3D<float4> ##i##0; Texture3D<float4> ##i##1; Texture3D<float4> ##i##2;
#define SH_TEXTURE3D_PARAM(i) Texture3D<float4> ##i##0, Texture3D<float4> ##i##1, Texture3D<float4> ##i##2
#define SH_TEXTURE3D_PARAM_IN(i) (##i##0), (##i##1), (##i##2)

SH3 READ_SH_TEXTURE3D(SH_TEXTURE3D_PARAM(tex), int3 id)
{
	return UnpackSH(tex0[id], tex1[id], tex2[id]);
}

SH3 SAMPLE_SH_TEXTURE3D(SH_TEXTURE3D_PARAM(tex), SamplerState ss, float3 uvw)
{
	return UnpackSH(
		tex0.SampleLevel(ss, uvw, 0),
		tex1.SampleLevel(ss, uvw, 0),
		tex2.SampleLevel(ss, uvw, 0)
	);
}

#define SH_RWTEXTURE3D(i) RWTexture3D<float4> ##i##0_RW; RWTexture3D<float4> ##i##1_RW; RWTexture3D<float4> ##i##2_RW;
#define SH_RWTEXTURE3D_PARAM(i) RWTexture3D<float4> ##i##0_RW, RWTexture3D<float4> ##i##1_RW, RWTexture3D<float4> ##i##2_RW
#define SH_RWTEXTURE3D_PARAM_IN(i) (##i##0_RW), (##i##1_RW), (##i##2_RW)

SH3 READ_SH_RWTEXTURE3D(SH_RWTEXTURE3D_PARAM(tex), int3 id)
{
	return UnpackSH(tex0_RW[id], tex1_RW[id], tex2_RW[id]);
}

void WRITE_SH_RWTEXTURE3D(SH_RWTEXTURE3D_PARAM(tex), int3 id, SH3 sh)
{
	float4 col0, col1, col2;
	PackSH(sh, col0, col1, col2);
	tex0_RW[id] = col0;
	tex1_RW[id] = col1;
	tex2_RW[id] = col2;
}

#endif // SH_INCLUDED

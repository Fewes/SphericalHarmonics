# SphericalHarmonics

# What is this?
A single-file utility library for working with spherical harmonics in shaders. It contains macros for declaring, adding radiance to, packing, unpacking and sampling irradiance using L1 spherical harmonics. It is mainly intended to be a drop-in helper when implementing GI solutions, as L1 harmonics provide decent directional information and only require 3 float4s for storage (meaning you only have to read 3 textures to sample irradiance).

# How do I use it?
[Example project](https://github.com/Fewes/SphericalHarmonicsDev)

## Include library in shader
```
#include "Packages/dev.fewes.sphericalharmonics/Include.hlsl"
```

## Declaring an empty 3-channel SH structure
```
SH3 sh = (SH3)0;
```

## Gathering irradiance
```
for (int i = 0; i < sampleCount; i++)
{
    float3 direction = GetDirection(i);
    float3 radiance = GetRadiance(direction);
    sh.AddRadiance(direction, radiance);
}
sh.Scale(SPHERE_SOLID_ANGLE / sampleCount);
```

## Packing data
```
float4 shData1, shData2, shData3;
PackSH(sh, shData1, shData2, shData3);
// Pack float4s to texture, vertex interpolator etc.
```

## Unpacking data
```
SH3 sh = UnpackSH(shData1, shData2, shData3);
```

## Sampling irradiance
```
float3 irradiance = sh.Evaluate(direction);
```
### OR (no ringing)
```
float3 irradiance = sh.EvaluateNonLinear(direction);
```

## Declaring an irradiance volume texture
(3 textures with packed data must be set as _IrradianceField0, _IrradianceField1 and _IrradianceField2)
```
SH_TEXTURE3D(_IrradianceField)
```

## Sampling from irradiance volume texture
```
SH# sh = SAMPLE_SH_TEXTURE3D(SH_TEXTURE3D_PARAM_IN(_IrradianceField), my_linear_clamp_sampler, uvw);
```

## Declaring an irradiance volume texture (UAV)
(3 textures must be set as _IrradianceFieldOutput0, _IrradianceFieldOutput1 and _IrradianceFieldOutput2)
```
SH_RWTEXTURE3D(_IrradianceFieldOutput)
```

## Writing to irradiance volume texture (UAV)
```
WRITE_SH_RWTEXTURE3D(SH_RWTEXTURE3D_PARAM_IN(_IrradianceFieldOutput), id, sh);
```

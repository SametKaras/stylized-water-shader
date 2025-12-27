# 🔬 Technical Breakdown: Stylized Water Shader

This document provides a detailed explanation of each technique used in the water shader. Each section covers: the purpose of the technique, mathematical foundations, implementation details, and code examples.

---

## Table of Contents

1. [Depth-Based Coloring](#1-depth-based-coloring)
2. [Gerstner Waves](#2-gerstner-waves)
3. [Normal Mapping & UV Animation](#3-normal-mapping--uv-animation)
4. [Fresnel Effect](#4-fresnel-effect)
5. [Refraction (GrabPass)](#5-refraction-grabpass)
6. [Caustics (Voronoi)](#6-caustics-voronoi)
7. [Flow Maps](#7-flow-maps)
8. [Subsurface Scattering](#8-subsurface-scattering)
9. [Shore Waves & Foam](#9-shore-waves--foam)
10. [Planar Reflection](#10-planar-reflection)
11. [Tessellation](#11-tessellation)

---

## 1. Depth-Based Coloring

### Purpose
Creates realistic color transitions like real water: light colors (turquoise) in shallow areas and dark colors (navy blue) in deep areas.

### How It Works
1. Read scene depth from Unity's depth texture
2. Calculate the water surface depth
3. Find the difference between them (waterDepth)
4. Lerp between two colors based on this value

### Mathematical Basis
```
waterDepth = sceneDepth - surfaceDepth
depthFactor = saturate(waterDepth / maxDistance)
finalColor = lerp(shallowColor, deepColor, depthFactor)
```

### Code
```hlsl
// In fragment shader
float2 screenUV = i.screenPos.xy / i.screenPos.w;
float sceneDepth = LinearEyeDepth(tex2D(_CameraDepthTexture, screenUV).r);
float surfaceDepth = i.screenPos.w;
float waterDepth = sceneDepth - surfaceDepth;
float depthFactor = saturate(waterDepth / _DepthMaxDistance);

float4 waterColor = lerp(_ShallowColor, _DeepColor, depthFactor);
```

### Requirements
- Camera must have `DepthTextureMode.Depth` enabled
- `EnableDepthTexture.cs` script handles this automatically

---

## 2. Gerstner Waves

### Purpose
Physically accurate ocean wave simulation. Unlike simple sine waves, Gerstner waves:
- Create sharp peaks and rounded troughs
- Move vertices both vertically and horizontally
- Mimic real water behavior

### Mathematical Basis
Gerstner wave formula:
```
P(x,z,t) = [x + Σ(Qi * Ai * Di.x * cos(wi * Di · (x,z) + φi * t))]
           [Σ(Ai * sin(wi * Di · (x,z) + φi * t))]
           [z + Σ(Qi * Ai * Di.y * cos(wi * Di · (x,z) + φi * t))]

Where:
- Qi = steepness (wave sharpness)
- Ai = amplitude (wave height)
- Di = direction (wave direction)
- wi = 2π / wavelength
- φi = phase velocity = √(g / wi)
```

### Code
```hlsl
float3 GerstnerWave(float4 wave, float3 p, inout float3 tangent, inout float3 binormal)
{
    float steepness = wave.z;
    float wavelength = wave.w;
    float k = 2 * UNITY_PI / wavelength;     // Wave number
    float c = sqrt(9.8 / k);                  // Phase velocity
    float2 d = normalize(wave.xy);            // Direction
    float f = k * (dot(d, p.xz) - c * _Time.y * _WaveSpeed);
    float a = steepness / k;                  // Amplitude
    
    // Update tangent and binormal (for normal calculation)
    tangent += float3(
        -d.x * d.x * (steepness * sin(f)),
        d.x * (steepness * cos(f)),
        -d.x * d.y * (steepness * sin(f))
    );
    binormal += float3(
        -d.x * d.y * (steepness * sin(f)),
        d.y * (steepness * cos(f)),
        -d.y * d.y * (steepness * sin(f))
    );
    
    // Vertex displacement
    return float3(
        d.x * (a * cos(f)),   // X offset
        a * sin(f),            // Y offset (height)
        d.y * (a * cos(f))     // Z offset
    );
}
```

### Usage
```hlsl
// Sum multiple waves
p += GerstnerWave(_WaveA, worldPos, tangent, binormal);
p += GerstnerWave(_WaveB, worldPos, tangent, binormal);
p += GerstnerWave(_WaveC, worldPos, tangent, binormal);

// Calculate normal
float3 normal = normalize(cross(binormal, tangent));
```

---

## 3. Normal Mapping & UV Animation

### Purpose
Adds small ripples and detail to the water surface. Two normal map layers moving in different directions create an organic appearance.

### How It Works
1. Create two different UV sets (different speed and direction)
2. Sample normal map for each UV
3. Blend the two normals
4. Apply perturbation to world normal

### Code
```hlsl
// Two-layer UV animation
float2 uv1 = i.uv * _NormalScale + _Time.y * _NormalSpeed * float2(1, 0.5);
float2 uv2 = i.uv * _NormalScale * 0.8 + _Time.y * _NormalSpeed * float2(-0.5, 1);

// Normal map sampling
float3 normal1 = UnpackNormal(tex2D(_NormalMap, uv1));
float3 normal2 = UnpackNormal(tex2D(_NormalMap, uv2));

// Blend (RNM - Reoriented Normal Mapping is more accurate but simple blend works too)
float3 normalBlend = normalize(normal1 + normal2);
normalBlend.xy *= _NormalStrength;

// Apply to world normal
float3 worldNormal = normalize(i.worldNormal + float3(normalBlend.x, 0, normalBlend.y) * 0.3);
```

---

## 4. Fresnel Effect

### Purpose
Changes reflection amount based on viewing angle:
- Looking straight down: Water interior visible (less reflection)
- Looking at grazing angle: Reflection intensifies

### Mathematical Basis
Schlick Fresnel Approximation:
```
F = F0 + (1 - F0) * (1 - cos(θ))^5

Simplified version:
fresnel = (1 - dot(viewDir, normal))^power
```

### Code
```hlsl
float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);
float fresnel = 1.0 - saturate(dot(viewDir, worldNormal));
fresnel = pow(fresnel, _FresnelPower) * _FresnelStrength;

// Usage
finalColor = lerp(finalColor, reflectionColor, fresnel);
```

---

## 5. Refraction (GrabPass)

### Purpose
Makes underwater objects appear bent/distorted.

### How It Works
1. Capture the screen before water is rendered using GrabPass
2. Offset UV coordinates based on normal map
3. Sample grab texture with distorted UV

### Code
```hlsl
// At shader start
GrabPass { "_GrabTexture" }

// In fragment shader
float2 refractionOffset = normalBlend.xy * _RefractionStrength;
float2 grabUV = (i.grabPos.xy + refractionOffset) / i.grabPos.w;
float3 refractionColor = tex2D(_GrabTexture, grabUV).rgb;
```

### Note
- Refraction decreases with depth (less visibility in deep water)
- Can be combined with underwater fog

---

## 6. Caustics (Voronoi)

### Purpose
Moving patterns created by light underwater. The dancing light effect seen at pool bottoms.

### How It Works
1. Generate Voronoi noise pattern
2. Two layers at different scales and speeds
3. Invert (1 - voronoi) and intensify
4. Reduce intensity based on depth

### Mathematical Basis
Voronoi: Calculate distance to nearest random point for each pixel.

### Code
```hlsl
float2 voronoiRandomVector(float2 uv, float offset)
{
    float2x2 m = float2x2(15.27, 47.63, 99.41, 89.98);
    uv = frac(sin(mul(uv, m)) * 46839.32);
    return float2(sin(uv.y * offset) * 0.5 + 0.5, cos(uv.x * offset) * 0.5 + 0.5);
}

float voronoi(float2 uv, float time)
{
    float2 g = floor(uv);
    float2 f = frac(uv);
    float minDist = 1.0;
    
    for(int y = -1; y <= 1; y++)
    {
        for(int x = -1; x <= 1; x++)
        {
            float2 lattice = float2(x, y);
            float2 offset = voronoiRandomVector(g + lattice, time);
            float d = distance(lattice + offset, f);
            minDist = min(minDist, d);
        }
    }
    return minDist;
}

float caustics(float2 uv, float time)
{
    float c1 = voronoi(uv, time);
    float c2 = voronoi(uv * 1.3 + 5.0, time * 1.2);
    c1 = pow(1.0 - c1, 3.0);  // Invert and intensify
    c2 = pow(1.0 - c2, 3.0);
    return (c1 + c2) * 0.5;
}
```

---

## 7. Flow Maps

### Purpose
Simulates water flowing in a specific direction (river, stream effect).

### How It Works
1. Read flow vector (from texture or uniform)
2. Calculate two-phase UV (for seamless looping)
3. Sample texture for each phase
4. Blend phases based on weight

### Mathematical Basis
```
Phase A: progress = frac(time)
Phase B: progress = frac(time + 0.5)

UV_A = uv - flowVector * progressA
UV_B = uv - flowVector * progressB

Weight = 1 - abs(1 - 2 * progress)  // Triangle wave
```

### Code
```hlsl
float3 FlowUVW(float2 uv, float2 flowVector, float time, bool flowB)
{
    float phaseOffset = flowB ? 0.5 : 0;
    float progress = frac(time + phaseOffset);
    
    float3 uvw;
    uvw.xy = uv - flowVector * progress;
    uvw.z = 1 - abs(1 - 2 * progress);  // Blend weight
    return uvw;
}

// Usage
float3 uvwA = FlowUVW(uv, flowVector, time, false);
float3 uvwB = FlowUVW(uv, flowVector, time, true);

float3 normalA = UnpackNormal(tex2D(_NormalMap, uvwA.xy));
float3 normalB = UnpackNormal(tex2D(_NormalMap, uvwB.xy));
float3 normalBlend = normalize(normalA * uvwA.z + normalB * uvwB.z);
```

---

## 8. Subsurface Scattering (SSS)

### Purpose
Simulates light scattering as it passes through water. Creates a greenish glow at wave peaks when sunlight comes from behind.

### How It Works
1. Distort light direction with normal
2. Take negative dot product with view direction
3. Modulate based on wave height

### Code
```hlsl
// SSS calculation
float3 H = normalize(lightDir + worldNormal * _SSSDistortion);
float VdotH = pow(saturate(dot(viewDir, -H)), _SSSPower);
float waveHeightFactor = saturate(i.waveHeight * 2 + 0.5);
float3 sss = _SSSColor.rgb * VdotH * _SSSStrength * waveHeightFactor;

// Wave height comes from vertex shader
o.waveHeight = p.y - originalPos.y;
```

---

## 9. Shore Waves & Foam

### Purpose
- Shore Waves: Waves breaking at the shoreline
- Foam: Foam at object edges and shoreline

### Shore Waves
```hlsl
float ShoreWave(float shoreDepth, float2 worldXZ)
{
    float shorePhase = shoreDepth * _ShoreWaveFrequency - _Time.y * _ShoreWaveSpeed;
    float wave = sin(shorePhase) * 0.5 + 0.5;
    wave = pow(wave, 2.0);  // Sharp wave peaks
    return wave * _ShoreWaveAmplitude * saturate(1.0 - shoreDepth / _ShoreDistance);
}
```

### Foam Texture
```hlsl
// Two-layer foam texture (more organic)
float2 foamUV1 = i.worldPos.xz * _FoamScale * 0.1 + _Time.y * _FoamSpeed * float2(1, 0.5);
float2 foamUV2 = i.worldPos.xz * _FoamScale * 0.1 * 0.8 + _Time.y * _FoamSpeed * float2(-0.5, 1);

float foamTex1 = tex2D(_FoamTexture, foamUV1).r;
float foamTex2 = tex2D(_FoamTexture, foamUV2).r;
float foamTexture = (foamTex1 + foamTex2) * 0.5;

// Edge foam (based on depth)
float edgeFoamMask = 1.0 - saturate(waterDepth / _FoamDistance);
float edgeFoam = step(_FoamCutoff, foamTexture * edgeFoamMask) * _FoamStrength;
```

---

## 10. Planar Reflection

### Purpose
Real-time reflection on water surface. Mirror image of sky and objects.

### How It Works
1. Calculate main camera's reflection position
2. Mirror the camera using reflection matrix
3. Render scene with a separate camera
4. Send RenderTexture to shader

### C# Script (Summary)
```csharp
// Calculate reflection matrix
Matrix4x4 reflection = CalculateReflectionMatrix(reflectionPlane);

// Move camera to reflection position
reflectionCamera.worldToCameraMatrix = mainCamera.worldToCameraMatrix * reflection;

// Oblique projection (clip underwater)
Vector4 clipPlane = CameraSpacePlane(reflectionCamera, pos, normal);
reflectionCamera.projectionMatrix = mainCamera.CalculateObliqueMatrix(clipPlane);

// Render
GL.invertCulling = true;
reflectionCamera.Render();
GL.invertCulling = false;
```

### Shader Code
```hlsl
// Vertex shader
o.reflectionPos = ComputeScreenPos(o.pos);

// Fragment shader
float2 reflectionUV = i.reflectionPos.xy / i.reflectionPos.w;
reflectionUV.y = 1.0 - reflectionUV.y;  // Flip Y axis
reflectionUV += normalBlend.xy * _ReflectionDistortion;
float3 reflectionColor = tex2D(_ReflectionTex, reflectionUV).rgb;

// Control with Fresnel
finalColor = lerp(finalColor, reflectionColor, fresnel * _ReflectionStrength);
```

---

## 11. Tessellation

### Purpose
Dynamically subdivide mesh on GPU:
- More detail up close (smooth waves)
- Less detail far away (performance)

### Pipeline
```
Vertex Shader → Hull Shader → Tessellator → Domain Shader → Fragment Shader
```

### Hull Shader
Determines tessellation factors:
```hlsl
[domain("tri")]
[outputcontrolpoints(3)]
[outputtopology("triangle_cw")]
[partitioning("fractional_odd")]
[patchconstantfunc("PatchConstantFunction")]
TessellationControlPoint hull(InputPatch<TessellationControlPoint, 3> patch, uint id : SV_OutputControlPointID)
{
    return patch[id];
}
```

### Distance-Based Factor
```hlsl
float CalcDistanceTessFactor(float4 vertex)
{
    float3 worldPos = mul(unity_ObjectToWorld, vertex).xyz;
    float dist = distance(worldPos, _WorldSpaceCameraPos);
    float f = clamp(1.0 - (dist - _TessellationMinDistance) / 
              (_TessellationMaxDistance - _TessellationMinDistance), 0.01, 1.0);
    return f * _TessellationFactor;
}
```

### Domain Shader
Creates new vertices and applies Gerstner waves:
```hlsl
[domain("tri")]
v2f domain(TessellationFactors factors, OutputPatch<TessellationControlPoint, 3> patch, 
           float3 barycentricCoordinates : SV_DomainLocation)
{
    // Barycentric interpolation
    float4 vertex = patch[0].vertex * barycentricCoordinates.x +
                    patch[1].vertex * barycentricCoordinates.y +
                    patch[2].vertex * barycentricCoordinates.z;
    
    // Apply Gerstner waves
    // ... (normal vertex shader operations)
}
```

---

## 🎯 Performance Tips

| Feature | GPU Cost | Optimization |
|---------|----------|--------------|
| Tessellation | High | Use distance-based LOD |
| Planar Reflection | High | Low resolution (256-512) |
| GrabPass | Medium | Use once |
| Caustics | Low | Reduce loop iterations |
| Normal Mapping | Low | Optimize texture size |

---

## 📚 Resources

- [GPU Gems: Effective Water Simulation](https://developer.nvidia.com/gpugems/gpugems/part-i-natural-effects/chapter-1-effective-water-simulation-physical-models)
- [Catlike Coding: Flow](https://catlikecoding.com/unity/tutorials/flow/)
- [GPU Gems: Caustics](https://developer.nvidia.com/gpugems/gpugems/part-i-natural-effects/chapter-2-rendering-water-caustics)
- [Tessellation in Unity](https://docs.unity3d.com/Manual/SL-SurfaceShaderTessellation.html)

---

## 👤 Author

**Samet Karaş**
- GitHub: [@SametKaras](https://github.com/SametKaras)

---

*This breakdown is prepared for those who want to understand how each technique in the shader works.*

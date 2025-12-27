# 🔬 Technical Breakdown: Stylized Water Shader

Bu döküman, water shader'daki her tekniğin detaylı açıklamasını içerir. Her bölüm şunları kapsar: tekniğin amacı, matematiksel temeli, implementasyon detayları ve kod örnekleri.

---

## İçindekiler

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

### Amaç
Gerçek suda olduğu gibi, sığ bölgelerde açık renk (turkuaz), derin bölgelerde koyu renk (lacivert) geçişi sağlar.

### Nasıl Çalışır
1. Unity'nin depth texture'ından sahne derinliğini oku
2. Su yüzeyinin derinliğini hesapla
3. İkisi arasındaki farkı bul (waterDepth)
4. Bu değere göre iki renk arasında lerp yap

### Matematiksel Temel
```
waterDepth = sceneDepth - surfaceDepth
depthFactor = saturate(waterDepth / maxDistance)
finalColor = lerp(shallowColor, deepColor, depthFactor)
```

### Kod
```hlsl
// Fragment shader'da
float2 screenUV = i.screenPos.xy / i.screenPos.w;
float sceneDepth = LinearEyeDepth(tex2D(_CameraDepthTexture, screenUV).r);
float surfaceDepth = i.screenPos.w;
float waterDepth = sceneDepth - surfaceDepth;
float depthFactor = saturate(waterDepth / _DepthMaxDistance);

float4 waterColor = lerp(_ShallowColor, _DeepColor, depthFactor);
```

### Gereksinimler
- Kamerada `DepthTextureMode.Depth` aktif olmalı
- `EnableDepthTexture.cs` script'i bunu otomatik yapar

---

## 2. Gerstner Waves

### Amaç
Fiziksel olarak doğru okyanus dalgaları simülasyonu. Basit sinüs dalgalarından farklı olarak, Gerstner dalgaları:
- Sivri tepeler ve yuvarlak çukurlar oluşturur
- Vertex'leri hem dikey hem yatay hareket ettirir
- Gerçek su davranışını taklit eder

### Matematiksel Temel
Gerstner dalga formülü:
```
P(x,z,t) = [x + Σ(Qi * Ai * Di.x * cos(wi * Di · (x,z) + φi * t))]
           [Σ(Ai * sin(wi * Di · (x,z) + φi * t))]
           [z + Σ(Qi * Ai * Di.y * cos(wi * Di · (x,z) + φi * t))]

Burada:
- Qi = steepness (dalga dikliği)
- Ai = amplitude (dalga yüksekliği)
- Di = direction (dalga yönü)
- wi = 2π / wavelength
- φi = phase velocity = √(g / wi)
```

### Kod
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
    
    // Tangent ve binormal güncelle (normal hesabı için)
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

### Kullanım
```hlsl
// Birden fazla dalga toplama
p += GerstnerWave(_WaveA, worldPos, tangent, binormal);
p += GerstnerWave(_WaveB, worldPos, tangent, binormal);
p += GerstnerWave(_WaveC, worldPos, tangent, binormal);

// Normal hesapla
float3 normal = normalize(cross(binormal, tangent));
```

---

## 3. Normal Mapping & UV Animation

### Amaç
Su yüzeyinde küçük dalgacıklar ve detay ekler. İki katman normal map farklı yönlerde hareket ederek organik görünüm sağlar.

### Nasıl Çalışır
1. İki farklı UV seti oluştur (farklı hız ve yön)
2. Her UV için normal map sample et
3. İki normal'i blend et
4. World normal'e perturb uygula

### Kod
```hlsl
// İki katman UV animasyonu
float2 uv1 = i.uv * _NormalScale + _Time.y * _NormalSpeed * float2(1, 0.5);
float2 uv2 = i.uv * _NormalScale * 0.8 + _Time.y * _NormalSpeed * float2(-0.5, 1);

// Normal map sample
float3 normal1 = UnpackNormal(tex2D(_NormalMap, uv1));
float3 normal2 = UnpackNormal(tex2D(_NormalMap, uv2));

// Blend (RNM - Reoriented Normal Mapping daha doğru ama basit blend de çalışır)
float3 normalBlend = normalize(normal1 + normal2);
normalBlend.xy *= _NormalStrength;

// World normal'e uygula
float3 worldNormal = normalize(i.worldNormal + float3(normalBlend.x, 0, normalBlend.y) * 0.3);
```

---

## 4. Fresnel Effect

### Amaç
Bakış açısına göre yansıma miktarını değiştirir:
- Dik bakınca: Su içi görünür (az yansıma)
- Yatay bakınca: Yansıma güçlenir

### Matematiksel Temel
Schlick Fresnel Approximation:
```
F = F0 + (1 - F0) * (1 - cos(θ))^5

Basitleştirilmiş versiyon:
fresnel = (1 - dot(viewDir, normal))^power
```

### Kod
```hlsl
float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);
float fresnel = 1.0 - saturate(dot(viewDir, worldNormal));
fresnel = pow(fresnel, _FresnelPower) * _FresnelStrength;

// Kullanım
finalColor = lerp(finalColor, reflectionColor, fresnel);
```

---

## 5. Refraction (GrabPass)

### Amaç
Su altındaki nesnelerin bükülmüş/distorted görünmesini sağlar.

### Nasıl Çalışır
1. GrabPass ile su render edilmeden önceki ekranı yakala
2. Normal map'e göre UV koordinatlarını offset et
3. Distorted UV ile grab texture'ı sample et

### Kod
```hlsl
// Shader başında
GrabPass { "_GrabTexture" }

// Fragment shader'da
float2 refractionOffset = normalBlend.xy * _RefractionStrength;
float2 grabUV = (i.grabPos.xy + refractionOffset) / i.grabPos.w;
float3 refractionColor = tex2D(_GrabTexture, grabUV).rgb;
```

### Not
- Derinliğe göre refraction azalır (derin suda daha az görünürlük)
- Underwater fog ile kombine edilebilir

---

## 6. Caustics (Voronoi)

### Amaç
Su altında ışığın oluşturduğu hareketli desenler. Havuz tabanındaki dans eden ışık efekti.

### Nasıl Çalışır
1. Voronoi noise pattern oluştur
2. İki katman farklı scale ve hızda
3. Ters çevir (1 - voronoi) ve güçlendir
4. Derinliğe göre intensity azalt

### Matematiksel Temel
Voronoi: Her pixel için en yakın rastgele noktaya mesafe hesapla.

### Kod
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
    c1 = pow(1.0 - c1, 3.0);  // Ters çevir ve güçlendir
    c2 = pow(1.0 - c2, 3.0);
    return (c1 + c2) * 0.5;
}
```

---

## 7. Flow Maps

### Amaç
Suyun belirli bir yöne akmasını simüle eder (nehir, akarsu efekti).

### Nasıl Çalışır
1. Flow vector oku (texture veya uniform)
2. İki fazlı UV hesapla (kesintisiz döngü için)
3. Her faz için texture sample et
4. Fazları weight'e göre blend et

### Matematiksel Temel
```
Phase A: progress = frac(time)
Phase B: progress = frac(time + 0.5)

UV_A = uv - flowVector * progressA
UV_B = uv - flowVector * progressB

Weight = 1 - abs(1 - 2 * progress)  // Üçgen dalga
```

### Kod
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

// Kullanım
float3 uvwA = FlowUVW(uv, flowVector, time, false);
float3 uvwB = FlowUVW(uv, flowVector, time, true);

float3 normalA = UnpackNormal(tex2D(_NormalMap, uvwA.xy));
float3 normalB = UnpackNormal(tex2D(_NormalMap, uvwB.xy));
float3 normalBlend = normalize(normalA * uvwA.z + normalB * uvwB.z);
```

---

## 8. Subsurface Scattering (SSS)

### Amaç
Işığın su içinden geçerken saçılmasını simüle eder. Dalga tepelerinde güneş arkadan geldiğinde yeşilimsi parıltı.

### Nasıl Çalışır
1. Işık yönünü normal ile distort et
2. View direction ile negatif dot product al
3. Dalga yüksekliğine göre modüle et

### Kod
```hlsl
// SSS hesaplama
float3 H = normalize(lightDir + worldNormal * _SSSDistortion);
float VdotH = pow(saturate(dot(viewDir, -H)), _SSSPower);
float waveHeightFactor = saturate(i.waveHeight * 2 + 0.5);
float3 sss = _SSSColor.rgb * VdotH * _SSSStrength * waveHeightFactor;

// Dalga yüksekliği vertex shader'dan gelir
o.waveHeight = p.y - originalPos.y;
```

---

## 9. Shore Waves & Foam

### Amaç
- Shore Waves: Kıyıya vuran dalgalar
- Foam: Nesne kenarlarında ve kıyıda köpük

### Shore Waves
```hlsl
float ShoreWave(float shoreDepth, float2 worldXZ)
{
    float shorePhase = shoreDepth * _ShoreWaveFrequency - _Time.y * _ShoreWaveSpeed;
    float wave = sin(shorePhase) * 0.5 + 0.5;
    wave = pow(wave, 2.0);  // Keskin dalga tepeleri
    return wave * _ShoreWaveAmplitude * saturate(1.0 - shoreDepth / _ShoreDistance);
}
```

### Foam Texture
```hlsl
// İki katman foam texture (daha organik)
float2 foamUV1 = i.worldPos.xz * _FoamScale * 0.1 + _Time.y * _FoamSpeed * float2(1, 0.5);
float2 foamUV2 = i.worldPos.xz * _FoamScale * 0.1 * 0.8 + _Time.y * _FoamSpeed * float2(-0.5, 1);

float foamTex1 = tex2D(_FoamTexture, foamUV1).r;
float foamTex2 = tex2D(_FoamTexture, foamUV2).r;
float foamTexture = (foamTex1 + foamTex2) * 0.5;

// Edge foam (derinliğe göre)
float edgeFoamMask = 1.0 - saturate(waterDepth / _FoamDistance);
float edgeFoam = step(_FoamCutoff, foamTexture * edgeFoamMask) * _FoamStrength;
```

---

## 10. Planar Reflection

### Amaç
Su yüzeyinde gerçek zamanlı yansıma. Gökyüzü ve nesnelerin ayna görüntüsü.

### Nasıl Çalışır
1. Ana kameranın yansıma pozisyonunu hesapla
2. Reflection matrix ile kamerayı aynala
3. Ayrı bir kamera ile sahneyi render et
4. RenderTexture'ı shader'a gönder

### C# Script (Özet)
```csharp
// Reflection matrix hesapla
Matrix4x4 reflection = CalculateReflectionMatrix(reflectionPlane);

// Kamerayı yansıma pozisyonuna taşı
reflectionCamera.worldToCameraMatrix = mainCamera.worldToCameraMatrix * reflection;

// Oblique projection (su altını kırp)
Vector4 clipPlane = CameraSpacePlane(reflectionCamera, pos, normal);
reflectionCamera.projectionMatrix = mainCamera.CalculateObliqueMatrix(clipPlane);

// Render
GL.invertCulling = true;
reflectionCamera.Render();
GL.invertCulling = false;
```

### Shader Kodu
```hlsl
// Vertex shader
o.reflectionPos = ComputeScreenPos(o.pos);

// Fragment shader
float2 reflectionUV = i.reflectionPos.xy / i.reflectionPos.w;
reflectionUV.y = 1.0 - reflectionUV.y;  // Y ekseni ters
reflectionUV += normalBlend.xy * _ReflectionDistortion;
float3 reflectionColor = tex2D(_ReflectionTex, reflectionUV).rgb;

// Fresnel ile kontrol
finalColor = lerp(finalColor, reflectionColor, fresnel * _ReflectionStrength);
```

---

## 11. Tessellation

### Amaç
GPU'da mesh'i dinamik olarak subdivide et:
- Yakında çok detay (smooth dalgalar)
- Uzakta az detay (performans)

### Pipeline
```
Vertex Shader → Hull Shader → Tessellator → Domain Shader → Fragment Shader
```

### Hull Shader
Tessellation faktörlerini belirler:
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
Yeni vertex'leri oluşturur ve Gerstner waves uygular:
```hlsl
[domain("tri")]
v2f domain(TessellationFactors factors, OutputPatch<TessellationControlPoint, 3> patch, 
           float3 barycentricCoordinates : SV_DomainLocation)
{
    // Barycentric interpolation
    float4 vertex = patch[0].vertex * barycentricCoordinates.x +
                    patch[1].vertex * barycentricCoordinates.y +
                    patch[2].vertex * barycentricCoordinates.z;
    
    // Gerstner waves uygula
    // ... (normal vertex shader işlemleri)
}
```

---

## 🎯 Performans İpuçları

| Özellik | GPU Cost | Optimizasyon |
|---------|----------|--------------|
| Tessellation | Yüksek | Distance-based LOD kullan |
| Planar Reflection | Yüksek | Düşük resolution (256-512) |
| GrabPass | Orta | Tek seferde kullan |
| Caustics | Düşük | Loop iteration azalt |
| Normal Mapping | Düşük | Texture boyutu optimize |

---

## 📚 Kaynaklar

- [GPU Gems: Effective Water Simulation](https://developer.nvidia.com/gpugems/gpugems/part-i-natural-effects/chapter-1-effective-water-simulation-physical-models)
- [Catlike Coding: Flow](https://catlikecoding.com/unity/tutorials/flow/)
- [GPU Gems: Caustics](https://developer.nvidia.com/gpugems/gpugems/part-i-natural-effects/chapter-2-rendering-water-caustics)
- [Tessellation in Unity](https://docs.unity3d.com/Manual/SL-SurfaceShaderTessellation.html)

---

## 👤 Yazar

**Samet Karaş**
- GitHub: [@SametKaras](https://github.com/SametKaras)

---

*Bu breakdown, shader'daki her tekniğin nasıl çalıştığını anlamak isteyenler için hazırlanmıştır.*

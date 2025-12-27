Shader "Custom/StylizedWater"
{
    Properties
    {
        _ShallowColor ("Shallow Color", Color) = (0.3, 0.8, 0.85, 0.8)
        _DeepColor ("Deep Color", Color) = (0.1, 0.2, 0.4, 1.0)
        _DepthMaxDistance ("Depth Max Distance", Float) = 3.0
        
        [Header(Tessellation)]
        _TessellationFactor ("Tessellation Factor", Range(1, 64)) = 8
        _TessellationMinDistance ("Min Distance", Float) = 5
        _TessellationMaxDistance ("Max Distance", Float) = 30
        
        [Header(Gerstner Waves)]
        _WaveA ("Wave A (dir.xy, steepness, wavelength)", Vector) = (1, 0, 0.5, 10)
        _WaveB ("Wave B (dir.xy, steepness, wavelength)", Vector) = (0, 1, 0.25, 8)
        _WaveC ("Wave C (dir.xy, steepness, wavelength)", Vector) = (1, 1, 0.15, 5)
        _WaveSpeed ("Wave Speed", Float) = 1.0
        
        [Header(Surface)]
        _NormalMap ("Normal Map", 2D) = "bump" {}
        _NormalStrength ("Normal Strength", Range(0, 2)) = 1.0
        _NormalScale ("Normal Tiling", Float) = 4.0
        _NormalSpeed ("Normal Speed", Float) = 0.1
        
        [Header(Flow)]
        _FlowMap ("Flow Map (RG)", 2D) = "grey" {}
        _FlowStrength ("Flow Strength", Range(0, 1)) = 0.5
        _FlowSpeed ("Flow Speed", Float) = 0.5
        [Toggle] _UseFlowMap ("Use Flow Map", Float) = 0
        _FlowDirection ("Flow Direction (if no map)", Vector) = (1, 0, 0, 0)
        
        [Header(Fresnel)]
        _FresnelColor ("Fresnel Color", Color) = (1, 1, 1, 1)
        _FresnelPower ("Fresnel Power", Range(0.5, 10)) = 3.0
        _FresnelStrength ("Fresnel Strength", Range(0, 1)) = 0.5
        
        [Header(Reflection)]
        _ReflectionTex ("Reflection Texture", 2D) = "black" {}
        _ReflectionStrength ("Reflection Strength", Range(0, 1)) = 0.5
        _ReflectionDistortion ("Reflection Distortion", Range(0, 0.2)) = 0.05
        
        [Header(Subsurface Scattering)]
        _SSSColor ("SSS Color", Color) = (0.2, 0.9, 0.6, 1)
        _SSSStrength ("SSS Strength", Range(0, 1)) = 0.5
        _SSSPower ("SSS Power", Range(1, 10)) = 3.0
        _SSSDistortion ("SSS Distortion", Range(0, 1)) = 0.5
        
        [Header(Underwater Fog)]
        _UnderwaterFogColor ("Underwater Fog Color", Color) = (0.1, 0.3, 0.4, 1)
        _UnderwaterFogDensity ("Fog Density", Range(0, 2)) = 0.5
        _UnderwaterFogOffset ("Fog Offset", Float) = 0.0
        
        [Header(Shore Waves)]
        _ShoreWaveSpeed ("Shore Wave Speed", Float) = 1.0
        _ShoreWaveFrequency ("Shore Wave Frequency", Float) = 2.0
        _ShoreWaveAmplitude ("Shore Wave Amplitude", Range(0, 1)) = 0.3
        _ShoreDistance ("Shore Distance", Float) = 2.0
        
        [Header(Foam)]
        _FoamTexture ("Foam Texture", 2D) = "white" {}
        _FoamColor ("Foam Color", Color) = (1, 1, 1, 1)
        _FoamScale ("Foam Tiling", Float) = 10.0
        _FoamDistance ("Foam Distance", Float) = 0.5
        _FoamStrength ("Foam Strength", Range(0, 1)) = 0.8
        _FoamCutoff ("Foam Cutoff", Range(0, 1)) = 0.5
        _FoamSpeed ("Foam Speed", Float) = 0.1
        _ShoreFoamStrength ("Shore Foam Strength", Range(0, 2)) = 1.0
        
        [Header(Refraction)]
        _RefractionStrength ("Refraction Strength", Range(0, 0.2)) = 0.05
        
        [Header(Specular)]
        _SpecularColor ("Specular Color", Color) = (1, 1, 1, 1)
        _SpecularPower ("Specular Power", Range(1, 500)) = 100.0
        _SpecularStrength ("Specular Strength", Range(0, 2)) = 1.0
        
        [Header(Caustics)]
        _CausticsScale ("Caustics Scale", Float) = 5.0
        _CausticsSpeed ("Caustics Speed", Float) = 1.0
        _CausticsStrength ("Caustics Strength", Range(0, 1)) = 0.5
    }
    
    SubShader
    {
        Tags 
        { 
            "RenderType" = "Transparent" 
            "Queue" = "Transparent"
        }
        
        GrabPass { "_GrabTexture" }
        
        Pass
        {
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            
            CGPROGRAM
            #pragma vertex vert
            #pragma hull hull
            #pragma domain domain
            #pragma fragment frag
            #pragma target 4.6
            
            #include "UnityCG.cginc"
            #include "Tessellation.cginc"
            
            // Tessellation parametreleri
            float _TessellationFactor;
            float _TessellationMinDistance;
            float _TessellationMaxDistance;
            
            // Depth parametreleri
            float4 _ShallowColor;
            float4 _DeepColor;
            float _DepthMaxDistance;
            
            // Gerstner dalga parametreleri
            float4 _WaveA;
            float4 _WaveB;
            float4 _WaveC;
            float _WaveSpeed;
            
            // Normal map parametreleri
            sampler2D _NormalMap;
            float _NormalStrength;
            float _NormalScale;
            float _NormalSpeed;
            
            // Flow parametreleri
            sampler2D _FlowMap;
            float _FlowStrength;
            float _FlowSpeed;
            float _UseFlowMap;
            float4 _FlowDirection;
            
            // Fresnel parametreleri
            float4 _FresnelColor;
            float _FresnelPower;
            float _FresnelStrength;
            
            // Reflection parametreleri
            sampler2D _ReflectionTex;
            float _ReflectionStrength;
            float _ReflectionDistortion;
            
            // SSS parametreleri
            float4 _SSSColor;
            float _SSSStrength;
            float _SSSPower;
            float _SSSDistortion;
            
            // Underwater Fog parametreleri
            float4 _UnderwaterFogColor;
            float _UnderwaterFogDensity;
            float _UnderwaterFogOffset;
            
            // Shore Wave parametreleri
            float _ShoreWaveSpeed;
            float _ShoreWaveFrequency;
            float _ShoreWaveAmplitude;
            float _ShoreDistance;
            
            // Foam parametreleri
            sampler2D _FoamTexture;
            float4 _FoamColor;
            float _FoamScale;
            float _FoamDistance;
            float _FoamStrength;
            float _FoamCutoff;
            float _FoamSpeed;
            float _ShoreFoamStrength;
            
            // Refraction parametreleri
            float _RefractionStrength;
            sampler2D _GrabTexture;
            
            // Specular parametreleri
            float4 _SpecularColor;
            float _SpecularPower;
            float _SpecularStrength;
            
            // Caustics parametreleri
            float _CausticsScale;
            float _CausticsSpeed;
            float _CausticsStrength;
            
            sampler2D _CameraDepthTexture;
            
            // Vertex Input
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };
            
            // Tessellation Control Point
            struct TessellationControlPoint
            {
                float4 vertex : INTERNALTESSPOS;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };
            
            // Tessellation Factors
            struct TessellationFactors
            {
                float edge[3] : SV_TessFactor;
                float inside : SV_InsideTessFactor;
            };
            
            // Fragment Input
            struct v2f
            {
                float4 pos : SV_POSITION;
                float4 screenPos : TEXCOORD0;
                float2 uv : TEXCOORD1;
                float3 worldPos : TEXCOORD2;
                float3 worldNormal : TEXCOORD3;
                float4 grabPos : TEXCOORD4;
                float waveHeight : TEXCOORD5;
                float4 reflectionPos : TEXCOORD6;
            };
            
            // Helper fonksiyonlar
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
                c1 = pow(1.0 - c1, 3.0);
                c2 = pow(1.0 - c2, 3.0);
                return (c1 + c2) * 0.5;
            }
            
            float3 GerstnerWave(float4 wave, float3 p, inout float3 tangent, inout float3 binormal)
            {
                float steepness = wave.z;
                float wavelength = wave.w;
                float k = 2 * UNITY_PI / wavelength;
                float c = sqrt(9.8 / k);
                float2 d = normalize(wave.xy);
                float f = k * (dot(d, p.xz) - c * _Time.y * _WaveSpeed);
                float a = steepness / k;
                
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
                
                return float3(
                    d.x * (a * cos(f)),
                    a * sin(f),
                    d.y * (a * cos(f))
                );
            }
            
            float3 FlowUVW(float2 uv, float2 flowVector, float time, bool flowB)
            {
                float phaseOffset = flowB ? 0.5 : 0;
                float progress = frac(time + phaseOffset);
                
                float3 uvw;
                uvw.xy = uv - flowVector * progress;
                uvw.z = 1 - abs(1 - 2 * progress);
                return uvw;
            }
            
            float ShoreWave(float shoreDepth, float2 worldXZ)
            {
                float shorePhase = shoreDepth * _ShoreWaveFrequency - _Time.y * _ShoreWaveSpeed;
                float wave = sin(shorePhase) * 0.5 + 0.5;
                wave = pow(wave, 2.0);
                return wave * _ShoreWaveAmplitude * saturate(1.0 - shoreDepth / _ShoreDistance);
            }
            
            // Vertex Shader - sadece veriyi aktar
            TessellationControlPoint vert(appdata v)
            {
                TessellationControlPoint o;
                o.vertex = v.vertex;
                o.uv = v.uv;
                o.normal = v.normal;
                return o;
            }
            
            // Distance-based tessellation factor hesaplama
            float CalcDistanceTessFactor(float4 vertex)
            {
                float3 worldPos = mul(unity_ObjectToWorld, vertex).xyz;
                float dist = distance(worldPos, _WorldSpaceCameraPos);
                float f = clamp(1.0 - (dist - _TessellationMinDistance) / (_TessellationMaxDistance - _TessellationMinDistance), 0.01, 1.0);
                return f * _TessellationFactor;
            }
            
            // Patch Constant Function
            TessellationFactors PatchConstantFunction(InputPatch<TessellationControlPoint, 3> patch)
            {
                TessellationFactors f;
                
                float factor0 = CalcDistanceTessFactor(patch[0].vertex);
                float factor1 = CalcDistanceTessFactor(patch[1].vertex);
                float factor2 = CalcDistanceTessFactor(patch[2].vertex);
                
                f.edge[0] = (factor1 + factor2) * 0.5;
                f.edge[1] = (factor2 + factor0) * 0.5;
                f.edge[2] = (factor0 + factor1) * 0.5;
                f.inside = (factor0 + factor1 + factor2) / 3.0;
                
                return f;
            }
            
            // Hull Shader
            [domain("tri")]
            [outputcontrolpoints(3)]
            [outputtopology("triangle_cw")]
            [partitioning("fractional_odd")]
            [patchconstantfunc("PatchConstantFunction")]
            TessellationControlPoint hull(InputPatch<TessellationControlPoint, 3> patch, uint id : SV_OutputControlPointID)
            {
                return patch[id];
            }
            
            // Domain Shader - asıl vertex işlemleri burada
            [domain("tri")]
            v2f domain(TessellationFactors factors, OutputPatch<TessellationControlPoint, 3> patch, float3 barycentricCoordinates : SV_DomainLocation)
            {
                appdata data;
                
                // Barycentric interpolation
                #define INTERPOLATE(fieldName) data.fieldName = \
                    patch[0].fieldName * barycentricCoordinates.x + \
                    patch[1].fieldName * barycentricCoordinates.y + \
                    patch[2].fieldName * barycentricCoordinates.z;
                
                INTERPOLATE(vertex)
                INTERPOLATE(uv)
                INTERPOLATE(normal)
                
                // Gerstner Waves uygula
                v2f o;
                
                float3 worldPos = mul(unity_ObjectToWorld, data.vertex).xyz;
                float3 originalPos = worldPos;
                
                float3 tangent = float3(1, 0, 0);
                float3 binormal = float3(0, 0, 1);
                float3 p = worldPos;
                
                p += GerstnerWave(_WaveA, worldPos, tangent, binormal);
                p += GerstnerWave(_WaveB, worldPos, tangent, binormal);
                p += GerstnerWave(_WaveC, worldPos, tangent, binormal);
                
                float3 normal = normalize(cross(binormal, tangent));
                
                o.waveHeight = p.y - originalPos.y;
                
                float4 localPos = mul(unity_WorldToObject, float4(p, 1.0));
                
                o.pos = UnityObjectToClipPos(localPos);
                o.screenPos = ComputeScreenPos(o.pos);
                o.uv = data.uv;
                o.worldPos = p;
                o.worldNormal = normal;
                o.grabPos = ComputeGrabScreenPos(o.pos);
                o.reflectionPos = ComputeScreenPos(o.pos);
                
                return o;
            }
            
            // Fragment Shader
            float4 frag(v2f i) : SV_Target
            {
                // Flow vector hesapla
                float2 flowVector;
                if (_UseFlowMap > 0.5)
                {
                    flowVector = tex2D(_FlowMap, i.uv).rg * 2 - 1;
                }
                else
                {
                    flowVector = _FlowDirection.xy;
                }
                flowVector *= _FlowStrength;
                
                float flowTime = _Time.y * _FlowSpeed;
                
                float3 uvwA = FlowUVW(i.uv * _NormalScale, flowVector, flowTime, false);
                float3 uvwB = FlowUVW(i.uv * _NormalScale, flowVector, flowTime, true);
                
                float3 normalA = UnpackNormal(tex2D(_NormalMap, uvwA.xy));
                float3 normalB = UnpackNormal(tex2D(_NormalMap, uvwB.xy));
                float3 normalBlend = normalize(normalA * uvwA.z + normalB * uvwB.z);
                
                normalBlend.xy *= _NormalStrength;
                normalBlend = normalize(normalBlend);
                
                float3 worldNormal = normalize(i.worldNormal + float3(normalBlend.x, 0, normalBlend.y) * 0.3);
                
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);
                float3 lightDir = normalize(_WorldSpaceLightPos0.xyz);
                
                // Fresnel hesaplama
                float fresnel = 1.0 - saturate(dot(viewDir, worldNormal));
                fresnel = pow(fresnel, _FresnelPower) * _FresnelStrength;
                
                // Reflection hesaplama
                float2 reflectionUV = i.reflectionPos.xy / i.reflectionPos.w;
                reflectionUV.y = 1.0 - reflectionUV.y;
                reflectionUV += normalBlend.xy * _ReflectionDistortion;
                float3 reflectionColor = tex2D(_ReflectionTex, reflectionUV).rgb;
                
                // SSS hesaplama
                float3 H = normalize(lightDir + worldNormal * _SSSDistortion);
                float VdotH = pow(saturate(dot(viewDir, -H)), _SSSPower);
                float waveHeightFactor = saturate(i.waveHeight * 2 + 0.5);
                float3 sss = _SSSColor.rgb * VdotH * _SSSStrength * waveHeightFactor;
                
                // Lighting
                float NdotL = dot(worldNormal, lightDir);
                float lighting = 0.5 + 0.5 * NdotL;
                float colorVariation = (normalBlend.x + normalBlend.y) * 0.1;
                
                // Specular (Blinn-Phong)
                float3 halfDir = normalize(lightDir + viewDir);
                float NdotH = saturate(dot(worldNormal, halfDir));
                float specular = pow(NdotH, _SpecularPower) * _SpecularStrength;
                
                // Depth hesaplama
                float2 screenUV = i.screenPos.xy / i.screenPos.w;
                float sceneDepth = LinearEyeDepth(tex2D(_CameraDepthTexture, screenUV).r);
                float surfaceDepth = i.screenPos.w;
                float waterDepth = sceneDepth - surfaceDepth;
                float depthFactor = saturate(waterDepth / _DepthMaxDistance);
                
                // Shore wave hesaplama
                float shoreWave = ShoreWave(waterDepth, i.worldPos.xz);
                float shoreFactor = saturate(1.0 - waterDepth / _ShoreDistance);
                
                // Underwater Fog hesaplama
                float fogDepth = max(0, waterDepth - _UnderwaterFogOffset);
                float fogFactor = 1.0 - exp(-fogDepth * _UnderwaterFogDensity);
                fogFactor = saturate(fogFactor);
                
                // Caustics hesaplama
                float2 causticsUV = i.worldPos.xz * _CausticsScale * 0.1;
                float causticsPattern = caustics(causticsUV, _Time.y * _CausticsSpeed);
                float causticsIntensity = causticsPattern * _CausticsStrength * (1.0 - depthFactor) * (1.0 - fogFactor);
                
                // Refraction
                float2 refractionOffset = normalBlend.xy * _RefractionStrength;
                float2 grabUV = (i.grabPos.xy + refractionOffset) / i.grabPos.w;
                float3 refractionColor = tex2D(_GrabTexture, grabUV).rgb;
                
                // Underwater fog'u refraction'a uygula
                refractionColor = lerp(refractionColor, _UnderwaterFogColor.rgb, fogFactor);
                
                // Foam texture hesaplama
                float2 foamUV1 = i.worldPos.xz * _FoamScale * 0.1 + _Time.y * _FoamSpeed * float2(1, 0.5);
                float2 foamUV2 = i.worldPos.xz * _FoamScale * 0.1 * 0.8 + _Time.y * _FoamSpeed * float2(-0.5, 1);
                
                float foamTex1 = tex2D(_FoamTexture, foamUV1).r;
                float foamTex2 = tex2D(_FoamTexture, foamUV2).r;
                float foamTexture = (foamTex1 + foamTex2) * 0.5;
                
                // Edge foam
                float edgeFoamMask = 1.0 - saturate(waterDepth / _FoamDistance);
                float edgeFoam = step(_FoamCutoff, foamTexture * edgeFoamMask) * _FoamStrength;
                
                // Shore foam
                float shoreFoamMask = shoreWave * shoreFactor * _ShoreFoamStrength;
                float shoreFoam = step(_FoamCutoff * 0.8, foamTexture * shoreFoamMask);
                
                // Toplam foam
                float totalFoam = saturate(edgeFoam + shoreFoam);
                
                // Su rengi
                float4 waterColor = lerp(_ShallowColor, _DeepColor, depthFactor);
                waterColor.rgb *= lighting;
                waterColor.rgb += colorVariation;
                
                // Refraction karıştır
                float refractionMix = 1.0 - depthFactor;
                float3 finalColor = lerp(waterColor.rgb, refractionColor, refractionMix * 0.5);
                
                // Reflection ekle
                finalColor = lerp(finalColor, reflectionColor, fresnel * _ReflectionStrength);
                
                // SSS ekle
                finalColor += sss;
                
                // Caustics ekle
                finalColor += causticsIntensity;
                
                // Fresnel color ekle
                finalColor = lerp(finalColor, _FresnelColor.rgb, fresnel * 0.3);
                
                // Specular ekle
                finalColor += _SpecularColor.rgb * specular;
                
                // Foam ekle
                finalColor = lerp(finalColor, _FoamColor.rgb, totalFoam);
                
                return float4(finalColor, waterColor.a);
            }
            ENDCG
        }
    }
    
    // Tessellation desteklemeyen GPU'lar için fallback
    Fallback "Diffuse"
}
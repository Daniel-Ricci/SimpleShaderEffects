Shader "Custom/S_Portal2"
{
    Properties
    {
        [HDR] _CoreColor ("Event Horizon", Color) = (0.025, 0.22, 0.72, 1)
        [HDR] _NebulaColor ("Nebula", Color) = (0.08, 1.45, 2.8, 1)
        [HDR] _RimColor ("Rim Plasma", Color) = (2.8, 0.42, 4.2, 1)
        _SwirlSpeed ("Vortex Speed", Range(0, 4)) = 0.55
        _Distortion ("Energy Distortion", Range(0, 0.2)) = 0.065
        _RimWidth ("Rim Width", Range(0.01, 0.12)) = 0.045
        _Brightness ("Radiance", Range(0.1, 4)) = 1.35
    }

    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" "RenderPipeline"="UniversalPipeline" }
        Blend One One
        Cull Off
        ZWrite Off

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes { float4 positionOS : POSITION; float2 uv : TEXCOORD0; };
            struct Varyings { float4 positionCS : SV_POSITION; float2 uv : TEXCOORD0; };

            CBUFFER_START(UnityPerMaterial)
                float4 _CoreColor;
                float4 _NebulaColor;
                float4 _RimColor;
                float _SwirlSpeed;
                float _Distortion;
                float _RimWidth;
                float _Brightness;
            CBUFFER_END

            Varyings vert(Attributes v)
            {
                Varyings o;
                o.positionCS = TransformObjectToHClip(v.positionOS.xyz);
                o.uv = v.uv;
                return o;
            }

            float hash21(float2 p)
            {
                p = frac(p * float2(123.34, 456.21));
                p += dot(p, p + 45.32);
                return frac(p.x * p.y);
            }

            float noise21(float2 p)
            {
                float2 i = floor(p);
                float2 f = frac(p);
                f = f * f * (3.0 - 2.0 * f);
                float a = hash21(i);
                float b = hash21(i + float2(1, 0));
                float c = hash21(i + float2(0, 1));
                float d = hash21(i + float2(1, 1));
                return lerp(lerp(a, b, f.x), lerp(c, d, f.x), f.y);
            }

            float fbm(float2 p)
            {
                float value = 0.0;
                float amplitude = 0.5;
                [unroll] for (int octave = 0; octave < 4; octave++)
                {
                    value += noise21(p) * amplitude;
                    p = p * 2.03 + float2(17.1, 9.2);
                    amplitude *= 0.5;
                }
                return value;
            }

            float4 frag(Varyings i) : SV_Target
            {
                float2 p = (i.uv - 0.5) * 2.0;
                float radius = length(p);
                float angle = atan2(p.y, p.x);
                float time = _Time.y;

                // Counter-rotating flow layers create the depth and turbulent lensing of a hot portal.
                float2 flowUV = p * 3.2;
                float warpA = fbm(flowUV + float2(time * 0.11, -time * 0.07));
                float warpB = fbm(flowUV * 1.7 - float2(time * 0.08, time * 0.13));
                float warpedRadius = radius + (warpA - 0.5) * _Distortion * 2.0;
                float warpedAngle = angle + (warpB - 0.5) * 0.7 + time * _SwirlSpeed;
                float2 vortexUV = float2(warpedAngle * 1.8 + warpedRadius * 5.5,
                                         warpedRadius * 7.0 - time * 0.35);

                float cloud = fbm(vortexUV * 1.15 + float2(time * 0.08, 0));
                float filaments = fbm(float2(warpedAngle * 6.0 + warpedRadius * 15.0,
                                               warpedRadius * 18.0 - time * 0.85));
                float streaks = pow(saturate(1.0 - abs(filaments - 0.52) * 3.8), 3.0);
                float radialBands = 0.5 + 0.5 * sin(warpedRadius * 39.0 - time * 1.8 + (cloud - 0.5) * 7.0);

                // A dark center gives the bright accretion flow a readable event-horizon silhouette.
                float horizon = 1.0 - smoothstep(0.0, 0.47, radius);
                float disk = smoothstep(0.28, 0.39, warpedRadius) * (1.0 - smoothstep(0.83, 0.98, warpedRadius));
                float turbulence = saturate(cloud * 1.4 + streaks * 0.7 + radialBands * 0.24 - 0.48);
                float hotFilaments = streaks * smoothstep(0.35, 0.9, cloud) * disk;

                float edge = 1.0 - smoothstep(0.94, 1.0, radius);
                float rim = exp(-pow((radius - 0.91) / max(_RimWidth, 0.005), 2.0));
                float coronaNoise = fbm(float2(angle * 11.0, time * 0.18 + radius * 5.0));
                float corona = exp(-max(radius - 0.91, 0.0) * 24.0) * (1.0 - smoothstep(0.98, 1.08, radius));
                corona *= 0.55 + coronaNoise * 0.8;

                float3 deepColor = _CoreColor.rgb * (0.18 + cloud * 0.45);
                float3 plasmaColor = lerp(_CoreColor.rgb, _NebulaColor.rgb, saturate(turbulence * 1.35));
                float3 color = deepColor * horizon;
                color += plasmaColor * (disk * (0.35 + turbulence * 1.1));
                color += _NebulaColor.rgb * hotFilaments * 1.7;
                color += _RimColor.rgb * (rim * (1.1 + coronaNoise * 0.75) + corona * 0.85);
                color += _CoreColor.rgb * exp(-radius * 8.0) * 0.7;

                // Soft circular falloff keeps the quad invisible beyond the portal silhouette.
                color *= edge;
                return float4(color * _Brightness, edge);
            }
            ENDHLSL
        }
    }
    FallBack Off
}

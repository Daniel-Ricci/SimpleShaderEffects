Shader "Custom/S_DissolveEffect"
{
    Properties
    {
        [Header(Base)]
        [MainTexture] _BaseMap("Base Map", 2D) = "white" {}
        [MainColor] _BaseColor("Base Color", Color) = (0.95, 0.45, 0.55, 1)

        [Header(Dissolve)]
        _DissolveAmount("Dissolve Amount", Range(0, 1)) = 0.55
        _NoiseScale("Noise Scale", Range(0.1, 20)) = 3.5
        _NoiseContrast("Noise Contrast", Range(0.25, 4)) = 1.25
        _NoiseScroll("Noise Scroll (X, Y)", Vector) = (0, 0, 0, 0)

        [Header(Glowing Edge)]
        [HDR] _EdgeColor("Edge Color", Color) = (0.05, 0.8, 1, 1)
        _EdgeWidth("Edge Width", Range(0.001, 0.25)) = 0.06
        _EdgeEmission("Edge Emission", Range(0, 10)) = 3
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "Queue" = "Geometry"
            "RenderPipeline" = "UniversalPipeline"
        }

        Pass
        {
            Cull Off
            ZWrite On

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor;
                float4 _BaseMap_ST;
                float4 _NoiseScroll;
                float4 _EdgeColor;
                float _DissolveAmount;
                float _NoiseScale;
                float _NoiseContrast;
                float _EdgeWidth;
                float _EdgeEmission;
            CBUFFER_END

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            struct MeshData
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Interpolators
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            // repeatable pseudo-random value for one noise grid point.
            float Hash21(float2 p)
            {
                p = frac(p * float2(123.34, 345.45));
                p += dot(p, p + 34.345);
                return frac(p.x * p.y);
            }

            // smoothly interpolated value noise. Unlike random pixels, it forms organic islands.
            float ValueNoise(float2 p)
            {
                float2 cell = floor(p);
                float2 local = frac(p);
                local = local * local * (3.0 - 2.0 * local);

                float bottom = lerp(Hash21(cell), Hash21(cell + float2(1, 0)), local.x);
                float top = lerp(Hash21(cell + float2(0, 1)), Hash21(cell + float2(1, 1)), local.x);
                return lerp(bottom, top, local.y);
            }

            // several noise layers avoid the regular square-grid appearance of a single layer.
            float FractalNoise(float2 p)
            {
                float noise = 0.0;
                noise += ValueNoise(p) * 0.5;
                noise += ValueNoise(p * 2.03 + 17.2) * 0.25;
                noise += ValueNoise(p * 4.01 + 39.7) * 0.125;
                noise += ValueNoise(p * 8.02 + 71.4) * 0.0625;
                return noise / 0.9375;
            }

            Interpolators vert(MeshData IN)
            {
                Interpolators OUT;
                OUT.vertex = TransformObjectToHClip(IN.vertex.xyz);
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);
                return OUT;
            }

            half4 frag(Interpolators IN) : SV_Target
            {
                float2 noiseUV = IN.uv * _NoiseScale + _NoiseScroll.xy * _Time.y;
                float noise = FractalNoise(noiseUV);
                noise = pow(saturate(noise), _NoiseContrast);

                // fragments below this threshold disappear entirely.
                float remaining = noise - _DissolveAmount;
                clip(remaining);

                // only the surviving pixels immediately beside the threshold become the glowing rim.
                float edge = 1.0 - smoothstep(0.0, _EdgeWidth, remaining);

                float3 baseColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv).rgb * _BaseColor.rgb;
                float3 color = lerp(baseColor, _EdgeColor.rgb, edge);
                color += _EdgeColor.rgb * edge * _EdgeEmission;

                return half4(color, 1.0);
            }
            ENDHLSL
        }
    }
}

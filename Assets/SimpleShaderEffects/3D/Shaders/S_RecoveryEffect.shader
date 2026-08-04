Shader "Custom/S_RecoveryEffect"
{
    Properties
    {
        [Header(Base)]
        [MainColor] _BaseColor("Base Color", Color) = (0.18, 0.9, 0.35, 1)
        _Opacity("Opacity", Range(0, 1)) = 0.65

        [Header(Recovery Rings)]
        [HDR] _RingColor("Ring Color", Color) = (0.3, 1, 0.45, 1)
        _RingIntensity("Ring Intensity", Range(0, 5)) = 2
        _RingCount("Ring Count", Range(1, 12)) = 6
        _RingSpeed("Ring Speed", Range(0, 3)) = 0.7
        _RingSharpness("Ring Sharpness", Range(1, 32)) = 14
        _RingWobble("Ring Wobble", Range(0, 0.1)) = 0.018

        [Header(Travelling Highlights)]
        _Speed("Speed", Range(0, 3)) = 1
        _WaveHorizontalFrequency("Wave Horizontal Frequency", Range(1, 50)) = 12
        _WaveVerticalFrequency("Wave Vertical Frequency", Range(0, 10)) = 1
        _HighlightSharpness("Highlight Sharpness", Range(1, 32)) = 10
        _HighlightIntensity("Highlight Intensity", Range(0, 4)) = 1.5

        [Header(Fresnel Effect)]
        [HDR] _FresnelColor("Fresnel Color", Color) = (0.45, 1, 0.65, 1)
        _FresnelIntensity("Fresnel Intensity", Range(0, 5)) = 0.8
        _FresnelPower("Fresnel Power", Range(0.5, 10)) = 4

        [Header(Vertical Fade)]
        _BottomFade("Bottom Fade", Range(0.001, 0.5)) = 0.1
        _TopFade("Top Fade", Range(0.001, 0.75)) = 0.2
    }

    SubShader
    {
        Tags {
            "RenderType" = "Transparent"
            "Queue" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
        }

        Pass
        {
            Cull Off
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off

            HLSLPROGRAM
            #define TAU 6.283185307179586f

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            float4 _BaseColor;
            float _Opacity;
            float4 _RingColor;
            float _RingIntensity;
            float _RingCount;
            float _RingSpeed;
            float _RingSharpness;
            float _RingWobble;
            float _Speed;
            float _WaveHorizontalFrequency;
            float _WaveVerticalFrequency;
            float _HighlightSharpness;
            float _HighlightIntensity;
            float4 _FresnelColor;
            float _FresnelIntensity;
            float _FresnelPower;
            float _BottomFade;
            float _TopFade;

            struct MeshData
            {
                float4 vertex : POSITION;
                float3 normals : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct Interpolators
            {
                float4 vertex : SV_POSITION;
                float3 normalWS : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                float2 uv : TEXCOORD2;
            };

            Interpolators vert(MeshData IN)
            {
                Interpolators OUT;
                OUT.vertex = TransformObjectToHClip(IN.vertex.xyz);
                OUT.normalWS = TransformObjectToWorldNormal(IN.normals);
                OUT.positionWS = TransformObjectToWorld(IN.vertex.xyz);
                OUT.uv = IN.uv;
                return OUT;
            }

            half4 frag(Interpolators IN) : SV_Target
            {
                // clips the base and top of the cilinder
                clip(0.999 - abs(IN.normalWS.y));

                float time = _Time.y;
                
                // moving rings
                float wobble = sin((IN.uv.x * _WaveHorizontalFrequency + time * _Speed) * TAU) * _RingWobble;
                float ringPhase = frac((IN.uv.y + wobble) * _RingCount - time * _RingSpeed);
                float ringDistance = abs(ringPhase - 0.5) * 2.0;
                float ring = pow(saturate(1.0 - ringDistance), _RingSharpness);

                // bright packets move along each circular ring
                float highlightPhase = (IN.uv.x * _WaveHorizontalFrequency + IN.uv.y * _WaveVerticalFrequency - time * _Speed) * TAU;
                float highlight = pow(sin(highlightPhase) * 0.5 + 0.5, _HighlightSharpness);
                float ringLight = ring * (0.45 + highlight * _HighlightIntensity);

                // top and bottom fade
                float bottomFade = smoothstep(0.0, _BottomFade, IN.uv.y);
                float topFade = 1.0 - smoothstep(1.0 - _TopFade, 1.0, IN.uv.y);
                float verticalFade = bottomFade * topFade;

                // fresnel effect
                float3 normalWS = normalize(IN.normalWS);
                float3 viewDirectionWS = GetWorldSpaceNormalizeViewDir(IN.positionWS);
                float fresnel = pow(1.0 - saturate(abs(dot(normalWS, viewDirectionWS))), _FresnelPower);

                // final color
                float3 color = _BaseColor.rgb * ringLight;
                color += _RingColor.rgb * ring * highlight * _RingIntensity;
                color += _FresnelColor.rgb * fresnel * ring * _FresnelIntensity;

                float alpha = saturate((ringLight + fresnel * ring * 0.35) * verticalFade * _Opacity);
                clip(alpha - 0.001);

                return float4(color, alpha);
            }
            ENDHLSL
        }
    }
}

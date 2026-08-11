Shader "Custom/S_BuffEffect"
{
    Properties
    {
        [Header(Base)]
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        [Toggle] _IsDebuff("Is Debuff", Float) = 0
        
        [Header(Wave Effect)]
        _Speed("Speed", Range(0,1)) = 0.05
        _WaveHorizontalFrequency("Wave Horizontal Frequency", Range(1, 50)) = 10
        _WaveVerticalFrequency("Wave Vertical Frequency", Range(1, 20)) = 10
        
        [Header(Fresnel Effect)]
        [HDR] _FresnelColor("Fresnel Color", Color) = (0.3, 1, 0.6, 1)
        _FresnelIntensity("Fresnel Intensity", Range(0, 5)) = 1.5
        _FresnelPower("Fresnel Power", Range(0.5, 10)) = 3
        
        [Header(Light Ring)]
        [HDR] _RingColor("Ring Color", Color) = (0.7, 1, 0.85, 1)
        _RingIntensity("Ring Intensity", Range(0, 5)) = 2
        _RingCount("Ring Count", Range(1, 8)) = 2
        _RingSpeed("Ring Speed", Range(0, 3)) = 0.8
        _RingSharpness("Ring Sharpness", Range(1, 16)) = 7
        _RingAlphaBoost("Ring Alpha Boost", Range(0, 1)) = 0.4
    }

    SubShader
    {
        Tags {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Transparent"
            "Queue" = "Transparent"
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
            float _Speed;
            float _WaveHorizontalFrequency;
            float _WaveVerticalFrequency;
            float _IsDebuff;
            float4 _FresnelColor;
            float _FresnelIntensity;
            float _FresnelPower;
            float4 _RingColor;
            float _RingIntensity;
            float _RingCount;
            float _RingSpeed;
            float _RingSharpness;
            float _RingAlphaBoost;

            struct MeshData
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct Interpolators
            {
                float4 vertex : SV_POSITION;
                float3 positionWS : TEXCOORD1;
                float3 normalWS : TEXCOORD0;
                float2 uv : TEXCOORD2;
            };

            Interpolators vert(MeshData IN)
            {
                Interpolators OUT;
                OUT.vertex = TransformObjectToHClip(IN.vertex.xyz);
                OUT.normalWS = TransformObjectToWorldNormal(IN.normal);
                OUT.positionWS = TransformObjectToWorld(IN.vertex.xyz);
                OUT.uv = IN.uv;
                return OUT;
            }

            half4 frag(Interpolators IN) : SV_Target
            {
                // clips the base and top of the cilinder
                clip(0.999f - abs(IN.normalWS.y));
                
                float4 outColor = _BaseColor;
                
                // reduce color alpha as it goes up
                float transparencyGradient = (1 - IN.uv.y);
                
                // creates wave effect
                float yOffset = cos((IN.uv.x) * TAU * floor(_WaveHorizontalFrequency)) * 0.01f;
                float timeOffset = _Time.y * _Speed;
                timeOffset *= _IsDebuff == 1 ? -1 : 1;
                float waveEffect = cos( (IN.uv.y + yOffset - timeOffset) * TAU * floor(_WaveVerticalFrequency) ) * 0.5f + 0.5f;
                
                outColor.xyz *= waveEffect;
                
                // fresnel effect
                float3 normalWS = normalize(IN.normalWS);
                float3 viewDirectionWS = GetWorldSpaceNormalizeViewDir(IN.positionWS);
                float viewNormalDot = saturate(abs(dot(normalWS, viewDirectionWS)));
                float fresnel = pow(1.0 - viewNormalDot, _FresnelPower);
                
                // light ring
                float direction = _IsDebuff == 1 ? -1.0 : 1.0;
                float ringPhase = frac(IN.uv.y * _RingCount - _Time.y * _RingSpeed * direction);
                float ringDistance = abs(ringPhase - 0.5) * 2.0;
                float ring = pow(saturate(1.0 - ringDistance), _RingSharpness);

                outColor.rgb += _RingColor.rgb * ring * _RingIntensity;

                outColor.rgb += _FresnelColor.rgb * fresnel * _FresnelIntensity;
                outColor.a = /*clamp(*/(waveEffect + ring * _RingAlphaBoost) * transparencyGradient;//, 0, 0.25f);
                
                return outColor ;
            }
            ENDHLSL
        }
    }
}
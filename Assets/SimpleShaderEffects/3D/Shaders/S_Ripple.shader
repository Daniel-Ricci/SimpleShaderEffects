Shader "Custom/S_RippleEffect"
{
    Properties
    {
        [Header(Base)]
        [MainColor] _BaseColor("Base Color", Color) = (0.02, 0.2, 0.35, 1)
        [HDR] _RippleColor("Ripple Color", Color) = (0.15, 0.75, 1, 1)
        [HDR] _FresnelColor("Fresnel Color", Color) = (0.1, 0.7, 1, 1)
        _Opacity("Opacity", Range(0, 1)) = 0.7

        [Header(Ripple Shape)]
        [Vector] _RippleCenter("Ripple Center (Local X, Z)", Vector) = (0, 0, 0, 0)
        _WaveAmplitude("Wave Amplitude", Range(0, 0.5)) = 0.08
        _WaveFrequency("Wave Frequency", Range(0.1, 30)) = 8
        _WaveSpeed("Wave Speed", Range(0, 10)) = 2
        _WaveFalloff("Wave Falloff", Range(0, 10)) = 0.8
        _DetailStrength("Detail Strength", Range(0, 1)) = 0.25

        [Header(Ripple Highlights)]
        _CrestSharpness("Crest Sharpness", Range(1, 32)) = 10
        _CrestIntensity("Crest Intensity", Range(0, 5)) = 1.5
        _SpecularIntensity("Specular Intensity", Range(0, 5)) = 1.5
        _SpecularPower("Specular Power", Range(8, 256)) = 96

        [Header(Fresnel)]
        _FresnelIntensity("Fresnel Intensity", Range(0, 5)) = 1
        _FresnelPower("Fresnel Power", Range(0.5, 10)) = 4
    }

    SubShader
    {
        Tags
        {
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

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            #define TAU 6.283185307179586f
            #define NORMAL_SAMPLE_DISTANCE 0.02f

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor;
                float4 _RippleColor;
                float4 _FresnelColor;
                float4 _RippleCenter;

                float _Opacity;
                float _WaveAmplitude;
                float _WaveFrequency;
                float _WaveSpeed;
                float _WaveFalloff;
                float _DetailStrength;

                float _CrestSharpness;
                float _CrestIntensity;
                float _SpecularIntensity;
                float _SpecularPower;

                float _FresnelIntensity;
                float _FresnelPower;
            CBUFFER_END

            struct MeshData
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Interpolators
            {
                float4 vertex : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float2 ripplePosition : TEXCOORD2;
            };

            float GetRipplePhase(float2 positionXZ)
            {
                float distanceFromCenter = length(positionXZ - _RippleCenter.xy);

                // the wave front travels outward because time is subtracted.
                return distanceFromCenter * _WaveFrequency
                    - _Time.y * _WaveSpeed;
            }

            float GetRippleHeight(float2 positionXZ)
            {
                float distanceFromCenter = length(positionXZ - _RippleCenter.xy);
                float phase = GetRipplePhase(positionXZ) * TAU;

                // primary concentric wave.
                float primaryWave = cos(phase);

                // smaller wave makes the ripple less perfectly mathematical.
                float detailWave = sin(
                    phase * 2.17
                    + positionXZ.x * 1.4
                    - _Time.y * _WaveSpeed * 1.5
                ) * _DetailStrength;

                // ripples gradually lose energy away from their source.
                float attenuation = exp(-distanceFromCenter * _WaveFalloff);

                return (primaryWave + detailWave)
                    * _WaveAmplitude
                    * attenuation;
            }

            Interpolators vert(MeshData IN)
            {
                Interpolators OUT;

                float3 positionOS = IN.vertex.xyz;

                // displace the surface vertically.
                positionOS.y += GetRippleHeight(positionOS.xz);

                // sample surrounding wave heights to build an accurate normal.
                float heightLeft = GetRippleHeight(
                    IN.vertex.xz - float2(NORMAL_SAMPLE_DISTANCE, 0)
                );

                float heightRight = GetRippleHeight(
                    IN.vertex.xz + float2(NORMAL_SAMPLE_DISTANCE, 0)
                );

                float heightBack = GetRippleHeight(
                    IN.vertex.xz - float2(0, NORMAL_SAMPLE_DISTANCE)
                );

                float heightForward = GetRippleHeight(
                    IN.vertex.xz + float2(0, NORMAL_SAMPLE_DISTANCE)
                );

                float3 tangentX = normalize(float3(
                    NORMAL_SAMPLE_DISTANCE * 2,
                    heightRight - heightLeft,
                    0
                ));

                float3 tangentZ = normalize(float3(
                    0,
                    heightForward - heightBack,
                    NORMAL_SAMPLE_DISTANCE * 2
                ));

                // tangent order keeps the normal pointing upward.
                float3 normalOS = normalize(cross(tangentZ, tangentX));

                OUT.vertex = TransformObjectToHClip(positionOS);
                OUT.positionWS = TransformObjectToWorld(positionOS);
                OUT.normalWS = TransformObjectToWorldNormal(normalOS);
                OUT.ripplePosition = IN.vertex.xz;

                return OUT;
            }

            half4 frag(Interpolators IN) : SV_Target
            {
                float3 normalWS = normalize(IN.normalWS);
                float3 viewDirectionWS =
                    GetWorldSpaceNormalizeViewDir(IN.positionWS);

                Light mainLight = GetMainLight();
                float3 lightDirectionWS = normalize(mainLight.direction);
                float3 halfDirectionWS =
                    normalize(lightDirectionWS + viewDirectionWS);

                float NdotL = saturate(dot(normalWS, lightDirectionWS));

                float specular = pow(
                    saturate(dot(normalWS, halfDirectionWS)),
                    _SpecularPower
                ) * _SpecularIntensity;

                float fresnel = pow(
                    1.0 - saturate(dot(normalWS, viewDirectionWS)),
                    _FresnelPower
                ) * _FresnelIntensity;

                float ripplePhase = GetRipplePhase(IN.ripplePosition) * TAU;

                // brightest on the upper portion of each wave crest.
                float crest = pow(
                    saturate(cos(ripplePhase) * 0.5 + 0.5),
                    _CrestSharpness
                ) * _CrestIntensity;

                float3 color = _BaseColor.rgb * (0.25 + NdotL * 0.75);
                color += _RippleColor.rgb * crest;
                color += _RippleColor.rgb * specular;
                color += _FresnelColor.rgb * fresnel;

                return half4(color, _BaseColor.a * _Opacity);
            }

            ENDHLSL
        }
    }
}
Shader "Custom/S_ForceField"
{
    Properties
    {
        [Header(Base)]
        _Color ("Color", Color) = (0.2,0.6,1,1)
        [HDR]_EmissionColor ("Emission Color", Color) = (0.2,0.6,2,1)

        [Header(Fresnel Effect)]
        _FresnelPower ("Fresnel Power", Range(0.5,8)) = 4
        _FresnelIntensity ("Fresnel Intensity", Range(0,10)) = 2

        [Header(Band)]
        _BandDensity ("Band Density", Float) = 40
        _BandSpeed ("Band Speed", Float) = 1
        _BandStrength ("Band Strength", Range(0,1)) = 0.5
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline"="UniversalPipeline"
            "RenderType"="Transparent"
            "Queue"="Transparent"
        }

        Blend SrcAlpha One
        ZWrite Off
        Cull Back

        Pass
        {
            Name "Forward"

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct MeshData
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct Interpolators
            {
                float4 vertex : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float2 uv : TEXCOORD2;
            };

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            CBUFFER_START(UnityPerMaterial)
            float4 _Color;
            float4 _EmissionColor;
            float _FresnelPower;
            float _FresnelIntensity;
            float _BandDensity;
            float _BandSpeed;
            float _BandStrength;
            CBUFFER_END

            Interpolators vert(MeshData IN)
            {
                Interpolators OUT;

                float3 pos = IN.vertex.xyz;

                VertexPositionInputs vp = GetVertexPositionInputs(pos);

                OUT.vertex = vp.positionCS;
                OUT.positionWS = vp.positionWS;
                OUT.normalWS = TransformObjectToWorldNormal(IN.normal);
                OUT.uv = IN.uv;

                return OUT;
            }

            half4 frag(Interpolators IN) : SV_Target
            {
                float3 N = normalize(IN.normalWS);
                float3 V = normalize(GetCameraPositionWS() - IN.positionWS);

                float fresnel = pow(1.0 - saturate(dot(N, V)), _FresnelPower);
                fresnel *= _FresnelIntensity;

                float bands = sin(IN.positionWS.y * _BandDensity + _Time.y * _BandSpeed);
                bands = lerp(1.0, bands * 0.5 + 0.5, _BandStrength);

                float mask = saturate(fresnel * bands);

                float3 emission = _EmissionColor.rgb * mask;
                float alpha = mask;

                return float4(emission + _Color.rgb * 0.35, alpha);
            }

            ENDHLSL
        }
    }
}

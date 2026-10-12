Shader "Custom/S_OutlineEffect"
{
    Properties
    {
        [Header(Base)]
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)

        [Header(Outline)]
        [HDR] _OutlineColor("Outline Color", Color) = (0, 0, 0, 1)
        _OutlineWidth("Outline Width", Range(0.01, 1)) = 0.3
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "Queue" = "Geometry"
            "RenderPipeline" = "UniversalPipeline"
        }

        // URP renders this single pass reliably without requiring a Renderer Feature.
        Pass
        {
            Name "ForwardUnlit"
            Tags { "LightMode" = "SRPDefaultUnlit" }
            Cull Back
            ZWrite On

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor;
                float4 _OutlineColor;
                float _OutlineWidth;
            CBUFFER_END

            struct MeshData
            {
                float4 vertex : POSITION;
                float3 normals : NORMAL;
            };

            struct Interpolators
            {
                float4 vertex : SV_POSITION;
                float3 normalWS : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
            };

            Interpolators vert(MeshData IN)
            {
                Interpolators OUT;
                OUT.vertex = TransformObjectToHClip(IN.vertex.xyz);
                OUT.normalWS = TransformObjectToWorldNormal(IN.normals);
                OUT.positionWS = TransformObjectToWorld(IN.vertex.xyz);
                return OUT;
            }

            half4 frag(Interpolators IN) : SV_Target
            {
                float3 normalWS = normalize(IN.normalWS);
                float3 viewDirectionWS = GetWorldSpaceNormalizeViewDir(IN.positionWS);

                // Near the silhouette, normal and view direction are perpendicular.
                float fresnel = 1.0 - saturate(dot(normalWS, viewDirectionWS));
                float outline = smoothstep(1.0 - _OutlineWidth * 2, 1.0, fresnel);

                return lerp(_BaseColor, _OutlineColor, outline);
            }
            ENDHLSL
        }
    }
}

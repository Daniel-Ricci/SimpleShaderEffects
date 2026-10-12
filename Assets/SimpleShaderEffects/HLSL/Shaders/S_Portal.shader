Shader "Custom/S_Portal"
{
    Properties
    {
        [HDR] _InnerColor ("Inner Color", Color) = (0,0.5,1,1)
        [HDR] _OuterColor ("Outer Color", Color) = (0.7,0,1,1)
        _SwirlSpeed ("Swirl Speed", Range(0,10)) = 2
    }

    SubShader
    {
        Tags
        {
            "RenderType"="Transparent"
            "Queue"="Transparent"
        }

        Blend One One
        Cull Off
        ZWrite Off

        Pass
        {
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct MeshData
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Interpolators
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            float4 _InnerColor;
            float4 _OuterColor;
            float _SwirlSpeed;

            Interpolators vert(MeshData v)
            {
                Interpolators o;
                o.vertex = TransformObjectToHClip(v.vertex);
                o.uv = v.uv;
                return o;
            }

            float4 frag(Interpolators i) : SV_Target
            {
                float2 uv = i.uv;

                //----------------------------------
                // Center UVs around (0,0)
                //----------------------------------

                float2 p = uv - 0.5;

                float r = length(p);
                float angle = atan2(p.y, p.x);

                //----------------------------------
                // Swirl
                //----------------------------------

                angle += r * 8;
                angle += _Time.y * _SwirlSpeed;

                //----------------------------------
                // Energy bands
                //----------------------------------

                float bands =
                    sin(angle * 8 - _Time.y * 5) * 0.5 + 0.5;

                bands +=
                    sin(r * 30 - _Time.y * 8) * 0.5 + 0.5;

                bands *= 0.5;

                //----------------------------------
                // Portal body
                //----------------------------------

                float portal =
                    smoothstep(0.5, 0.0, r);

                //----------------------------------
                // Pulsing core
                //----------------------------------

                float core =
                    smoothstep(0.15, 0.0, r);

                core *=
                    1 + sin(_Time.y * 4) * 0.5;

                //----------------------------------
                // Color blend
                //----------------------------------

                float3 color =
                    lerp(_InnerColor.rgb,
                         _OuterColor.rgb,
                         bands);

                color *= portal;

                color += core * _InnerColor.rgb;

                //----------------------------------
                // Fade outside circle
                //----------------------------------

                float alpha =
                    smoothstep(0.5, 0.45, r);

                return float4(color, alpha);
            }

            ENDHLSL
        }
    }
}
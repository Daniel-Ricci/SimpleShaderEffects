Shader "Custom/S_WindFlagEffect"
{
    Properties
    {
        [Header(Main Texture)]
        [NoScaleOffset] _MainTex ("Texture", 2D) = "white" {}

        [Header(Wind)]
        [Vector] _WindDirection("Wind Direction (Local X, Local Y)", Vector) = (0, 1, 0, 0)
        _Speed("Speed", Range(0, 3)) = 1
        _WindStrength("Wind Strength", Range(0, 0.5)) = 0.2

        [Header(Flag Shape)]
        _PoleStiffness("Pole Stiffness", Range(0.5, 6)) = 2

        [Header(Waves)]
        _WaveFrequency("Wave Frequency", Range(0.1, 8)) = 1.5
        _SecondaryWaveStrength("Secondary Wave Strength", Range(0, 1)) = 0.35
        _GustStrength("Gust Strength", Range(0, 1)) = 0.25
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
        }

        Pass
        {
            Cull Off

            HLSLPROGRAM

            #define TAU 6.283185307179586f

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            sampler2D _MainTex;
            float4 _WindDirection;
            float _Speed;
            float _WindStrength;
            float _PoleStiffness;
            float _WaveFrequency;
            float _SecondaryWaveStrength;
            float _GustStrength;

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

            Interpolators vert(MeshData IN)
            {
                Interpolators OUT;
                
                float distanceFromPole = saturate((IN.vertex.x + 1.0) * 0.5);

                // the pole stays rigid; movement increases toward the loose edge.
                float freeEdgeMask = pow(distanceFromPole, _PoleStiffness);

                float2 windInput = _WindDirection.xy;
                float windLength = length(windInput);

                // Local Y points away from the surface on this rotated quad.
                float2 windDirection = windLength > 0.0001
                    ? windInput / windLength
                    : float2(0.0, 1.0);

                float time = _Time.y * _Speed;

                // Main broad wave moving from pole toward the free edge.
                float primaryPhase =
                    (distanceFromPole * _WaveFrequency - time) * TAU;

                float primaryWave = sin(primaryPhase);

                // Smaller wave adds uneven cloth-like movement.
                // Local Z varies along the flag's height for this mesh.
                float secondaryPhase =
                    (distanceFromPole * _WaveFrequency * 2.37
                    + IN.vertex.z * 0.75
                    - time * 1.6) * TAU;

                float secondaryWave =
                    sin(secondaryPhase) * _SecondaryWaveStrength;

                // Slow gusts stop the wind from having constant strength.
                float gust =
                    1.0 + sin(time * 0.45) * _GustStrength;

                float wave =
                    (primaryWave + secondaryWave)
                    * gust
                    * freeEdgeMask;

                // This quad is oriented so its cloth motion uses local X and Y.
                // Set Wind Direction to (0, 1) for normal outward/inward wind.
                float3 windOffset =
                    float3(windDirection.x, windDirection.y, 0.0)
                    * wave
                    * _WindStrength;

                IN.vertex.xyz += windOffset;

                OUT.vertex = TransformObjectToHClip(IN.vertex.xyz);
                OUT.uv = IN.uv;

                return OUT;
            }

            half4 frag(Interpolators IN) : SV_Target
            {
                float2 remap_uv = IN.uv + 0.5;
                return tex2D(_MainTex, remap_uv);
            }

            ENDHLSL
        }
    }
}
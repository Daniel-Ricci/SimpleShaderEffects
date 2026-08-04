Shader "Custom/S_TeleportEffect"
{
    Properties
    {
        [Header(Base)]
        [MainColor] _BaseColor("Base Color", Color) = (0.02, 0.55, 0.9, 1)
        [HDR] _EmissionColor("Emission Color", Color) = (0.1, 0.85, 1, 1)
        _Opacity("Opacity", Range(0, 1)) = 0.55

        [Header(Teleport Beam)]
        _Speed("Speed", Range(0, 3)) = 1
        _BeamIntensity("Beam Intensity", Range(0, 5)) = 1.5
        _BeamPulseFrequency("Beam Pulse Frequency", Range(0, 12)) = 3
        _BottomFade("Bottom Fade", Range(0.001, 0.5)) = 0.08
        _TopFade("Top Fade", Range(0.001, 0.5)) = 0.08

        [Header(Travelling Rings)]
        _RingCount("Ring Count", Range(1, 16)) = 8
        _RingSpeed("Ring Speed", Range(0, 4)) = 1.2
        _RingSharpness("Ring Sharpness", Range(1, 32)) = 14
        _RingIntensity("Ring Intensity", Range(0, 5)) = 2.5
        _RingWobble("Ring Wobble", Range(0, 0.1)) = 0.015

        [Header(Bottom Portal)]
        _BaseRadius("Base Radius", Range(0.01, 2)) = 0.5
        _PortalRingCount("Portal Ring Count", Range(1, 8)) = 3
        _PortalRingSpeed("Portal Ring Speed", Range(0, 3)) = 0.45
        _PortalRingSharpness("Portal Ring Sharpness", Range(1, 32)) = 12
        _PortalIntensity("Portal Intensity", Range(0, 5)) = 2.5

        [Header(Fresnel Effect)]
        _FresnelIntensity("Fresnel Intensity", Range(0, 5)) = 1.2
        _FresnelPower("Fresnel Power", Range(0.5, 10)) = 4
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
            float4 _EmissionColor;
            float _Opacity;
            float _Speed;
            float _BeamIntensity;
            float _BeamPulseFrequency;
            float _BottomFade;
            float _TopFade;
            float _RingCount;
            float _RingSpeed;
            float _RingSharpness;
            float _RingIntensity;
            float _RingWobble;
            float _BaseRadius;
            float _PortalRingCount;
            float _PortalRingSpeed;
            float _PortalRingSharpness;
            float _PortalIntensity;
            float _FresnelIntensity;
            float _FresnelPower;

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
                float3 positionOS : TEXCOORD2;
                float3 normalOS : TEXCOORD3;
                float2 uv : TEXCOORD4;
            };

            Interpolators vert(MeshData IN)
            {
                Interpolators OUT;
                OUT.vertex = TransformObjectToHClip(IN.vertex.xyz);
                OUT.normalWS = TransformObjectToWorldNormal(IN.normals);
                OUT.positionWS = TransformObjectToWorld(IN.vertex.xyz);
                OUT.positionOS = IN.vertex.xyz;
                OUT.normalOS = IN.normals;
                OUT.uv = IN.uv;
                return OUT;
            }

            half4 frag(Interpolators IN) : SV_Target
            {
                float time = _Time.y;

                // a cylinder has side faces, a top cap, and a bottom cap.
                // keep the side and bottom cap, but discard the top cap completely.
                float isCap = step(0.999, abs(IN.normalOS.y));
                float isBottomCap = step(0.999, -IN.normalOS.y);
                float isSide = 1.0 - isCap;

                // vertical beam with a subtle scrolling pulse.
                float beamPulse = sin((IN.uv.y * _BeamPulseFrequency - time * _Speed) * TAU) * 0.5 + 0.5;
                float bottomFade = smoothstep(0.0, _BottomFade, IN.uv.y);
                float topFade = 1.0 - smoothstep(1.0 - _TopFade, 1.0, IN.uv.y);
                float beam = (0.7 + beamPulse * 0.3) * bottomFade * topFade;

                // narrow rings repeatedly climb the side of the cylinder.
                float wobble = sin((IN.uv.x * 8.0 + time * _Speed) * TAU) * _RingWobble;
                float ringPhase = frac((IN.uv.y + wobble) * _RingCount - time * _RingSpeed);
                float ringDistance = abs(ringPhase - 0.5) * 2.0;
                float sideRing = pow(saturate(1.0 - ringDistance), _RingSharpness);

                // the bottom cap uses object-space XZ position, which gives a real radial portal.
                float radialDistance = length(IN.positionOS.xz) / max(_BaseRadius, 0.001);
                float portalPhase = frac(radialDistance * _PortalRingCount - time * _PortalRingSpeed);
                float portalDistance = abs(portalPhase - 0.5) * 2.0;
                float portalRing = pow(saturate(1.0 - portalDistance), _PortalRingSharpness);
                float portalCenter = pow(saturate(1.0 - radialDistance), 3.0) * 0.35;
                float portal = (portalRing + portalCenter) * step(radialDistance, 1.0);

                float3 normalWS = normalize(IN.normalWS);
                float3 viewDirectionWS = GetWorldSpaceNormalizeViewDir(IN.positionWS);
                float fresnel = pow(1.0 - saturate(abs(dot(normalWS, viewDirectionWS))), _FresnelPower);

                float sideLight = beam * _BeamIntensity + sideRing * _RingIntensity + fresnel * beam * _FresnelIntensity;
                float bottomLight = portal * _PortalIntensity;
                float3 color = _BaseColor.rgb * sideLight * isSide;
                color += _EmissionColor.rgb * (sideRing * _RingIntensity + fresnel * beam * _FresnelIntensity) * isSide;
                color += (_BaseColor.rgb + _EmissionColor.rgb) * bottomLight * isBottomCap;

                float alpha = (beam * 0.28 + sideRing * 0.5 + fresnel * beam * 0.2) * isSide;
                alpha += portal * 0.65 * isBottomCap;
                alpha = saturate(alpha * _Opacity);
                clip(alpha - 0.001);

                return half4(color, alpha);
            }
            ENDHLSL
        }
    }
}

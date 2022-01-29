Shader "Custom/RenderFeature/RayMarchVolumetricLight"
{
    Properties
    {
        _NoiseTex("NoiseTex", 2D) = "black" {}
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }

        Pass
        {
            HLSLPROGRAM

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma shader_feature _RAYLEIGH
            //#pragma multi_compile _ SHADOWS_SHADOWMASK

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            float4x4 _InvVP;
            int _SampleCount;
            half _MaxRayDistance;
            half _g;
            half _ExtinctionMie;
            half _ExtinctionRayleigh;
            half _FinalScale;
            half _NoiseScale;
            half _NoiseIntensity;

            TEXTURE2D(_NoiseTex);
            SAMPLER(sampler_point_repeat_noise);
            float4 _NoiseTex_ST;

            struct Attributes
            {
                float4 positionOS   : POSITION;
            };

            struct Varyings
            {
                float4 positionNDC : TEXCOORD0;
                float4 positionCS  : SV_POSITION;
            };

            half3 TransformPositionNDCToWorld(float2 positionNDC)
            {
                float depth = SampleSceneDepth(positionNDC);
                float4 ndc = float4(positionNDC,1.0,1.0) * 2 - 1;
                half IsGL = step(UNITY_NEAR_CLIP_VALUE,0);
                ndc.z = depth * (IsGL + 1) - IsGL ; //GL_NDC -1-1 DX_NDC 1-0
                
                float eyeDepth = LinearEyeDepth(depth,_ZBufferParams);
                half3 positionWS = mul(_InvVP,ndc * eyeDepth);
                return positionWS;
            }

            half MiePhase(half cos, half g)
		    {
                half g2 = g * g;
                return (1 - g2)/pow((12.56 * (1 + g2 - 2 * g * cos)),1.5); 			
		    }

            half RayleighPhase(half cos)
            {
                return 0.05968 * (1.0 + cos * cos);
            }

            half RayMarchShadowAttention(float2 positionNDC)
            {
                Light mainLight = GetMainLight();
                half3 cameraPosWS = GetCameraPositionWS();
                half3 positionWS = TransformPositionNDCToWorld(positionNDC);
 
                half3 rayDir = positionWS - cameraPosWS;
                half3 rayDirLength = length(rayDir);
                rayDir /= rayDirLength;
                half rayLength = min(_MaxRayDistance,rayDirLength);
                half stepSize = rayLength / _SampleCount;
                half cos = dot(mainLight.direction,-rayDir);
                float2 noiseUV = TRANSFORM_TEX(float2(positionNDC.x,positionNDC.y * _ScreenParams.y/_ScreenParams.x),_NoiseTex);
                half noise = SAMPLE_TEXTURE2D(_NoiseTex,sampler_point_repeat_noise,noiseUV * _NoiseScale).r * _NoiseIntensity;
                noise = 1.0 - noise;
                half3 rayEndPosition = cameraPosWS + rayDir * stepSize * noise;

                half extinction;
                half extinctionCoef;
                half phase;
#ifndef _RAYLEIGH
                extinction = rayLength * _ExtinctionMie;
                extinctionCoef = _ExtinctionMie;
                phase = MiePhase(cos,_g);
#else
                extinction = rayLength * _ExtinctionRayleigh;
                extinctionCoef = _ExtinctionRayleigh;
                phase = RayleighPhase(cos);
#endif
                half FinalAtten = 0;
                [loop]
                for(int i = 0; i< _SampleCount; ++i)
                {
                    half atten = MainLightRealtimeShadow(TransformWorldToShadowCoord(rayEndPosition));
                    extinction += extinctionCoef * stepSize;
                    FinalAtten += atten * exp(-extinction);
                    rayEndPosition += rayDir * stepSize * noise;
                }
                
                FinalAtten *= phase * stepSize * _FinalScale;
                return FinalAtten;
            }

            Varyings vert(Attributes input)
            {
                Varyings output = (Varyings)0;

                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                output.positionCS = vertexInput.positionCS;
                output.positionNDC = vertexInput.positionNDC;
                return output;
            }

            // The fragment shader definition.
            half4 frag(Varyings input) : SV_Target
            {
                return RayMarchShadowAttention(input.positionNDC.xy);
            }
            ENDHLSL
        }
    }
}


Shader "Custom/RenderFeature/BlitAdd"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            HLSLPROGRAM
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            
            #pragma vertex vert
            #pragma fragment frag

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            TEXTURE2D(_VolumetricLightTexture);
            SAMPLER(sampler_VolumetricLightTexture);

            struct Attributes 
            {
                float4 positionOS : POSITION;
                float2 texcoord : TEXCOORD0;
            };
        
            struct Varyings 
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };
            
            Varyings vert(Attributes input) 
            {
                Varyings output = (Varyings)0;
	
                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                output.positionCS = vertexInput.positionCS;

                output.uv = input.texcoord;
                return output;
            }
			
			half4 frag(Varyings input) : SV_Target
			{
                
                half4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
			    half mask = SAMPLE_TEXTURE2D(_VolumetricLightTexture, sampler_VolumetricLightTexture, input.uv).r;
                mask = 3 * mask * mask - 2 * mask * mask * mask; //smoothstep
                color.rgb += mask * GetMainLight().color;

                return color;
			}
            ENDHLSL
        }
    }
}

Shader "Custom/RenderFeature/Blur"
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
            float4 _MainTex_TexelSize;
            half _blurOffset;

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
                int i = _blurOffset;
                
                half mask = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv).r ;
			    mask += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv + float2( 0, i ) * _MainTex_TexelSize.xy).r;
                mask += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv + float2( i, 0 ) * _MainTex_TexelSize.xy).r;
                mask += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv + float2( -i, 0 ) * _MainTex_TexelSize.xy).r;
                mask += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv + float2( 0, -i ) * _MainTex_TexelSize.xy).r;

                return mask / 5.0;
			}
            ENDHLSL
        }

        Pass
        {
            HLSLPROGRAM
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            
            #pragma vertex vert
            #pragma fragment frag

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            float4 _MainTex_TexelSize;
            half _blurOffset;

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
                int i = _blurOffset;
                
                half mask = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv).r ;
			    mask += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv + float2( i, i ) * _MainTex_TexelSize.xy).r;
                mask += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv + float2( i, -i ) * _MainTex_TexelSize.xy).r;
                mask += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv + float2( -i, i ) * _MainTex_TexelSize.xy).r;
                mask += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv + float2( -i, -i ) * _MainTex_TexelSize.xy).r;
                
                return mask / 5.0;
			}
            ENDHLSL
        }
    }
}

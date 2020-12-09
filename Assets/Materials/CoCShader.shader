Shader "DOF/CoC"
{
    Properties
    {
        _NearBlurRadius("Near blur radius", Range(0, 9)) = 9
        _FarBlurRadius("Far blur radius", Range(0, 4)) = 4
        _NearStart("Near start", Float) = 0.3
        _NearEnd("Near end", Float) = 10
        _FarStart("Far start", Float) = 100
        _FarEnd("Far end", Float) = 1000

        [HideInInspector] _MainTex("Main tex", 2D) = "white"
    }

    HLSLINCLUDE

        #pragma target 3.5

        // 9-tap Gaussian blur offsets and weights. Requires only five texture
        // fetches by sampling between pixels and taking advantage of bilinear filtering.
        // http://rastergrid.com/blog/2010/09/efficient-gaussian-blur-with-linear-sampling
        const static float g_tapCount = 3;
        const static float g_offset[3] = { 0.0, 1.3846153846, 3.2307692308 };
        const static float g_weight[3] = { 0.2270270270, 0.3162162162, 0.0702702703 };

    ENDHLSL

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalRenderPipeline" }

        Pass
        {
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"     
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"       

            struct Attributes {
                float4 positionOS : POSITION;
                float2 texCoords  : TEXCOORD;            
            };

            struct Varyings {
                float4 positionHCS  : SV_POSITION;
                float2 texCoords : TEXCOORD;
            };

            CBUFFER_START(UnityPerMaterial)
                float _NearBlurRadius;
                float _FarBlurRadius;
                float _NearStart;
                float _NearEnd;
                float _FarStart;
                float _FarEnd;
                float _FullWidth;
                float _FullHeight;
            CBUFFER_END

            Varyings vert(Attributes IN) {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.texCoords = IN.texCoords;
                return OUT;
            }
           
            half4 frag(Varyings IN) : SV_Target {
                float depth = SampleSceneDepth(IN.texCoords);
                depth = LinearEyeDepth(depth, _ZBufferParams);

                // DOF determined by lerp between key values specified by artistic control 
                // rather than physical plausibility (i.e. thin lens equation).
                float coc = 0;
                if (depth < _NearEnd) {
                    float t = saturate((depth - _NearStart) / (_NearEnd - _NearStart));
                    coc = lerp(_NearBlurRadius, 0, t);
                } else if (depth > _FarStart && depth < _FarEnd) {
                    float t = saturate((depth - _FarStart) / (_FarEnd - _FarStart));
                    coc = lerp(0, _FarBlurRadius, t);
                }
                float normalizedCoc = coc / max(_NearBlurRadius, _FarBlurRadius);

                // SampleSceneColor requires the 'Opaque Texture' option to be enabled in 
                // the URP pipeline asset.
                float4 offsets = float4(-1 / _FullWidth, 1 / _FullWidth, -1 / _FullHeight, 1 / _FullHeight);
                float3 color = 0; 
                float weight = 0.25;
                color += weight * SampleSceneColor(IN.texCoords + offsets.xz);
                color += weight * SampleSceneColor(IN.texCoords + offsets.xw);
                color += weight * SampleSceneColor(IN.texCoords + offsets.yz);
                color += weight * SampleSceneColor(IN.texCoords + offsets.yw);
                
                return half4(color.r, color.g, color.b, normalizedCoc);
            }

            ENDHLSL
        }

        // Horizontal Gaussian blur
        Pass
        {
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes {
                float4 positionOS : POSITION;
                float2 texCoords  : TEXCOORD;            
            };

            struct Varyings {
                float4 positionHCS  : SV_POSITION;
                float2 texCoords : TEXCOORD;
            };

            CBUFFER_START(UnityPerMaterial)
                float _Width;
            CBUFFER_END

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);  

            Varyings vert(Attributes IN) {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.texCoords = IN.texCoords;
                return OUT;
            }
           
            half4 frag(Varyings IN) : SV_Target {
                // Sample our own color.
                half4 color = g_weight[0] * SAMPLE_TEXTURE2D_X(_MainTex, sampler_MainTex, IN.texCoords);

                // Gather neighboring colors.
                for (int i = 1; i < g_tapCount; i++) {
                    color += g_weight[i] * SAMPLE_TEXTURE2D_X(_MainTex, sampler_MainTex,
                        IN.texCoords + float2(g_offset[i] / _Width, 0));

                    color += g_weight[i] * SAMPLE_TEXTURE2D_X(_MainTex, sampler_MainTex,
                        IN.texCoords - float2(g_offset[i] / _Width, 0));
                }

                return color;
            }

            ENDHLSL
        }

        // Vertical Gaussian blur
        Pass
        {
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes {
                float4 positionOS : POSITION;
                float2 texCoords  : TEXCOORD0;            
            };

            struct Varyings {
                float4 positionHCS  : SV_POSITION;
                float2 texCoords : TEXCOORD0;
            };

            CBUFFER_START(UnityPerMaterial)
                float _Height;
            CBUFFER_END

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);  

            Varyings vert(Attributes IN) {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.texCoords = IN.texCoords;
                return OUT;
            }
           
            half4 frag(Varyings IN) : SV_Target {
                // Sample our own color.
                half4 color = g_weight[0] * SAMPLE_TEXTURE2D_X(_MainTex, sampler_MainTex, IN.texCoords);

                // Gather neighboring colors.
                for (int i = 1; i < g_tapCount; i++) {
                    color += g_weight[i] * SAMPLE_TEXTURE2D_X(_MainTex, sampler_MainTex,
                        IN.texCoords + float2(0, g_offset[i] / _Height));

                    color += g_weight[i] * SAMPLE_TEXTURE2D_X(_MainTex, sampler_MainTex,
                        IN.texCoords - float2(0, g_offset[i] / _Height));
                }

                return color;
            }

            ENDHLSL
        }

        // Silhoutte fixing. Blurs neighboring foreground CoC to pixels behind it, 
        // taking max of neighbor CoC and self CoC.
        Pass
        {
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes {
                float4 positionOS : POSITION;
                float2 texCoords  : TEXCOORD0;            
            };

            struct Varyings {
                float4 positionHCS  : SV_POSITION;
                float2 texCoords : TEXCOORD0;
            };

            TEXTURE2D(_DownsampledCoc);
            SAMPLER(sampler_DownsampledCoc);  

            TEXTURE2D(_BlurredCoc);
            SAMPLER(sampler_BlurredCoc);  

            Varyings vert(Attributes IN) {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.texCoords = IN.texCoords;
                return OUT;
            }
           
            half4 frag(Varyings IN) : SV_Target { 
                half4 blurred = SAMPLE_TEXTURE2D_X(_BlurredCoc, sampler_BlurredCoc, IN.texCoords);   
                half4 downsampled = SAMPLE_TEXTURE2D_X(_DownsampledCoc, sampler_DownsampledCoc, IN.texCoords);
                
                float thisCoc = downsampled.a;
                float estimatedNeighborCoc = 2 * blurred.a - downsampled.a;
                float correctedCoc = max(thisCoc, estimatedNeighborCoc); 
                
                return half4(downsampled.rgb, correctedCoc);
            }

            ENDHLSL
        }

        // Small blur to remove discontinuities from previous pass.
        Pass
        {
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes {
                float4 positionOS : POSITION;
                float2 texCoords  : TEXCOORD0;            
            };

            struct Varyings {
                float4 positionHCS  : SV_POSITION;
                float2 texCoords : TEXCOORD0;
            };

            CBUFFER_START(UnityPerMaterial)
                float _Width;
                float _Height;
            CBUFFER_END

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);  

            Varyings vert(Attributes IN) {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.texCoords = IN.texCoords;
                return OUT;
            }
           
            half4 frag(Varyings IN) : SV_Target { 
                float4 offsets = float4(-0.5 / _Width, 0.5 / _Width, -0.5 / _Height, 0.5 / _Height);
                float4 color = 0; 
                float weight = 0.25;
                color += weight * SAMPLE_TEXTURE2D_X(_MainTex, sampler_MainTex, IN.texCoords + offsets.xz);
                color += weight * SAMPLE_TEXTURE2D_X(_MainTex, sampler_MainTex, IN.texCoords + offsets.xw);
                color += weight * SAMPLE_TEXTURE2D_X(_MainTex, sampler_MainTex, IN.texCoords + offsets.yz);
                color += weight * SAMPLE_TEXTURE2D_X(_MainTex, sampler_MainTex, IN.texCoords + offsets.yw);
                return color;
            }

            ENDHLSL
        }

        // Composite source image, small, medium, and large blurs into final
        // image with DoF. (Approximates variable size blur with lerp between
        // the four images).
        Pass
        {
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes {
                float4 positionOS : POSITION;
                float2 texCoords  : TEXCOORD0;            
            };

            struct Varyings {
                float4 positionHCS  : SV_POSITION;
                float2 texCoords : TEXCOORD0;
            };

            CBUFFER_START(UnityPerMaterial)
                float _NearBlurRadius;
                float _FarBlurRadius;
                float _FullWidth;
                float _FullHeight;
            CBUFFER_END

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);  

            TEXTURE2D(_MediumBlur);
            SAMPLER(sampler_MediumBlur);

            TEXTURE2D(_LargeBlur);
            SAMPLER(sampler_LargeBlur);

            Varyings vert(Attributes IN) {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.texCoords = IN.texCoords;
                return OUT;
            }

            float4 sampleWithOffset(float2 texCoords, float x, float y) {
                texCoords += float2(x / _FullWidth, y / _FullHeight);
                return SAMPLE_TEXTURE2D_X(_MainTex, sampler_MainTex, texCoords);
            }

            half3 SmallBlur(float2 texCoords) {
                half3 color = 0;
                float weight = (4.0 / 17);
                color += (1.0 / 17) * sampleWithOffset(texCoords, 0, 0).rgb;
                color += weight * sampleWithOffset(texCoords, 0.5, -1.5).rgb;
                color += weight * sampleWithOffset(texCoords, -1.5, -0.5).rgb;
                color += weight * sampleWithOffset(texCoords, -0.5, 1.5).rgb;
                color += weight * sampleWithOffset(texCoords, 1.5, 0.5).rgb;
                return color;
            }
           
            half4 InterpolateDoF(float3 sharp, float3 small, float3 medium, float3 large, float t) {
                float d0 = 0.33, d1 = 0.66, d2 = 1;
                if (t < d0) {
                    return half4(lerp(sharp, small, t / d0), 1.0);
                } else if (t < d1) {
                    return half4(lerp(small, medium, (t - d0) / (d1 - d0)), 1.0);
                } else {
                    return half4(lerp(medium, large, (t - d1) / (d2 - d1)), 1.0);
                }
            }

            half4 frag(Varyings IN) : SV_Target { 
                float3 sharp = SAMPLE_TEXTURE2D_X(_MainTex, sampler_MainTex, IN.texCoords).rgb;
                float3 small = SmallBlur(IN.texCoords);
                float4 medium = SAMPLE_TEXTURE2D_X(_MediumBlur, sampler_MediumBlur, IN.texCoords);
                float3 large = SAMPLE_TEXTURE2D_X(_LargeBlur, sampler_LargeBlur, IN.texCoords).rgb;
                
                float coc = medium.a;
                return InterpolateDoF(sharp, small, medium.rgb, large, coc);
            }

            ENDHLSL
        }
    }
}
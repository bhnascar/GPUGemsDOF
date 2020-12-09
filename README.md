# GPUGemsDOF

A short Unity implementation of the [depth-of-field shader from GPU Gems 3](https://developer.nvidia.com/gpugems/gpugems3/part-iv-image-effects/chapter-28-practical-post-process-depth-field). Written as a [ScriptableRenderFeature](https://docs.unity3d.com/Packages/com.unity.render-pipelines.universal@7.3/api/UnityEngine.Rendering.Universal.ScriptableRendererFeature.html) for URP.

Not a line for line reproduction of the shaders in the source article (for example this uses some URP shader macros where appropriate), but faithful to the overall algorithm.

![DOF thumbnail](https://github.com/bhnascar/GPUGemsDOF/blob/master/thumbnail.png)

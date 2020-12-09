using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Experimental.Rendering;

public class DoFRenderPass : ScriptableRenderPass
{
  string tag;
  Material materialToBlit;

  RenderTargetIdentifier cameraColorTarget;
  RenderTexture cameraTextureCopy;
  RenderTexture downsampledCocTarget;
  RenderTexture tmpBlurTarget;
  RenderTexture blurredCocTarget;
  RenderTexture cocTarget;

  public DoFRenderPass(string tag, RenderPassEvent renderPassEvent, Material materialToBlit)
  {
    this.tag = tag;
    this.renderPassEvent = renderPassEvent;
    this.materialToBlit = materialToBlit;
  }

  public void Setup(RenderTargetIdentifier cameraColorTarget)
  {
    this.cameraColorTarget = cameraColorTarget;
  }

  public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
  {
    var downsampledDescriptor = cameraTextureDescriptor;
    downsampledDescriptor.width = cameraTextureDescriptor.width / 4;
    downsampledDescriptor.height = cameraTextureDescriptor.height / 4;
    downsampledDescriptor.graphicsFormat = GraphicsFormat.R8G8B8A8_SRGB;

    cameraTextureCopy = RenderTexture.GetTemporary(cameraTextureDescriptor);
    downsampledCocTarget = RenderTexture.GetTemporary(downsampledDescriptor);
    tmpBlurTarget = RenderTexture.GetTemporary(downsampledDescriptor);
    blurredCocTarget = RenderTexture.GetTemporary(downsampledDescriptor);
    cocTarget = RenderTexture.GetTemporary(downsampledDescriptor);

    cameraTextureCopy.filterMode = FilterMode.Bilinear;
    downsampledCocTarget.filterMode = FilterMode.Bilinear;
    tmpBlurTarget.filterMode = FilterMode.Bilinear;
    blurredCocTarget.filterMode = FilterMode.Bilinear;
    cocTarget.filterMode = FilterMode.Bilinear;
  }

  public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
  {
    CommandBuffer cmd = CommandBufferPool.Get(tag);
    cmd.Clear();

    cmd.SetGlobalInt("_Width", downsampledCocTarget.width);
    cmd.SetGlobalInt("_Height", downsampledCocTarget.height);
    cmd.SetGlobalInt("_FullWidth", 4 * downsampledCocTarget.width);
    cmd.SetGlobalInt("_FullHeight", 4 * downsampledCocTarget.height);

    // Calculate CoC and downsample.
    cmd.Blit(cameraColorTarget, cameraTextureCopy);
    cmd.Blit(cameraTextureCopy, downsampledCocTarget, materialToBlit, 0);

    // Two-pass Gaussian blur (horizontal then vertical).
    cmd.Blit(downsampledCocTarget, tmpBlurTarget, materialToBlit, 1);
    cmd.Blit(tmpBlurTarget, blurredCocTarget, materialToBlit, 2);

    // Fix foreground silhouettes.
    // Note: |CommandBuffer.SetGlobalTexture| appears to not work when there are
    // *any* global properties exposed in the Properties block of the material shader.
    materialToBlit.SetTexture("_DownsampledCoc", downsampledCocTarget);
    materialToBlit.SetTexture("_BlurredCoc", blurredCocTarget);
    cmd.Blit(cameraTextureCopy, tmpBlurTarget, materialToBlit, 3);

    // Apply small blur to fix discontinuities.
    cmd.Blit(tmpBlurTarget, cocTarget, materialToBlit, 4);

    // Blit final composited image to camera texture.
    // Note: Sharp texture provided by |cameraColorTarget|. Small blur computed
    // in fragment shader.
    materialToBlit.SetTexture("_MediumBlur", cocTarget);
    materialToBlit.SetTexture("_LargeBlur", blurredCocTarget);
    cmd.Blit(cameraTextureCopy, cameraColorTarget, materialToBlit, 5);

    context.ExecuteCommandBuffer(cmd);

    CommandBufferPool.Release(cmd);
  }

  public override void FrameCleanup(CommandBuffer cmd)
  {
    RenderTexture.ReleaseTemporary(cameraTextureCopy);
    RenderTexture.ReleaseTemporary(downsampledCocTarget);
    RenderTexture.ReleaseTemporary(blurredCocTarget);
    RenderTexture.ReleaseTemporary(tmpBlurTarget);
    RenderTexture.ReleaseTemporary(cocTarget);
  }
}


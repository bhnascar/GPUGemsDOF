using UnityEngine;
using UnityEngine.Rendering.Universal;

public class DoFFeature : ScriptableRendererFeature
{
  [System.Serializable]
  public struct CoCSettings
  {
    public bool isEnabled;
    public bool visualize;
    public RenderPassEvent renderPassEvent;
    public Material materialToBlit;
  };

  public CoCSettings settings = new CoCSettings();

  DoFRenderPass renderPass;

  public override void Create()
  {
    renderPass = new DoFRenderPass("coc", settings.renderPassEvent, settings.materialToBlit);
  }

  public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
  {
    if (!settings.isEnabled)
    {
      return;
    }
    renderPass.Setup(renderer.cameraColorTarget);
    renderer.EnqueuePass(renderPass);
  }
}

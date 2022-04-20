using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class RayMarchVolumetricLightFeature : ScriptableRendererFeature
{
    public RenderPassEvent renderPassEvent = RenderPassEvent.AfterRenderingTransparents;
    [Range(1,8)]public int downSample = 2;

    [System.Serializable]
    public class RenderVolumetricLightMaskSetting
    {
        public ScatteringMode scatteringMode;
        public Material material;
        public float maxRayDistance = 100f;
        [Range(16,128)]public int sampleCount = 64;
        [Range(0, 50)] public float FinalIntensity = 5f;

        [Header("Mie")]
        [Range(0, 1)] public float ExtinctionMie = 0.2f;
        [Range(-1, 1)] public float MieG = 0f;

        [Header("Rayleigh")]
        [Range(0, 1)] public float ExtinctionRayleigh = 0.2f;

        [Header("Noise")]
        public float NoiseScale = 100f;
        [Range(0, 1)] public float NoiseIntensity = 1f;

    }

    public enum ScatteringMode
    {
        Mie,
        Rayleigh
    }

    [System.Serializable]
    public class BlurSetting
    {
        public Material material;
        [Range(0,3)]public float blurOffset = 1;

    }

    [System.Serializable]
    public class BlitSetting
    {
        public Material material;
    }

    RenderVolumetricLightMaskPass renderVolumetricLightMaskPass;
    public RenderVolumetricLightMaskSetting renderVolumetricLightMaskSetting = new RenderVolumetricLightMaskSetting();

    BlurPass blurPass;
    public BlurSetting blurSetting = new BlurSetting();

    BlitAddPass blitAddPass;
    public BlitSetting blitSetting = new BlitSetting();

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(renderVolumetricLightMaskPass);
        renderer.EnqueuePass(blurPass);
        renderer.EnqueuePass(blitAddPass);
    }

    public override void Create()
    {
        renderVolumetricLightMaskPass = new RenderVolumetricLightMaskPass(renderVolumetricLightMaskSetting,renderPassEvent,downSample);
        blurPass = new BlurPass(blurSetting,renderPassEvent,downSample);
        blitAddPass = new BlitAddPass(blitSetting, renderPassEvent);
    }

    internal class RenderVolumetricLightMaskPass : ScriptableRenderPass
    {
        int downSample;
        RenderVolumetricLightMaskSetting setting;
        static readonly int volumetricLightMaskId = Shader.PropertyToID("_VolumetricLightTexture");
        const string UseRayleighKeyword = "_RAYLEIGH";

        public RenderVolumetricLightMaskPass(RenderVolumetricLightMaskSetting setting,RenderPassEvent renderPassEvent,int downSample)
        {
            this.setting = setting;
            this.renderPassEvent = renderPassEvent;
            this.downSample = downSample;
        }

        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
        {
            cmd.GetTemporaryRT(volumetricLightMaskId, new RenderTextureDescriptor(Screen.width / downSample, Screen.height / downSample, RenderTextureFormat.R8, 0));
            ConfigureTarget(volumetricLightMaskId);
            ConfigureClear(ClearFlag.All, Color.black);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (setting.material == null)
            {
                Debug.LogError("Missing RenderVolumetricLightMask Material");
                return;
            }
            CommandBuffer cmd = CommandBufferPool.Get("RenderVolumetricLightMaskPass");

            Matrix4x4 projection = GL.GetGPUProjectionMatrix(renderingData.cameraData.camera.projectionMatrix, false);
            Matrix4x4 InvVP = (projection * renderingData.cameraData.camera.worldToCameraMatrix).inverse;
            setting.material.SetMatrix("_InvVP", InvVP);
            setting.material.SetInt("_SampleCount", setting.sampleCount);
            setting.material.SetFloat("_MaxRayDistance", setting.maxRayDistance);
            setting.material.SetFloat("_g", setting.MieG);
            setting.material.SetFloat("_ExtinctionMie", setting.ExtinctionMie);
            setting.material.SetFloat("_ExtinctionRayleigh", setting.ExtinctionRayleigh);
            setting.material.SetFloat("_NoiseScale", setting.NoiseScale);
            setting.material.SetFloat("_NoiseIntensity", setting.NoiseIntensity);
            setting.material.SetFloat("_FinalScale", setting.FinalIntensity);
            CoreUtils.SetKeyword(setting.material, UseRayleighKeyword, setting.scatteringMode == ScatteringMode.Rayleigh);
            cmd.SetViewProjectionMatrices(Matrix4x4.identity, Matrix4x4.identity);
            cmd.DrawMesh(RenderingUtils.fullscreenMesh, Matrix4x4.identity, setting.material, 0);
            cmd.SetViewProjectionMatrices(renderingData.cameraData.camera.worldToCameraMatrix, renderingData.cameraData.camera.projectionMatrix);

            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();
            CommandBufferPool.Release(cmd);

        }

        public override void FrameCleanup(CommandBuffer cmd)
        {
            cmd.ReleaseTemporaryRT(volumetricLightMaskId);
        }
    }

    internal class BlurPass : ScriptableRenderPass
    {
        static readonly int volumetricLightMaskId = Shader.PropertyToID("_VolumetricLightTexture");
        //static readonly RenderTargetIdentifier volumetricLightMask_Idt = new RenderTargetIdentifier(volumetricLightMaskId);

        static readonly int tempId = Shader.PropertyToID("_TempVolumetricLightTexture");
        //static readonly RenderTargetIdentifier temp_idt = new RenderTargetIdentifier(tempId);

        int downSample;
        BlurSetting setting;

        public BlurPass(BlurSetting blurSetting, RenderPassEvent renderPassEvent, int downSample)
        {
            setting = blurSetting;
            this.renderPassEvent = renderPassEvent;
            this.downSample = downSample;
        }

        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
        {
            cmd.GetTemporaryRT(tempId, new RenderTextureDescriptor(Screen.width / downSample, Screen.height / downSample, RenderTextureFormat.R8, 0));
            ConfigureTarget(tempId);
            ConfigureTarget(volumetricLightMaskId);
        }

        /// <inheritdoc/>
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if(setting.material == null)
            {
                Debug.LogError("Missing BlurVolumetricLight Material");
                return;
            }
            CommandBuffer cmd = CommandBufferPool.Get("BlurVolumeLight");

            cmd.SetGlobalFloat("_blurOffset", setting.blurOffset);
            Blit(cmd, volumetricLightMaskId, tempId, setting.material, 0);
            Blit(cmd, tempId, volumetricLightMaskId, setting.material, 1);

            cmd.SetGlobalFloat("_blurOffset", setting.blurOffset + 0.5f);
            Blit(cmd, volumetricLightMaskId, tempId, setting.material, 0);
            Blit(cmd, tempId, volumetricLightMaskId, setting.material, 1);

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        /// <inheritdoc/>
        public override void FrameCleanup(CommandBuffer cmd)
        {
            cmd.ReleaseTemporaryRT(tempId);
        }
    }

    internal class BlitAddPass : ScriptableRenderPass
    {

        static readonly int tempId = Shader.PropertyToID("_TempCameraColorTexture");
        RenderTargetIdentifier source;
        BlitSetting setting;

        public BlitAddPass(BlitSetting blitSetting, RenderPassEvent renderPassEvent)
        {
            setting = blitSetting;
            this.renderPassEvent = renderPassEvent;
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            source = renderingData.cameraData.renderer.cameraColorTarget;
        }

        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
        {
            cmd.GetTemporaryRT(tempId, cameraTextureDescriptor);
            ConfigureTarget(tempId);
        }

        /// <inheritdoc/>
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (setting.material == null)
            {
                Debug.LogError("Missing BlitAddVolumetricLight Material");
                return;
            }
            CommandBuffer cmd = CommandBufferPool.Get("BlitAddVolumeLight");

            Blit(cmd, source, tempId, setting.material, 0);
            Blit(cmd, tempId, source);

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        /// <inheritdoc/>
        public override void FrameCleanup(CommandBuffer cmd)
        {
            cmd.ReleaseTemporaryRT(tempId);
        }
    }
}

using UnityEngine;

public class EnableDepthTexture : MonoBehaviour
{
    void Start()
    {
        Camera cam = GetComponent<Camera>();
        cam.depthTextureMode = DepthTextureMode.Depth;
    }
}
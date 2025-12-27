using UnityEngine;

[ExecuteInEditMode]
public class PlanarReflection : MonoBehaviour
{
    [Header("Reflection Settings")]
    public int textureResolution = 512;
    public float clipPlaneOffset = 0.07f;
    public LayerMask reflectLayers = -1;
    
    [Header("References")]
    public Material waterMaterial;
    
    private Camera reflectionCamera;
    private RenderTexture reflectionTexture;
    private static bool isRendering = false;
    
    void OnWillRenderObject()
    {
        if (isRendering)
            return;
            
        Camera currentCamera = Camera.current;
        if (currentCamera == null)
            return;
            
        isRendering = true;
        
        // Reflection camera ve texture oluştur
        CreateReflectionCamera(currentCamera);
        
        // Su yüzeyinin pozisyonu ve normali
        Vector3 pos = transform.position;
        Vector3 normal = transform.up;
        
        // Reflection matrix hesapla
        float d = -Vector3.Dot(normal, pos) - clipPlaneOffset;
        Vector4 reflectionPlane = new Vector4(normal.x, normal.y, normal.z, d);
        
        Matrix4x4 reflection = Matrix4x4.zero;
        CalculateReflectionMatrix(ref reflection, reflectionPlane);
        
        // Reflection kamerasını ayarla
        Vector3 oldPos = currentCamera.transform.position;
        Vector3 newPos = reflection.MultiplyPoint(oldPos);
        reflectionCamera.worldToCameraMatrix = currentCamera.worldToCameraMatrix * reflection;
        
        // Oblique projection matrix (su altını kırp)
        Vector4 clipPlane = CameraSpacePlane(reflectionCamera, pos, normal, 1.0f);
        Matrix4x4 projectionMatrix = currentCamera.CalculateObliqueMatrix(clipPlane);
        reflectionCamera.projectionMatrix = projectionMatrix;
        
        reflectionCamera.cullingMask = ~(1 << 4) & reflectLayers.value; // Water layer hariç
        reflectionCamera.targetTexture = reflectionTexture;
        
        // Kamerayı ters çevir (ayna etkisi)
        GL.invertCulling = true;
        reflectionCamera.transform.position = newPos;
        Vector3 euler = currentCamera.transform.eulerAngles;
        reflectionCamera.transform.eulerAngles = new Vector3(-euler.x, euler.y, euler.z);
        reflectionCamera.Render();
        GL.invertCulling = false;
        
        // Material'e texture'ı ata
        if (waterMaterial != null)
        {
            waterMaterial.SetTexture("_ReflectionTex", reflectionTexture);
        }
        
        isRendering = false;
    }
    
    void CreateReflectionCamera(Camera currentCamera)
    {
        // RenderTexture oluştur
        if (reflectionTexture == null || reflectionTexture.width != textureResolution)
        {
            if (reflectionTexture != null)
                DestroyImmediate(reflectionTexture);
                
            reflectionTexture = new RenderTexture(textureResolution, textureResolution, 16);
            reflectionTexture.name = "WaterReflection";
            reflectionTexture.hideFlags = HideFlags.DontSave;
        }
        
        // Reflection kamera oluştur
        if (reflectionCamera == null)
        {
            GameObject go = new GameObject("Reflection Camera");
            reflectionCamera = go.AddComponent<Camera>();
            reflectionCamera.enabled = false;
            go.hideFlags = HideFlags.HideAndDontSave;
        }
        
        // Kamera ayarlarını kopyala
        reflectionCamera.CopyFrom(currentCamera);
        reflectionCamera.renderingPath = RenderingPath.Forward;
    }
    
    void CalculateReflectionMatrix(ref Matrix4x4 reflectionMat, Vector4 plane)
    {
        reflectionMat.m00 = (1F - 2F * plane[0] * plane[0]);
        reflectionMat.m01 = (-2F * plane[0] * plane[1]);
        reflectionMat.m02 = (-2F * plane[0] * plane[2]);
        reflectionMat.m03 = (-2F * plane[3] * plane[0]);
        
        reflectionMat.m10 = (-2F * plane[1] * plane[0]);
        reflectionMat.m11 = (1F - 2F * plane[1] * plane[1]);
        reflectionMat.m12 = (-2F * plane[1] * plane[2]);
        reflectionMat.m13 = (-2F * plane[3] * plane[1]);
        
        reflectionMat.m20 = (-2F * plane[2] * plane[0]);
        reflectionMat.m21 = (-2F * plane[2] * plane[1]);
        reflectionMat.m22 = (1F - 2F * plane[2] * plane[2]);
        reflectionMat.m23 = (-2F * plane[3] * plane[2]);
        
        reflectionMat.m30 = 0F;
        reflectionMat.m31 = 0F;
        reflectionMat.m32 = 0F;
        reflectionMat.m33 = 1F;
    }
    
    Vector4 CameraSpacePlane(Camera cam, Vector3 pos, Vector3 normal, float sideSign)
    {
        Vector3 offsetPos = pos + normal * clipPlaneOffset;
        Matrix4x4 m = cam.worldToCameraMatrix;
        Vector3 cpos = m.MultiplyPoint(offsetPos);
        Vector3 cnormal = m.MultiplyVector(normal).normalized * sideSign;
        return new Vector4(cnormal.x, cnormal.y, cnormal.z, -Vector3.Dot(cpos, cnormal));
    }
    
    void OnDisable()
    {
        if (reflectionTexture != null)
        {
            DestroyImmediate(reflectionTexture);
            reflectionTexture = null;
        }
        if (reflectionCamera != null)
        {
            DestroyImmediate(reflectionCamera.gameObject);
            reflectionCamera = null;
        }
    }
}
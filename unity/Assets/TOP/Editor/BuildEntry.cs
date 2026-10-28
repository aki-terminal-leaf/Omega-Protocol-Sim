// SPDX-License-Identifier: MIT
using System;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEditor.Build.Reporting;
using UnityEngine;
using UnityEngine.Rendering;
using Top.UnityReplay;
public static class BuildEntry {
 public static void Inspect(){
  var graphics=AssetDatabase.LoadAllAssetsAtPath("ProjectSettings/GraphicsSettings.asset").First();using(var so=new SerializedObject(graphics)){var a=so.FindProperty("m_AlwaysIncludedShaders");for(int i=0;i<a.arraySize;i++){var shader=a.GetArrayElementAtIndex(i).objectReferenceValue;Debug.Log("TOP_SHADER "+i+" "+(shader?shader.name:"NULL")+" path="+AssetDatabase.GetAssetPath(shader));}}
  Debug.Log("TOP_SOURCE_INSPECT_V9");EditorApplication.Exit(0);
 }
 public static void BuildAndExit(){try{if(TopReplay.Arg("math-data")!=null)TopMathGate.Check();Build();EditorApplication.Exit(0);}catch(Exception e){Debug.LogException(e);EditorApplication.Exit(1);}}
 public static void Build(){
  PlayerSettings.companyName="Aki";PlayerSettings.productName="TOP Replay";PlayerSettings.colorSpace=ColorSpace.Linear;PlayerSettings.runInBackground=true;
  PlayerSettings.defaultScreenWidth=1280;PlayerSettings.defaultScreenHeight=800;PlayerSettings.fullScreenMode=FullScreenMode.Windowed;
  PlayerSettings.SetUseDefaultGraphicsAPIs(BuildTarget.StandaloneWindows64,false);PlayerSettings.SetGraphicsAPIs(BuildTarget.StandaloneWindows64,new[]{GraphicsDeviceType.Direct3D11});
  var graphics=AssetDatabase.LoadAllAssetsAtPath("ProjectSettings/GraphicsSettings.asset").FirstOrDefault();
  if(graphics){var so=new SerializedObject(graphics);var a=so.FindProperty("m_AlwaysIncludedShaders");for(int i=a.arraySize-1;i>=0;i--){var shader=a.GetArrayElementAtIndex(i).objectReferenceValue;if(shader&&shader.name=="Hidden/Internal-Colored"){Debug.Log("TOP_REMOVE_EDITOR_ONLY_SHADER "+shader.name);a.DeleteArrayElementAtIndex(i);if(i<a.arraySize&&a.GetArrayElementAtIndex(i).objectReferenceValue==null)a.DeleteArrayElementAtIndex(i);}}foreach(var name in new[]{"glTF/PbrMetallicRoughness","glTF/PbrSpecularGlossiness","glTF/Unlit","Standard","Unlit/Texture"}){var shader=Shader.Find(name);if(!shader)throw new Exception("Missing shader "+name);bool found=false;for(int i=0;i<a.arraySize;i++)if(a.GetArrayElementAtIndex(i).objectReferenceValue==shader)found=true;if(!found){a.InsertArrayElementAtIndex(a.arraySize);a.GetArrayElementAtIndex(a.arraySize-1).objectReferenceValue=shader;}}so.ApplyModifiedPropertiesWithoutUndo();a.Dispose();so.Dispose();}
  GC.Collect();GC.WaitForPendingFinalizers();
  var scene=EditorSceneManager.NewScene(NewSceneSetup.EmptyScene,NewSceneMode.Single);new GameObject("TOP Replay").AddComponent<TopReplay>();Directory.CreateDirectory("Assets/TOP/Scenes");EditorSceneManager.SaveScene(scene,"Assets/TOP/Scenes/Replay.unity");AssetDatabase.SaveAssets();
  string output=TopReplay.Arg("build-output")??Path.GetFullPath("Builds/Windows/TOPReplay.exe");Directory.CreateDirectory(Path.GetDirectoryName(output));
  var report=BuildPipeline.BuildPlayer(new BuildPlayerOptions{scenes=new[]{"Assets/TOP/Scenes/Replay.unity"},locationPathName=output,target=BuildTarget.StandaloneWindows64,options=BuildOptions.Development});
  File.WriteAllText(output+".build.json",JsonUtility.ToJson(new Receipt{result=report.summary.result.ToString(),errors=(int)report.summary.totalErrors,warnings=(int)report.summary.totalWarnings,unity=Application.unityVersion},true));
  if(report.summary.result!=BuildResult.Succeeded)throw new Exception("TOP build failed "+report.summary.result);Debug.Log("TOP_BUILD_SUCCEEDED "+output);
 }
 [Serializable]class Receipt {public string result,unity;public int errors,warnings;}
}

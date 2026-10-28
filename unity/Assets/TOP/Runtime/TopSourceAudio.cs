// SPDX-License-Identifier: MIT
// Original decoded source streams, reconstructed cue timing. Not original game mixing/BGM.
using System;
using System.IO;
using System.Linq;
using System.Collections;
using System.Collections.Generic;
using Newtonsoft.Json.Linq;
using UnityEngine;
using UnityEngine.Networking;
namespace Top.UnityReplay {
public sealed class TopSourceAudioProbe:MonoBehaviour {
 public volatile bool Silence;
 readonly object gate=new();int blocks;long samples;float peak;
 void OnAudioFilterRead(float[] data,int channels){float p=0;foreach(var v in data)p=Mathf.Max(p,Mathf.Abs(v));lock(gate){blocks++;samples+=data.Length;peak=Mathf.Max(peak,p);}if(Silence)Array.Clear(data,0,data.Length);}
 public JObject Report(){lock(gate)return new JObject{{"blocks",blocks},{"samples",samples},{"peak",peak},{"output_silenced",Silence}};}
}
public sealed partial class TopReplay {
 public bool AudioEnabled,AudioMuted;
 const int AudioConcurrency=2,AudioClipBudget=96;
 bool audioDisposed,audioQaSilence;double audioLastClock=double.NaN;
 sealed class SourceAudioCue {public string Key,Asset,Source;public double Start,End;}
 sealed class SourceAudioVoice {public SourceAudioCue Cue;public AudioSource Source;public TopSourceAudioProbe Probe;}
 readonly Dictionary<string,AudioClip> audioClips=new();readonly Dictionary<string,string> audioFailures=new();
 readonly HashSet<string> audioPending=new();readonly Queue<string> audioQueue=new();readonly Dictionary<string,UnityWebRequest> audioRequests=new();
 readonly Dictionary<string,SourceAudioVoice> audioVoices=new();readonly HashSet<string> audioDiagnostics=new();
 List<SourceAudioCue> audioCues;GameObject audioRoot;
 void BuildAudioCues(){if(audioCues!=null)return;audioCues=new();foreach(var c in Full["audioCues"]){string source=S(c["source"]);if(DirOwned(source))continue;audioCues.Add(new SourceAudioCue{Key=S(c["key"]),Asset=S(c["asset"]),Source=source,Start=D(c["start"]),End=D(c["end"])});}audioCues=audioCues.OrderBy(c=>c.Start).ToList();}
 void RequestAudio(string asset){if(audioDisposed||audioClips.ContainsKey(asset)||audioFailures.ContainsKey(asset)||!audioPending.Add(asset))return;audioQueue.Enqueue(asset);PumpAudio();}
 void PumpAudio(){while(!audioDisposed&&audioRequests.Count<AudioConcurrency&&audioQueue.Count>0){var asset=audioQueue.Dequeue();StartCoroutine(LoadSourceAudio(asset));}}
 IEnumerator LoadSourceAudio(string asset){
  UnityWebRequest request=null;UnityWebRequestAsyncOperation operation=null;Exception creationError=null;
  try{var spec=Manifest["native_assets"]?[asset];if(S(spec?["kind"])!="encoded_audio")throw new Exception("undeclared encoded audio");string path=Path.Combine(DataRoot,S(spec["file"]));request=UnityWebRequestMultimedia.GetAudioClip(new Uri(path).AbsoluteUri,AudioType.OGGVORBIS);request.timeout=15;audioRequests[asset]=request;operation=request.SendWebRequest();}
  catch(Exception e){creationError=e;}
  if(creationError!=null){audioFailures[asset]=creationError.Message;audioRequests.Remove(asset);audioPending.Remove(asset);request?.Dispose();yield break;}
  try{
   yield return operation;if(audioDisposed)yield break;
   try{
    if(request.result!=UnityWebRequest.Result.Success)audioFailures[asset]=request.error;
    else{var clip=DownloadHandlerAudioClip.GetContent(request);if(!clip||clip.samples<=0||clip.frequency<=0){if(clip)Destroy(clip);audioFailures[asset]="empty native decode";}
     else if(audioClips.Count>=AudioClipBudget){Destroy(clip);audioFailures[asset]="native clip budget exceeded";}
     else{clip.name=asset;audioClips.Add(asset,clip);}}
   }catch(Exception e){audioFailures[asset]=e.Message;}
  }finally{audioRequests.Remove(asset);audioPending.Remove(asset);request.Dispose();}
  // Async completion fills only the cache; the next current-state sync owns playback.
 }
 void RemoveAudioVoice(string key){if(!audioVoices.TryGetValue(key,out var v))return;audioVoices.Remove(key);if(v.Source){v.Source.Stop();Destroy(v.Source.gameObject);}}
 void StopAudioVoices(){foreach(var key in audioVoices.Keys.ToArray())RemoveAudioVoice(key);}
 void SyncAudio(){
  if(audioDisposed||!Ready||Full==null)return;PumpAudio();
  if(!AudioEnabled||!Playing||Rate<.1f||Rate>3){if(AudioEnabled&&Playing&&(Rate<.1f||Rate>3))audioDiagnostics.Add("audio_muted_outside_native_pitch_range_0.1_to_3");StopAudioVoices();audioLastClock=double.NaN;return;}
  BuildAudioCues();if(!double.IsNaN(audioLastClock)&&(Clock<audioLastClock||Clock-audioLastClock>1500*Math.Max(1,Rate)))StopAudioVoices();audioLastClock=Clock;
  var wanted=new HashSet<string>();
  foreach(var cue in audioCues){if(cue.Start>Clock)break;if(Clock>=cue.End)continue;double age=(Clock-cue.Start)/1000;if(!audioClips.TryGetValue(cue.Asset,out var clip)){RequestAudio(cue.Asset);continue;}if(age<0||age>=clip.length)continue;wanted.Add(cue.Key);
   if(!audioVoices.TryGetValue(cue.Key,out var voice)){
    if(!audioRoot)audioRoot=new GameObject("Original source audio");var go=new GameObject(cue.Key);go.transform.SetParent(audioRoot.transform,false);var source=go.AddComponent<AudioSource>();source.playOnAwake=false;source.loop=false;source.spatialBlend=0;source.volume=.3f;source.clip=clip;source.pitch=Rate;source.mute=AudioMuted;var probe=go.AddComponent<TopSourceAudioProbe>();probe.Silence=audioQaSilence;voice=new SourceAudioVoice{Cue=cue,Source=source,Probe=probe};audioVoices.Add(cue.Key,voice);
    source.timeSamples=Math.Clamp((int)(age*clip.frequency),0,clip.samples-1);source.Play();
   }else{var source=voice.Source;source.pitch=Rate;source.mute=AudioMuted;if(Math.Abs(source.time-age)>.2)source.timeSamples=Math.Clamp((int)(age*clip.frequency),0,clip.samples-1);if(!source.isPlaying&&!AudioListener.pause){source.timeSamples=Math.Clamp((int)(age*clip.frequency),0,clip.samples-1);source.Play();}}
  }
  foreach(var key in audioVoices.Keys.Where(k=>!wanted.Contains(k)).ToArray())RemoveAudioVoice(key);
 }
 public JObject AudioReport(){BuildAudioCues();return new JObject{{"enabled",AudioEnabled},{"muted",AudioMuted},{"disposed",audioDisposed},{"cueCount",audioCues.Count},{"decodedCount",audioClips.Count},{"pendingCount",audioPending.Count},{"requestCount",audioRequests.Count},{"active",new JArray(audioVoices.Values.Select(v=>new JObject{{"key",v.Cue.Key},{"asset",v.Cue.Asset},{"offset",v.Source.time},{"pitch",v.Source.pitch},{"playing",v.Source.isPlaying},{"muted",v.Source.mute},{"probe",v.Probe.Report()}}))},{"failed",JObject.FromObject(audioFailures)},{"diagnostics",new JArray(audioDiagnostics)},{"mixing","flat 0.3 gain; pitch-linked rate; original mixing/attenuation/looping/BGM OPEN"},{"auditory_comparison","NOT_RUN"},{"complete",false}};}
 void DisposeAudio(){if(audioDisposed)return;audioDisposed=true;AudioEnabled=false;StopAudioVoices();foreach(var r in audioRequests.Values.ToArray()){r.Abort();r.Dispose();}audioRequests.Clear();audioQueue.Clear();audioPending.Clear();foreach(var clip in audioClips.Values)Destroy(clip);audioClips.Clear();if(audioRoot)Destroy(audioRoot);}
}
}

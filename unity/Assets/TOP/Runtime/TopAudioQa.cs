// SPDX-License-Identifier: MIT
using System;
using System.IO;
using System.Linq;
using System.Collections;
using System.Collections.Generic;
using Newtonsoft.Json.Linq;
using UnityEngine;
namespace Top.UnityReplay {
public sealed partial class TopReplay {
 IEnumerator AudioQa(string output){
  Directory.CreateDirectory(output);EffectsEnabled=false;Playing=false;audioQaSilence=true;
  var assets=((JObject)Manifest["native_assets"]).Properties().Where(x=>S(x.Value["kind"])=="encoded_audio").Select(x=>x.Name).ToArray();foreach(var id in assets)RequestAudio(id);
  float began=Time.realtimeSinceStartup;while(audioPending.Count>0&&Time.realtimeSinceStartup-began<30){PumpAudio();yield return null;}if(audioPending.Count!=0||audioFailures.Count!=0||audioClips.Count!=assets.Length)throw new Exception("Native audio decode/cache gate failed: "+AudioReport());
  var decoded=new JArray();var firstAudio=new Dictionary<string,double>();
  foreach(var pair in audioClips){var clip=pair.Value;var pcm=new float[clip.samples*clip.channels];if(!clip.GetData(pcm,0))throw new Exception("Native decoded PCM unreadable "+pair.Key);float peak=0;int first=-1;for(int i=0;i<pcm.Length;i++){float a=Math.Abs(pcm[i]);if(!float.IsFinite(a))throw new Exception("Non-finite PCM");peak=Math.Max(peak,a);if(first<0&&a>.00001f)first=i;}firstAudio[pair.Key]=first<0?double.PositiveInfinity:(double)first/clip.channels/clip.frequency;decoded.Add(new JObject{{"asset",pair.Key},{"frequency",clip.frequency},{"channels",clip.channels},{"samples",clip.samples},{"seconds",clip.length},{"peak",peak},{"first_signal_seconds",first<0?-1:firstAudio[pair.Key]}});}
  File.WriteAllText(Path.Combine(output,"decodes.json"),decoded.ToString());BuildAudioCues();var rows=new JArray();AudioEnabled=true;
  foreach(int phase in Enumerable.Range(1,6)){
   double start=D(Record["phase_markers"][phase-1]["t"]),end=phase<6?D(Record["phase_markers"][phase]["t"]):duration;
   var cue=audioCues.FirstOrDefault(c=>c.Start>=start&&c.Start<end&&firstAudio.TryGetValue(c.Asset,out var first)&&first+.4<Math.Min((c.End-c.Start)/1000,audioClips[c.Asset].length));if(cue==null)throw new Exception("No audible original cue for P"+phase);
   Playing=false;Seek(cue.Start+(firstAudio[cue.Asset]+.05)*1000);Rate=1;Playing=true;SyncAudio();yield return new WaitForSecondsRealtime(.25f);SyncAudio();var state=AudioReport();var voices=(JArray)state["active"];
   if(!voices.Any(v=>S(v["asset"])==cue.Asset&&D(v["probe"]?["peak"])>0&&D(v["probe"]?["blocks"])>0))throw new Exception("Native DSP produced no signal for P"+phase+": "+state);
   rows.Add(new JObject{{"phase",phase},{"clock",Clock},{"cue",cue.Key},{"state",state}});Playing=false;SyncAudio();if(audioVoices.Count!=0)throw new Exception("Pause retained native audio voices");
  }
  var active=audioCues.First(c=>firstAudio[c.Asset]+1<Math.Min((c.End-c.Start)/1000,audioClips[c.Asset].length));Seek(active.Start+(firstAudio[active.Asset]+.05)*1000);Playing=true;Rate=2;SyncAudio();if(audioVoices.Count==0||audioVoices.Values.Any(v=>Math.Abs(v.Source.pitch-2)>.001))throw new Exception("Native audio rate gate failed");var stopped=audioVoices.Values.First();stopped.Source.Stop();SyncAudio();if(!stopped.Source.isPlaying)throw new Exception("Stopped native voice failed to recover");AudioMuted=true;SyncAudio();if(audioVoices.Values.Any(v=>!v.Source.mute))throw new Exception("Mute failed");
  AudioMuted=false;Rate=8;SyncAudio();if(audioVoices.Count!=0)throw new Exception("Unsupported native pitch range was not silent");
  Rate=1;Seek(0);SyncAudio();if(audioVoices.Count!=0)throw new Exception("Seek retained stale audio");AudioEnabled=false;SyncAudio();yield return null;if(audioVoices.Count!=0)throw new Exception("Disable retained voices");Playing=false;string reloading=audioClips.Keys.First();Destroy(audioClips[reloading]);audioClips.Remove(reloading);RequestAudio(reloading);if(audioRequests.Count==0)throw new Exception("In-flight disposal test has no request");DisposeAudio();yield return null;var disposed=AudioReport();if(audioVoices.Count!=0||audioClips.Count!=0||audioPending.Count!=0||audioRequests.Count!=0)throw new Exception("Dispose retained audio resources");
  File.WriteAllText(Path.Combine(output,"states.json"),rows.ToString());File.WriteAllText(Path.Combine(output,"disposed.json"),disposed.ToString());File.WriteAllText(Path.Combine(output,"result.json"),new JObject{{"status","NATIVE_DECODE_DSP_LIFECYCLE_PASS_NOT_AUDITORY_FIDELITY"},{"decoded",assets.Length},{"signal_phases",rows.Count},{"pause",true},{"seek_stale_voice_cleanup",true},{"rate_2",true},{"rate_8_silent_native_limit",true},{"mute",true},{"disable",true},{"dispose",true},{"dispose_inflight_request",true},{"stopped_voice_recovery",true},{"probe_output_silenced",true},{"original_mixing_BGM_complete",false},{"auditory_comparison","NOT_RUN"}}.ToString());Application.Quit(0);
 }
}
}

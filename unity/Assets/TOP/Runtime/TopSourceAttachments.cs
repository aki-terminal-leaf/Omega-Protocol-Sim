// SPDX-License-Identifier: MIT
// Available original NPC EID tables; existing source-preview rotation/host limitations remain.
using System;
using System.IO;
using System.Linq;
using Newtonsoft.Json.Linq;
namespace Top.UnityReplay {
public sealed partial class TopReplay {
 JObject sourceAttachments=new();
 void LoadSourceAttachments(){
  string file=Path.Combine(DataRoot,"attachment-data.json");if(!File.Exists(file)){diagnostics.Add("original_eid_metadata_unavailable/legacy_MF_only");return;}
  sourceAttachments=JObject.Parse(File.ReadAllText(file));if((int?)sourceAttachments["schema"]!=1||sourceAttachments["families"] is not JObject families)throw new Exception("Invalid original EID metadata schema");
  foreach(var table in families.Properties()){
   if(table.Value["rows"] is not JArray rows||rows.Count!=(int?)table.Value["count"]||rows.Select(r=>DirInt(r["id"])).Distinct().Count()!=rows.Count)throw new Exception("Invalid original EID table "+table.Name);
  }
 }
 string SourceAttachmentFamily(string form)=>S(sourceAttachments["byForm"]?[form],DirFamily(form));
 JToken SourceAttachmentRow(string family,int id){if(family==null)return null;var rows=(sourceAttachments["families"]?[family]?["rows"]??Weapons["eid"]?[family]?["rows"]) as JArray;return rows?.FirstOrDefault(r=>DirInt(r["id"])==id);}
 public JObject SourceAttachmentReport()=>new JObject{{"families",sourceAttachments["families"] is JObject f?f.Count:0},{"byForm",sourceAttachments["byForm"]??new JObject()},{"game_host_equivalence",false}};
}
}

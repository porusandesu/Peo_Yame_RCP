using System.Diagnostics;
using System.Drawing;
using System.Windows.Forms;
namespace PeoYameTray;
internal static class Program {
  static Process? backend; static NotifyIcon? tray;
  static string DataDir => Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Peo Yame", "data");
  [STAThread] static void Main() {
    ApplicationConfiguration.Initialize(); Directory.CreateDirectory(DataDir);
    var m=new ContextMenuStrip();
    m.Items.Add("Start",null,(_,_)=>Start());
    m.Items.Add("Restart backend",null,(_,_)=>{StopBackend();StartBackend();OpenWeb();});
    m.Items.Add("Stop",null,(_,_)=>StopBackend());
    m.Items.Add(new ToolStripSeparator());
    m.Items.Add("Quit",null,(_,_)=>{StopBackend();tray!.Visible=false;Application.Exit();});
    var icon=Path.Combine(AppContext.BaseDirectory,"PeoYame.ico");
    tray=new NotifyIcon{Text="Peo Yame",Icon=File.Exists(icon)?new Icon(icon):SystemIcons.Application,ContextMenuStrip=m,Visible=true};
    Application.Run();
  }
  static void Start(){StartBackend();OpenWeb();}
  static void StartBackend(){
    if(backend is {HasExited:false})return;
    var root=Path.Combine(AppContext.BaseDirectory,"backend");var node=Path.Combine(root,"node.exe");
    if(!File.Exists(node)){MessageBox.Show("Backend runtime is missing.");return;}
    var info=new ProcessStartInfo(node){UseShellExecute=false,CreateNoWindow=true,WorkingDirectory=root};
    info.ArgumentList.Add("src/server.js");info.Environment["PEO_YAME_DATA_DIR"]=DataDir;info.Environment["HOST"]="127.0.0.1";info.Environment["PORT"]="3000";
    backend=Process.Start(info);
  }
  static void OpenWeb()=>Process.Start(new ProcessStartInfo("http://127.0.0.1:3000"){UseShellExecute=true});
  static void StopBackend(){try{if(backend is {HasExited:false}){backend.Kill(true);backend.WaitForExit(5000);}}catch{}}
}

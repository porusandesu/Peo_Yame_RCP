using System.Diagnostics;
using System.Drawing;
using System.Net;
using System.Net.Http.Json;
using System.Runtime.InteropServices;
using System.Windows.Forms;
namespace PeoYameTray;
internal static class Program {
  static Process? backend; static NotifyIcon? tray;
  static string DataDir => Environment.GetEnvironmentVariable("PEO_YAME_DATA_DIR") ?? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Peo Yame", "data");
  static int Port => int.TryParse(Environment.GetEnvironmentVariable("PORT"), out var value) ? value : 3000;
  [STAThread] static int Main(string[] args) {
    if (args.Contains("--self-test")) return SelfTestAsync().GetAwaiter().GetResult();
    ApplicationConfiguration.Initialize(); Directory.CreateDirectory(DataDir);
    var m=new ContextMenuStrip();
    m.Items.Add("Start",null,async(_,_)=>await StartAsync());
    m.Items.Add("Restart backend",null,async(_,_)=>{StopBackend();await StartBackendAsync();OpenWeb();});
    m.Items.Add("Stop",null,(_,_)=>StopBackend());
    m.Items.Add(new ToolStripSeparator());
    m.Items.Add("Quit",null,(_,_)=>{StopBackend();tray!.Visible=false;Application.Exit();});
    var icon=Path.Combine(AppContext.BaseDirectory,"PeoYame.png");
    tray=new NotifyIcon{Text="Peo Yame",Icon=File.Exists(icon)?LoadPngIcon(icon):SystemIcons.Application,ContextMenuStrip=m,Visible=true};
    Application.Run(); return 0;
  }
  static async Task StartAsync(){await StartBackendAsync();OpenWeb();}
  static async Task StartBackendAsync(){
    if(backend is {HasExited:false})return;
    Directory.CreateDirectory(DataDir);
    var root=Path.Combine(AppContext.BaseDirectory,"backend");var node=Path.Combine(root,"node.exe");
    if(!File.Exists(node))throw new FileNotFoundException("Backend runtime is missing.",node);
    var info=new ProcessStartInfo(node){UseShellExecute=false,CreateNoWindow=true,WorkingDirectory=root};
    info.ArgumentList.Add("src/server.js");info.Environment["PEO_YAME_DATA_DIR"]=DataDir;info.Environment["HOST"]="127.0.0.1";info.Environment["PORT"]=Port.ToString();
    backend=Process.Start(info)??throw new InvalidOperationException("Backend did not start.");
    using var client=new HttpClient();var url="http://127.0.0.1:"+Port+"/api/health";
    for(var i=0;i<40;i++){try{var response=await client.GetAsync(url);if(response.StatusCode==HttpStatusCode.OK)return;}catch{}await Task.Delay(250);}
    StopBackend();throw new TimeoutException("Backend health check did not pass.");
  }
  static Icon LoadPngIcon(string path){using var bitmap=new Bitmap(path);var handle=bitmap.GetHicon();try{return (Icon)Icon.FromHandle(handle).Clone();}finally{DestroyIcon(handle);}}
  [DllImport("user32.dll",SetLastError=true)] static extern bool DestroyIcon(IntPtr handle);
  static void OpenWeb()=>Process.Start(new ProcessStartInfo("http://127.0.0.1:"+Port){UseShellExecute=true});
  static void StopBackend(){try{if(backend is {HasExited:false}){backend.Kill(true);backend.WaitForExit(5000);}}catch{}backend=null;}
  static async Task<int> SelfTestAsync(){
    var log=Environment.GetEnvironmentVariable("PEO_YAME_SELF_TEST_LOG")??Path.Combine(Path.GetTempPath(),"PeoYame-self-test.log");
    try{File.WriteAllText(log,"Self-test entered.");}catch{}
    var dir=Path.Combine(Path.GetTempPath(),"PeoYameTrayTest-"+Guid.NewGuid().ToString("N"));Directory.CreateDirectory(dir);
    Environment.SetEnvironmentVariable("PEO_YAME_DATA_DIR",dir);Environment.SetEnvironmentVariable("PORT","38191");
    try{
      await StartBackendAsync();
      using var client=new HttpClient();var root="http://127.0.0.1:38191";
      var web=await client.GetAsync(root+"/");if(web.StatusCode!=HttpStatusCode.OK)throw new Exception("Start did not make the web application available.");
      var reg=await client.PostAsJsonAsync(root+"/api/account/register",new{name="CI Farmer",phone="71234567",password="test password 2026"});if(reg.StatusCode!=HttpStatusCode.Created)throw new Exception("Start/register lifecycle failed.");
      StopBackend();await StartBackendAsync();
      var login=await client.PostAsJsonAsync(root+"/api/account/login",new{phone="71234567",password="test password 2026"});if(login.StatusCode!=HttpStatusCode.OK)throw new Exception("Restart did not preserve account credentials.");
      StopBackend();
      try{await client.GetAsync(root+"/api/health");throw new Exception("Stop left backend responding.");}catch(HttpRequestException){}
      File.WriteAllText(log,"Start, restart with saved account, and stop passed.");return 0;
    }catch(Exception error){try{File.WriteAllText(Environment.GetEnvironmentVariable("PEO_YAME_SELF_TEST_LOG")??Path.Combine(Path.GetTempPath(),"PeoYame-self-test.log"),error.ToString());}catch{}StopBackend();return 1;}
    finally{StopBackend();try{Directory.Delete(dir,true);}catch{}}
  }
}
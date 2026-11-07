using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Net;
using System.Threading;
using System.Windows.Forms;

internal sealed class WindowsLauncherContext : ApplicationContext
{
    private readonly string backendPath;
    private readonly int port;
    private readonly Mutex singleInstanceMutex;
    private readonly NotifyIcon trayIcon;
    private readonly ContextMenuStrip menu;
    private Process backendProcess;

    internal WindowsLauncherContext(string backendPath, int port, Mutex singleInstanceMutex)
    {
        this.backendPath = backendPath;
        this.port = port;
        this.singleInstanceMutex = singleInstanceMutex;

        menu = new ContextMenuStrip();
        menu.Items.Add("Launch web panel", null, delegate { LaunchWebPanel(); });
        menu.Items.Add("Restart backend", null, delegate { RestartBackend(); });
        menu.Items.Add("Shutdown backend", null, delegate { StopBackend(); });
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add("Exit Peo Yame", null, delegate { ExitThread(); });
        menu.Opening += delegate { RefreshMenuState(); };

        trayIcon = new NotifyIcon();
        trayIcon.Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath);
        trayIcon.Text = "Peo Yame Backend";
        trayIcon.ContextMenuStrip = menu;
        trayIcon.Visible = true;
        trayIcon.MouseUp += delegate(object sender, MouseEventArgs args)
        {
            if (args.Button == MouseButtons.Left)
            {
                menu.Show(Cursor.Position);
            }
        };

        StartBackend();
    }

    private void RefreshMenuState()
    {
        bool running = IsBackendRunning();
        menu.Items[1].Enabled = true;
        menu.Items[2].Enabled = running;
    }

    private bool IsBackendRunning()
    {
        if (backendProcess == null) return false;
        try
        {
            backendProcess.Refresh();
            return !backendProcess.HasExited;
        }
        catch
        {
            return false;
        }
    }

    private void StartBackend()
    {
        if (IsBackendRunning()) return;
        try
        {
            ProcessStartInfo startInfo = new ProcessStartInfo(backendPath);
            startInfo.WorkingDirectory = Path.GetDirectoryName(backendPath);
            startInfo.UseShellExecute = false;
            startInfo.CreateNoWindow = true;
            startInfo.WindowStyle = ProcessWindowStyle.Hidden;
            backendProcess = Process.Start(startInfo);
        }
        catch (Exception error)
        {
            MessageBox.Show(
                "Peo Yame could not start its backend.\r\n\r\n" + error.Message,
                "Peo Yame",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error);
        }
    }

    private void RestartBackend()
    {
        StopBackend();
        StartBackend();
    }

    private void StopBackend()
    {
        if (!IsBackendRunning())
        {
            if (backendProcess != null)
            {
                backendProcess.Dispose();
                backendProcess = null;
            }
            return;
        }

        try
        {
            ProcessStartInfo stopInfo = new ProcessStartInfo(
                "taskkill.exe",
                "/PID " + backendProcess.Id + " /T /F");
            stopInfo.UseShellExecute = false;
            stopInfo.CreateNoWindow = true;
            stopInfo.WindowStyle = ProcessWindowStyle.Hidden;
            using (Process stopProcess = Process.Start(stopInfo))
            {
                if (stopProcess != null) stopProcess.WaitForExit(10000);
            }
        }
        catch
        {
            try
            {
                if (IsBackendRunning()) backendProcess.Kill();
            }
            catch { }
        }

        try
        {
            backendProcess.WaitForExit(10000);
            if (IsBackendRunning()) backendProcess.Kill();
        }
        catch { }
        backendProcess.Dispose();
        backendProcess = null;
    }

    private void LaunchWebPanel()
    {
        if (!IsBackendRunning()) StartBackend();
        string address = "http://127.0.0.1:" + port + "/";
        ThreadPool.QueueUserWorkItem(delegate
        {
            bool ready = false;
            for (int attempt = 0; attempt < 30; attempt++)
            {
                try
                {
                    HttpWebRequest request = (HttpWebRequest)WebRequest.Create(address + "api/health");
                    request.Timeout = 1000;
                    using (HttpWebResponse response = (HttpWebResponse)request.GetResponse())
                    {
                        ready = response.StatusCode == HttpStatusCode.OK;
                    }
                    if (ready) break;
                }
                catch { Thread.Sleep(500); }
            }

            if (ready)
            {
                try
                {
                    Process.Start(new ProcessStartInfo(address) { UseShellExecute = true });
                    return;
                }
                catch { }
            }

            try
            {
                trayIcon.BalloonTipTitle = "Peo Yame";
                trayIcon.BalloonTipText = "The web panel could not be opened. Restart the backend and try again.";
                trayIcon.ShowBalloonTip(5000);
            }
            catch { }
        });
    }

    protected override void ExitThreadCore()
    {
        StopBackend();
        trayIcon.Visible = false;
        trayIcon.Dispose();
        menu.Dispose();
        singleInstanceMutex.ReleaseMutex();
        singleInstanceMutex.Dispose();
        base.ExitThreadCore();
    }
}

internal static class WindowsLauncher
{
    [STAThread]
    private static void Main()
    {
        bool createdNew;
        Mutex singleInstanceMutex = new Mutex(true, "Local\\PeoYameBackendTray", out createdNew);
        if (!createdNew)
        {
            singleInstanceMutex.Dispose();
            return;
        }

        string appDirectory = AppDomain.CurrentDomain.BaseDirectory;
        string backendPath = Path.Combine(appDirectory, "runtime", "Peo-Yame-Backend-Core.exe");
        int port;
        if (!Int32.TryParse(Environment.GetEnvironmentVariable("PORT"), out port) || port < 1 || port > 65535)
        {
            port = 3000;
        }

        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        Application.Run(new WindowsLauncherContext(backendPath, port, singleInstanceMutex));
    }
}

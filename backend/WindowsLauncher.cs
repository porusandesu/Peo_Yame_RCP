using System;
using System.Diagnostics;
using System.IO;

internal static class WindowsLauncher
{
    [STAThread]
    private static void Main()
    {
        string appDirectory = AppDomain.CurrentDomain.BaseDirectory;
        string backendPath = Path.Combine(appDirectory, "runtime", "Peo-Yame-Backend-Core.exe");
        ProcessStartInfo startInfo = new ProcessStartInfo(backendPath);
        startInfo.WorkingDirectory = Path.GetDirectoryName(backendPath);
        startInfo.UseShellExecute = false;
        startInfo.CreateNoWindow = true;
        startInfo.WindowStyle = ProcessWindowStyle.Hidden;
        Process.Start(startInfo);
    }
}

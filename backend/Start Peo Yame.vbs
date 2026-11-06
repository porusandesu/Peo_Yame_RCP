Option Explicit
Dim shell, files, folder, executable
Set shell = CreateObject("WScript.Shell")
Set files = CreateObject("Scripting.FileSystemObject")
folder = files.GetParentFolderName(WScript.ScriptFullName)
executable = files.BuildPath(folder, "Peo-Yame-Backend.exe")
shell.CurrentDirectory = folder
shell.Run Chr(34) & executable & Chr(34), 0, False

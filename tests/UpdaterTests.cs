using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using RockBand3DeluxeLauncher;

static class UpdaterTests {
 static readonly string[] Files = {
  "RockBand3DeluxeLauncher.exe", "RockBand3DeluxeLauncher.exe.config", "game-files.json",
  "runtime/rockband3deluxe.exe", "runtime/rexruntime.dll", "runtime/rexgpu-xenos.dll",
  "runtime/beatles-input.dll", "runtime/rb3-content.exe", "runtime/rockband3deluxe.toml", "Update-App.ps1"
 };
 static void Require(bool ok, string message) { if (!ok) throw new Exception(message); }
 static string Hash(byte[] bytes) {
  using (var hash = SHA256.Create()) return BitConverter.ToString(hash.ComputeHash(bytes)).Replace("-", "");
 }
 static void Write(string path, string content) {
  Directory.CreateDirectory(Path.GetDirectoryName(path));
  File.WriteAllText(path, content, new UTF8Encoding(false));
 }
 static void Fixture(string path, bool badHash, string extra) {
  using (var stream = File.Create(path))
  using (var zip = new ZipArchive(stream, ZipArchiveMode.Create)) {
   var manifest = new ApplicationManifest {Version="v0.2.0", Files=new List<ApplicationFile>()};
   foreach (var name in Files) {
    byte[] bytes = Encoding.UTF8.GetBytes("new " + name);
    using (var output = zip.CreateEntry(name).Open()) output.Write(bytes, 0, bytes.Length);
    manifest.Files.Add(new ApplicationFile {Path=name, Sha256=badHash ? new string('0',64) : Hash(bytes)});
   }
   using (var output = zip.CreateEntry("release-files.json").Open())
    new System.Runtime.Serialization.Json.DataContractJsonSerializer(typeof(ApplicationManifest)).WriteObject(output,manifest);
   if (extra != null) using (var writer = new StreamWriter(zip.CreateEntry(extra).Open())) writer.Write("extra");
  }
 }
 static void InvalidPackage(string root, string extra, bool hash, int index) {
  string archive = Path.Combine(root, "invalid-" + index + ".zip");
  Fixture(archive, hash, extra);
  try {
   Updates.ExtractPackage(archive, Path.Combine(root,"invalid-" + index), "v0.2.0");
  } catch (InvalidDataException) { return; }
  throw new Exception("Invalid update package was accepted");
 }
 static void Installer(string root, string helper, bool fail) {
  string app = Path.Combine(root, fail ? "rollback" : "success");
  string stage = Path.Combine(app, ".update-test", "application");
  string fixture = Path.Combine(root,"valid.zip");
  Directory.CreateDirectory(app);
  foreach (var name in Files) Write(Path.Combine(app,name), "old " + name);
  Write(Path.Combine(app,"userdata","save.dat"), "save");
  Write(Path.Combine(app,"cache","shader"), "cache");
  Write(Path.Combine(app,"launcher-settings.json"), "settings");
  Updates.ExtractPackage(fixture,stage,"v0.2.0");
  FileStream locked = fail ? File.Open(Path.Combine(app, "runtime/rockband3deluxe.exe"),FileMode.Open,FileAccess.Read,FileShare.Read) : null;
  string executable = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System),"WindowsPowerShell","v1.0","powershell.exe");
  string[] args = {"-NoProfile","-ExecutionPolicy","Bypass","-File",helper,"-ApplicationDirectory",app,
   "-StagingDirectory",stage,"-LauncherProcessId","2147483647","-NoRestart"};
  try {
   var start = new ProcessStartInfo(executable,String.Join(" ",args.Select(GameFiles.Quote))) {
    UseShellExecute=false,CreateNoWindow=true,WindowStyle=ProcessWindowStyle.Hidden,
    RedirectStandardOutput=true,RedirectStandardError=true
   };
   using (var process = Process.Start(start)) {
    string output = process.StandardOutput.ReadToEnd();
    string error = process.StandardError.ReadToEnd();
    process.WaitForExit();
    Require(fail ? process.ExitCode != 0 : process.ExitCode == 0, output + error);
   }
  } finally { if (locked != null) locked.Dispose(); }
  foreach (var name in Files)
   Require(File.ReadAllText(Path.Combine(app,name)) == (fail ? "old " : "new ") + name, "Incorrect installed file: " + name);
  Require(File.ReadAllText(Path.Combine(app,"userdata","save.dat")) == "save", "Save changed during update");
  Require(File.ReadAllText(Path.Combine(app,"cache","shader")) == "cache", "Shader cache changed during update");
  Require(File.ReadAllText(Path.Combine(app,"launcher-settings.json")) == "settings", "Launcher profile changed during update");
 }
 static int Main(string[] args) {
  string root = args[0], helper = args[1];
  Directory.CreateDirectory(root);
  Require(Updates.CompareVersions("v0.2.0", "0.1.0-preview") > 0, "New release");
  Require(Updates.CompareVersions("v0.1.0-preview", "0.1.0-preview") == 0, "Same version");
  Require(Updates.CompareVersions("v0.1.0", "0.1.0-preview") > 0, "Stable release precedence");
  Require(Updates.CompareVersions("v0.1.0-preview.10", "0.1.0-preview.2") > 0, "Prerelease numerical order");
  Require(Updates.CompareVersions("v0.0.9", "0.1.0-preview") < 0, "Downgrade rejected");
  Fixture(Path.Combine(root,"valid.zip"), false, null);
  InvalidPackage(root,"../userdata/save.dat",false,1);
  InvalidPackage(root,"launcher-settings.json",false,2);
  InvalidPackage(root,"RockBand3DeluxeLauncher.exe",false,3);
  InvalidPackage(root,null,true,4);
  Installer(root,helper,false);
  Installer(root,helper,true);
  if (args.Length > 2) Updates.ExtractPackage(args[2],Path.Combine(root,"release"),"v"+ReleaseVersion.Current);
  Console.WriteLine("PASS: version ordering, unsafe packages, checksums, complete update, rollback, player data, release extraction.");
  return 0;
 }
}

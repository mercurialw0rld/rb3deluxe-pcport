using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Net;
using System.Runtime.Serialization;
using System.Runtime.Serialization.Json;
using System.Security.Cryptography;
using System.Text.RegularExpressions;

namespace RockBand3DeluxeLauncher {
 [DataContract] public sealed class ReleaseAsset {
  [DataMember(Name="name")] public string Name;
  [DataMember(Name="browser_download_url")] public string DownloadUrl;
  [DataMember(Name="digest")] public string Digest;
  [DataMember(Name="size")] public long Size;
 }
 [DataContract] public sealed class ReleaseInfo {
  [DataMember(Name="tag_name")] public string Tag;
  [DataMember(Name="draft")] public bool Draft;
  [DataMember(Name="assets")] public List<ReleaseAsset> Assets;
 }
 [DataContract] public sealed class ApplicationFile {
  [DataMember] public string Path;
  [DataMember] public string Sha256;
 }
 [DataContract] public sealed class ApplicationManifest {
  [DataMember] public string Version;
  [DataMember] public List<ApplicationFile> Files;
 }
 [DataContract] public sealed class UpdateResult {
  [DataMember] public bool Success;
  [DataMember] public string Message;
 }
 public static class Updates {
  const long MaximumPackageBytes = 512L * 1024 * 1024;
  static readonly Regex TagPattern = new Regex(@"^v?(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?$", RegexOptions.CultureInvariant);
  static readonly HashSet<string> ApplicationFiles = new HashSet<string>(StringComparer.OrdinalIgnoreCase) {
   "RockBand3DeluxeLauncher.exe", "RockBand3DeluxeLauncher.exe.config", "game-files.json",
   "runtime/rockband3deluxe.exe", "runtime/rexruntime.dll", "runtime/rexgpu-xenos.dll",
   "runtime/beatles-input.dll", "runtime/rb3-content.exe", "runtime/rockband3deluxe.toml",
   "runtime/concrt140.dll", "runtime/msvcp140.dll", "runtime/msvcp140_1.dll",
   "runtime/msvcp140_2.dll", "runtime/msvcp140_atomic_wait.dll", "runtime/msvcp140_codecvt_ids.dll",
   "runtime/vccorlib140.dll", "runtime/vcruntime140.dll", "runtime/vcruntime140_1.dll",
   "runtime/vcruntime140_threads.dll", "Update-App.ps1"
  };

  public static int CompareVersions(string left, string right) {
   var a = TagPattern.Match(left ?? "");
   var b = TagPattern.Match(right ?? "");
   if (!a.Success || !b.Success) throw new InvalidDataException("Unsupported release version.");
   var numericA = new Version(a.Groups[1].Value + "." + a.Groups[2].Value + "." + a.Groups[3].Value);
   var numericB = new Version(b.Groups[1].Value + "." + b.Groups[2].Value + "." + b.Groups[3].Value);
   int comparison = numericA.CompareTo(numericB);
   if (comparison != 0) return comparison;
   string preA = a.Groups[4].Value, preB = b.Groups[4].Value;
   if (preA == preB) return 0;
   if (preA.Length == 0) return 1;
   if (preB.Length == 0) return -1;
   var partsA = preA.Split('.');
   var partsB = preB.Split('.');
   for (int i = 0; i < Math.Min(partsA.Length, partsB.Length); i++) {
    bool numberA = partsA[i].All(Char.IsDigit), numberB = partsB[i].All(Char.IsDigit);
    if (numberA && numberB) {
     string valueA = partsA[i].TrimStart('0'), valueB = partsB[i].TrimStart('0');
     comparison = valueA.Length.CompareTo(valueB.Length);
     if (comparison == 0) comparison = StringComparer.Ordinal.Compare(valueA, valueB);
    } else if (numberA != numberB) comparison = numberA ? -1 : 1;
    else comparison = StringComparer.Ordinal.Compare(partsA[i], partsB[i]);
    if (comparison != 0) return comparison;
   }
   return partsA.Length.CompareTo(partsB.Length);
  }

  static HttpWebRequest Request(string url) {
   ServicePointManager.SecurityProtocol |= SecurityProtocolType.Tls12;
   var request = (HttpWebRequest)WebRequest.Create(url);
   request.UserAgent = "RockBand3Deluxe-PC/" + ReleaseVersion.Current;
   request.Accept = "application/vnd.github+json";
   request.Timeout = 15000;
   request.ReadWriteTimeout = 30000;
   return request;
  }

  public static ReleaseInfo CheckLatest() {
   try {
    var request = Request("https://api.github.com/repos/" + ReleaseVersion.Repository + "/releases/latest");
    using (var response = request.GetResponse())
    using (var stream = response.GetResponseStream()) {
     var release = (ReleaseInfo)new DataContractJsonSerializer(typeof(ReleaseInfo)).ReadObject(stream);
     if (release == null || release.Draft) return null;
     CompareVersions(release.Tag, ReleaseVersion.Current);
     return release;
    }
   } catch (WebException error) {
    var response = error.Response as HttpWebResponse;
    if (response != null && response.StatusCode == HttpStatusCode.NotFound) {
     response.Dispose();
     return null;
    }
    if (response != null) response.Dispose();
    throw;
   }
  }

  public static ReleaseAsset PackageAsset(ReleaseInfo release) {
   string name = "RockBand3Deluxe-" + release.Tag + "-windows-x64.zip";
   var asset = (release.Assets ?? new List<ReleaseAsset>()).FirstOrDefault(a => a.Name == name);
   Uri url;
   string prefix = "https://github.com/" + ReleaseVersion.Repository + "/releases/download/";
   if (asset == null || asset.Size <= 0 || asset.Size > MaximumPackageBytes ||
       !Uri.TryCreate(asset.DownloadUrl, UriKind.Absolute, out url) ||
       !asset.DownloadUrl.StartsWith(prefix, StringComparison.Ordinal)) {
    throw new InvalidDataException("This release has no Windows x64 application package. Open the Releases page to see its downloads.");
   }
   return asset;
  }

  static string Sha256(string path) {
   using (var sha = SHA256.Create())
   using (var input = File.OpenRead(path)) return BitConverter.ToString(sha.ComputeHash(input)).Replace("-", "");
  }

  public static bool AllowedFile(string name) {
   if (ApplicationFiles.Contains(name)) return true;
   if (!name.StartsWith("licenses/", StringComparison.Ordinal) || name.Substring(9).Contains("/")) return false;
   return Regex.IsMatch(name.Substring(9), @"^[A-Za-z0-9_.-]+\.(txt|md)$", RegexOptions.CultureInvariant);
  }

  public static void ExtractPackage(string archive, string destination, string version) {
   if (Directory.Exists(destination)) throw new IOException("The update staging folder must be new.");
   using (var zip = ZipFile.OpenRead(archive)) {
    var index = zip.GetEntry("release-files.json");
    if (index == null || index.Length > 1024 * 1024) throw new InvalidDataException("The update file list is missing or invalid.");
    ApplicationManifest manifest;
    using (var input = index.Open()) manifest = (ApplicationManifest)new DataContractJsonSerializer(typeof(ApplicationManifest)).ReadObject(input);
    if (manifest == null || manifest.Version != version || manifest.Files == null || manifest.Files.Count > 100)
     throw new InvalidDataException("The update does not match the selected release.");
    var names = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
    long total = 0;
    foreach (var file in manifest.Files) {
     if (file == null || file.Path == null || file.Path.Contains("\\") || !AllowedFile(file.Path) ||
         !names.Add(file.Path) || !Regex.IsMatch(file.Sha256 ?? "", "^[0-9A-Fa-f]{64}$"))
      throw new InvalidDataException("The update contains an invalid application file.");
     var entry = zip.GetEntry(file.Path);
     if (entry == null || entry.Length > MaximumPackageBytes) throw new InvalidDataException("An update file is missing or too large.");
     total += entry.Length;
    }
    string[] required = {"RockBand3DeluxeLauncher.exe", "RockBand3DeluxeLauncher.exe.config", "game-files.json",
     "runtime/rockband3deluxe.exe", "runtime/rexruntime.dll", "runtime/rexgpu-xenos.dll", "runtime/beatles-input.dll",
     "runtime/rb3-content.exe", "runtime/rockband3deluxe.toml", "Update-App.ps1"};
    if (total > MaximumPackageBytes || required.Any(name => !names.Contains(name)) || zip.Entries.Count != names.Count + 1)
     throw new InvalidDataException("The update package is incomplete or contains unexpected files.");
    if (zip.Entries.Select(e => e.FullName).Distinct(StringComparer.OrdinalIgnoreCase).Count() != zip.Entries.Count)
     throw new InvalidDataException("The update contains duplicate files.");
    Directory.CreateDirectory(destination);
    foreach (var file in manifest.Files) {
     string path = Path.Combine(destination, file.Path.Replace('/', Path.DirectorySeparatorChar));
     Directory.CreateDirectory(Path.GetDirectoryName(path));
     zip.GetEntry(file.Path).ExtractToFile(path);
     if (!String.Equals(Sha256(path), file.Sha256, StringComparison.OrdinalIgnoreCase))
      throw new InvalidDataException("An update file failed verification. Please download the update again.");
    }
    index.ExtractToFile(Path.Combine(destination, "release-files.json"));
   }
  }

  public static string Download(ReleaseInfo release, Action<string> progress) {
   var asset = PackageAsset(release);
   string work = Path.Combine(GameFiles.AppRoot, ".update-" + Guid.NewGuid().ToString("N"));
   Directory.CreateDirectory(work);
   try {
   string archive = Path.Combine(work, "package.zip");
   progress("Downloading " + release.Tag + ".");
   using (var response = Request(asset.DownloadUrl).GetResponse())
   using (var input = response.GetResponseStream())
   using (var output = File.Create(archive)) {
    var buffer = new byte[1024 * 1024];
    long received = 0;
    int count;
    while ((count = input.Read(buffer, 0, buffer.Length)) > 0) {
     received += count;
     if (received > asset.Size) throw new InvalidDataException("The update download exceeds its expected size.");
     output.Write(buffer, 0, count);
    }
    if (received != asset.Size) throw new InvalidDataException("The update download is incomplete.");
   }
   if (!String.IsNullOrEmpty(asset.Digest) && (!asset.Digest.StartsWith("sha256:", StringComparison.Ordinal) ||
       !String.Equals(Sha256(archive), asset.Digest.Substring(7), StringComparison.OrdinalIgnoreCase)))
    throw new InvalidDataException("The update download failed SHA-256 verification.");
   progress("Verifying application files.");
   string stage = Path.Combine(work, "application");
   ExtractPackage(archive, stage, release.Tag);
   File.Delete(archive);
   return stage;
   } catch {
    try { Directory.Delete(work, true); } catch (IOException) { } catch (UnauthorizedAccessException) { }
    throw;
   }
  }

  public static void Install(string stage) {
   string helper = Path.Combine(GameFiles.AppRoot, "Update-App.ps1");
   if (!File.Exists(helper)) throw new FileNotFoundException("The update helper is missing. Download and extract the complete Windows package.");
   string executable = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "WindowsPowerShell", "v1.0", "powershell.exe");
   string[] arguments = {"-NoProfile", "-ExecutionPolicy", "Bypass", "-File", helper,
    "-ApplicationDirectory", GameFiles.AppRoot.TrimEnd(Path.DirectorySeparatorChar),
    "-StagingDirectory", stage, "-LauncherProcessId", Process.GetCurrentProcess().Id.ToString()};
   var start = new ProcessStartInfo(executable, String.Join(" ", arguments.Select(GameFiles.Quote))) {
    UseShellExecute = false, CreateNoWindow = true, WindowStyle = ProcessWindowStyle.Hidden,
    WorkingDirectory = GameFiles.AppRoot
   };
   using (var process = Process.Start(start)) {
    if (process == null) throw new IOException("Windows could not start the update installer.");
    if (process.WaitForExit(1000)) throw new IOException("The update installer could not start. See update-result.json in the application folder.");
   }
  }

  public static bool InstallationInProgress() {
   string path = Path.Combine(GameFiles.AppRoot, ".update.lock");
   if (!File.Exists(path)) return false;
   try { using (File.Open(path, FileMode.Open, FileAccess.ReadWrite, FileShare.None)) return false; }
   catch (IOException) { return true; }
  }
 }
}

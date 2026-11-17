using System.Reflection;

[assembly: AssemblyVersion("0.1.0.0")]
[assembly: AssemblyFileVersion("0.1.0.0")]
[assembly: AssemblyInformationalVersion(RockBand3DeluxeLauncher.ReleaseVersion.Current)]

namespace RockBand3DeluxeLauncher {
 public static class ReleaseVersion {
  public const string Current = "0.1.0-preview";
  public const string Repository = "mercurialw0rld/rb3deluxe-pcport";
  public const string ReleasesUrl = "https://github.com/" + Repository + "/releases";
 }
}

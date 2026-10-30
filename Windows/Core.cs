using System.Diagnostics;
using System.Text;
using System.Text.RegularExpressions;

namespace EnvAssistant;
record CommandResult(int Code, string Text, bool TimedOut = false);
enum Detection { Installed, Missing, Unknown }
record Probe(Detection State, string? Version, string Detail);
record Choice(string Id, string Version);
record Scheme(int Schema, Choice[] Choices);

static partial class Core
{
    public const string Auto = "已有版本优先";
    public const int NoApplicationsFound = unchecked((int)0x8A150014);
    public static string? WingetPath()
    {
        string path = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Microsoft", "WindowsApps", "winget.exe");
        return File.Exists(path) ? path : null;
    }
    public static async Task<CommandResult> Run(string path, IEnumerable<string> arguments, TimeSpan timeout)
    {
        var start = new ProcessStartInfo(path) { UseShellExecute = false, CreateNoWindow = true, RedirectStandardOutput = true, RedirectStandardError = true, StandardOutputEncoding = Encoding.UTF8, StandardErrorEncoding = Encoding.UTF8 };
        foreach (string argument in arguments) start.ArgumentList.Add(argument);
        using var process = new Process { StartInfo = start };
        try
        {
            process.Start();
            var output = ReadBounded(process.StandardOutput);
            var error = ReadBounded(process.StandardError);
            using var deadline = new CancellationTokenSource(timeout);
            try { await process.WaitForExitAsync(deadline.Token); }
            catch (OperationCanceledException)
            {
                try { process.Kill(entireProcessTree: true); } catch { }
                // Installation completion is unknown after timeout; never retry automatically.
                return new(-1, "检测或安装超时，请检查当前安装状态后重新检测。", true);
            }
            return new(process.ExitCode, Clean((await output) + "\n" + (await error)));
        }
        catch (Exception e) { return new(-1, e.Message); }
    }
    static async Task<string> ReadBounded(StreamReader reader)
    {
        var text = new StringBuilder(); char[] buffer = new char[2048]; int count;
        while ((count = await reader.ReadAsync(buffer)) > 0)
        {
            text.Append(buffer, 0, count);
            if (text.Length > 24000) text.Remove(0, text.Length - 24000);
        }
        return text.ToString();
    }
    [GeneratedRegex(@"\x1B\[[0-?]*[ -/]*[@-~]")] private static partial Regex Ansi();
    public static string Clean(string text) => Ansi().Replace(text, "").Replace("\0", "").Trim();
    public static Probe ParseInstalled(string id, CommandResult result)
    {
        if (result.TimedOut) return new(Detection.Unknown, null, result.Text);
        if (result.Code == NoApplicationsFound) return new(Detection.Missing, null, "WinGet 未匹配到已安装软件；自定义安装可能未识别。");
        if (result.Code != 0) return new(Detection.Unknown, null, result.Text);
        // Match the exact ID column rather than localized header labels.
        var match = Regex.Match(result.Text, @"(?m)^[^\r\n]+?[ \t]+" + Regex.Escape(id) + @"[ \t]+(?<version>[^ \t\r\n]+)(?:[ \t\r\n]|$)", RegexOptions.CultureInvariant);
        if (!match.Success) return new(Detection.Unknown, null, "查询成功，但无法可靠读取软件行，请手动核对。\n" + result.Text);
        string version = match.Groups["version"].Value;
        return new(Detection.Installed, version, result.Text);
    }
    public static async Task<Probe> Inspect(string winget, Tool tool) => ParseInstalled(tool.Id, await Run(winget,
        ["list", "--id", tool.Id, "--exact", "--source", "winget", "--disable-interactivity"], TimeSpan.FromSeconds(45)));
    public static string Plan(Probe? probe, string requested) => probe switch
    {
        null => "请先检测",
        { State: Detection.Unknown } => "需要检查，暂不安装",
        { State: Detection.Missing } => requested == Auto ? "安装软件源当前版本" : "安装 " + requested,
        { State: Detection.Installed } when requested == Auto || probe.Version == requested => "复用已有安装",
        _ => "已有其他版本，请核对；暂不切换"
    };
    public static bool CanInstall(Probe? probe) => probe?.State == Detection.Missing;
    public static string[] Versions(string output) => output.Split('\n').Select(x => x.Trim())
        .Where(x => Regex.IsMatch(x, @"^\d+(?:\.\d+){1,4}(?:[-+][A-Za-z0-9.-]+)?$"))
        .Distinct(StringComparer.Ordinal).Take(100).ToArray();
    public static Choice[] Validate(Scheme scheme)
    {
        if (scheme.Schema != 1 || scheme.Choices is null || scheme.Choices.Length > Catalog.Tools.Length) throw new InvalidDataException("不支持的配置方案。");
        var ids = new HashSet<string>();
        foreach (var choice in scheme.Choices)
            if (choice is null || !Catalog.Tools.Any(t => t.Id == choice.Id) || !ids.Add(choice.Id) || choice.Version is null || (choice.Version != Auto && !Regex.IsMatch(choice.Version, @"^\d+(?:\.\d+){1,4}(?:[-+][A-Za-z0-9.-]+)?$"))) throw new InvalidDataException("方案包含未知软件、重复项或无效版本。");
        return scheme.Choices;
    }
    public static void Open(string uri) => Process.Start(new ProcessStartInfo(uri) { UseShellExecute = true });
}

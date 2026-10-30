namespace EnvAssistant;
record InstallReport(bool Success, string Detail);
static class Installer
{
    public static string[] Arguments(Choice choice) =>
        ["install", "--id", choice.Id, "--exact", "--source", "winget", "--interactive", "--disable-interactivity", .. (choice.Version == Core.Auto ? Array.Empty<string>() : new[] { "--version", choice.Version })];
    public static async Task<InstallReport> Execute(Choice[] choices,
        Func<Tool, Task<Probe>> inspect, Func<Choice, Task<CommandResult>> install,
        Action<string> log, Func<bool> stop)
    {
        foreach (Choice choice in Core.Validate(new Scheme(1, choices)))
        {
            if (stop()) return new(false, "已停止后续任务，已完成的安装会保留。");
            Tool tool = Catalog.Tools.Single(t => t.Id == choice.Id);
            Probe probe = await inspect(tool);
            string plan = Core.Plan(probe, choice.Version);
            log(tool.Name + "：" + plan);
            if (probe.State == Detection.Installed && (choice.Version == Core.Auto || choice.Version == probe.Version)) continue;
            if (!Core.CanInstall(probe)) return new(false, tool.Name + "：" + plan + "。请重新检测并处理。");
            if (stop()) return new(false, "已停止后续任务。");
            CommandResult result = await install(choice);
            log(tool.Name + " 安装退出码：0x" + unchecked((uint)result.Code).ToString("X8") + "\r\n" + result.Text);
            if (result.Code != 0 || result.TimedOut) return new(false, tool.Name + " 安装未确认成功，已停止后续任务。请检查日志和安装器，重新检测后再决定。");
            Probe after = await inspect(tool);
            if (after.State != Detection.Installed || (choice.Version != Core.Auto && after.Version != choice.Version))
                return new(false, tool.Name + " 安装器已结束，但未验证到所选版本。请核对软件状态，不会自动重试。");
            log(tool.Name + "：安装后已检测到 " + after.Version + "（首次启动及服务状态尚未验证）。");
        }
        return new(true, "所选软件已检测到。首次启动、账号、SDK、许可和服务运行状态请在对应软件中确认。");
    }
}

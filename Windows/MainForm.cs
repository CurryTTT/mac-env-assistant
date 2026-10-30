using System.Text;
using System.Text.Json;
namespace EnvAssistant;
sealed partial class MainForm : Form
{
    readonly DataGridView grid = new() { Dock = DockStyle.Fill, AllowUserToAddRows = false, AllowUserToDeleteRows = false, RowHeadersVisible = false, AutoSizeColumnsMode = DataGridViewAutoSizeColumnsMode.Fill, MultiSelect = false, SelectionMode = DataGridViewSelectionMode.FullRowSelect, BackgroundColor = Color.White, BorderStyle = BorderStyle.None };
    readonly ComboBox purpose = new() { DropDownStyle = ComboBoxStyle.DropDownList, Width = 130 };
    readonly TextBox search = new() { Width = 200, PlaceholderText = "搜索名称或类别" };
    readonly CheckBox consent = new() { AutoSize = true, Text = "允许 WinGet 联网查询软件源（可能发送设备区域信息）" };
    readonly Label status = new() { Dock = DockStyle.Fill, AutoEllipsis = true, Text = "请选择软件，允许联网后检测所选软件。", Padding = new Padding(8) };
    readonly TextBox log = new() { Dock = DockStyle.Fill, Multiline = true, ReadOnly = true, ScrollBars = ScrollBars.Both, WordWrap = false, Font = new Font("Consolas", 10) };
    readonly TabControl tabs = new() { Dock = DockStyle.Fill };
    readonly Dictionary<string, Probe> probes = new();
    readonly List<Control> locked = [];
    readonly Button stop = new() { Text = "完成当前项后停止", AutoSize = true, Enabled = false };
    bool busy, stopRequested;
    string? winget;

    public MainForm()
    {
        Text = "环境配置助手 · Windows 试用版 0.1.0";
        ClientSize = new Size(1180, 800); MinimumSize = new Size(1000, 660);
        StartPosition = FormStartPosition.CenterScreen; Font = new Font("Microsoft YaHei UI", 10);
        var root = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 4, ColumnCount = 1, Padding = new Padding(16) };
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, 52)); root.RowStyles.Add(new RowStyle(SizeType.Absolute, 60)); root.RowStyles.Add(new RowStyle(SizeType.Percent, 100)); root.RowStyles.Add(new RowStyle(SizeType.Absolute, 44));
        root.Controls.Add(new Label { Text = "配置你的开发环境", Font = new Font(Font.FontFamily, 22, FontStyle.Bold), AutoSize = true }, 0, 0);
        var permissions = new FlowLayoutPanel { Dock = DockStyle.Fill, WrapContents = true };
        permissions.Controls.Add(consent);
        var terms = new LinkLabel { Text = "WinGet 使用说明", AutoSize = true, Margin = new Padding(12, 4, 0, 0) };
        terms.LinkClicked += (_, _) => Core.Open("https://learn.microsoft.com/windows/package-manager/winget/"); permissions.Controls.Add(terms);
        root.Controls.Add(permissions, 0, 1); root.Controls.Add(tabs, 0, 2); root.Controls.Add(status, 0, 3); Controls.Add(root);
        CreateToolsTab(); CreateLogTab(); CreateProjectTab(); CreateAboutTab();
        winget = Core.WingetPath(); locked.Add(consent);
        if (winget is null) status.Text = "未发现 WinGet。请从“说明”打开微软 App Installer 安装页，安装后重新打开本软件。";
        FormClosing += (_, e) => { if (busy) { e.Cancel = true; MessageBox.Show("请先停止后续任务，等待当前项结束后关闭。", "任务正在进行"); } };
    }
    Button ActionButton(string text, Action action, FlowLayoutPanel parent)
    {
        var b = new Button { Text = text, AutoSize = true, Padding = new Padding(4) };
        b.Click += (_, _) => action(); parent.Controls.Add(b); locked.Add(b); return b;
    }
    void CreateLogTab()
    {
        var tab = new TabPage("安装日志"); tabs.TabPages.Add(tab); tab.Controls.Add(log);
        var bar = new FlowLayoutPanel { Dock = DockStyle.Bottom, Height = 52 };
        ActionButton("导出日志…", () => { using var d = new SaveFileDialog { Filter = "文本文件|*.txt", FileName = "环境配置日志.txt" }; if (d.ShowDialog() == DialogResult.OK) File.WriteAllText(d.FileName, log.Text, new UTF8Encoding(false)); }, bar); tab.Controls.Add(bar);
    }
    void CreateAboutTab()
    {
        var tab = new TabPage("说明"); tabs.TabPages.Add(tab);
        var panel = new FlowLayoutPanel { Dock = DockStyle.Fill, FlowDirection = FlowDirection.TopDown, WrapContents = false, Padding = new Padding(24), AutoScroll = true }; tab.Controls.Add(panel);
        panel.Controls.Add(new Label { AutoSize = true, MaximumSize = new Size(900, 0), Text = "Windows 首个试用版 · 0.1.0\n\n适用于 Windows 10 / 11 x64，需要可用的 WinGet，内置 .NET 运行库。\n\n勾选软件 → 允许联网查询 → 检测 → 可选查询版本 → 确认安装计划。第三方安装器可能显示许可、管理员权限或重启请求，由你决定。\n\n不自动接受源协议或第三方许可。若查询提示源协议未确认，请在 Windows 终端运行 winget list --source winget，查看协议并自行决定，再返回检测。WSL、GPU、SDK、模型、账号及数据库服务需要另行配置。安装后只确认 WinGet 检测结果，首次启动和服务状态需另外检查。\n\n未匹配到不代表绝对没有安装；自定义安装、便携版或其他包管理器可能未识别。请核对后再决定安装。\n\n方案只包含软件 ID 和版本。日志可能包含本机路径，导出后请自行决定分享范围。\n\n尚无 Windows 代码签名，系统可能提示未知发布者。macOS 版的 Git 配置与历史管理尚未全部移植。" });
        ActionButton("获取微软 App Installer / WinGet", () => Core.Open("https://apps.microsoft.com/detail/9nblggh4nns1"), panel);
        ActionButton("项目与下载", () => Core.Open("https://github.com/CurryTTT/mac-env-assistant/releases"), panel);
    }
    bool Ready()
    {
        winget = Core.WingetPath();
        if (winget is null) { MessageBox.Show("未发现 WinGet，请到“说明”获取微软 App Installer。"); return false; }
        if (!consent.Checked) { MessageBox.Show("请先WinGet 使用说明，再勾选允许查询。"); return false; }
        return true;
    }
    async Task Busy(Func<Task> action)
    {
        if (busy) return; busy = true; stopRequested = false;
        foreach (var c in locked) c.Enabled = false; stop.Enabled = true; UseWaitCursor = true;
        try { await action(); }
        catch (Exception e) { Append(e.Message); status.Text = "操作未完成，请查看日志。"; MessageBox.Show(e.Message, "操作未完成"); }
        finally { busy = false; foreach (var c in locked) c.Enabled = true; stop.Enabled = false; UseWaitCursor = false; }
    }
    void Append(string text)
    {
        if (text.Length > 30000) text = text[^30000..];
        if (log.TextLength > 200000) log.Text = log.Text[^100000..];
        log.AppendText(text + "\r\n\r\n");
    }
}

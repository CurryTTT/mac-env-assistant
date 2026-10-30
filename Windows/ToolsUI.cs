using System.Text;
using System.Text.Json;
namespace EnvAssistant;
sealed partial class MainForm
{
    void CreateToolsTab()
    {
        var tab = new TabPage("选择软件"); tabs.TabPages.Add(tab);
        var layout = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 4, ColumnCount = 1 };
        layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 52)); layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 42)); layout.RowStyles.Add(new RowStyle(SizeType.Percent, 100)); layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 100)); tab.Controls.Add(layout);
        var filters = new FlowLayoutPanel { Dock = DockStyle.Fill, Padding = new Padding(4), AutoScroll = true };
        purpose.Items.AddRange(Catalog.Purposes); purpose.SelectedIndex = 0;
        purpose.SelectedIndexChanged += (_, _) => Filter(); search.TextChanged += (_, _) => Filter();
        filters.Controls.Add(purpose); filters.Controls.Add(search);
        ActionButton("勾选当前筛选", () => { foreach (DataGridViewRow r in grid.Rows) if (r.Visible) r.Cells[0].Value = true; }, filters);
        ActionButton("清空选择", () => { foreach (DataGridViewRow r in grid.Rows) r.Cells[0].Value = false; }, filters);
        ActionButton("导入方案", Import, filters); ActionButton("保存方案", Export, filters); layout.Controls.Add(filters, 0, 0);
        layout.Controls.Add(new Label { Text = "用途只筛选列表；由你勾选。Python 系列分行选择，具体版本可查询后选择。已有其他版本不会自动切换。", Dock = DockStyle.Fill, Padding = new Padding(6), AutoEllipsis = true }, 0, 1);
        grid.Columns.Add(new DataGridViewCheckBoxColumn { HeaderText = "选择", FillWeight = 9 });
        grid.Columns.Add(new DataGridViewTextBoxColumn { HeaderText = "软件", ReadOnly = true, FillWeight = 27 });
        grid.Columns.Add(new DataGridViewTextBoxColumn { HeaderText = "类别", ReadOnly = true, FillWeight = 16 });
        grid.Columns.Add(new DataGridViewComboBoxColumn { HeaderText = "版本", FillWeight = 20, FlatStyle = FlatStyle.Flat });
        grid.Columns.Add(new DataGridViewTextBoxColumn { HeaderText = "已安装", ReadOnly = true, FillWeight = 20 });
        grid.Columns.Add(new DataGridViewTextBoxColumn { HeaderText = "计划", ReadOnly = true, FillWeight = 32 });
        foreach (Tool tool in Catalog.Tools)
        {
            int i = grid.Rows.Add(false, tool.Name, tool.Category, Core.Auto, "尚未检测", "请先检测"); grid.Rows[i].Tag = tool;
            var cell = (DataGridViewComboBoxCell)grid.Rows[i].Cells[3]; cell.Items.Add(Core.Auto); cell.Value = Core.Auto;
        }
        grid.CurrentCellDirtyStateChanged += (_, _) => { if (grid.IsCurrentCellDirty) grid.CommitEdit(DataGridViewDataErrorContexts.Commit); };
        grid.CellValueChanged += (_, e) => { if (e.RowIndex >= 0 && e.ColumnIndex == 3) RefreshRow(grid.Rows[e.RowIndex]); };
        grid.DataError += (_, e) => { e.ThrowException = false; status.Text = "所选版本无效，请重新选择。"; };
        locked.Add(grid); locked.Add(filters); layout.Controls.Add(grid, 0, 2);
        var actions = new FlowLayoutPanel { Dock = DockStyle.Fill, Padding = new Padding(4), AutoScroll = true };
        ActionButton("检测所选软件", async () => await Scan(), actions);
        ActionButton("查询当前行版本", async () => await LoadVersions(), actions);
        ActionButton("软件官网", () => { if (grid.CurrentRow?.Tag is Tool t) Core.Open(t.Website); }, actions);
        ActionButton("查看检测详情", () => { if (grid.CurrentRow?.Tag is Tool t && probes.TryGetValue(t.Id, out var p)) MessageBox.Show(p.Detail, t.Name, MessageBoxButtons.OK, MessageBoxIcon.Information); }, actions);
        ActionButton("确认安装计划…", async () => await Install(), actions);
        stop.Click += (_, _) => { stopRequested = true; stop.Enabled = false; status.Text = "等待当前查询或安装结束，再停止后续任务。"; };
        actions.Controls.Add(stop); layout.Controls.Add(actions, 0, 3);
    }
    void Filter()
    {
        grid.CurrentCell = null;
        string use = purpose.Text, query = search.Text.Trim();
        foreach (DataGridViewRow row in grid.Rows)
        {
            var tool = (Tool)row.Tag!;
            row.Visible = (use == "全部" || tool.Uses.Split(' ').Contains(use)) && (query.Length == 0 || (tool.Name + tool.Category + tool.Id).Contains(query, StringComparison.OrdinalIgnoreCase));
        }
    }
    Choice[] Selected() { grid.EndEdit(); return grid.Rows.Cast<DataGridViewRow>().Where(r => r.Cells[0].Value is true).Select(r => new Choice(((Tool)r.Tag!).Id, r.Cells[3].Value?.ToString() ?? Core.Auto)).ToArray(); }
    DataGridViewRow Row(string id) => grid.Rows.Cast<DataGridViewRow>().Single(r => ((Tool)r.Tag!).Id == id);
    void RefreshRow(DataGridViewRow row)
    {
        var tool = (Tool)row.Tag!; probes.TryGetValue(tool.Id, out var p);
        row.Cells[4].Value = p is null ? "尚未检测" : p.State switch { Detection.Installed => p.Version ?? "版本未知", Detection.Missing => "未匹配到", _ => "查询未确认" };
        row.Cells[5].Value = Core.Plan(p, row.Cells[3].Value?.ToString() ?? Core.Auto);
        row.DefaultCellStyle.ForeColor = p?.State == Detection.Unknown ? Color.DarkRed : Color.Black;
    }
    async Task Scan()
    {
        if (!Ready()) return; var choices = Selected();
        if (choices.Length == 0) { MessageBox.Show("请先勾选需要检测的软件。"); return; }
        await Busy(async () => {
            int n = 0;
            foreach (Choice choice in choices)
            {
                if (stopRequested) break;
                var tool = Catalog.Tools.Single(t => t.Id == choice.Id); status.Text = $"检测 {++n}/{choices.Length}：{tool.Name}";
                probes[tool.Id] = await Core.Inspect(winget!, tool); RefreshRow(Row(tool.Id));
            }
            status.Text = stopRequested ? "已停止后续检测。" : "检测完成。未匹配到的软件请核对自定义安装，再确认计划。";
        });
    }
    async Task LoadVersions()
    {
        if (!Ready() || grid.CurrentRow?.Tag is not Tool tool) return;
        await Busy(async () => {
            status.Text = "查询 " + tool.Name + " 的可用版本…";
            var result = await Core.Run(winget!, ["show", "--id", tool.Id, "--exact", "--source", "winget", "--versions", "--disable-interactivity"], TimeSpan.FromSeconds(60));
            if (result.Code != 0) throw new IOException(result.Text);
            var versions = Core.Versions(result.Text); if (versions.Length == 0) throw new IOException("未能读取可选版本。\n" + result.Text);
            var cell = (DataGridViewComboBoxCell)Row(tool.Id).Cells[3]; string previous = cell.Value?.ToString() ?? Core.Auto;
            cell.Items.Clear(); cell.Items.Add(Core.Auto); cell.Items.AddRange(versions.Cast<object>().ToArray()); cell.Value = cell.Items.Contains(previous) ? previous : Core.Auto;
            status.Text = "版本列表已读取；历史安装包能否下载，以安装结果为准。";
        });
    }
    async Task Install()
    {
        if (!Ready()) return; Choice[] choices = Selected();
        if (choices.Length == 0) { MessageBox.Show("请先勾选软件。"); return; }
        if (choices.Any(c => !probes.TryGetValue(c.Id, out var p) || p.State == Detection.Unknown || (p.State == Detection.Installed && c.Version != Core.Auto && p.Version != c.Version))) { MessageBox.Show("请先检测并处理查询失败或版本不符的项目。已有其他版本不会自动切换。"); return; }
        string plan = string.Join("\n", choices.Select(c => Catalog.Tools.Single(t => t.Id == c.Id).Name + "：" + Core.Plan(probes[c.Id], c.Version)));
        if (MessageBox.Show(plan + "\n\n将再次检查，再依次调用 WinGet。安装器可能显示许可、管理员权限或重启请求，由你决定。WSL、SDK、数据库等首次设置需另行完成。\n\n继续？", "确认安装计划", MessageBoxButtons.OKCancel, MessageBoxIcon.Information) != DialogResult.OK) return;
        await Busy(async () => {
            tabs.SelectedIndex = 1; Append("任务开始 " + DateTimeOffset.Now.ToString("u"));
            var report = await Installer.Execute(choices, async tool => { var p = await Core.Inspect(winget!, tool); probes[tool.Id] = p; RefreshRow(Row(tool.Id)); return p; },
                async c => { status.Text = "安装 " + Catalog.Tools.Single(t => t.Id == c.Id).Name + "，请留意安装器窗口…"; return await Core.Run(winget!, Installer.Arguments(c), TimeSpan.FromMinutes(60)); }, Append, () => stopRequested);
            Append(report.Detail); status.Text = report.Success ? "任务完成，请确认首次启动与服务状态。" : "任务停止，请查看日志并重新检测。";
            MessageBox.Show(report.Detail, report.Success ? "任务完成" : "需要处理");
        });
    }
    void Export()
    {
        using var d = new SaveFileDialog { Filter = "配置方案|*.json", FileName = "windows-environment.json" };
        if (d.ShowDialog() == DialogResult.OK) File.WriteAllText(d.FileName, JsonSerializer.Serialize(new Scheme(1, Selected()), new JsonSerializerOptions { WriteIndented = true }), new UTF8Encoding(false));
    }
    void Import()
    {
        using var d = new OpenFileDialog { Filter = "配置方案|*.json" }; if (d.ShowDialog() != DialogResult.OK) return;
        try
        {
            if (new FileInfo(d.FileName).Length > 65536) throw new InvalidDataException("方案文件过大。");
            var scheme = JsonSerializer.Deserialize<Scheme>(File.ReadAllText(d.FileName)) ?? throw new InvalidDataException("无效方案。"); Choice[] choices = Core.Validate(scheme);
            foreach (DataGridViewRow row in grid.Rows)
            {
                var choice = choices.SingleOrDefault(c => c.Id == ((Tool)row.Tag!).Id); row.Cells[0].Value = choice is not null;
                var cell = (DataGridViewComboBoxCell)row.Cells[3]; if (choice is not null && !cell.Items.Contains(choice.Version)) cell.Items.Add(choice.Version); cell.Value = choice?.Version ?? Core.Auto;
            }
            probes.Clear(); foreach (DataGridViewRow row in grid.Rows) RefreshRow(row);
            purpose.SelectedIndex = 0; search.Clear(); status.Text = "方案已载入，请重新检测；尚未安装任何软件。";
        }
        catch (Exception e) { MessageBox.Show(e.Message, "无法导入"); }
    }
}

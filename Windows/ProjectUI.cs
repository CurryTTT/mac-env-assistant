namespace EnvAssistant;
sealed partial class MainForm
{
    void CreateProjectTab()
    {
        var tab = new TabPage("Python 项目环境"); tabs.TabPages.Add(tab);
        var panel = new FlowLayoutPanel { Dock = DockStyle.Fill, FlowDirection = FlowDirection.TopDown, WrapContents = false, AutoScroll = true, Padding = new Padding(20) }; tab.Controls.Add(panel);
        panel.Controls.Add(new Label { Text = "选择已有 python.exe，为项目创建独立 .venv。已有目录将保留，不会覆盖。", AutoSize = true, MaximumSize = new Size(850, 0) });
        var python = new TextBox { Width = 760, PlaceholderText = "Python 解释器完整路径（python.exe）" };
        var folder = new TextBox { Width = 760, PlaceholderText = "项目文件夹" }; panel.Controls.Add(python);
        ActionButton("选择 python.exe…", () => { using var d = new OpenFileDialog { Filter = "Python 解释器|python.exe", CheckFileExists = true }; if (d.ShowDialog() == DialogResult.OK) python.Text = d.FileName; }, panel);
        panel.Controls.Add(folder); ActionButton("选择项目文件夹…", () => { using var d = new FolderBrowserDialog(); if (d.ShowDialog() == DialogResult.OK) folder.Text = d.SelectedPath; }, panel);
        ActionButton("创建 .venv…", async () =>
        {
            if (!Path.IsPathFullyQualified(python.Text) || !File.Exists(python.Text) || !Path.IsPathFullyQualified(folder.Text) || !Directory.Exists(folder.Text)) { MessageBox.Show("请选择有效的解释器和项目文件夹。"); return; }
            string interpreter = python.Text, destination = Path.Combine(folder.Text, ".venv");
            if (Path.Exists(destination)) { MessageBox.Show("已有 .venv，请手动检查。软件不会覆盖或合并该目录。"); return; }
            if (MessageBox.Show("将运行你选择的解释器：\n" + interpreter + "\n\n创建项目环境：\n" + destination, "确认创建", MessageBoxButtons.OKCancel) != DialogResult.OK) return;
            await Busy(async () => {
                var version = await Core.Run(interpreter, ["--version"], TimeSpan.FromSeconds(15));
                if (version.Code != 0 || !version.Text.StartsWith("Python 3.")) throw new IOException("解释器检查未通过：" + version.Text);
                if (Path.Exists(destination)) throw new IOException(".venv 已存在，请重新检查。");
                Append(version.Text);
                var result = await Core.Run(interpreter, ["-m", "venv", destination], TimeSpan.FromMinutes(5)); Append(result.Text);
                if (result.Code != 0) throw new IOException("创建未确认成功，请检查保留下来的目录和日志。");
                var check = await Core.Run(Path.Combine(destination, "Scripts", "python.exe"), ["-c", "import sys, ssl, pip; print(sys.executable); print(ssl.OPENSSL_VERSION); print(pip.__version__)"], TimeSpan.FromSeconds(20));
                Append(check.Text); status.Text = check.Code == 0 ? "项目解释器、SSL 与 pip 已验证；项目依赖尚未安装。" : "目录已创建，但验证失败，请查看日志。";
            });
        }, panel);
        panel.Controls.Add(new Label { Text = "创建失败时保留目录供检查。账号、模型、项目依赖及 Git 身份配置请在对应工具中处理。", AutoSize = true, MaximumSize = new Size(850, 0) });
        locked.Add(panel);
    }
}

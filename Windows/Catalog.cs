namespace EnvAssistant;

record Tool(string Id, string Name, string Category, string Uses, string Website);
static class Catalog
{
    public static readonly Tool[] Tools = [
        new("Git.Git", "Git", "基础开发", "软件工程 前端 Python AI 嵌入式 游戏", "https://git-scm.com/"),
        new("Microsoft.VisualStudioCode", "Visual Studio Code", "编辑器", "软件工程 前端 Python AI 嵌入式", "https://code.visualstudio.com/"),
        new("Anysphere.Cursor", "Cursor", "编辑器", "AI 前端 软件工程", "https://cursor.com/"),
        new("GitHub.GitHubDesktop", "GitHub Desktop", "基础开发", "软件工程 前端 游戏", "https://desktop.github.com/"),
        new("GitHub.cli", "GitHub CLI", "基础开发", "软件工程", "https://cli.github.com/"),
        new("Python.Python.3.12", "Python 3.12", "语言与运行时", "Python AI", "https://www.python.org/"),
        new("Python.Python.3.13", "Python 3.13", "语言与运行时", "Python AI", "https://www.python.org/"),
        new("OpenJS.NodeJS.LTS", "Node.js LTS", "语言与运行时", "前端 AI 软件工程", "https://nodejs.org/"),
        new("astral-sh.uv", "uv", "语言与运行时", "Python AI", "https://docs.astral.sh/uv/"),
        new("GoLang.Go", "Go", "语言与运行时", "软件工程", "https://go.dev/"),
        new("Microsoft.OpenJDK.21", "Microsoft OpenJDK 21", "语言与运行时", "软件工程", "https://www.microsoft.com/openjdk"),
        new("Rustlang.Rustup", "Rustup", "语言与运行时", "软件工程 嵌入式", "https://www.rust-lang.org/"),
        new("Ollama.Ollama", "Ollama", "AI 与容器", "AI", "https://ollama.com/"),
        new("Docker.DockerDesktop", "Docker Desktop", "AI 与容器", "AI 软件工程 数据库", "https://www.docker.com/products/docker-desktop/"),
        new("Postman.Postman", "Postman", "API 调试", "软件工程 前端", "https://www.postman.com/"),
        new("Bruno.Bruno", "Bruno", "API 调试", "软件工程 前端", "https://www.usebruno.com/"),
        new("DBeaver.DBeaver.Community", "DBeaver Community", "数据库", "数据库 软件工程", "https://dbeaver.io/"),
        new("DBBrowserForSQLite.DBBrowserForSQLite", "DB Browser for SQLite", "数据库", "数据库 Python", "https://sqlitebrowser.org/"),
        new("PostgreSQL.PostgreSQL.17", "PostgreSQL 17", "数据库", "数据库 软件工程", "https://www.postgresql.org/"),
        new("GodotEngine.GodotEngine", "Godot Engine", "游戏开发", "游戏", "https://godotengine.org/"),
        new("Unity.UnityHub", "Unity Hub", "游戏开发", "游戏", "https://unity.com/"),
        new("BlenderFoundation.Blender", "Blender", "游戏开发", "游戏", "https://www.blender.org/"),
        new("ArduinoSA.IDE.stable", "Arduino IDE", "嵌入式", "嵌入式", "https://www.arduino.cc/en/software"),
        new("Kitware.CMake", "CMake", "嵌入式", "嵌入式 软件工程 游戏", "https://cmake.org/"),
        new("Ninja-build.Ninja", "Ninja", "嵌入式", "嵌入式 软件工程", "https://ninja-build.org/"),
        new("Mozilla.Firefox", "Firefox", "网页与终端", "前端", "https://www.mozilla.org/firefox/"),
        new("Microsoft.PowerShell", "PowerShell", "网页与终端", "软件工程", "https://learn.microsoft.com/powershell/"),
        new("Microsoft.WindowsTerminal", "Windows Terminal", "网页与终端", "软件工程", "https://github.com/microsoft/terminal")
    ];
    public static readonly string[] Purposes = ["全部", "AI", "Python", "前端", "软件工程", "游戏", "数据库", "嵌入式"];
}

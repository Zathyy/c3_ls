# c3_ls

Language Server Protocol (LSP) implementation for the **C3 programming language**

---

## Getting Started

### Prerequisites
Before compiling, ensure you have the **C3 compiler (`c3c`)** installed and available in your system path. 
* Recommended version: 0.8.1

### Installation

Run the following commands in your terminal:

```bash
# 1. Clone the repository with its submodules
git clone --recursive [https://github.com/yourusername/c3_ls.git](https://github.com/yourusername/c3_ls.git)

# 2. Navigate into the project directory
cd c3_ls

# 3. Build the language server using the C3 compiler
c3c build
```

### Command-line args

| Argument | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `--stdlib-path` | `String` | *None* | Explicit path to the C3 standard library directory. |
| `--compiler-path` | `String` | *None* | Absolute path to the C3 compiler (`c3c`) binary. |
| `--log-path` | `String` | *None* | Output path destination for the language server's log file. |
| `--cache-path` | `String` | *None* | Overrides the default directory where workspace cache files are stored. |
| `--log-level` | `LogLevel` | `ERROR` | Sets the minimum logging severity (`DEBUG`, `INFO`, `WARN`, `ERROR`). |
| `--diagnostics-delay` | `uint` | `0` | Specifies a delay (in milliseconds) before calculating and sending diagnostics as you type. |
| `--send-crash-reports` | `bool` | `false` | Enables or disables automated crash reporting to help improve stability. |

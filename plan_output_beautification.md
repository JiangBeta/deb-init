# 计划：增强脚本输出美观性

**目标：**
通过引入更多颜色、美观元素和统一的日志管理，使 `main.sh` 及其子脚本的输出更加清晰、易读和美观。

**步骤：**

1.  **修改 [`scripts/common_functions.sh`](scripts/common_functions.sh)**
    *   **定义颜色常量和样式函数：** 在文件顶部定义 ANSI 颜色码常量（如 `RED`, `GREEN`, `YELLOW` 等）和样式常量（如 `BOLD`, `UNDERLINE`）。
    *   **添加新的日志级别函数：** 增加 `log_success` 函数，用于表示成功完成的操作。
    *   **添加通用的文本着色函数：** 增加 `print_color` 函数，用于输出任意带颜色的文本。
    *   **添加用于打印标题和分隔线的函数：** 增加 `print_title` 和 `print_separator` 函数，用于美化输出的结构。
    *   **优化现有日志函数：** 确保 `format_log` 函数以及 `log_info`、`log_warn`、`log_error` 能够更好地利用这些新的颜色常量。

2.  **修改 [`main.sh`](main.sh)**
    *   **更新 `show_menu` 函数：** 使用 `print_title` 函数美化菜单标题，使用 `print_color` 或直接使用颜色常量美化菜单分类和菜单项，并使用 `print_separator` 函数美化菜单的边框和分隔线。
    *   **更新 `download_and_run_script` 函数：** 确保所有输出（下载成功/失败、脚本开始/完成）都通过 `log_info`、`log_error` 或新的 `log_success` 函数进行，以统一输出风格。
    *   **更新 `execute_selection` 函数：** 确保操作结果（成功/失败）的提示信息使用 `log_info` 或 `log_error`，并美化“按任意键返回主菜单...”的提示。
    *   **统一输出流：** 检查 `main.sh` 中所有直接使用 `echo` 或 `printf` 输出到终端的地方，尽可能替换为 `common_functions.sh` 中定义的日志或美化函数。

3.  **子脚本输出统一性考虑：**
    *   为了统一子脚本的输出，子脚本也需要 `source common_functions.sh` 并使用其中定义的日志和美化函数。在实施阶段，我将先修改 `main.sh` 和 `common_functions.sh`，并建议您在后续任务中逐步修改子脚本以实现完全统一。

**Mermaid 图示：**

```mermaid
graph TD
    A[开始] --> B{读取 main.sh 和 common_functions.sh};
    B --> C{分析现有输出和日志机制};
    C --> D[定义增强输出计划];
    D --> E[修改 common_functions.sh];
    E --> E1[定义颜色常量];
    E --> E2[添加 print_color, print_title, print_separator];
    E --> E3[添加 log_success];
    E --> E4[优化现有日志函数];
    E --> F[修改 main.sh];
    F --> F1[更新 show_menu 函数];
    F --> F2[更新 download_and_run_script 函数];
    F --> F3[更新 execute_selection 函数];
    F --> F4[统一所有直接输出];
    F --> G{检查子脚本输出统一性};
    G --> H[完成];
# -*- coding: utf-8 -*-

import argparse
from pathlib import Path


def process_markdown_file(file_path: Path) -> bool:
    """
    检查单个 Markdown 文件，如果 Front Matter 中缺少 weight，
    则在其末尾添加 weight: 10 并保存。
    此版本不使用任何第三方库。

    Args:
        file_path: 指向 .md 文件的 Path 对象。

    Returns:
        如果文件被更新则返回 True，否则返回 False。
    """
    try:
        content = file_path.read_text(encoding="utf-8")

        # 检查文件是否以 Front Matter 分隔符 '---' 开头
        if not content.startswith("---"):
            return False

        # 将内容按 '---' 分割成三部分：
        # parts[0] 应为空字符串
        # parts[1] 是 Front Matter 的内容
        # parts[2] 是 Markdown 的正文
        parts = content.split("---", 2)
        if len(parts) < 3:
            # 文件格式不规范，例如只有一个 '---'
            return False

        front_matter_block = parts[1]

        # 逐行检查 'weight:' 是否已存在，这样比简单的字符串查找更准确
        has_weight = False
        for line in front_matter_block.strip().split("\n"):
            if line.strip().startswith("weight:"):
                has_weight = True
                break

        # 如果 weight 已存在，则直接返回，不做任何修改
        if has_weight:
            return False

        # 如果 weight 不存在，则在 Front Matter 的末尾添加它
        print(f"  -> Adding weight to: {file_path.name}")

        # 在现有 Front Matter 内容的末尾添加新行
        # .rstrip() 用于移除末尾可能存在的空行，保证格式整洁
        updated_front_matter = front_matter_block.rstrip() + "\nweight: 10\n"

        # 重新组合文件的所有部分
        new_content = "---".join(["", updated_front_matter, parts[2]])

        # 将更新后的完整内容写回文件
        file_path.write_text(new_content, encoding="utf-8")

        return True

    except Exception as e:
        print(f"  -> Error processing file {file_path.name}: {e}")
        return False


def main():
    """主函数，用于解析参数和遍历文件。"""
    parser = argparse.ArgumentParser(
        description="Recursively adds 'weight: 10' to Markdown files that lack it, ignoring 'papers' directories."
    )
    parser.add_argument(
        "directory",
        type=str,
        help="The root directory to scan for .md files.",
    )
    args = parser.parse_args()

    root_path = Path(args.directory)

    if not root_path.is_dir():
        print(f"Error: The provided path '{root_path}' is not a valid directory.")
        return

    print(f"Scanning for .md files in: {root_path}\n")

    updated_files_count = 0
    processed_files_count = 0
    ignored_dirs_count = 0

    # 使用 rglob 进行递归遍历
    for md_file in root_path.rglob("*.md"):
        # 检查路径的任何部分是否是 'papers' 文件夹
        if "papers" in md_file.parts:
            if ignored_dirs_count == 0:
                print("Ignoring all files under 'papers' directories...")
            ignored_dirs_count += 1
            continue

        processed_files_count += 1
        if process_markdown_file(md_file):
            updated_files_count += 1

    print("\n--------------------")
    print("✅ Scan Complete!")
    print(f"   - Processed files: {processed_files_count}")
    print(f"   - Files updated:   {updated_files_count}")
    print(f"   - Files skipped:   {processed_files_count - updated_files_count}")
    print("--------------------")


if __name__ == "__main__":
    main()

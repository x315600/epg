#!/bin/bash
# generate_m3u.sh
# 根据附件原理生成 m3u8 集合
# 输入文件: youtubelocal.m3u (必须存在于当前目录)
# 输出文件: jx.m3u

INPUT="youtubelocal.m3u"
OUTPUT="jx.m3u"

# 检查输入文件是否存在
if [ ! -f "$INPUT" ]; then
    echo "错误: 输入文件 $INPUT 不存在"
    exit 1
fi

# 清空输出文件
> "$OUTPUT"

inside_extinf=false
while IFS= read -r line || [ -n "$line" ]; do
    # 保留 #EXTM3U 头
    if [[ "$line" == "#EXTM3U" ]]; then
        echo "$line" >> "$OUTPUT"
        continue
    fi

    # 遇到 #EXTINF 标记
    if [[ "$line" == "#EXTINF:"* ]]; then
        echo "$line" >> "$OUTPUT"
        inside_extinf=true
        continue
    fi

    # 处理 URL 行
    if [[ "$line" =~ ^https?:// ]]; then
        url="$line"
        echo "Processing: $url"

        # 获取直链（同附件 fetch_direct_link 原理）
        # 使用 --no-warnings 减少干扰，错误输出到 /dev/null
        direct_url=$(yt-dlp -g --no-warnings "$url" 2>/dev/null | head -n1)

        if [ -n "$direct_url" ] && [[ "$direct_url" =~ ^https?:// ]]; then
            # 如果当前在 #EXTINF 之后，直接输出直链
            if [ "$inside_extinf" = true ]; then
                echo "$direct_url" >> "$OUTPUT"
                inside_extinf=false
            else
                # 独立的 URL，尝试获取标题并生成 #EXTINF
                title=$(yt-dlp --get-title --no-warnings "$url" 2>/dev/null)
                echo "#EXTINF:-1,${title:-YouTube Video}" >> "$OUTPUT"
                echo "$direct_url" >> "$OUTPUT"
            fi
        else
            echo "  Failed to get direct link, keeping original URL"
            # 失败时保留原 URL（同样处理 EXTINF 状态）
            if [ "$inside_extinf" = true ]; then
                echo "$line" >> "$OUTPUT"
                inside_extinf=false
            else
                # 如果独立 URL 失败，仍可生成一个占位 EXTINF
                echo "#EXTINF:-1,YouTube Video (failed)" >> "$OUTPUT"
                echo "$line" >> "$OUTPUT"
            fi
        fi
    else
        # 其他行（如注释、空白行）原样输出
        echo "$line" >> "$OUTPUT"
    fi
done < "$INPUT"

echo "Generated $OUTPUT successfully."

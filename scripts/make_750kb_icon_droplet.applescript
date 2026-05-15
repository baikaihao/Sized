on open droppedItems
    set helperPath to (POSIX path of (path to me)) & "Contents/Resources/make_750kb_icon.swift"
    set successCount to 0
    set failureText to ""

    repeat with droppedItem in droppedItems
        set itemPath to POSIX path of droppedItem
        try
            set shellCommand to "/usr/bin/swift " & (quoted form of helperPath) & " " & (quoted form of itemPath)
            do shell script shellCommand
            set successCount to successCount + 1
        on error errMsg
            set failureText to failureText & itemPath & return & errMsg & return & return
        end try
    end repeat

    if failureText is not "" then
        display dialog failureText with title "750KB Icon Maker" buttons {"OK"} default button "OK"
    else
        display notification ("已输出 " & successCount & " 个图标") with title "750KB Icon Maker"
    end if
end open

on run
    display dialog "把图片拖到这个 app 上，会在原图同目录输出不超过 750KB 的 .icns 图标。图片内容会等比缩放并居中，不会拉伸。" with title "750KB Icon Maker" buttons {"OK"} default button "OK"
end run

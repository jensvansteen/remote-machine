-- ~/.hammerspoon/init.lua — smart paste for remote terminal sessions.
--
-- Hotkey: Cmd+Shift+V
--   1. Clipboard has file URL(s)  → upload with scp, preserving filenames
--   2. Clipboard has a raw image  → save as <timestamp>.png, then upload
--   3. Otherwise                  → no-op alert
--
-- The remote path is typed only after scp succeeds. Your clipboard is never
-- replaced; normal Cmd+V elsewhere keeps its original content.
--
-- Diagnostic log at /tmp/hammerspoon.log; JXA errors at /tmp/hammerspoon-py.err
--
-- Reload hotkey: Cmd+Alt+Ctrl+R

local STAGING_DIR = os.getenv("HOME") .. "/.cache/remote-machine/handoff"
local USER_CONFIG_PATH = os.getenv("HOME") .. "/.hammerspoon/user-config.lua"
local USER_CONFIG = {}
local configOk, configValue = pcall(dofile, USER_CONFIG_PATH)
if configOk and type(configValue) == "table" then USER_CONFIG = configValue end
local MINI_HOST = USER_CONFIG.miniHost
local MINI_DROP_DIR = USER_CONFIG.miniDropDir
local LOG_PATH = "/tmp/hammerspoon.log"

local function log(msg)
    local f = io.open(LOG_PATH, "a")
    if f then
        f:write(os.date("%H:%M:%S") .. " " .. tostring(msg) .. "\n")
        f:close()
    end
end

local function urlDecode(s)
    return (s:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end))
end

local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

-- Byte-perfect file copy with zero shell involvement. Returns ok, message.
local function copyFile(src, dst)
    local fIn = io.open(src, "rb")
    if not fIn then return false, "open src failed: " .. src end
    local data = fIn:read("*all")
    fIn:close()
    if not data then return false, "read src returned nil" end

    local fOut = io.open(dst, "wb")
    if not fOut then return false, "open dst failed: " .. dst end
    local wroteOk, wroteErr = fOut:write(data)
    fOut:close()
    if not wroteOk then return false, "write dst failed: " .. tostring(wroteErr) end

    local srcAttr = hs.fs.attributes(src)
    local dstAttr = hs.fs.attributes(dst)
    return true, string.format("%d bytes (src=%d dst=%d)",
        #data,
        srcAttr and srcAttr.size or -1,
        dstAttr and dstAttr.size or -1)
end

-- Return ALL source paths currently on the pasteboard, or empty table.
-- hs.pasteboard.readURL alone often returns nil for image files copied from
-- Finder, so we also try readString and readDataForUTI on several UTIs.
local function findFilePaths()
    local paths = {}
    local seen = {}

    local function add(s)
        if type(s) ~= "string" or seen[s] then return end
        seen[s] = true
        if s:match("^file://") then
            table.insert(paths, urlDecode(s:gsub("^file://", "")))
        elseif s:sub(1, 1) == "/" then
            table.insert(paths, s)
        end
    end

    local u = hs.pasteboard.readURL()
    if type(u) == "table" then
        for _, item in ipairs(u) do add(item) end
    else
        add(u)
    end

    if #paths == 0 then
        for _, uti in ipairs({"public.file-url", "NSFilenamesPboardType", "public.url"}) do
            add(hs.pasteboard.readString(uti))
            add(hs.pasteboard.readDataForUTI(uti))
        end
    end

    return paths
end

-- JXA helper: resolve a /.file/id=... reference URL to a real filesystem path.
-- macOS Finder Cmd+C often puts these opaque URLs on the pasteboard. POSIX
-- open()/cp can't read them — only Cocoa's NSURL.filePathURL knows the
-- translation. We use JXA (JavaScript for Automation) because it's built into
-- macOS, has full Cocoa access, and doesn't need PyObjC installed.
local RESOLVER_PATH = "/tmp/hammerspoon-resolve-fileref.js"
do
    local f = io.open(RESOLVER_PATH, "w")
    if f then
        f:write([[
ObjC.import("Foundation");
function run(argv) {
    if (argv.length < 1) return "";
    var u = $.NSURL.URLWithString("file://" + argv[0]);
    if (!u) return "";
    var fp = u.filePathURL;
    return fp ? ObjC.unwrap(fp.path) : "";
}
]])
        f:close()
    end
end

local function resolveRealPath(p)
    if not p:match("^/%.file/id=") then return p end
    local cmd = string.format(
        "/usr/bin/osascript -l JavaScript %s %q 2>>/tmp/hammerspoon-py.err",
        RESOLVER_PATH, p
    )
    local out, ok = hs.execute(cmd)
    if ok and out then
        local resolved = trim(out)
        if #resolved > 0 then return resolved end
    end
    return nil
end

hs.hotkey.bind({"cmd", "shift"}, "v", function()
    if type(MINI_HOST) ~= "string" or MINI_HOST == "" or
       type(MINI_DROP_DIR) ~= "string" or MINI_DROP_DIR == "" then
        hs.alert.show("Set miniHost and miniDropDir in ~/.hammerspoon/user-config.lua", 3)
        return
    end
    if not MINI_HOST:match("^[A-Za-z0-9_.@-]+$") then
        hs.alert.show("miniHost must be an SSH alias or hostname", 3)
        return
    end
    if not MINI_DROP_DIR:match("^/[A-Za-z0-9_./-]+$") then
        hs.alert.show("miniDropDir must be an absolute path using letters, numbers, / . _ -", 3)
        return
    end

    local rawList = findFilePaths()
    local sources = {}
    for _, p in ipairs(rawList) do
        local resolved = resolveRealPath(p)
        if resolved then table.insert(sources, resolved) end
    end

    if #sources == 0 then
        local img = hs.pasteboard.readImage()
        if not img then
            hs.alert.show("Cmd+Shift+V: no image or file in clipboard", 1)
            return
        end
        hs.execute("/bin/mkdir -p " .. string.format("%q", STAGING_DIR))
        local fname = os.date("%Y%m%d-%H%M%S") .. ".png"
        local imagePath = STAGING_DIR .. "/" .. fname
        if not img:saveToFile(imagePath) then
            hs.alert.show("Could not save clipboard image", 2)
            return
        end
        sources = {imagePath}
    end

    local remotePaths = {}
    local args = {"-p", "--"}
    for _, source in ipairs(sources) do
        local fname = source:match("([^/]+)$")
        if not fname or fname:find("[\r\n]") then
            hs.alert.show("Invalid filename in clipboard item", 2)
            return
        end
        table.insert(args, source)
        table.insert(remotePaths, MINI_DROP_DIR .. "/" .. fname)
    end
    table.insert(args, MINI_HOST .. ":" .. MINI_DROP_DIR .. "/")

    hs.alert.show("Sending " .. #sources .. " file(s) over SSH…", 2)
    local task = hs.task.new("/usr/bin/scp", function(exitCode, stdout, stderr)
        log("scp exit=" .. tostring(exitCode) .. " stderr=" .. tostring(stderr))
        if exitCode ~= 0 then
            hs.alert.show("File transfer failed; check SSH and /tmp/hammerspoon.log", 3)
            return
        end
        hs.eventtap.keyStrokes(table.concat(remotePaths, "\n"))
        if #remotePaths == 1 then
            hs.alert.show("Sent → " .. remotePaths[1]:match("([^/]+)$"), 1)
        else
            hs.alert.show("Sent " .. #remotePaths .. " files", 1)
        end
    end, nil, args)
    if not task or not task:start() then
        hs.alert.show("Could not start scp transfer", 3)
    end
end)

-- Reload config: Cmd+Alt+Ctrl+R
hs.hotkey.bind({"cmd", "alt", "ctrl"}, "r", function() hs.reload() end)

hs.alert.show("Hammerspoon loaded", 0.8)

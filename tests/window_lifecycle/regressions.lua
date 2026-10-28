-- Usage: luajit regressions.lua /path/to/simpleui.koplugin /path/to/tests
local root, tests = assert(arg[1]), assert(arg[2])
package.path = root .. '/?.lua;' .. package.path
local loader = loadstring or load
unpack = unpack or table.unpack
local function source(path, first, last)
    local f = assert(io.open(root .. '/' .. path)); local s = f:read('*a'); f:close()
    local a = assert(s:find(first, 1, true)); local b = assert(s:find(last, a, true))
    return s:sub(a, b - 1)
end
local function execute(s) return assert(loader(s))() end
local function nop() end
logger = {dbg = nop, warn = nop}
Input = {}
Event = {}; function Event:new(name, ...) return {handler = 'on' .. name, args = {...}} end
local Class = {}; Class.__index = Class
function Class:extend(t) t = t or {}; t.__index = t; return setmetatable(t, self) end
function Class:new(t) t = t or {}; t.__index = nil; return setmetatable(t, self) end
function Class:getSize() return self.dimen or {w = self.width or 10, h = self.height or self[1] and self[1]:getSize().h or 10} end
function Class:handleEvent(ev)
    for _, child in ipairs(self) do if child:handleEvent(ev) then return true end end
    local fn = self[ev.handler]
    if fn then return fn(self, unpack(ev.args or {})) end
end
function Class:registerTouchZones() end
local Geom = Class:extend{}
function Geom:copy() return Geom:new{x=self.x,y=self.y,w=self.w,h=self.h} end
function Geom:combine() return self end
local Screen = {getWidth=function() return 1072 end, getHeight=function() return 1448 end, scaleBySize=function(_,n) return n end}
local Device = {screen=Screen, hasKeys=function() return arg[3] == 'keys' end, hasDPad=function() return false end, isTouchDevice=function() return true end,
    canRestart=function() return true end, canReboot=function() return true end, canSuspend=function() return true end}
UIManager = {_window_stack={}, _task_queue={}, _dirty={}}
function UIManager:setDirty() end
function UIManager:_refresh() end
function UIManager:nextTick(f) self._task_queue[#self._task_queue+1]=f end
function UIManager:scheduleIn(_, f) self:nextTick(f) end
function UIManager:forceRePaint() end
function UIManager:flushSettings() self.flushed = true end
function UIManager:quit() self._exit_code=0; self._window_stack={}; self._task_queue={} end
function UIManager:restartKOReader() self:quit(); self._exit_code=85 end
function UIManager:suspend() self.suspended=true end
assert(loadfile(tests..'/koreader-window-api.lua'))()
local original_close = UIManager.close
local function tick()
    local n=0
    while #UIManager._task_queue>0 do
        n=n+1; assert(n<100,'runaway scheduled tasks')
        local tasks_now=UIManager._task_queue; UIManager._task_queue={}
        for _,f in ipairs(tasks_now) do f() end
    end
end
local UI = {getPortraitDims=function() return 1072,1448 end,getLandscapeFactor=function() return 1 end,getTopInset=function() return 0 end,
    Notify={sticky=nop, toast=nop},getWindowStack=function() return UIManager._window_stack end}
_G.UI = UI
local Config = {isNavpagerEnabled=function() return false end,loadTabConfig=function() return {'home'} end,ICON=setmetatable({}, {__index=function(_,k) return k end})}
local bar_calls=0
local BB={AREA_H=function() return 80 end,setTempTabActive=function() bar_calls=bar_calls+1 end}
local style={COLOR={},BORDER_SZ=1}
local modules={
    ['device']=Device,['ui/uimanager']=UIManager,['ui/event']=Event,['ui/geometry']=Geom,['logger']=logger,
    ['ui/size']={padding={large=10,small=3},radius={window=3}},['ffi/util']={template=nop},
    ['infra/sui_core']=UI,['infra/sui_config']=Config,['features/sui_style']=style,
    ['infra/sui_backdrop']={RoundedFrame=Class},['infra/sui_i18n']={translate=function(t) return t end,ngettext=function(t) return t end},
    ['screens/sui_bottombar']=BB,['infra/sui_layout']={load=function() return {} end},
}
for _,name in ipairs({'ffi/blitbuffer','ui/font','ui/bidi','infra/sui_datenames','modules/moduleregistry',
    'features/dialogs/sui_bento_sheet','infra/sui_bento','infra/sui_virtual_paths','libs/libkoreader-lfs',
    'infra/sui_store','infra/sui_text'}) do modules[name]=modules[name] or {} end
for _,name in ipairs({'ui/widget/container/bottomcontainer','ui/widget/buttondialog','ui/widget/container/centercontainer',
    'ui/widget/container/framecontainer','ui/gesturerange','ui/widget/horizontalgroup','ui/widget/horizontalspan',
    'ui/widget/container/inputcontainer','ui/widget/container/leftcontainer','ui/widget/linewidget','ui/widget/overlapgroup',
    'ui/widget/container/rightcontainer','ui/widget/textboxwidget','ui/widget/textwidget','ui/widget/verticalgroup','ui/widget/verticalspan'}) do modules[name]=Class:extend{} end
modules['ui/widget/eventlistener']={handleEvent=function(self,ev) local f=self[ev.handler]; if f then return f(self, unpack(ev.args or {})) end end}
for name,m in pairs(modules) do package.loaded[name]=m end
local Window = require('engines/sui_window')
-- Exercise the actual show/close/wrapper methods, with layout/drawing omitted.
function Window:_repaint() self.repaints=(self.repaints or 0)+1 end
function Window:_updateNavbarArrows() end
local Settings = require('screens/sui_settings_window')
local sheet_spec
package.loaded['engines/sui_action_sheet']={list=function(items) return items end,show=function(opts)
    sheet_spec=opts
    local w=Window:new{screens={__root__=function() return {} end},on_close=opts.on_close}
    w:show(); return w
end}
local QA=require('features/sui_quickactions')
local passed=0
local function reset()
    Window.closeAll{force=true}; tick()
    UIManager._window_stack={}; UIManager._task_queue={}; UIManager._dirty={}
    UIManager._simpleui_exiting=nil; UIManager._exit_code=nil; UIManager.flushed=nil; UIManager.suspended=nil
    UIManager.close=original_close
    Window._open_instances={}; Settings._instance=nil
    package.loaded['apps/filemanager/filemanager']={}
    package.loaded['apps/reader/readerui']={}
    package.loaded['engines/sui_screen_engine']=nil
    QA._power_dialog=nil; sheet_spec=nil
end
local function test(name, fn)
    reset(); fn(); passed=passed+1; print('PASS '..name)
end
local function window(opts)
    opts=opts or {}; opts.screens={__root__=function() return {} end}
    local w=Window:new(opts); w:show(); return w
end
local function item(text)
    for _,v in ipairs(sheet_spec.sections[1]) do if v.text==text then return v end end
    error('missing power item '..text)
end

test('normal close removes wrapper and calls cleanup once, after stack removal',function()
    local n=0; local w
    w=window{on_close=function() assert(not w:_isWrapperShown()); n=n+1 end}
    assert(w:close()==true and w:close()==true)
    tick(); assert(n==1 and #UIManager._window_stack==0 and #Window._open_instances==0)
end)
test('CloseWidget is dispatched only once, without recursive close',function()
    local w=window(); local n=0; local own=w._wrapper.onCloseWidget
    function w._wrapper:onCloseWidget() n=n+1; return own(self) end
    w:close(); tick(); assert(n==1)
end)
test('failed close preserves window/registry/callbacks and retries successfully',function()
    local n=0; local w=window{on_close=function() n=n+1 end}
    local fail_once=true
    function UIManager:close(widget,...)
        if fail_once then fail_once=false; error('injected CloseWidget failure') end
        return original_close(self,widget,...)
    end
    assert(w:close()==false and w:isOpen() and w:_isWrapperShown())
    assert(#Window._open_instances==1 and n==0)
    assert(w:close()==true); tick()
    assert(not w:isOpen() and #Window._open_instances==0 and n==1)
end)
test('external UIManager close finalizes after removal, once',function()
    local n=0; local w=window{on_close=function() n=n+1 end}
    UIManager:close(w:getWidget()); tick()
    assert(not w:isOpen() and #Window._open_instances==0 and n==1)
end)
test('failure inside actual CloseWidget dispatch can be retried',function()
    local n=0; local w=window{on_close=function() n=n+1 end}
    local own=w._wrapper.onCloseWidget; local first=true
    function w._wrapper:onCloseWidget()
        if first then first=false; error('injected handler failure') end
        return own(self)
    end
    assert(w:close()==false and w:isOpen() and n==0)
    assert(w:close()==true); tick(); assert(n==1 and not w:isOpen())
end)
test('dismiss callbacks run once across failure/retry and reset after reopen',function()
    local n=0; local w=window{on_dismiss=function() n=n+1 end}
    function UIManager:close() error('injected failure') end
    w:dismiss(); w:dismiss(); assert(n==1 and w:isOpen())
    UIManager.close=original_close; w:dismiss(); assert(n==1 and not w:isOpen())
    w:show(); w:dismiss(); assert(n==2 and not w:isOpen())
end)
test('one close callback failure does not block cleanup of other windows',function()
    local a=window{on_close=function() error('injected cleanup failure') end}; local b=window()
    assert(Window.closeAll{force=true}); tick()
    assert(not a:isOpen() and not b:isOpen() and #Window._open_instances==0)
end)
test('close-region measurement error does not strand the wrapper',function()
    local w=window(); function w:_modalRegion() error('injected size error') end
    assert(w:close()); tick(); assert(#UIManager._window_stack==0)
end)
test('Back does not open parent when close failed',function()
    local n=0; local w=window{on_back=function() n=n+1 end}
    function UIManager:close() error('injected close failure') end
    w:_goBack(); assert(n==0 and w:isOpen())
    UIManager.close=original_close; w:_goBack(); assert(n==1)
end)
test('closeAll continues after one failure and force handles non-dismissable windows',function()
    local a=window(); local b=window{dismissable=false}; local c=window()
    function c:close() return false end
    assert(Window.closeAll{force=true}==false)
    assert(not a:isOpen() and not b:isOpen() and c:isOpen())
    c.close=Window.close
end)
test('sleep cleanup leaves non-dismissable windows alone',function()
    local a=window(); local b=window{dismissable=false}
    assert(Window.closeAll()); assert(not a:isOpen() and b:isOpen())
end)
test('100 Settings opens reuse one window and release all caller callbacks',function()
    local n=0; local w=Settings:show(function() n=n+1 end)
    for i=1,99 do assert(Settings:show(function() n=n+1 end)==w) end
    assert(#UIManager._window_stack==1 and #Window._open_instances==1)
    w:close(); assert(n==100 and Settings._instance==nil)
    assert(Settings:show()~=w)
end)
test('explicit settings editor destination replaces existing session',function()
    local a=Settings:show(); local b=Settings:show(nil,{{id='pages'}},{current_page=2})
    assert(a~=b and not a:isOpen() and #Window._open_instances==1)
end)
test('Settings refuses to open while exiting',function()
    UIManager._simpleui_exiting=true; local n=0
    assert(Settings:show(function() n=n+1 end)==nil)
    assert(n==1 and #Window._open_instances==0)
end)
test('Settings opening failure clears the singleton and allows retry',function()
    local show=Window.show; function Window:show() error('injected show failure') end
    local ok=pcall(Settings.show, Settings); Window.show=show
    assert(not ok and Settings._instance==nil)
    assert(Settings:show():isOpen())
end)
test('Quick Settings closes old menu before deferred Settings action',function()
    _QA=function() return QA end; _Config=function() return Config end
    local plugin={}; local fm={_simpleui_plugin=plugin}; plugin.ui=fm
    function plugin:_navigate(id) QA.execute(id,{plugin=self,fm=fm}) end
    liveInstances=function() return fm,nil,plugin end
    safeExecute=function(id,ctx) QA.execute(id,ctx) end
    execute(source('screens/sui_quicksettings_bar.lua','local function runAction(', '\n-- ---------------------------------------------------------------------------\n-- Shared panel pieces')..'\nrunActionUnderTest=runAction')
    local menu=Class:new{}; UIManager:show(menu)
    assert(runActionUnderTest(menu,'sui_settings')==false)
    assert(Settings._instance==nil)
    UIManager:close(menu); tick()
    assert(Settings._instance and #UIManager._window_stack==1)
    assert(QA.isAsyncInPlace('sui_settings'))
end)

SimpleUIPlugin={}
execute(source('main.lua','local function closeSimpleUIWindows()', '\n-- Removes the file-dialog button'))
for _,event in ipairs({'onExit','onRestart','onCloseWidget'}) do
    test(event..' removes all windows even when no screen engine is loaded',function()
        Settings:show(); window{dismissable=false}
        SimpleUIPlugin[event]({}); tick()
        assert(#Window._open_instances==0 and #UIManager._window_stack==0)
    end)
end

test('power menu with nil plugin opens once, without tab updates',function()
    local old=bar_calls
    QA.showPowerDialog(nil); local w=QA._power_dialog
    assert(w and w:isOpen() and bar_calls==old)
    QA.showPowerDialog(nil); assert(QA._power_dialog==w and #Window._open_instances==1)
    w:close(); assert(QA._power_dialog==nil)
end)
test('power Sleep works without live plugin',function()
    QA.showPowerDialog(nil); item('Sleep').callback(); tick()
    assert(UIManager.suspended and UIManager.flushed and QA._power_dialog==nil)
end)
for _,action in ipairs({'Quit','Restart'}) do
    test('power '..action..' works when no native event listener remains',function()
        QA.showPowerDialog(nil); item(action).callback(); tick()
        assert(UIManager._exit_code==(action=='Quit' and 0 or 85))
        assert(UIManager.flushed)
    end)
end
for _,action in ipairs({'Quit','Restart'}) do
    test('power '..action..' preserves native teardown and clears other overlays',function()
        local plugin={}; local fm=Class:new{_simpleui_plugin=plugin}; plugin.ui=fm
        local visited=false
        function fm:onExit(finish)
            SimpleUIPlugin.onExit(plugin); visited=true; UIManager:close(self); finish()
        end
        function fm:onRestart()
            SimpleUIPlugin.onRestart(plugin); visited=true; UIManager:close(self); UIManager:restartKOReader()
        end
        package.loaded['apps/filemanager/filemanager']={instance=fm}
        UIManager:show(fm); Settings:show(); window{dismissable=false}
        QA.showPowerDialog(plugin); item(action).callback(); tick()
        assert(visited and UIManager._exit_code==(action=='Quit' and 0 or 85))
        assert(#Window._open_instances==0 and #UIManager._window_stack==0)
    end)
end
test('failed power sheet close does not set a permanent exiting flag',function()
    QA.showPowerDialog(nil)
    function UIManager:close() error('injected power close failure') end
    item('Quit').callback()
    assert(not UIManager._simpleui_exiting and QA._power_dialog:isOpen())
    UIManager.close=original_close
    item('Quit').callback(); tick(); assert(UIManager._exit_code==0)
end)
test('300 repeated settings open/close cycles leave no wrappers or singleton',function()
    for i=1,300 do local w=Settings:show(); assert(w:close()); tick() end
    assert(#Window._open_instances==0 and #UIManager._window_stack==0 and Settings._instance==nil)
end)
reset()
print('RESULT '..passed..' regression tests passed ('..(jit and jit.version or _VERSION)..')')

-- Extracted from KOReader official master frontend/ui/uimanager.lua, 2026-10-28.
-- Show/close/broadcast implementations; device drawing and input are mocked.
function UIManager:show(widget, refreshtype, refreshregion, x, y, refreshdither)
    if not widget then
        logger.dbg("attempted to show a nil widget")
        return
    end
    if self.silent_mode and widget.honor_silent_mode then
        logger.dbg("widget show disabled:", widget.id or widget.name or tostring(widget))
        return
    end
    logger.dbg("show widget:", widget.id or widget.name or tostring(widget))

    local window = {x = x or 0, y = y or 0, widget = widget}
    -- put this window on top of the topmost non-modal window
    for i = #self._window_stack, 0, -1 do
        local top_window = self._window_stack[i]
        -- toasts are stacked on top of other toasts,
        -- then come modals, and then other widgets
        if top_window and top_window.widget.toast then
            if widget.toast then
                table.insert(self._window_stack, i + 1, window)
                break
            end
        elseif widget.modal or not top_window or not top_window.widget.modal then
            table.insert(self._window_stack, i + 1, window)
            break
        end
    end
    -- and schedule it to be painted
    self:setDirty(widget, refreshtype, refreshregion, refreshdither)
    -- tell the widget that it is shown now
    widget:handleEvent(Event:new("Show"))
    -- check if this widget disables double tap gesture
    Input.disable_double_tap = widget.disable_double_tap ~= false
    -- a widget may handle concurrent contacts as independent taps
    Input.allow_concurrent_taps = widget.allow_concurrent_taps == true
    -- a widget may override tap interval (when it doesn't, nil restores the default)
    Input.tap_interval_override = widget.tap_interval_override
    -- If input was disabled, re-enable it while this widget is shown so we can actually interact with it.
    -- The only thing that could actually call show in this state is something automatic, so we need to be able to deal with it.
    if UIManager._input_gestures_disabled then
        logger.dbg("Gestures were disabled, temporarily re-enabling them to allow interaction with widget")
        self:setIgnoreTouchInput(false)
        widget._restored_input_gestures = true
    end
end

function UIManager:close(widget, refreshtype, refreshregion, refreshdither)
    if not widget then
        logger.dbg("attempted to close a nil widget")
        return
    end
    logger.dbg("close widget:", widget.name or widget.id or tostring(widget))
    local dirty = false
    -- First notify the closed widget to save its settings...
    widget:handleEvent(Event:new("FlushSettings"))
    -- ...and notify it that it ought to be gone now.
    widget:handleEvent(Event:new("CloseWidget"))
    -- Make sure it's disabled by default and check if there are any widgets that want it disabled or enabled.
    Input.disable_double_tap = true
    Input.allow_concurrent_taps = false
    local requested_disable_double_tap = nil
    local is_covered = false
    local start_idx = 1
    -- Then remove all references to that widget on stack and refresh.
    for i = #self._window_stack, 1, -1 do
        local w = self._window_stack[i].widget
        if w == widget then
            self._dirty[w] = nil
            table.remove(self._window_stack, i)
            dirty = true
        else
            if not is_covered then
                -- If anything else on the stack not already hidden by (i.e., below) a fullscreen widget was dithered, honor the hint
                if w.dithered then
                    refreshdither = true
                    logger.dbg("Lower widget", w.name or w.id or tostring(w), "was dithered, honoring the dithering hint")
                end

                -- Remember the uppermost widget that covers the full screen, so we don't bother calling setDirty on hidden (i.e., lower) widgets in the following dirty loop.
                -- _repaint already does that later on to skip the actual paintTo calls, so this ensures we limit the refresh queue to stuff that will actually get painted.
                if w.covers_fullscreen then
                    is_covered = true
                    start_idx = i
                    logger.dbg("Lower widget", w.name or w.id or tostring(w), "covers the full screen")
                    if i > 1 then
                        logger.dbg("not refreshing", i-1, "covered widget(s)")
                   end
                end
            end

            -- Set double tap to how the topmost widget with that flag wants it
            if requested_disable_double_tap == nil and w.disable_double_tap ~= nil then
                requested_disable_double_tap = w.disable_double_tap
            end
        end
    end
    if requested_disable_double_tap ~= nil then
        Input.disable_double_tap = requested_disable_double_tap
    end
    if self._window_stack[1] then
        local top_widget = self._window_stack[#self._window_stack].widget
        -- set input overrides to what the topmost widget specifies
        Input.allow_concurrent_taps = top_widget.allow_concurrent_taps == true
        Input.tap_interval_override = top_widget.tap_interval_override
    end
    if dirty and not widget.invisible then
        -- schedule the remaining visible (i.e., uncovered) widgets to be painted
        for i = start_idx, #self._window_stack do
            self:setDirty(self._window_stack[i].widget)
        end
        self:_refresh(refreshtype, refreshregion, refreshdither)
    end
    if widget._restored_input_gestures then
        logger.dbg("Widget is gone, disabling gesture handling again")
        self:setIgnoreTouchInput(true)
    end
end

function UIManager:broadcastEvent(event)
    -- Unlike sendEvent, we send the event to *all* (window-level) widgets (i.e., we don't stop, even if a handler returns true).
    -- NOTE: Same defensive approach to _window_stack changing from under our feet as above.
    local checked_widgets = {}
    local handled = false
    local i = #self._window_stack
    while i > 0 do
        local widget = self._window_stack[i].widget
        if not checked_widgets[widget] then
            checked_widgets[widget] = true
            if widget:handleEvent(event) then
                handled = true
            end
            i = #self._window_stack
        else
            i = i - 1
        end
    end
    return handled
end

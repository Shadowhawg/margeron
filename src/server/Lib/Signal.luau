-- Minimal callback list. Handlers run in their own threads so one error can't break the others.
local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal:Connect(handler)
	table.insert(self._handlers, handler)
end

function Signal:Fire(...)
	for _, handler in ipairs(self._handlers) do
		task.spawn(handler, ...)
	end
end

return Signal

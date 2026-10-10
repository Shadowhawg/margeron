--!strict
-- Minimal typed signal. Handlers run in their own thread so one erroring listener
-- can't break the others.

export type Connection = { Disconnect: (self: Connection) -> () }
export type Signal<T...> = {
	Connect: (self: Signal<T...>, handler: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
}

local Signal = {}

function Signal.new<T...>(): Signal<T...>
	local handlers: { [number]: (T...) -> () } = {}
	local nextId = 0

	local signal = {}

	function signal.Connect(_self: Signal<T...>, handler: (T...) -> ()): Connection
		nextId += 1
		local id = nextId
		handlers[id] = handler
		local connection = {}
		function connection.Disconnect(_: Connection)
			handlers[id] = nil
		end
		return connection :: Connection
	end

	function signal.Fire(_self: Signal<T...>, ...: T...)
		for _, handler in handlers do
			task.spawn(handler, ...)
		end
	end

	return signal :: Signal<T...>
end

return Signal

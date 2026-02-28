-- Preload globals
local table = table
local pcall = pcall

local function tryWhile<R...>(
	f: () -> R...,
	onSuccess: ((R...) -> ())?,
	onError: ((string, number?) -> boolean?)?,
	attempt: number
)
	local out = table.pack(pcall(f))
	if out[1] then
		if onSuccess then onSuccess(table.unpack(out, 2)) end
	elseif onError then
		local try = onError(out[2], attempt)
		if try then tryWhile(f, onSuccess, onError, attempt) end
	end
end

local function try<R...>(
	f: () -> R...,
	onSuccess: ((R...) -> ())?,
	onError: ((string, number?) -> boolean?)?,
	maxAttempts: number,
	delay: number?,
	attempt: number
)
	local out = table.pack(pcall(f))
	if out[1] then
		if onSuccess then onSuccess(table.unpack(out, 2)) end
	else
		if maxAttempts > attempt then
			task.wait(delay)
			try(f, onSuccess, onError, maxAttempts, delay, attempt)
		else
			if onError then onError(out[2]) end
		end
	end
end

--- Calls provided function `f` with `pcall`, if success calls `onSuccess` with returned arguments from `f`.
--- If an error occurs, if `maxAttempts` > 0 then it will attempt to recall the `f`
--- and call `onError` when attempts reaches the end.
--- Otherwise `onError` is called each time with the error and the current attempt unless it returns `true`.
local function TryCall<R...>(
	f: () -> R...,
	onSuccess: ((R...) -> ())?,
	onError: ((string, number?) -> boolean?)?,
	maxAttempts: number?,
	attemptDelayMS: number?
)
	if maxAttempts == nil then
		tryWhile(f, onSuccess, onError, 1)
	else
		try(f, onSuccess, onError, maxAttempts, attemptDelayMS / 1000, 1)
	end
end

return TryCall

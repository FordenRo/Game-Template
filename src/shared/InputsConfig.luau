local Input = require("./Services/InputService/InputTypes")

return {
	UI = Input.Context(1, "UI", {
		Settings = Input.BoolAction(1, "Open settings", {
			Keyboard = {
				KeyCode = "N",
			},
		}),
	}),
}

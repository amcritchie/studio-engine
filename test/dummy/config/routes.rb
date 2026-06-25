Rails.application.routes.draw do
  # Draw the engine's shared route table the same way every consuming app does
  # (Studio.routes(self), not `mount`). The boot test asserts the named path
  # helpers generate, proving the engine's route DSL is valid under the host
  # Rails version's router. Controllers load lazily on dispatch, so drawing
  # these does not pull in the host-only auth controllers.
  Studio.routes(self)
end

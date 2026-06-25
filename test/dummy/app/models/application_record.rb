# Host-provided base class. The non-isolated studio-engine ships models that
# inherit from ApplicationRecord (e.g. ErrorLog, ThemeSetting) but never defines
# it — each consuming app does. The dummy app supplies it so Zeitwerk can
# autoload the engine's models when the boot test references them.
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
end

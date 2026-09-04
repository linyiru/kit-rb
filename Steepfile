# frozen_string_literal: true

target :lib do
  signature "sig"
  check "lib"

  # http.rb and json ship without RBS here; treat their calls as untyped.
  library "json"
  configure_code_diagnostics(Steep::Diagnostic::Ruby.lenient)
end

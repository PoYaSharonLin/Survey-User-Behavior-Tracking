# frozen_string_literal: true

def require_app(folders = %w[infrastructure domain application presentation lib])
  # Load config first (stays at backend_app/config/)
  Dir.glob(File.join(__dir__, 'backend_app/config/**/*.rb')).each do |file|
    require_relative file
  end

  # Load app code (all runtime code lives in backend_app/app/)
  rb_list = Array(folders).flatten.join(',')
  Dir.glob(File.join(__dir__, "backend_app/app/{#{rb_list}}/**/*.rb")).each do |file|
    require_relative file
  end
end

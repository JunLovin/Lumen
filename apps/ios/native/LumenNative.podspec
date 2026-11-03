Pod::Spec.new do |s|
  s.name = 'LumenNative'
  s.version = '0.0.1'
  s.summary = 'TurboModules that expose LumenKit to the React Native app.'
  s.homepage = 'https://github.com/JunLovin/Lumen'
  s.license = { type: 'Proprietary', text: 'All rights reserved.' }
  s.author = 'Mathias Rendón'
  s.platforms = { ios: '18.0' }
  s.source = { path: '.' }
  s.source_files = 'ios/**/*.{mm,swift}'
  s.swift_version = '6.0'

  install_modules_dependencies(s)
  spm_dependency(
    s,
    url: File.expand_path('../../../packages/LumenKit', __dir__),
    requirement: {},
    products: ['LumenApplication', 'LumenDomain', 'LumenSignal', 'LumenTransport']
  )
end

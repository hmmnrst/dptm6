
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "dptm6/version"

Gem::Specification.new do |spec|
  spec.name          = "dptm6"
  spec.version       = DPTM6::VERSION
  spec.authors       = ["Masahiro Nomoto"]
  spec.email         = ["hmmnrst@users.noreply.github.com"]

  spec.summary       = %q{dclpdftonemerge for DCL 6}
  spec.description   = %q{Merge tones in PDF made by DCL (Dennou Club Library) ver. 6}
  spec.homepage      = "https://github.com/hmmnrst/dptm6"
  spec.license       = "MIT"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end

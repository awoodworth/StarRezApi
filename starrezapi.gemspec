Gem::Specification.new do |s|
  s.name = "StarRezApi"
  s.summary = "A module mixin that allows a class to access StarRez"
  s.description = "This gem that allows the user access to the StarRez REST Web Services and Reporting API"
  s.files = Dir["{lib,rails}/**/*"] + ["MIT-LICENSE", "Rakefile"]
  s.version = "0.2.2"
  
  if s.respond_to? :specification_version then
      s.specification_version = 3

      if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
        s.add_runtime_dependency(%q<httparty>, [">= 0.7.4"])
        s.add_runtime_dependency(%q<xml-simple>, [">= 1.0.12"])
      else
        s.add_dependency(%q<httparty>, [">= 0.7.4"])
        s.add_dependency(%q<xml-simple>, [">= 1.0.12"])
      end
    else
      s.add_dependency(%q<httparty>, [">= 0.7.4"])
      s.add_dependency(%q<xml-simple>, [">= 1.0.12"])
    end
end

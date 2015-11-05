# SimpleDOI
A library for locating DOIs and retrieving metadata about their targets

## Basic Usage
### Retrieve the target resource URL from a known DOI

```ruby
require 'simple_doi'

# Instantiate a DOI object based on a DOI string
doi = SimpleDOI::DOI.new '10.1000/182'

# Specify "curb" or "net/http" as the resolver backend
doi.backend = 'curb'

# Resolve the target URL
puts doi.target_url
# Prints: "http://www.doi.org/hb.html"
```

### Extract one or more DOIs from a larger string, such as a URL
```ruby
require 'simple_doi'

input = 'http://dx.doi.org/10.1000/182'

# SimpleDOI#extract returns an array of DOI objects
dois = SimpleDOI.extract input
puts dois.first.inspect
# Prints: [#<SimpleDOI::DOI:0x007f6316bf14d8 @doi="10.1000/182", @target_url=nil, @backend=nil>]

# Note the @target_url has not yet been resolved
```

## Backends
SimpleDOI supports either Net/HTTP or cURL (via Curb) as its resolver backend.
On instantiation, it will attempt to detect if Curb is present and use it,
falling back to Net/HTTP, and raising an error if neither is available.

## Supported DOIs

## Building the gem
```shell
# Build a .gem of the current version
$ gem build simple_doi.gemspec

# Perform a local install
$ gem install simple_doi-x.x.x.gem
```

## Testing
```shell
$ bundle exec rake test
```

## Known issues

# SimpleDOI
A library for locating DOIs and retrieving metadata about their targets

## Basic Usage
### Retrieve the target resource URL from a known DOI

```ruby
require 'simple_doi'

# Instantiate a DOI object based on a DOI string
doi = SimpleDOI::DOI.new '10.1000/182'

# Override "curb" or "net/http" as the resolver backend
# Defaults to 'curb' if Curl is already in use (curb already required), otherwise Net/HTTP
doi.backend = 'curb'

# Resolve the target URL
puts doi.target_url
# Prints: "http://www.doi.org/hb.html"
```

### Extract one or more DOIs from a larger string, such as a URL
```ruby
# An HTTP backend must be loaded
require 'curb'
# alternatively
# require 'net/http'

require 'simple_doi'

input = 'http://dx.doi.org/10.1000/182'

# SimpleDOI#extract returns an array of DOI objects
dois = SimpleDOI.extract input
puts dois.first.inspect
# Prints: [#<SimpleDOI::DOI:0x007f6316bf14d8 @doi="10.1000/182", @target_url=nil, @backend=curb>]

# Note the @target_url has not yet been resolved
```

### Retrieve metadata about the target resource
Via content negotiation `Accept:` headers, JSON or XML metadata can be
retrieved.  The `SimpleDOI::MetadataParser` module provides _very basic_ parsing
for `application/citeproc+json` and `application/unixref+xml` content types.
Review the source files in `lib/metadata_parser/*.rb` to see available metadata
methods.

Note that not all targets may be able to supply your requested format. Content
negotiation allows you to request multiple types in order of preference, and the
`DOI#lookup` method will return the first it could retrieve while setting its
`response_content_type` property accordingly.

```ruby
# Retrieve JSON metadata (default format)
doi = SimpleDOI::DOI.new('10.1111/j.1475-3995.1998.tb00130.x')

# Call lookup() with no format specified for JSON
json = doi.lookup
puts doi.response_content_type
# "application/vnd.citationstyles.csl+json"

# Retrieve Unixref XML
doi = SimpleDOI::DOI.new('10.1111/j.1475-3995.1998.tb00130.x')

# Call lookup() and specify the
xml = doi.lookup SimpleDOI::UNIXREF_XML
puts doi.response_content_type
# "application/vnd.crossref.unixref+xml"

# Call lookup() and prefer XML, but fallback to JSON if unavailable
response = doi.lookup [SimpleDOI::UNIXREF_XML, SimpleDOI::CITEPROC_JSON]
# Check the response_content_type to verify you got what you wanted
if doi.response_content_type == SimpleDOI::UNIXREF_XML
  # Handle it as XML...
else
  # Handle it as JSON
end

```

Valid format arguments for `lookup` are `SimpleDOI::UNIXREF_XML,
SimpleDOI::CITEPROC_JSON`

### Parse returned metadata
The metadata format parsers included with this library are not comprehensive.
They present a common, simple interface to retrieve certain metadata components
we have needed in the past, but if you have more complex requirements you can
always pass the response body to a general purpose interface like `JSON` or
`Nokogiri`.

`SimpleDOI::MetadataParser::CiteprocJSONParser` and
`SimpleDOI::MetadataParser::UnixrefXMLParser` accept the `body` attribute set on
a `DOI` object after lookup and provide wrapper methods to retrieve certain
important bibliographic attributes.

```ruby
# Lookup an identifier, requesting Unixref XML
doi = SimpleDOI::DOI.new('10.1111/j.1475-3995.1998.tb00130.x')
doi.lookup SimpleDOI::UNIXREF_XML

# Pass the body to a UnixrefXMLParser initializer
parser = SimpleDOI::MetadataParser::UnixrefXMLParser.new(doi.body)

# Is it a book/mongraph?
parser.book?
# false

# Is it a general journal/serial (not article)?
parser.journal?
# false

# Is it a journal/serial article
parser.journal_article?
# true

# Is it a conference proceeding?
parser.conference_proceeding?
# false

# Get the ISSN
parser.issn
# "0969-6016"

# Get the journal title
parser.journal_title
# "International Transactions in Operational Research"

# Get the article title
parser.article_title
# "Passenger Choice Analysis for Seat Capacity Control...."

# Get some publication information
"Vol: #{parser.volume} Issue: #{parser.issue} Pages: #{parser.pagination} Published: #{parser.publication_date}"
# "Vol: 5 Issue: 6 Pages: 471-486"
# "Published: 1998-11-01"

# Get the authors/editors/contributors
parser.contributors
# "[#<struct SimpleDOI::MetadataParser::Parser::Contributor given_name=\"S-E.\", surname=\"Andersson\", contributor_role=\"author\", sequence=1>]"

# If multiple contributor_role values, shorthand as:
parser.authors
parser.editors

# Bundle up the whole thing as a Hash
parser.to_h
# {:book_title=>nil, :book_series_title=>nil, :isbn=>nil, :eisbn=>nil, :journal_title=>"International Transactions in Operational Research", :journal_isoabbrev_title=>"Int Trans Operational Res", :issn=>"0969-6016", :eissn=>"1475-3995", :article_title=>"Passenger Choice Analysis for Seat Capacity Control: A Pilot Project in Scandinavian Airlines", :conference_title=>nil, :contributors=>[{:given_name=>"S-E.", :surname=>"Andersson", :contributor_role=>"author", :sequence=>1}], :doi=>"10.1111/j.1475-3995.1998.tb00130.x", :url=>"http://doi.wiley.com/10.1111/j.1475-3995.1998.tb00130.x", :publisher=>nil, :volume=>"5", :issue=>"6", :pagination=>"471-486", :publication_date=>#<Date: 1998-11-01 ((2451119j,0s,0n),+0s,2299161j)>}
```

All currently implemented methods are listed in
[`lib/metadata_parser.rb`](lib/metadata_parser.rb)

## Backends
SimpleDOI supports either Net/HTTP or cURL (via Curb) as its resolver backend.
On instantiation, it will attempt to detect if Curb is present and use it,
falling back to Net/HTTP, and raising an error if neither is available.

The purpose of this is to avoid having to `require` curl when Net/HTTP is
already in use. It comes at the cost of not declaring the Curb dependency and is
maybe not helpful. It could be removed in the future, depending on one or the
other.

If neither `curb` nor `net/http` has been required previously,
`SimpleDOI::DOI.new` will raise an error.

## Supported DOIs
The University of Minnesota Libraries has collected many diverse thousands of
DOIs, mostly from URLs passing through proxy servers. This library attempts to
support all of those. They range from very simple to extremely complex.

- `10.1023/B:SOVI.0000043002.02424.ca`
- `10.1002/(SICI)1099-1050(199609)5:5!!447::AID-HEC220!!3.0.CO;2-#`

Certain common patterns are used to extract additional ISSN identifiers
from the DOIs. **Note**: These are strictly pattern matches from the DOI string,
and therefore not guaranteed to actually _be_ valid ISSNs. In our experience,
and for our purposes they are sufficient.

- `10.1111/j.1475-3995.1998.tb00130.x` will yield `1475-3995` as its ISSN

For many examples of supported strings, see
[`tests/fixtures/good-doi.txt`](tests/fixtures/good-doi.txt).

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

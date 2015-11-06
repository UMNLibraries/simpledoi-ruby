require 'minitest/autorun'
require 'webmock'
require 'webmock/minitest'
require_relative '../lib/simple_doi/simple_doi'

module SimpleDOI
  module Test
    class SimpleDOITest < MiniTest::Test
      WebMock.disable_net_connect!
      def setup
      end
      def teardown
      end

      # Test a long list of known good DOIs
      def test_valid_doi
        File.foreach File.dirname(__FILE__) + '/fixtures/good-doi.txt' do |doi|
          assert SimpleDOI.valid?(doi), "#{doi} should be considered a valid DOI"
        end
      end

      # Test a list of known faulty DOIs
      def test_invalid_doi
        File.foreach File.dirname(__FILE__) + '/fixtures/bad-doi.txt' do |doi|
          refute SimpleDOI.valid?(doi), "#{doi} should not be considered a valid DOI"
        end
      end

      def test_initialize
        # Valid DOI, creates object
        doi = '10.1234/abcdefg'
        doi_obj = SimpleDOI::DOI.new doi
        assert_instance_of SimpleDOI::DOI, doi_obj, '#{doi} should result in a valid SimpleDOI::DOI object'

        # Invalid DOI throws exception
        assert_raises ArgumentError do
          SimpleDOI::DOI.new('not a DOI')
        end

        # dx.doi.org info stripped
        doi = 'http://dx.doi.org/10.1234/abcdefg?nosfx=y'
        doi_obj = SimpleDOI::DOI.new doi
        assert doi_obj.to_s == doi, 'dx.doi.org URL info should be stripped'
      end

      def test_backend
        doi = SimpleDOI::DOI.new '10.1234/abcdefg'
        # Should work fine
        assert_equal 'curb', (doi.backend = 'curb')
        assert_equal 'net/http', (doi.backend = 'net/http')

        # Should fail invalid
        assert_raises ArgumentError do
          doi.backend = 'UNSUPPORTED'
        end
      end

      def test_prefix_suffix
        doi = SimpleDOI::DOI.new '10.1234/abcdefg.123456'
        assert_equal '10.1234', doi.prefix

        doi = SimpleDOI::DOI.new '10.1234.56/abcdefg.123456'
        assert_equal '10.1234.56', doi.prefix

        doi = SimpleDOI::DOI.new '10.1234.56/abcdefg.123456'
        assert_equal 'abcdefg.123456', doi.suffix

        # Multiple /, all in the suffix
        doi = SimpleDOI::DOI.new '10.1234/abcdefg/123456/xyz.99'
        assert_equal 'abcdefg/123456/xyz.99', doi.suffix
      end

      def test_extract_doi
        File.foreach File.dirname(__FILE__) + '/fixtures/extract-single.txt' do |line|
          expected, haystack = line.split ' ', 2
          extracted = SimpleDOI.extract haystack
          assert_kind_of SimpleDOI::DOI, extracted.first, 'The extracted object should be a SimpleDOI::DOI object'
          assert_equal expected, extracted.first.doi, "A DOI #{expected} should be found in the string and returned"
        end
      end

      def test_extract_multiple_doi
        # Multi tests repeat the same string twice
        # so each should return 2 DOIs and both should match expected
        File.foreach File.dirname(__FILE__) + '/fixtures/extract-multi.txt' do |line|
          expected, haystack = line.split ' ', 2
          found = SimpleDOI.extract haystack
          assert_equal 2, found.count, "Two DOIs should be found in the haystack string '#{haystack}'"
          assert_equal expected, found.first.doi
          assert_equal expected, found.last.doi
        end
      end

      def test_issn
        good_issn = [
          ['1234-1234', '10.1234/j.1234-1234.abcd'],
          ['1234-1234', '10.1234/ISSN.1234-1234.abcd'],
          ['1234-123X', '10.1234/J.1234-123X.abcd'],
          ['1234-123X', '10.1234/ISSN.1234-123X.abcd'],
          ['1234-123X', '10.1234/ISSN.1234-123X.abcd'],
          ['1234-1234', '10.1234/1234-1234(STUFF)abcd'],
          ['1234-123X', '10.1234/1234-123X(STUFF)abcd'],
          ['1234-123X', '10.1234/1234-123X.abcd'],
          ['1234-123X', '10.1234/S1234-123X(STUFF).abcd'],
          ['1234-123X', '10.1234/(ISSN)1234-123X.STUFF.abcd']
        ]
        bad_issn = [
          '10.1234/j.12345-1234.abc',
          '10.1234/no.issn-here',
          '10.1234/j.1234-123Z.abc',
          '10.1234/issn.1234-123z.abc',
          '10.1234/1234-1234noboundary.abc',
          '10.1234/1234-123tooshort.abc',
          '10.1234/XYZS1234-123X(STUFF).abcd'
        ]
        good_issn.each do |pair|
          doi = SimpleDOI::DOI.new pair[1]
          assert_equal pair[0], doi.issn, "The ISSN #{pair[0]} should be returned"
        end
        bad_issn.each do |doi_str|
          doi = SimpleDOI::DOI.new doi_str
          assert_nil doi.issn, "No ISSN string should be found in #{doi_str}"
        end
      end

      def test_url
        doi = SimpleDOI::DOI.new '10.1234/abcd.321'
        assert_equal 'http://dx.doi.org/10.1234%2Fabcd.321', doi.url, 'A full CGI escaped URL should be returned'
      end

      def test_lookup_json
        # Mock a set of returns first to dx.doi.org with a location redirect,
        # then to a target resource returning JSON
        expected = { 'prop1' => 'property', 'prop2' => 'property' }

        stub_request(:get, /http:\/\/dx.doi.org\/(.+)json/)
          .to_return(body: 'This is redirecting', status: 301, headers: { 'location' => 'http://example.com/doijson' })
        stub_request(:get, 'http://example.com/doijson')
          .to_return(body: expected.to_json, status: 200, headers: { 'content-type' => 'application/citeproc+json' })

        # Lookup with curb
        doi = SimpleDOI::DOI.new '10.1234/abcd.json'
        doi.backend = 'curb'
        hash = doi.lookup_json
        assert_equal expected, hash

        # Lookup with Net::HTTP
        doi = SimpleDOI::DOI.new '10.1234/abcd.json'
        doi.backend = 'net/http'
        hash = doi.lookup_json
        assert_equal expected, hash
        assert_equal 'application/citeproc+json', doi.response_content_type
      end

      def test_lookup_xml
        expected = '<?xml version="1.1><root><node>value</node>"'

        stub_request(:get, /http:\/\/dx.doi.org\/(.+)xml/)
          .to_return(body: 'This is redirecting', status: 301, headers: { 'location' => 'http://example.com/doixml' })
        stub_request(:get, 'http://example.com/doixml')
          .to_return(body: expected, status: 200, headers: { 'content-type' => 'application/unixref+xml' })

        # Lookup with curb
        doi = SimpleDOI::DOI.new '10.1234/efgh.xml'
        assert_nil doi.response_content_type, 'No content type should be set before lookup'
        assert_nil doi.body, 'No body should be set before lookup'

        doi.backend = 'curb'
        hash = doi.lookup_xml
        assert_equal expected, hash
        assert_equal 'application/unixref+xml', doi.response_content_type
        assert_equal expected, doi.body

        # Lookup with Net::HTTP
        doi = SimpleDOI::DOI.new '10.1234/efgh.xml'
        doi.backend = 'net/http'
        xml = doi.lookup_xml
        assert_equal expected, xml
        assert_equal 'application/unixref+xml', doi.response_content_type
        assert_equal expected, doi.body
      end

      def test_lookup_multi
        expected_xml = '<?xml version="1.1><root><node>value</node>"'

        stub_request(:get, /http:\/\/dx.doi.org\/(.+)xml/)
          .to_return(body: 'This is redirecting', status: 301, headers: { 'location' => 'http://example.com/doixml' })
        stub_request(:get, 'http://example.com/doixml')
          .to_return(body: expected_xml, status: 200, headers: { 'content-type' => 'application/unixref+xml' })

        expected_json = '{"prop1":"property", "prop2":"property"}'

        stub_request(:get, /http:\/\/dx.doi.org\/(.+)json/)
          .to_return(body: 'This is redirecting', status: 301, headers: { 'location' => 'http://example.com/doijson' })
        stub_request(:get, 'http://example.com/doijson')
          .to_return(body: expected_json, status: 200, headers: { 'content-type' => 'application/citeproc+json' })

        # Lookup with curb
        doi = SimpleDOI::DOI.new '10.1234/efgh.xml'
        assert_nil doi.response_content_type, 'No content type should be set before lookup'
        assert_nil doi.body, 'No body should be set before lookup'

        doi.backend = 'curb'
        # Lookup preferring xml
        body = doi.lookup([SimpleDOI::UNIXREF_XML, SimpleDOI::CITEPROC_JSON])
        assert_equal expected_xml, body
        assert_equal 'application/unixref+xml', doi.response_content_type
        assert_equal expected_xml, doi.body

        # No XML return, should get JSON
        doi = SimpleDOI::DOI.new '10.1234/efgh.json'
        assert_nil doi.response_content_type, 'No content type should be set before lookup'
        assert_nil doi.body, 'No body should be set before lookup'

        doi.backend = 'curb'
        # Lookup preferring xml, but actually get JSON
        body = doi.lookup([SimpleDOI::UNIXREF_XML, SimpleDOI::CITEPROC_JSON])
        assert_equal expected_json, body
        assert_equal 'application/citeproc+json', doi.response_content_type
        assert_equal expected_json, doi.body
      end

      def test_lookup_404
        stub_request(:get, 'http://dx.doi.org/10.1234%2Fnotexist')
          .to_return(body: 'DOI DOES NOT EXIST', status: 404, headers: { 'content-type' => 'text/html' })

        # Lookup with curb
        doi = SimpleDOI::DOI.new '10.1234/notexist'
        doi.backend = 'curb'
        assert_nil doi.lookup_json, 'Non-existing DOI should return nil'
        assert_nil doi.body
        assert_nil doi.response_content_type

        # Lookup with Net::HTTP
        doi = SimpleDOI::DOI.new '10.1234/notexist'
        doi.backend = 'net/http'
        assert_nil doi.lookup_json, 'Non-existing DOI should return nil'
        assert_nil doi.body
        assert_nil doi.response_content_type
      end

      def test_invalid_content_type_raises_exception
        stub_request(:get, /http:\/\/dx.doi.org\/(.+)/)
          .to_return(body: 'This is redirecting', status: 301, headers: { 'location' => 'http://example.com/doijson' })
        stub_request(:get, 'http://example.com/doijson')
          .to_return(body: 'This returns HTML', status: 200, headers: { 'content-type' => 'text/html' })

        doi = SimpleDOI::DOI.new '10.1234/abcd'
        doi.backend = 'curb'
        assert_raises SimpleDOI::InvalidResponseContentTypeError, 'An error should be raised when an unsupported content-type is returned' do
          doi.lookup
          puts doi.response_code
          puts doi.response_content_type

          puts doi.body
        end
      end

      def test_target_url
        stub_request(:get, 'http://dx.doi.org/10.1234%2Ftarget')
          .to_return(body: 'REDIRECT TO LOCATION', status: 301, headers: { 'location' => 'http://example.com/target' })
        stub_request(:get, 'http://dx.doi.org/10.1234%2Ftarget_notexist')
          .to_return(body: 'DOI DOES NOT EXIST', status: 404)

        doi = SimpleDOI::DOI.new '10.1234/target'
        doi.backend = 'curb'
        assert_equal 'http://example.com/target', doi.target_url, 'The target_url should match expected'

        doi = SimpleDOI::DOI.new '10.1234/target'
        doi.backend = 'net/http'
        assert_equal 'http://example.com/target', doi.target_url, 'The target_url should match expected'

        doi = SimpleDOI::DOI.new '10.1234/target_notexist'
        doi.backend = 'curb'
        assert_nil doi.target_url, 'Non-existent DOI should return nil'

        doi = SimpleDOI::DOI.new '10.1234/target_notexist'
        doi.backend = 'net/http'
        assert_nil doi.target_url, 'Non-existent DOI should return nil'
      end
    end
  end
end

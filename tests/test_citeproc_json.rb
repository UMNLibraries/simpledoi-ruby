require 'minitest/autorun'
require_relative '../lib/metadata_parser/citeproc_json_parser'

module SimpleDOI
  module MetadataParser
    module Test
      class CiteprocJSONParserTest < Minitest::Test
        def fixture_path
          File.join(File.dirname(__FILE__), 'fixtures')
        end

        def test_initialize_fail
          assert_raises JSON::ParserError do
            CiteprocJSONParser.new 'this is not json'
          end
        end

        def test_initialize
          json_str = File.read("#{fixture_path}/citeproc-journal-1.json")
          json = CiteprocJSONParser.new json_str
          assert_equal json_str, json.str, 'The input JSON string should be available as a property'
        end

        def test_type
          json = CiteprocJSONParser.new File.read("#{fixture_path}/citeproc-journal-1.json")
          assert json.journal?, 'The input JSON should represent a journal type'

          json = CiteprocJSONParser.new File.read("#{fixture_path}/citeproc-journal-2.json")
          assert json.journal?, 'The input JSON should represent a journal type'
          refute json.book?, 'The input JSON should not represent a book type'
          refute json.book_series?, 'The input JSON should not represent a book series type'

          json = CiteprocJSONParser.new File.read("#{fixture_path}/citeproc-book-2.json")
          assert json.book?, 'The input JSON should represent a book type'
          refute json.book_series?, 'The input JSON should not represent a book series type'
          refute json.journal?, 'The input JSON should not represent a journal type'

          json = CiteprocJSONParser.new File.read("#{fixture_path}/citeproc-bookseries-1.json")
          assert json.book_series?, 'The input JSON should represent a book series type'
          refute json.book?, 'The input JSON should not represent a book type'
          refute json.journal?, 'The input JSON should not represent a journal type'
        end

        def test_journal
          json = CiteprocJSONParser.new File.read("#{fixture_path}/citeproc-journal-1.json")
          assert_equal 'Rehabilitation Psychology', json.journal_title
          assert_equal '1939-1544', json.issn
          assert_equal '10.1037/0090-5550.52.1.74', json.doi

          json = CiteprocJSONParser.new File.read("#{fixture_path}/citeproc-journal-2.json")
          assert_equal 'Teaching Education', json.journal_title
          assert_equal 'Critical liberal education : an undergraduate pedagogy for teacher candidates in socially diverse university settings', json.article_title
          assert_equal '1047-6210', json.issn
          assert_equal '10.1080/10476210903420072', json.doi
          assert_nil json.isbn
          assert_nil json.book_title
          assert_nil json.book_series_title
        end

        def test_journal_to_hash
          json = CiteprocJSONParser.new File.read("#{fixture_path}/citeproc-journal-1.json")
          h = json.to_hash
          assert_equal 'Rehabilitation Psychology', h[:journal_title]
          assert_equal '1939-1544', h[:issn]
          assert_equal '10.1037/0090-5550.52.1.74', h[:doi]
          assert_nil h[:isbn]
          assert_nil h[:eisbn]
          assert_nil h[:book_title]
        end

        def test_book
          json = CiteprocJSONParser.new File.read("#{fixture_path}/citeproc-book-2.json")
          assert_equal 'The Triple Helix, Open Innovation, and the DOI Research Agenda', json.book_title
          assert_equal '978-0-387-72803-2', json.isbn
          assert_nil json.journal_isoabbrev_title
          assert_nil json.issn
          assert_nil json.eissn
          assert_equal '10.1007/978-0-387-72804-9_32', json.doi

          json = CiteprocJSONParser.new File.read("#{fixture_path}/citeproc-book-3.json")
          assert_equal 'Organizational Dynamics of Technology-Based Innovation: Diversifying the Research Agenda', json.book_title
          assert_equal '978-0-387-72803-2', json.isbn
          assert_nil json.eisbn
          assert_nil json.journal_isoabbrev_title
          assert_nil json.issn
          assert_nil json.eissn
          assert_equal '10.1007/978-0-387-72804-9', json.doi
        end

        def test_book_to_hash
          json = CiteprocJSONParser.new File.read("#{fixture_path}/citeproc-book-2.json")
          h = json.to_hash
          assert_equal 'The Triple Helix, Open Innovation, and the DOI Research Agenda', h[:book_title]
          assert_equal '978-0-387-72803-2', h[:isbn]
          assert_equal '10.1007/978-0-387-72804-9_32', h[:doi]

          assert_nil h[:issn]
          assert_nil h[:eissn]
          assert_nil h[:journal_title]
          assert_nil h[:journal_isoabbrev_title]
        end

        def test_book_series
          json = CiteprocJSONParser.new File.read("#{fixture_path}/citeproc-bookseries-1.json")
          assert_equal 'ACS Symposium Series', json.book_series_title
          assert_equal 'The Fate of Nutrients and Pesticides in the Urban Environment', json.book_title
          assert_equal '0-8412-7422-3', json.isbn
          assert_equal '1947-5918', json.issn
          assert_equal '10.1021/bk-2008-0997', json.doi
        end

        def test_conference_proceeding
          json = CiteprocJSONParser.new File.read("#{fixture_path}/citeproc-conference-2.json")
          assert_equal 'Exact Solutions for In-Plane Displacements of Curved Beams under Thermo Load', json.article_title
          assert_equal '2009 International Conference on Engineering Computation', json.book_title
          assert_equal '2009 International Conference on Engineering Computation', json.book_series_title
          assert_equal '978-0-7695-3655-2', json.isbn
          assert_equal '10.1109/icec.2009.62', json.doi
        end
      end
    end
  end
end

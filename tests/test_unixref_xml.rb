require 'minitest/autorun'
require_relative '../lib/metadata_parser/unixref_xml_parser'

module SimpleDOI
  module MetadataParser
    module Test
      class UnixrefXMLParserTest < Minitest::Test
        def fixture_path
          File.join(File.dirname(__FILE__), 'fixtures')
        end

        def test_initialize_fail
          assert_raises Nokogiri::XML::SyntaxError do
            UnixrefXMLParser.new 'this is not xml'
          end
        end

        def test_initialize
          xml_str = File.read("#{fixture_path}/unixref-journal-1.xml")
          xml = UnixrefXMLParser.new xml_str
          assert_equal xml_str, xml.str, 'The input XML string should be available as a property'
        end

        def test_type
          xml = UnixrefXMLParser.new File.read("#{fixture_path}/unixref-journal-1.xml")
          assert xml.journal_article?

          xml = UnixrefXMLParser.new File.read("#{fixture_path}/unixref-journal-2.xml")
          assert xml.journal_article?
          refute xml.book?
          refute xml.book_series?
          refute xml.conference_proceeding?

          xml = UnixrefXMLParser.new File.read("#{fixture_path}/unixref-journal-root-1.xml")
          assert xml.journal?
          refute xml.journal_article?
          refute xml.book?
          refute xml.book_series?
          refute xml.conference_proceeding?

          xml = UnixrefXMLParser.new File.read("#{fixture_path}/unixref-book-2.xml")
          assert xml.book?
          refute xml.book_series?
          refute xml.journal_article?
          refute xml.conference_proceeding?

          xml = UnixrefXMLParser.new File.read("#{fixture_path}/unixref-bookseries-1.xml")
          assert xml.book_series?
          refute xml.book?
          refute xml.journal_article?
          refute xml.conference_proceeding?

          xml = UnixrefXMLParser.new File.read("#{fixture_path}/unixref-book-chapter-2.xml")
          assert xml.book_chapter?

          xml = UnixrefXMLParser.new File.read("#{fixture_path}/unixref-conference-1.xml")
          assert xml.conference_proceeding?
          refute xml.book?
          refute xml.journal_article?
          refute xml.book_series?

          xml = UnixrefXMLParser.new File.read("#{fixture_path}/unixref-conference-2.xml")
          assert xml.conference_proceeding?
          refute xml.book?
          refute xml.journal_article?
          refute xml.book_series?
        end

        def test_journal
          xml = UnixrefXMLParser.new File.read("#{fixture_path}/unixref-journal-1.xml")
          assert_equal 'Rehabilitation Psychology', xml.journal_title
          assert_equal 'Rehab. Psych.', xml.journal_isoabbrev_title
          assert_equal 'Fear of reinjury, negative affect, and catastrophizing predicting return to sport in recreational athletes with anterior cruciate ligament injuries at 1 year postsurgery.', xml.article_title
          assert_equal '0090-5550', xml.issn
          assert_equal '1939-1544', xml.eissn
          assert_equal '10.1037/0090-5550.52.1.74', xml.doi
          assert_equal 'http://doi.apa.org/getdoi.cfm?doi=10.1037/0090-5550.52.1.74', xml.url
          assert_equal 'http://doi.apa.org/getdoi.cfm?doi=10.1037/0090-5550.52.1.74&fakeformat=pdf', xml.fulltext_url

          xml = UnixrefXMLParser.new File.read("#{fixture_path}/unixref-journal-2.xml")
          assert_equal 'Teaching Education', xml.journal_title
          assert_equal 'Teaching Ed.', xml.journal_isoabbrev_title
          assert_equal '1047-6210', xml.issn
          assert_equal '1470-1286', xml.eissn
          assert_equal '10.1080/10476210903420072', xml.doi
          assert_equal 'http://www.tandfonline.com/doi/abs/10.1080/10476210903420072', xml.url
          assert_equal 'Christina', xml.authors.first.given_name
          assert_equal 'Chávez‐Reyes', xml.authors.first.surname
          assert_equal 1, xml.authors.first.sequence
          assert_equal 'author', xml.authors.first.contributor_role
          assert_nil xml.isbn
          assert_nil xml.book_title
          assert_nil xml.book_series_title
          assert_nil xml.fulltext_url
        end

        def test_issn_without_print_attribute
          xml = UnixrefXMLParser.new File.read("#{fixture_path}/unixref-journal-1-noissnattr.xml")
          assert_equal '0090-5550', xml.issn
          assert_equal '1939-1544', xml.eissn
        end

        def test_journal_to_h
          xml = UnixrefXMLParser.new File.read("#{fixture_path}/unixref-journal-1.xml")
          h = xml.to_h
          assert_equal 'Rehabilitation Psychology', h[:journal_title]
          assert_equal 'Rehab. Psych.', h[:journal_isoabbrev_title]
          assert_equal '0090-5550', h[:issn]
          assert_equal '1939-1544', h[:eissn]
          assert_equal '10.1037/0090-5550.52.1.74', h[:doi]
          assert_equal 'http://doi.apa.org/getdoi.cfm?doi=10.1037/0090-5550.52.1.74', h[:url]
          assert_nil h[:isbn]
          assert_nil h[:eisbn]
          assert_nil h[:book_title]
        end

        def test_book
          xml = UnixrefXMLParser.new File.read("#{fixture_path}/unixref-book-2.xml")
          assert_equal 'Organizational Dynamics of Technology-Based Innovation: Diversifying the Research Agenda', xml.book_title
          assert_equal '978-0-387-72803-2', xml.isbn
          assert_equal '978-0-387-72803-X', xml.eisbn
          assert_nil xml.journal_isoabbrev_title
          assert_nil xml.issn
          assert_nil xml.eissn
          assert_equal '10.1007/978-0-387-72804-9', xml.doi
          assert_equal 'http://www.springerlink.com/index/10.1007/978-0-387-72804-9', xml.url
          assert_equal '235', xml.volume
          assert_equal 'Springer US; Boston, MA', xml.publisher
          assert_equal Date.new(2007, 1, 1), xml.publication_date
          assert_equal Hash[year: 2007, month: nil, day: nil], xml.publication_date_hash

          xml = UnixrefXMLParser.new File.read("#{fixture_path}/unixref-book-3.xml")
          assert_equal 'This Book Title', xml.book_title
          assert_equal '978-0-387-72803-2', xml.isbn
          assert_nil xml.eisbn
          assert_nil xml.journal_isoabbrev_title
          assert_nil xml.issn
          assert_nil xml.eissn
          assert_equal '10.1007/978-0-387-72804-9', xml.doi
          assert_equal 'http://link.springer.com/10.1007/978-0-387-72804-9', xml.url
          assert_equal '235', xml.volume
          assert_equal 'Springer US', xml.publisher
          assert_equal Date.new(2007, 1, 1), xml.publication_date
        end

        def test_isbn_without_print_attribute
          xml = UnixrefXMLParser.new File.read("#{fixture_path}/unixref-book-2-noisbnattr.xml")
          assert_equal '978-0-387-72803-2', xml.isbn
          assert_equal '978-0-387-72803-X', xml.eisbn
        end

        def test_book_to_h
          xml = UnixrefXMLParser.new File.read("#{fixture_path}/unixref-book-2.xml")
          h = xml.to_h
          assert_equal 'Organizational Dynamics of Technology-Based Innovation: Diversifying the Research Agenda', h[:book_title]
          assert_equal '978-0-387-72803-2', h[:isbn]
          assert_equal '978-0-387-72803-X', h[:eisbn]
          assert_equal '10.1007/978-0-387-72804-9', h[:doi]
          assert_equal 'http://www.springerlink.com/index/10.1007/978-0-387-72804-9', h[:url]
          assert_equal 4, h[:contributors].count
          assert_equal 'Ferneley', h[:contributors][2][:surname]
          assert_equal Date.new(2007, 1, 1), h[:publication_date]

          assert_nil h[:issn]
          assert_nil h[:eissn]
          assert_nil h[:journal_title]
          assert_nil h[:journal_isoabbrev_title]
        end

        def test_book_chapter
          xml = UnixrefXMLParser.new File.read("#{fixture_path}/unixref-book-chapter-1.xml")
          assert_equal 'Theory and Research on Small Groups', xml.book_title
          assert_equal 'Cooperative Learning and Social Interdependence Theory', xml.chapter_title
          assert_equal 'Social Psychological Applications to Social Issues', xml.book_series_title
          assert_equal 'Chapter 2', xml.chapter_number
          assert_equal '9-35', xml.pagination
          assert_equal Date.new(2002, 1, 1), xml.publication_date
          assert_equal '0-306-45679-6', xml.isbn
          assert_equal 8, xml.editors.count
          assert_equal 2, xml.authors.count
          assert_equal 10, xml.contributors.count
          assert_equal 'http://www.springerlink.com/index/pdf/10.1007/0-306-47144-2_2', xml.fulltext_url

          xml = UnixrefXMLParser.new File.read("#{fixture_path}/unixref-book-chapter-2.xml")
          assert_equal '10.1159/000446756', xml.doi
          assert_equal 'Perspiration Research', xml.book_title
          assert_equal 'Sweat as an Efficient Natural Moisturizer', xml.chapter_title
          assert_equal 'Current Problems in Dermatology', xml.book_series_title
          assert_nil xml.chapter_number
          assert_equal '30-41', xml.pagination
          assert_equal 'http://www.karger.com/Article/Pdf/446756', xml.fulltext_url
        end

        def test_book_series
          xml = UnixrefXMLParser.new File.read("#{fixture_path}/unixref-bookseries-1.xml")
          assert_equal 'ACS Symposium Series', xml.book_series_title
          assert_equal 'The Fate of Nutrients and Pesticides in the Urban Environment', xml.book_title
          assert_equal '0-8412-7422-3', xml.isbn
          assert_equal '0-8412-2140-5', xml.eisbn
          assert_equal '1947-5918', xml.eissn
          assert_equal '10.1021/bk-2008-0997', xml.doi
          assert_equal 'http://pubs.acs.org/doi/book/10.1021/bk-2008-0997', xml.url
          assert_equal 1, xml.authors.count
          assert_equal 'Art Vandelay', xml.authors[0].given_name + ' ' + xml.authors[0].surname
          assert_equal 4, xml.editors.count
          assert_equal 'Petrovic', xml.editors.last.surname
          assert_equal 1, xml.contributors.last.sequence
          # This series lists 4 editors and 1 author
          assert_equal 'author', xml.contributors.last.contributor_role
          assert_equal "997", xml.volume
          assert_equal Date.new(2008, 9, 12), xml.publication_date
        end

        def test_conference_proceeding
          xml = UnixrefXMLParser.new File.read("#{fixture_path}/unixref-conference-1.xml")
          assert_equal '2012 IEEE Symposium on Computer Applications and Industrial Electronics (ISCAIE)', xml.conference_title
          assert_equal '2012 International Symposium on Computer Applications and Industrial Electronics (ISCAIE)', xml.book_title
          assert_equal '978-1-4673-3032-9', xml.isbn
          assert_equal '978-1-4673-3033-6', xml.eisbn
          assert_equal 'Evaluating thread level parallelism based on optimum cache architecture', xml.article_title
          assert_equal '10.1109/ISCAIE.2012.6482067', xml.doi
          assert_equal 'http://ieeexplore.ieee.org/lpdocs/epic03/wrapper.htm?arnumber=6482067', xml.url
          assert_equal "48-53", xml.pagination
          assert_equal Date.new(2012, 12, 1), xml.publication_date

          xml = UnixrefXMLParser.new File.read("#{fixture_path}/unixref-conference-2.xml")
          assert_equal '2009 International Conference on Engineering Computation', xml.conference_title
          assert_equal '2009 International Conference on Engineering Computation', xml.book_title
          assert_equal '978-0-7695-3655-2', xml.isbn
          assert_nil xml.eisbn
          assert_equal 'Exact Solutions for In-Plane Displacements of Curved Beams under Thermo Load', xml.article_title
          assert_equal 'Zhao', xml.authors.last.surname
          assert_equal '10.1109/ICEC.2009.62', xml.doi
          assert_equal 'http://ieeexplore.ieee.org/lpdocs/epic03/wrapper.htm?arnumber=5167124', xml.url
          assert_equal '193-196', xml.pagination
          assert_equal 'IEEE', xml.publisher
          assert_equal Date.new(2009, 5, 1), xml.publication_date
        end

        def test_conference_series
          xml = UnixrefXMLParser.new File.read("#{fixture_path}/unixref-conference-series-1.xml")
          assert_equal '219th ECS Meeting', xml.conference_title
          assert_equal 'Optical and Electrical Properties of Si-Based Multilayer Structures for Solar Cell Applications', xml.article_title
          assert_equal 'ECS Transactions', xml.conference_series_title
        end
      end
    end
  end
end

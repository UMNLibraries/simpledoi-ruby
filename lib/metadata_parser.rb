module SimpleDOI
  module MetadataParser
    # Metadata parser base class
    class Parser
      PROPERTIES = [
        :book_title,
        :book_series_title,
        :chapter_title,
        :chapter_number,
        :isbn,
        :eisbn,
        :journal_title,
        :journal_isoabbrev_title,
        :issn,
        :eissn,
        :article_title,
        :conference_title,
        :conference_series_title,
        :contributors,
        :doi,
        :url,
        :publisher,
        :volume,
        :issue,
        :pagination,
        :publication_date
      ].freeze

      Contributor = Struct.new(:given_name, :surname, :contributor_role, :sequence)

      # Params:
      # +str+:: +String+ XML String
      def initialize(str)
        @str = str
      end

      def journal?
        raise NotImplementedError
      end

      def journal_article?
        raise NotImplementedError
      end

      def book?
        raise NotImplementedError
      end

      def book_series?
        raise NotImplementedError
      end

      def authors
        contributors.select {|c| c.contributor_role == 'author'}
      end

      def editors
        contributors.select {|c| c.contributor_role == 'editor'}
      end

      def contributors
        @contributors ||= []
      end

      def publisher
        # Return publisher name concatenated with place if available
        # If would throw a method error for :+ on publisher_name if nil, to dump nil for the whole thing
        publisher_name + (publisher_place ? "; #{publisher_place}" : "") rescue nil
      end

      def publisher_name
        raise NotImplementedError
      end

      def publisher_place
        raise NotImplementedError
      end

      # Return all properties as a Hash
      def to_h
        hash = {}
        PROPERTIES.each { |property| hash[property] = send property }
        # Array of Struct needs additional handling
        hash[:contributors] = @contributors.map(&:to_h)
        hash
      end
      alias :to_hash :to_h

      # Default readers for all PROPERTIES unless a real method already exists
      # Instead of doing this at the beginning then overwriting some property methods
      # since ruby will complain with warnings when redefining methods.
      attr_reader :str, *(PROPERTIES.reject {|p| method_defined?(p)})
    end
  end
end

# CHANGELOG

1.0.0:
 * `SimpleDOI::MetadataParser#journal?` behavior has changed and
   `SimpleDOI::MetadataParser#journal_article?` was added.  Previously, calls to
   `journal?` would return true for DOI's pointing to articles or DOI's pointing
   to the journal itself rather than a specific article. As of 1.0.0,
   `.journal?` returns `true` for the journal record only.  Use
   `journal_article?` to determine if the metadata represents a single article
   within a containing journal/publication.

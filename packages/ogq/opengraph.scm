(self_closing_tag
  (tag_name) @tag
  (attribute
    (attribute_name) @opengraph
    (quoted_attribute_value) @value)
  (attribute
    (attribute_name) @key
    (quoted_attribute_value) @value)
  (#eq? @tag "meta")
  (#any-of? @opengraph "property")
  (#any-of? @key "content"))
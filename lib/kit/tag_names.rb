# frozen_string_literal: true

module Kit
  # How Kit matches tag names, in one dependency-free place so the client
  # (Resources::Tags#ensure, Subscribers#upsert_and_tag) and Kit::Testing's
  # factories agree exactly: runs of Unicode whitespace (`[[:space:]]`, not
  # `\s`, so a fullwidth or typographic space cannot mint a look-alike tag)
  # collapsed to one ASCII space and trimmed; then matched case-insensitively.
  module TagNames
    # The canonical spelling. Raises ArgumentError when nothing is left.
    def self.normalize(name)
      normalized = name.to_s.gsub(/[[:space:]]+/, " ").strip
      raise ArgumentError, "tag name must not be blank" if normalized.empty?

      normalized
    end

    # The key two names share when Kit would treat them as the same tag.
    def self.key(name)
      normalize(name).downcase
    end

    # Normalised names, first spelling wins, one per case-insensitive key —
    # the set of tags upsert_and_tag applies for `names`.
    def self.distinct(names)
      Array(names).map { |name| normalize(name) }.uniq(&:downcase)
    end
  end
end

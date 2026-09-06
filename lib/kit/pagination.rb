# frozen_string_literal: true

module Kit
  # The `pagination` object Kit returns alongside every list. Kit uses cursor
  # pagination: to walk forward, pass `after: end_cursor`; backward, `before:
  # start_cursor`. `total_count` is present only when the request asked for it
  # with `include_total_count: true` (nil otherwise).
  Pagination = Data.define(
    :has_previous_page, :has_next_page, :start_cursor, :end_cursor, :per_page, :total_count
  ) do
    # total_count is optional so Pagination.new(...) without it keeps working.
    def initialize(total_count: nil, **rest)
      super
    end

    def self.from(hash)
      new(
        has_previous_page: hash["has_previous_page"],
        has_next_page: hash["has_next_page"],
        start_cursor: hash["start_cursor"],
        end_cursor: hash["end_cursor"],
        per_page: hash["per_page"],
        total_count: hash["total_count"]
      )
    end
  end

  # One page of results plus the cursor to fetch the next. `Collection` is
  # Enumerable over the *current* page; `auto_paging_each` lazily walks every
  # remaining page by following `end_cursor`, so callers never touch cursors:
  #
  #   client.subscribers.list.auto_paging_each { |s| puts s.email_address }
  #   client.subscribers.list.auto_paging_each.lazy.first(500)
  #
  # The block given to `.new` fetches the next Collection from an `after` cursor.
  class Collection
    include Enumerable

    # Query params that must not be carried into a follow-up page request: a
    # `before` cursor contradicts the `after` we add, and Kit asks that
    # `include_total_count` be sent on the first page only.
    FIRST_PAGE_ONLY = %i[before include_total_count].freeze

    # The params for the page after `after`, derived from the original request.
    def self.next_page_params(params, after)
      params.reject { |key, _| FIRST_PAGE_ONLY.include?(key.to_sym) }.merge(after: after)
    end

    attr_reader :data, :pagination

    # Kit's total across all pages, when the first request asked for it.
    def total_count
      @pagination.total_count
    end

    def initialize(data:, pagination:, &fetch_after)
      @data = data
      @pagination = pagination
      @fetch_after = fetch_after
    end

    # Iterates the current page only.
    def each(&)
      @data.each(&)
    end

    # The next Collection, or nil when there is no next page.
    def next_page
      return nil unless @pagination.has_next_page

      @fetch_after.call(@pagination.end_cursor)
    end

    # Iterates every item across every remaining page, fetching lazily. Returns
    # an Enumerator when no block is given (so `.lazy` composes).
    def auto_paging_each(&block)
      return enum_for(:auto_paging_each) unless block

      page = self
      loop do
        page.data.each(&block)
        break unless page.pagination.has_next_page

        page = page.next_page
      end
    end
  end
end

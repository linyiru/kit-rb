# frozen_string_literal: true

RSpec.describe Kit::Collection do
  # Builds a Collection whose next-page fetcher walks a fixed list of pages,
  # exercising the pagination engine without any real resource.
  def paged(pages)
    build = lambda do |index|
      items, has_next = pages[index]
      pagination = Kit::Pagination.new(
        has_previous_page: index.positive?, has_next_page: has_next,
        start_cursor: "s#{index}", end_cursor: "e#{index}", per_page: 2
      )
      described_class.new(data: items, pagination: pagination) do |after|
        expect(after).to eq("e#{index}") # follows end_cursor forward
        build.call(index + 1)
      end
    end
    build.call(0)
  end

  it "is Enumerable over the current page only" do
    collection = paged([[%w[a b], true], [%w[c], false]])
    expect(collection.to_a).to eq(%w[a b])
    expect(collection.map(&:upcase)).to eq(%w[A B])
  end

  it "auto_paging_each walks every item across every page" do
    collection = paged([[%w[a b], true], [%w[c d], true], [%w[e], false]])
    seen = []
    collection.auto_paging_each { |item| seen << item }
    expect(seen).to eq(%w[a b c d e])
  end

  it "auto_paging_each returns a lazy Enumerator without a block" do
    collection = paged([[%w[a b], true], [%w[c d], true], [%w[e], false]])
    expect(collection.auto_paging_each.lazy.first(3)).to eq(%w[a b c])
  end

  it "next_page is nil on the last page" do
    collection = paged([[%w[a], false]])
    expect(collection.next_page).to be_nil
  end

  it "stops after one page when has_next_page is false" do
    collection = paged([[%w[only], false]])
    expect(collection.auto_paging_each.to_a).to eq(%w[only])
  end
end

# frozen_string_literal: true

class StockSyncJob < ApplicationJob
  # No retry but stay as failed job:
  sidekiq_options retry: 0

  # We synchronise stock of stock-controlled variants linked to a remote
  # product. These variants are rare though and we check first before we
  # enqueue a new job. That should save some time loading the order with
  # all the stock data to make this decision.
  def self.sync_linked_catalogs(order)
    stock_controlled_variants = order.variants.reject(&:on_demand)
    links = SemanticLink.where(variant_id: stock_controlled_variants.map(&:id))
    semantic_ids = links.pluck(:semantic_id)

    return if semantic_ids.empty?

    user = order.distributor.owner
    reference_id = semantic_ids.first # Assuming one catalog for now.
    perform_later(user, reference_id)
  rescue StandardError => e
    # Errors here shouldn't affect the shopping. So let's report them
    # separately:
    Bugsnag.notify(e) do |payload|
      payload.add_metadata(:order, order)
    end
  end

  def perform(user, semantic_id)
    urls = FdcUrlBuilder.new(semantic_id)
    json_catalog = DfcRequest.new(user).call(urls.catalog_url)
    graph = DfcIo.import(json_catalog)

    products = graph.select do |subject|
      subject.is_a? DataFoodConsortium::Connector::SuppliedProduct
    end
    products_by_id = products.index_by(&:semanticId)
    product_ids = products_by_id.keys
    variants = Spree::Variant.where(supplier: user.enterprises)
      .includes(:semantic_links).references(:semantic_links)
      .where(semantic_links: { semantic_id: product_ids })

    variants.each do |variant|
      next if variant.on_demand

      product = products_by_id[variant.semantic_links[0].semantic_id]
      catalog_item = product&.catalogItems&.first
      CatalogItemBuilder.apply_stock(catalog_item, variant)
      variant.stock_items[0].save!
    end
  end
end

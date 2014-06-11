json.array!(@documents) do |document|
  json.extract! document, :id, :title, :content, :shared, :owner_id
  json.url document_url(document, format: :json)
end

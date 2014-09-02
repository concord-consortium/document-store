require 'rails_helper'

RSpec.describe Document, :type => :model do
  describe "content handling" do
    it "should convert form_content string object into content hash" do
      d = Document.new(title: "Doc", owner_id: 1)
      d.form_content = '{ "test": "value", "bar": 1, "baz": { "sub": false }, "biz": [1,2,3,4]  }'
      expect(d.save).to be true
      expect(d.instance_variable_get("@form_content")).to be_nil
      expect(d.content).not_to be_nil
      expect(d.content).to match({ "test" => "value", "bar" => 1, "baz" => { "sub" => false }, "biz" => [1,2,3,4] })
    end

    it "should fail to save when form_content is invalid json" do
      d = Document.new(title: "Doc", owner_id: 1)
      d.form_content = '{ test: "value", "bar": 1, "baz": { "sub": false }, "biz": [1,2,3,4]  }'
      expect(d.save).to be false
      expect(d.instance_variable_get("@form_content")).not_to be_nil
      expect(d.content).to be_nil
    end

    it 'should allow the document title to be re-used only when the run_key is different' do
      d = Document.new(title: "Doc1", owner_id: 1, run_key: 'foo', form_content: '{ "test": "value" }')
      expect(d.save).to be true

      d = Document.new(title: "Doc1", owner_id: 1, run_key: 'bar', form_content: '{ "test": "value" }')
      expect(d.save).to be true

      d = Document.new(title: "Doc1", owner_id: 1, run_key: 'foo', form_content: '{ "test": "value" }')
      expect(d.save).to be false

      # and work with anonymous docs
      d = Document.new(title: "Doc2", owner_id: nil, run_key: 'foo', form_content: '{ "test": "value" }')
      expect(d.save).to be true

      d = Document.new(title: "Doc2", owner_id: nil, run_key: 'foo', form_content: '{ "test": "value" }')
      expect(d.save).to be false

      d = Document.new(title: "Doc2", owner_id: nil, run_key: 'bar', form_content: '{ "test": "value" }')
      expect(d.save).to be true
    end
  end
end

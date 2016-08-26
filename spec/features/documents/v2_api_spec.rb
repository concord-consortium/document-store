feature 'Document', :codap do
  describe 'V2 API' do
    describe 'open' do
      scenario 'shared documents can be opened without an access key' do
        doc = FactoryGirl.create(:document, title: 'testDoc', shared: true, content: '[1, 2, 3]')
        visit "/v2/documents/#{doc.id}"
        expect(page).to have_content %![1,2,3]!
        expect(page.response_headers['Allow']).to eq "GET, HEAD, OPTIONS"
      end
      scenario 'shared documents can be opened by read-only access key' do
        doc = FactoryGirl.create(:document, title: 'testDoc', shared: true, content: '[1, 2, 3]', read_access_key: 'foo')
        visit "/v2/documents/#{doc.id}?accessKey=RO::foo"
        expect(page).to have_content %![1,2,3]!
        expect(page.response_headers['Allow']).to eq "GET, HEAD, OPTIONS"
      end
      scenario 'unshared documents can be opened by read-only access key' do
        doc = FactoryGirl.create(:document, title: 'testDoc', shared: false, content: '[1, 2, 3]', read_access_key: 'foo')
        visit "/v2/documents/#{doc.id}?accessKey=RO::foo"
        expect(page).to have_content %![1,2,3]!
        expect(page.response_headers['Allow']).to eq "GET, HEAD, OPTIONS"
      end
      scenario 'shared documents can be opened by read-write access key' do
        doc = FactoryGirl.create(:document, title: 'testDoc', shared: true, content: '[1, 2, 3]', read_write_access_key: 'bar')
        visit "/v2/documents/#{doc.id}?accessKey=RW::bar"
        expect(page).to have_content %![1,2,3]!
        expect(page.response_headers['Allow']).to eq "GET, HEAD, OPTIONS, PUT, PATCH"
      end
      scenario 'unshared documents can be opened by read-write access key' do
        doc = FactoryGirl.create(:document, title: 'testDoc', shared: false, content: '[1, 2, 3]', read_write_access_key: 'bar')
        visit "/v2/documents/#{doc.id}?accessKey=RW::bar"
        expect(page).to have_content %![1,2,3]!
        expect(page.response_headers['Allow']).to eq "GET, HEAD, OPTIONS, PUT, PATCH"
      end
      scenario 'documents that do not exist cannot be opened' do
        visit "/v2/documents/100000"
        expect(page.status_code).to eq(404)
        expect(page).to have_content %!{"valid":false,"message":"error.notFound"}!
      end
      scenario 'unshared documents cannot be opened without an access key' do
        doc = FactoryGirl.create(:document, title: 'testDoc', shared: false, content: '[1, 2, 3]')
        visit "/v2/documents/#{doc.id}"
        expect(page.status_code).to eq(400)
        expect(page).to have_content %!{"valid":false,"errors":["Missing accessKey parameter"],"message":"error.missingParam"}!
      end
      scenario 'documents cannot be opened by an invalid read-only access key' do
        doc = FactoryGirl.create(:document, title: 'testDoc', shared: false, content: '[1, 2, 3]')
        visit "/v2/documents/#{doc.id}?accessKey=RO::invalid"
        expect(page.status_code).to eq(400)
        expect(page).to have_content %!{"valid":false,"errors":["Invalid accessKey"],"message":"error.invalidAccessKey"}!
      end
      scenario 'documents cannot be opened by an invalid read-write access key' do
        doc = FactoryGirl.create(:document, title: 'testDoc', shared: false, content: '[1, 2, 3]')
        visit "/v2/documents/#{doc.id}?accessKey=RW::invalid"
        expect(page.status_code).to eq(400)
        expect(page).to have_content %!{"valid":false,"errors":["Invalid accessKey"],"message":"error.invalidAccessKey"}!
      end
    end

    describe 'save' do
      scenario 'documents can be saved using valid read-write access key' do
        doc = FactoryGirl.create(:document, title: "newdoc", form_content: '{ "foo": "bar" }', read_write_access_key: 'foo')
        page.driver.browser.submit :put, "/v2/documents/#{doc.id}?accessKey=RW::foo", '{ "def": [1,2,3,4] }'
        doc.reload()
        expect(doc.title).to eq("newdoc")
        expect(doc.read_write_access_key).to eq("foo")
        expect(doc.content).to match({"def" => [1,2,3,4] })
      end

      scenario 'documents that do not exist cannot be saved' do
        page.driver.browser.submit :put, "/v2/documents/100000", ""
        expect(page.status_code).to eq(404)
        expect(page).to have_content %!{"valid":false,"message":"error.notFound"}!
      end

      scenario 'documents cannot be saved using invalid read-write access key' do
        doc = FactoryGirl.create(:document, title: 'testDoc', shared: false, content: '[1, 2, 3]')
        page.driver.browser.submit :put, "/v2/documents/#{doc.id}?accessKey=RW::invalid", '{ "def": [1,2,3,4] }'
        expect(page.status_code).to eq(400)
        expect(page).to have_content %!{"valid":false,"errors":["Invalid accessKey"],"message":"error.invalidAccessKey"}!
      end

      scenario 'documents cannot be saved with a missing read-write access key' do
        doc = FactoryGirl.create(:document, title: 'testDoc', shared: false, content: '[1, 2, 3]')
        page.driver.browser.submit :put, "/v2/documents/#{doc.id}", '{ "def": [1,2,3,4] }'
        expect(page.status_code).to eq(400)
        expect(page).to have_content %!{"valid":false,"errors":["Missing accessKey parameter"],"message":"error.missingParam"}!
      end

      scenario 'documents cannot be saved using read-only access key' do
        doc = FactoryGirl.create(:document, title: 'testDoc', shared: false, content: '[1, 2, 3]')
        page.driver.browser.submit :put, "/v2/documents/#{doc.id}?accessKey=RO::foo", '{ "def": [1,2,3,4] }'
        expect(page.status_code).to eq(400)
        expect(page).to have_content %!{"valid":false,"errors":["Invalid accessKey type"],"message":"error.invalidAccessKeyType"}!
      end
    end

    describe 'patch' do
      scenario 'documents can be patched' do
        # take from sample at http://jsonpatch.com/
        doc = FactoryGirl.create(:document, title: "newdoc", content: '{"foo":"bar","baz":"qux"}', read_write_access_key: 'foo')
        page.driver.browser.submit :patch, "/v2/documents/#{doc.id}?accessKey=RW::foo", '[{ "op": "replace", "path": "/baz", "value": "boo" },  { "op": "add", "path": "/hello", "value": ["world"] },  { "op": "remove", "path": "/foo"}]'
        expect(page.status_code).to eq(200)
        expect(page).to have_content %!{"status":"Patched","valid":true,"id":#{doc.id}}!
        doc.reload()
        expect(doc.content.to_json).to eq '{"baz":"boo","hello":["world"]}'
      end

      scenario 'documents that do not exist cannot be patched' do
        page.driver.browser.submit :patch, "/v2/documents/100000", ""
        expect(page.status_code).to eq(404)
        expect(page).to have_content %!{"valid":false,"message":"error.notFound"}!
      end

      scenario 'documents cannot be patched using empty patch set' do
        doc = FactoryGirl.create(:document, title: "newdoc", content: '{"foo":"bar","baz":"qux"}', read_write_access_key: 'foo')
        page.driver.browser.submit :patch, "/v2/documents/#{doc.id}?accessKey=RW::foo", ''
        expect(page.status_code).to eq(400)
        expect(page).to have_content %!{"status":"Error","errors":["Invalid patch JSON (parsing)",!
      end

      scenario 'documents cannot be patched using invalid json for patch set' do
        doc = FactoryGirl.create(:document, title: "newdoc", content: '{"foo":"bar","baz":"qux"}', read_write_access_key: 'foo')
        page.driver.browser.submit :patch, "/v2/documents/#{doc.id}?accessKey=RW::foo", '{"bam"'
        expect(page.status_code).to eq(400)
        expect(page).to have_content %!{"status":"Error","errors":["Invalid patch JSON (parsing)",!
      end

      scenario 'documents cannot be patched using valid json but invalid patch set' do
        doc = FactoryGirl.create(:document, title: "newdoc", content: '{"foo":"bar","baz":"qux"}', read_write_access_key: 'foo')
        page.driver.browser.submit :patch, "/v2/documents/#{doc.id}?accessKey=RW::foo", '{"bing":"boom"}'
        expect(page.status_code).to eq(400)
        expect(page).to have_content %!{"status":"Error","errors":["Invalid patch JSON (parsing)",!
      end

      scenario 'documents cannot be patched using invalid read-write access key' do
        doc = FactoryGirl.create(:document, title: 'testDoc', shared: false, content: '[1, 2, 3]')
        page.driver.browser.submit :patch, "/v2/documents/#{doc.id}?accessKey=RW::invalid", '{ "def": [1,2,3,4] }'
        expect(page.status_code).to eq(400)
        expect(page).to have_content %!{"valid":false,"errors":["Invalid accessKey"],"message":"error.invalidAccessKey"}!
      end

      scenario 'documents cannot be patched with a missing read-write access key' do
        doc = FactoryGirl.create(:document, title: 'testDoc', shared: false, content: '[1, 2, 3]')
        page.driver.browser.submit :patch, "/v2/documents/#{doc.id}", '{ "def": [1,2,3,4] }'
        expect(page.status_code).to eq(400)
        expect(page).to have_content %!{"valid":false,"errors":["Missing accessKey parameter"],"message":"error.missingParam"}!
      end

      scenario 'documents cannot be patched using read-only access key' do
        doc = FactoryGirl.create(:document, title: 'testDoc', shared: false, content: '[1, 2, 3]')
        page.driver.browser.submit :patch, "/v2/documents/#{doc.id}?accessKey=RO::foo", '{ "def": [1,2,3,4] }'
        expect(page.status_code).to eq(400)
        expect(page).to have_content %!{"valid":false,"errors":["Invalid accessKey type"],"message":"error.invalidAccessKeyType"}!
      end
    end

    describe 'create' do
      scenario 'unshared documents can be created' do
        page.driver.browser.submit :post, "/v2/documents?title=test", '{ "foo": "bar" }'
        expect(page.status_code).to eq(201)
        expect(page).to have_content %!{"status":"Created","valid":true,!
        response = JSON.parse(page.body)
        doc = Document.find(response["id"])
        expect(doc.title).to eq "test"
        expect(doc.original_content.to_json).to eq '{"foo":"bar"}'
        expect(doc.original_content.to_json).to eq '{"foo":"bar"}'
        expect(doc.read_access_key).not_to be_nil
        expect(doc.read_write_access_key).not_to be_nil
        expect(doc.read_access_key).not_to eq doc.read_write_access_key
        expect(doc.run_key).to eq doc.read_write_access_key
        expect(doc.shared).to eq false
      end
      scenario 'shared documents can be created' do
        page.driver.browser.submit :post, "/v2/documents?title=test&shared=true", '{ "foo": "bar" }'
        expect(page.status_code).to eq(201)
        expect(page).to have_content %!{"status":"Created","valid":true,!
        response = JSON.parse(page.body)
        doc = Document.find(response["id"])
        expect(doc.shared).to eq true
      end
      scenario 'documents with no data cannot be created' do
        page.driver.browser.submit :post, "/v2/documents?title=test", ''
        expect(page.status_code).to eq(400)
        expect(page).to have_content %!{"status":"Error","errors":["Form content must be valid json"],"valid":false,"message":"error.writeFailed"}!
      end
      scenario 'documents with invalid json cannot be created' do
        page.driver.browser.submit :post, "/v2/documents?title=test", '{"foo'
        expect(page.status_code).to eq(400)
        expect(page).to have_content %!{"status":"Error","errors":["Form content must be valid json"],"valid":false,"message":"error.writeFailed"}!
      end
    end

    describe 'copy_shared' do
      scenario 'shared documents can be copied using source id to an unshared document' do
        doc = FactoryGirl.create(:document, title: 'testDoc', shared: true, content: '[1, 2, 3]')
        page.driver.browser.submit :post, "/v2/documents?source=#{doc.id}", ""
        expect(page.status_code).to eq(201)
        expect(page).to have_content %!{"status":"Copied","valid":true,!
        response = JSON.parse(page.body)
        expect(response["id"]).not_to eq doc.id
        copy = Document.find(response["id"])
        expect(copy.title).to eq doc.title
        expect(copy.content).to eq doc.content
        expect(copy.original_content).to eq doc.content
        expect(copy.read_access_key).to eq response["readAccessKey"]
        expect(copy.read_write_access_key).to eq response["readWriteAccessKey"]
        expect(copy.run_key).to eq response["readWriteAccessKey"]
        expect(copy.shared).to eq false
      end

      scenario 'shared documents can be copied using source id to a shared document' do
        doc = FactoryGirl.create(:document, title: 'testDoc', shared: true, content: '[1, 2, 3]')
        page.driver.browser.submit :post, "/v2/documents?source=#{doc.id}&shared=true", ""
        expect(page.status_code).to eq(201)
        expect(page).to have_content %!{"status":"Copied","valid":true,!
        response = JSON.parse(page.body)
        expect(response["id"]).not_to eq doc.id
        copy = Document.find(response["id"])
        expect(copy.shared).to eq true
      end

      scenario 'unshared documents cannot be copied using source id' do
        doc = FactoryGirl.create(:document, title: 'testDoc', shared: false, content: '[1, 2, 3]')
        page.driver.browser.submit :post, "/v2/documents?source=#{doc.id}", ""
        expect(page.status_code).to eq(403)
        expect(page).to have_content %!{"valid":false,"errors":["Source document is not shared"],"message":"error.notShared"}!
      end
    end

  end
end

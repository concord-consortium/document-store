feature 'Document', :codap do
  describe 'V2 API' do
    describe 'open' do
      scenario 'documents can be opened by readAccessKey' do
        doc = FactoryGirl.create(:document, title: 'testDoc', content: '[1, 2, 3]', read_access_key: 'foo')
        visit "/v2/document/open?readAccessKey=foo"
        expect(page).to have_content %![1,2,3]!
        expect(page.response_headers['Document-Id']).to eq("#{doc.id}")
        expect(page.response_headers['Allow']).to eq "GET, HEAD, OPTIONS"
        expect(page.response_headers['X-Document-Store-Read-Only']).to eq "true"
      end
      scenario 'documents can be opened by readWriteAccessKey' do
        doc = FactoryGirl.create(:document, title: 'testDoc', content: '[1, 2, 3]', read_write_access_key: 'bar')
        visit "/v2/document/open?readWriteAccessKey=bar"
        expect(page).to have_content %![1,2,3]!
        expect(page.response_headers['Document-Id']).to eq("#{doc.id}")
        expect(page.response_headers['Allow']).to eq "GET, HEAD, OPTIONS, PUT, PATCH"
        expect(page.response_headers['X-Document-Store-Read-Only']).to eq "false"
      end
      scenario 'documents cannot be opened by an invalid readAccessKey' do
        visit "/v2/document/open?readAccessKey=invalid"
        expect(page.status_code).to eq(404)
        expect(page).to have_content %!{"valid":false,"message":"error.notFound"}!
      end
      scenario 'documents cannot be opened by an invalid readWriteAccessKey' do
        visit "/v2/document/open?readWriteAccessKey=invalid"
        expect(page.status_code).to eq(404)
        expect(page).to have_content %!{"valid":false,"message":"error.notFound"}!
      end
      scenario 'opening documents without a readAccessKey or readWriteAccessKey fail with missing parameter error' do
        visit "/v2/document/open"
        expect(page.status_code).to eq(400)
        expect(page).to have_content %!{"valid":false,"errors":["Missing readAccessKey or readWriteAccessKey parameter"],"message":"error.missingParam"}!
      end
    end

    describe 'save' do
      scenario 'documents can be saved using valid readWriteAccessKey' do
        doc = FactoryGirl.create(:document, title: "newdoc", form_content: '{ "foo": "bar" }', read_write_access_key: 'foo')
        page.driver.browser.submit :put, "/v2/document/save?readWriteAccessKey=foo", '{ "def": [1,2,3,4] }'
        doc = Document.find(doc.id)
        expect(doc).not_to be_nil
        expect(doc.title).to eq("newdoc")
        expect(doc.read_write_access_key).to eq("foo")
        expect(doc.content).to match({"def" => [1,2,3,4] })
      end

      scenario 'documents cannot be saved using invalid readWriteAccessKey' do
        page.driver.browser.submit :put, "/v2/document/save?readWriteAccessKey=invalid", '{ "def": [1,2,3,4] }'
        expect(page.status_code).to eq(404)
        expect(page).to have_content %!{"valid":false,"message":"error.notFound"}!
      end

      scenario 'documents cannot be saved with a missing readWriteAccessKey' do
        page.driver.browser.submit :put, "/v2/document/save", '{ "def": [1,2,3,4] }'
        expect(page.status_code).to eq(400)
        expect(page).to have_content %!{"valid":false,"errors":["Missing readWriteAccessKey parameter"],"message":"error.missingParam"}!
      end

      scenario 'documents cannot be saved using readAccessKey' do
        page.driver.browser.submit :put, "/v2/document/save?readAccessKey=foo", '{ "def": [1,2,3,4] }'
        expect(page.status_code).to eq(400)
        expect(page).to have_content %!{"valid":false,"errors":["Missing readWriteAccessKey parameter"],"message":"error.missingParam"}!
      end
    end

    describe 'patch' do
      scenario 'documents can be patched' do
        # take from sample at http://jsonpatch.com/
        doc = FactoryGirl.create(:document, title: "newdoc", content: '{"foo":"bar","baz":"qux"}', read_write_access_key: 'foo')
        page.driver.browser.submit :patch, "/v2/document/patch?readWriteAccessKey=foo", '[{ "op": "replace", "path": "/baz", "value": "boo" },  { "op": "add", "path": "/hello", "value": ["world"] },  { "op": "remove", "path": "/foo"}]'
        expect(page.status_code).to eq(200)
        expect(page).to have_content %!{"status":"Patched","valid":true,"id":#{doc.id}}!
        doc.reload()
        expect(doc.content.to_json).to eq '{"baz":"boo","hello":["world"]}'
      end

      scenario 'documents cannot be patched using empty patch set' do
        doc = FactoryGirl.create(:document, title: "newdoc", content: '{"foo":"bar","baz":"qux"}', read_write_access_key: 'foo')
        page.driver.browser.submit :patch, "/v2/document/patch?readWriteAccessKey=foo", ''
        expect(page.status_code).to eq(400)
        expect(page).to have_content %!{"status":"Error","errors":["Invalid patch JSON (parsing)",!
      end

      scenario 'documents cannot be patched using invalid json for patch set' do
        doc = FactoryGirl.create(:document, title: "newdoc", content: '{"foo":"bar","baz":"qux"}', read_write_access_key: 'foo')
        page.driver.browser.submit :patch, "/v2/document/patch?readWriteAccessKey=foo", '{"bam"'
        expect(page.status_code).to eq(400)
        expect(page).to have_content %!{"status":"Error","errors":["Invalid patch JSON (parsing)",!
      end

      scenario 'documents cannot be patched using valid json but invalid patch set' do
        doc = FactoryGirl.create(:document, title: "newdoc", content: '{"foo":"bar","baz":"qux"}', read_write_access_key: 'foo')
        page.driver.browser.submit :patch, "/v2/document/patch?readWriteAccessKey=foo", '{"bing":"boom"}'
        expect(page.status_code).to eq(400)
        expect(page).to have_content %!{"status":"Error","errors":["Invalid patch JSON (parsing)",!
      end

      scenario 'documents cannot be patched using invalid readWriteAccessKey' do
        page.driver.browser.submit :patch, "/v2/document/patch?readWriteAccessKey=invalid", '{ "def": [1,2,3,4] }'
        expect(page.status_code).to eq(404)
        expect(page).to have_content %!{"valid":false,"message":"error.notFound"}!
      end

      scenario 'documents cannot be patched with a missing readWriteAccessKey' do
        page.driver.browser.submit :patch, "/v2/document/patch", '{ "def": [1,2,3,4] }'
        expect(page.status_code).to eq(400)
        expect(page).to have_content %!{"valid":false,"errors":["Missing readWriteAccessKey parameter"],"message":"error.missingParam"}!
      end

      scenario 'documents cannot be patched using readAccessKey' do
        page.driver.browser.submit :patch, "/v2/document/patch?readAccessKey=foo", '{ "def": [1,2,3,4] }'
        expect(page.status_code).to eq(400)
        expect(page).to have_content %!{"valid":false,"errors":["Missing readWriteAccessKey parameter"],"message":"error.missingParam"}!
      end
    end

    describe 'copy_shared' do
      scenario 'shared documents can be copied using recordid' do
        doc = FactoryGirl.create(:document, title: 'testDoc', shared: true, content: '[1, 2, 3]')
        page.driver.browser.submit :post, "/v2/document/copy_shared?recordid=#{doc.id}", ""
        expect(page.status_code).to eq(200)
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
      end

      scenario 'unshared documents cannot be copied using recordid' do
        doc = FactoryGirl.create(:document, title: 'testDoc', shared: false, content: '[1, 2, 3]')
        page.driver.browser.submit :post, "/v2/document/copy_shared?recordid=#{doc.id}", ""
        expect(page.status_code).to eq(403)
        expect(page).to have_content %!{"valid":false,"errors":["Source document is not shared"],"message":"error.notShared"}!
      end

      scenario 'documents cannot be copied with a missing recordid' do
        page.driver.browser.submit :post, "/v2/document/copy_shared", ""
        expect(page.status_code).to eq(400)
        expect(page).to have_content %!{"valid":false,"errors":["Missing recordid parameter"],"message":"error.missingParam"}!
      end

      scenario 'shared documents cannot be copied using readAccessKey' do
        doc = FactoryGirl.create(:document, title: 'testDoc', shared: true, content: '[1, 2, 3]', read_access_key: 'foo')
        page.driver.browser.submit :post, "/v2/document/copy_shared?readAccessKey=foo", ""
        expect(page.status_code).to eq(400)
        expect(page).to have_content %!{"valid":false,"errors":["Missing recordid parameter"],"message":"error.missingParam"}!
      end

      scenario 'shared documents cannot be copied using readWriteAccessKey' do
        doc = FactoryGirl.create(:document, title: 'testDoc', shared: true, content: '[1, 2, 3]', read_write_access_key: 'foo')
        page.driver.browser.submit :post, "/v2/document/copy_shared?readWriteAccessKey=foo", ""
        expect(page.status_code).to eq(400)
        expect(page).to have_content %!{"valid":false,"errors":["Missing recordid parameter"],"message":"error.missingParam"}!
      end
    end
  end
end

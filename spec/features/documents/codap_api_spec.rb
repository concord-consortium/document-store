
feature 'Document', :codap do
  describe 'CODAP API' do
    describe 'all' do
      scenario 'user can list documents' do
        user = FactoryGirl.create(:user, username: 'test')
        doc1 = FactoryGirl.create(:document, owner_id: user.id)
        signin(user.email, user.password)
        visit 'document/all'
        expect(page).to have_content %![{"name":"MyText","id":#{doc1.id},"_permissions":0}]!
      end

      scenario 'user can only list documents their own documents' do
        user = FactoryGirl.create(:user, username: 'test')
        user2 = FactoryGirl.create(:user, username: 'test2', email: 'test2@email.com')
        doc1 = FactoryGirl.create(:document, owner_id: user.id)
        doc2 = FactoryGirl.create(:document, owner_id: user2.id)
        signin(user2.email, user2.password)
        visit 'document/all'
        expect(page).to have_content %![{"name":"MyText","id":#{doc2.id},"_permissions":0}]!
      end

      scenario 'anonymous always lists no documents' do
        user = FactoryGirl.create(:user, username: 'test')
        doc1 = FactoryGirl.create(:document, owner_id: user.id)
        doc2 = FactoryGirl.create(:document, owner_id: nil)
        visit 'document/all'
        expect(page).to have_content %!{"valid":false,"message":"error.permissions"}!
      end

      scenario 'anonymous lists only documents with the specified run key' do
        user = FactoryGirl.create(:user, username: 'test')
        doc1 = FactoryGirl.create(:document, owner_id: user.id, run_key: 'foo')
        doc2 = FactoryGirl.create(:document, owner_id: nil, run_key: 'foo')
        visit 'document/all?runKey=foo'
        expect(page).to have_content %![{"name":"#{doc2.title}","id":#{doc2.id},"_permissions":0}]!
      end
    end

    describe 'open' do
      scenario 'user can open their own document' do
        user = FactoryGirl.create(:user, username: 'test')
        doc1 = FactoryGirl.create(:document, title: 'testDoc', owner_id: user.id, content: '[1, 2, 3]')
        signin(user.email, user.password)
        visit "document/open?recordid=#{doc1.id}"
        expect(page).to have_content %![1,2,3]!
      end

      scenario 'user can open a document shared by another person' do
        user = FactoryGirl.create(:user, username: 'test')
        user2 = FactoryGirl.create(:user, username: 'test2', email: 'test2@email.com')
        doc1 = FactoryGirl.create(:document, owner_id: user.id)
        doc2 = FactoryGirl.create(:document, title: "test2 doc", shared: true, owner_id: user2.id, form_content: '{ "foo": "bar" }')
        signin(user.email, user.password)
        visit 'document/open?owner=test2&recordname=test2%20doc'
        expect(page).to have_content %!{"foo":"bar"}!
      end

      scenario 'user cannot open a document that is not shared by another person' do
        user = FactoryGirl.create(:user, username: 'test')
        user2 = FactoryGirl.create(:user, username: 'test2', email: 'test2@email.com')
        doc1 = FactoryGirl.create(:document, owner_id: user.id)
        doc2 = FactoryGirl.create(:document, title: "test2 doc", shared: false, owner_id: user2.id, form_content: '{ "foo": "bar" }')
        signin(user.email, user.password)
        visit 'document/open?owner=test2&recordname=test2%20doc'
        expect(page.status_code).to eq(403)
        expect(page).to have_content %!{"valid":false,"message":"error.permissions"}!
      end

      describe 'anonymous' do
        scenario 'anonymous user can open a document shared by another person' do
          user2 = FactoryGirl.create(:user, username: 'test2', email: 'test2@email.com')
          doc2 = FactoryGirl.create(:document, title: "test2 doc", shared: true, owner_id: user2.id, form_content: '{ "foo": "bar" }')
          visit 'document/open?owner=test2&recordname=test2%20doc'
          expect(page).to have_content %!{"foo":"bar"}!
        end

        scenario 'anonymous user can not open a document not shared by another person' do
          user2 = FactoryGirl.create(:user, username: 'test2', email: 'test2@email.com')
          doc2 = FactoryGirl.create(:document, title: "test2 doc", shared: false, owner_id: user2.id, form_content: '{ "foo": "bar" }')
          visit 'document/open?owner=test2&recordname=test2%20doc'
          expect(page).to have_content %!{"valid":false,"message":"error.permissions"}!
        end

        scenario 'anonymous user can open a document shared by another person while providing a run key' do
          user2 = FactoryGirl.create(:user, username: 'test2', email: 'test2@email.com')
          doc2 = FactoryGirl.create(:document, title: "test2 doc", shared: true, owner_id: user2.id, form_content: '{ "foo": "bar" }')
          visit 'document/open?owner=test2&recordname=test2%20doc&runKey=foo'
          expect(page).to have_content %!{"foo":"bar"}!
        end

        scenario 'anonymous user can open an owner-less document with a matching run_key' do
          doc = FactoryGirl.create(:document, title: "test2 doc", shared: false, owner_id: nil, run_key: 'run1', form_content: '{ "foo": "bar2" }')
          visit 'document/open?runKey=run1&recordname=test2%20doc'
          expect(page).to have_content %!{"foo":"bar2"}!
        end

        scenario 'anonymous user can open an owner-less document with a matching run_key (second url)' do
          doc = FactoryGirl.create(:document, title: "test2 doc", shared: false, owner_id: nil, run_key: 'run1', form_content: '{ "foo": "bar2" }')
          visit 'document/open?runKey=run1&owner=&recordname=test2%20doc'
          expect(page).to have_content %!{"foo":"bar2"}!
        end

        scenario 'anonymous user can not open an owner-less document with a non-matching run_key' do
          doc = FactoryGirl.create(:document, title: "test2 doc", shared: false, owner_id: nil, run_key: 'run2', form_content: '{ "foo": "bar2" }')
          visit 'document/open?runKey=run1&recordname=test2%20doc'
          expect(page).to have_content %!{"valid":false,"message":"error.notFound"}!
        end

        scenario 'anonymous user can not open a document owned by another person even with the correct run_key' do
          user2 = FactoryGirl.create(:user, username: 'test2', email: 'test2@email.com')
          doc2 = FactoryGirl.create(:document, title: "test2 doc", shared: false, owner_id: user2.id, run_key: 'run2', form_content: '{ "foo": "bar" }')
          visit 'document/open?runKey=run2&owner=test2&recordname=test2%20doc'
          expect(page).to have_content %!{"valid":false,"message":"error.permissions"}!
        end

        scenario 'logged in user can open a non-shared document owned by anonymous with the correct run key' do
          user = FactoryGirl.create(:user, username: 'test3', email: 'test3@email.com')
          doc = FactoryGirl.create(:document, title: "test3 doc", shared: false, owner_id: nil, run_key: 'biz', form_content: '{ "foo": "baz" }')
          signin(user.email, user.password)
          visit 'document/open?recordname=test3%20doc&runKey=biz'
          expect(page).to have_content %!{"foo":"baz"}!
        end

        scenario 'logged in user can open a non-shared document owned by anonymous with the correct run key (second url)' do
          user = FactoryGirl.create(:user, username: 'test3', email: 'test3@email.com')
          doc = FactoryGirl.create(:document, title: "test3 doc", shared: false, owner_id: nil, run_key: 'biz', form_content: '{ "foo": "baz" }')
          signin(user.email, user.password)
          visit 'document/open?owner=&recordname=test3%20doc&runKey=biz'
          expect(page).to have_content %!{"foo":"baz"}!
        end

        scenario 'logged in user cannot open a non-shared document owned by anonymous with the incorrect run key' do
          user = FactoryGirl.create(:user, username: 'test3', email: 'test3@email.com')
          doc = FactoryGirl.create(:document, title: "test3 doc", shared: false, owner_id: nil, run_key: 'biz', form_content: '{ "foo": "baz" }')
          signin(user.email, user.password)
          visit 'document/open?recordname=test3%20doc&runKey=baz'
          expect(page).to have_content %!{"valid":false,"message":"error.notFound"}!
        end

        scenario 'logged in user cannot open a non-shared document owned by anonymous with the incorrect run key (second url)' do
          user = FactoryGirl.create(:user, username: 'test3', email: 'test3@email.com')
          doc = FactoryGirl.create(:document, title: "test3 doc", shared: false, owner_id: nil, run_key: 'biz', form_content: '{ "foo": "baz" }')
          signin(user.email, user.password)
          visit 'document/open?owner=&recordname=test3%20doc&runKey=baz'
          expect(page).to have_content %!{"valid":false,"message":"error.notFound"}!
        end
      end

      describe 'errors' do
        scenario 'user gets 403 when they open a document by id and do not own it' do
          user = FactoryGirl.create(:user, username: 'test')
          user2 = FactoryGirl.create(:user, username: 'test2', email: 'test2@email.com')
          doc1 = FactoryGirl.create(:document, title: 'testDoc', owner_id: user.id, content: '[1, 2, 3]')
          doc2 = FactoryGirl.create(:document, title: "test2 doc", owner_id: user2.id, form_content: '{ "foo": "bar" }')
          signin(user.email, user.password)
          visit "document/open?recordid=#{doc2.id}"
          expect(page.status_code).to eq(403)
          expect(page).to have_content %!{"valid":false,"message":"error.permissions"}!
        end

        scenario 'user gets 404 when they open a document by id and it does not exist' do
          user = FactoryGirl.create(:user, username: 'test')
          signin(user.email, user.password)
          visit "document/open?username=test&recordid=99999"
          expect(page.status_code).to eq(404)
          expect(page).to have_content %!{"valid":false,"message":"error.notFound"}!
        end

        scenario 'user gets 404 when they open a document by another person that does not exist' do
          user = FactoryGirl.create(:user, username: 'test')
          user2 = FactoryGirl.create(:user, username: 'test2', email: 'test2@email.com')
          doc1 = FactoryGirl.create(:document, owner_id: user.id)
          doc2 = FactoryGirl.create(:document, title: "test2 doc", shared: false, owner_id: user2.id, form_content: '{ "foo": "bar" }')
          signin(user.email, user.password)
          visit 'document/open?owner=test2&recordname=something'
          expect(page.status_code).to eq(404)
          expect(page).to have_content %!{"valid":false,"message":"error.notFound"}!
        end
      end
    end

    describe 'save' do
      scenario 'user can save their own document' do
        user = FactoryGirl.create(:user, username: 'test')
        expect(Document.find_by(title: "newdoc")).to be_nil
        signin(user.email, user.password)
        page.driver.browser.submit :post, 'document/save?recordname=newdoc', '{ "def": [1,2,3,4] }'
        doc = Document.find_by(title: "newdoc")
        expect(doc).not_to be_nil
        expect(doc.title).to eq("newdoc")
        expect(doc.content).to match({"def" => [1,2,3,4] })
        expect(doc.owner_id).to eq(user.id)
      end

      scenario 'user can not save over a document owned by someone else' do
        user = FactoryGirl.create(:user, username: 'test')
        user2 = FactoryGirl.create(:user, username: 'test2', email: 'test2@email.com')
        doc2 = FactoryGirl.create(:document, title: "newdoc", shared: false, owner_id: user2.id, form_content: '{ "foo": "bar" }')
        expect(Document.find_by(title: "newdoc", owner_id: user.id)).to be_nil
        expect(Document.find_by(title: "newdoc", owner_id: user2.id)).not_to be_nil
        signin(user.email, user.password)
        page.driver.browser.submit :post, 'document/save?recordname=newdoc', '{ "def": [1,2,3,4] }'
        doc = Document.find_by(title: "newdoc", owner_id: user.id)
        doc2 = Document.find_by(title: "newdoc", owner_id: user2.id)
        expect(doc).not_to be_nil
        expect(doc.content).to match({"def" => [1,2,3,4] })
        expect(doc2).not_to be_nil
        expect(doc2.content).to match({"foo" => "bar" })
      end

      scenario 'user overwrites their own document when a document by the same name exists' do
        user = FactoryGirl.create(:user, username: 'test')
        doc = FactoryGirl.create(:document, title: "newdoc", shared: false, owner_id: user.id, form_content: '{ "foo": "bar" }')
        signin(user.email, user.password)
        page.driver.browser.submit :post, 'document/save?recordname=newdoc', '{ "def": [1,2,3,4] }'
        doc.reload
        expect(doc).not_to be_nil
        expect(doc.content).to match({"def" => [1,2,3,4] })
      end

      describe 'anonymous' do
        scenario 'user cannot save documents when no run_key is present' do
          expect(Document.find_by(title: "newdoc")).to be_nil
          page.driver.browser.submit :post, '/document/save?recordname=newdoc', '{ "def": [1,2,3,4] }'
          doc = Document.find_by(title: "newdoc")
          expect(doc).to be_nil
        end

        scenario 'user can save documents when a run_key is present' do
          expect(Document.find_by(title: "newdoc")).to be_nil
          page.driver.browser.submit :post, '/document/save?recordname=newdoc&runKey=foo', '{ "def": [1,2,3,4] }'
          doc = Document.find_by(title: "newdoc")
          expect(doc).not_to be_nil
          expect(doc.title).to eq("newdoc")
          expect(doc.content).to match({"def" => [1,2,3,4] })
          expect(doc.owner_id).to be_nil
        end

        scenario 'user overwrites their own document when a document by the same name exists with the same run_key' do
          doc = FactoryGirl.create(:document, title: "newdoc", shared: false, owner_id: nil, run_key: 'foo', form_content: '{ "foo": "bar" }')
          page.driver.browser.submit :post, '/document/save?recordname=newdoc&runKey=foo', '{ "def": [1,2,3,4] }'
          doc.reload
          expect(doc).not_to be_nil
          expect(doc.content).to match({"def" => [1,2,3,4] })
        end

        scenario 'user creates a new document when a document by the same name exists with a different run_key' do
          doc = FactoryGirl.create(:document, title: "newdoc", shared: false, owner_id: nil, run_key: 'foo', form_content: '{ "foo": "bar" }')
          page.driver.browser.submit :post, '/document/save?recordname=newdoc&runKey=bar', '{ "def": [1,2,3,4] }'
          doc.reload
          docs = Document.where(title: 'newdoc', owner_id: nil)
          expect(docs.size).to be 2
          doc2 = docs.detect {|d| d != doc }
          expect(doc.content).to match({"foo" => "bar"})
          expect(doc.run_key).to eq('foo')
          expect(doc2.content).to match({"def" => [1,2,3,4] })
          expect(doc2.run_key).to eq('bar')
        end

      end
    end

    describe 'launch' do
      scenario 'user can launch a document via owner and recordname' do
        visit '/document/launch?owner=test2&recordname=something&server=http://foo.com/'
        expect(page.current_url).to eq 'http://foo.com/?documentServer=http%3A%2F%2Fwww.example.com%2F&doc=something&owner=test2'
      end
      scenario 'user can launch a document via owner and doc' do
        visit 'document/launch?owner=test2&recordname=something2&server=http://foo.com/'
        expect(page.current_url).to eq 'http://foo.com/?documentServer=http%3A%2F%2Fwww.example.com%2F&doc=something2&owner=test2'
      end
      scenario 'user can launch a document via moreGames' do
        visit 'document/launch?server=http://foo.com/&moreGames=%5B%7B%7D%5D'
        expect(page.current_url).to eq 'http://foo.com/?documentServer=http%3A%2F%2Fwww.example.com%2F&moreGames=%5B%7B%7D%5D'
      end
      scenario 'user can be logged in to launch' do
        # really, the requirement is that we don't need to be logged in, but that's already tested above,
        # so might as well test the inverse.
        user = FactoryGirl.create(:user, username: 'test')
        signin(user.email, user.password)
        visit 'document/launch?owner=test2&recordname=something2&server=http://foo.com/'
        expect(page.current_url).to eq 'http://foo.com/?documentServer=http%3A%2F%2Fwww.example.com%2F&doc=something2&owner=test2'
      end
      scenario 'the document does not need to exist to launch' do
        # this is already tested with the previous tests, but here we go
        r = SecureRandom.hex
        visit "document/launch?owner=test2&recordname=#{r}&server=http://foo.com/"
        expect(page.current_url).to eq "http://foo.com/?documentServer=http%3A%2F%2Fwww.example.com%2F&doc=#{r}&owner=test2"
      end
      scenario 'the user will be authenticated if auth_provider is set and the user is not logged in' do
        expect {
          visit 'document/launch?owner=test2&recordname=something2&server=http://foo.com/&auth_provider=http://bar.com'
        }.to raise_error(ActionController::RoutingError) # capybara doesn't handle the redirects well
        expect(page.current_url).to match 'http://bar.com/auth/concord_id/authorize'
      end
      scenario 'the user will not be authenticated if auth_provider is set and the user is logged in' do
        user = FactoryGirl.create(:user, username: 'test')
        signin(user.email, user.password)
        visit 'document/launch?owner=test2&recordname=something2&server=http://foo.com/&auth_provider=http://bar.com/'
        expect(page.current_url).to eq 'http://foo.com/?documentServer=http%3A%2F%2Fwww.example.com%2F&doc=something2&owner=test2'
      end
    end

    describe 'info' do
      scenario 'anonymous save is disabled' do
        visit "/user/info"
        expect(page.status_code).to eq(401)
        expect(page).to have_content %!{"valid":false,"enableSave":false}!
      end
      scenario 'anonymous save is enabled if a runKey is available' do
        visit "/user/info?runKey=foo"
        expect(page.status_code).to eq(401)
        expect(page).to have_content %!{"valid":false,"enableSave":true}!
      end
      scenario 'anonymous save is disabled' do
        user = FactoryGirl.create(:user, username: 'test')
        signin(user.email, user.password)
        visit "/user/info"
        expect(page.status_code).to eq(200)
        expect(page).to have_content %!{"valid":true,"sessionToken":"abc123","enableLogging":false,"privileges":0,"useCookie":false,"enableSave":true,"username":"test","name":"Test User"}!
      end
    end
  end
end

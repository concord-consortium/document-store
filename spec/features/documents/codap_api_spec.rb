
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

      scenario 'anonymous user can open a document shared by another person' do
        user2 = FactoryGirl.create(:user, username: 'test2', email: 'test2@email.com')
        doc2 = FactoryGirl.create(:document, title: "test2 doc", shared: true, owner_id: user2.id, form_content: '{ "foo": "bar" }')
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
    end

    describe 'launch' do
      scenario 'user can launch a document via owner and recordname' do
        visit 'document/launch?owner=test2&recordname=something&server=http://foo.com/'
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
  end
end

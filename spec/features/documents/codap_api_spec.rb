
feature 'Document', :codap do
  describe 'CODAP API' do
    describe 'all' do
      scenario 'user can list documents' do
        user = FactoryGirl.create(:user, username: 'test')
        doc1 = FactoryGirl.create(:document, owner_id: user.id)
        signin(user.email, user.password)
        visit '/document/all'
        expect(page).to have_content %![{"name":"MyText","id":#{doc1.id},"_permissions":0}]!
      end

      scenario 'user can only list documents their own documents' do
        user = FactoryGirl.create(:user, username: 'test')
        user2 = FactoryGirl.create(:user, username: 'test2', email: 'test2@email.com')
        doc1 = FactoryGirl.create(:document, owner_id: user.id)
        doc2 = FactoryGirl.create(:document, owner_id: user2.id)
        signin(user2.email, user2.password)
        visit '/document/all'
        expect(page).to have_content %![{"name":"MyText","id":#{doc2.id},"_permissions":0}]!
      end

      scenario 'anonymous always lists no documents' do
        user = FactoryGirl.create(:user, username: 'test')
        doc1 = FactoryGirl.create(:document, owner_id: user.id)
        doc2 = FactoryGirl.create(:document, owner_id: nil)
        visit '/document/all'
        expect(page).to have_content %!{"valid":false,"message":"error.permissions"}!
      end

      scenario 'anonymous lists only documents with the specified run key' do
        user = FactoryGirl.create(:user, username: 'test')
        doc1 = FactoryGirl.create(:document, owner_id: user.id, run_key: 'foo')
        doc2 = FactoryGirl.create(:document, owner_id: nil, run_key: 'foo')
        visit '/document/all?runKey=foo'
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
        visit '/document/open?owner=test2&recordname=test2%20doc'
        expect(page).to have_content %!{"foo":"bar"}!
      end

      scenario 'user cannot open a document that is not shared by another person' do
        user = FactoryGirl.create(:user, username: 'test')
        user2 = FactoryGirl.create(:user, username: 'test2', email: 'test2@email.com')
        doc1 = FactoryGirl.create(:document, owner_id: user.id)
        doc2 = FactoryGirl.create(:document, title: "test2 doc", shared: false, owner_id: user2.id, form_content: '{ "foo": "bar" }')
        signin(user.email, user.password)
        visit '/document/open?owner=test2&recordname=test2%20doc'
        expect(page.status_code).to eq(403)
        expect(page).to have_content %!{"valid":false,"message":"error.permissions"}!
      end

      describe 'anonymous' do
        scenario 'anonymous user can open a document shared by another person' do
          user2 = FactoryGirl.create(:user, username: 'test2', email: 'test2@email.com')
          doc2 = FactoryGirl.create(:document, title: "test2 doc", shared: true, owner_id: user2.id, form_content: '{ "foo": "bar" }')
          visit '/document/open?owner=test2&recordname=test2%20doc'
          expect(page).to have_content %!{"foo":"bar"}!
        end

        scenario 'anonymous user can not open a document not shared by another person' do
          user2 = FactoryGirl.create(:user, username: 'test2', email: 'test2@email.com')
          doc2 = FactoryGirl.create(:document, title: "test2 doc", shared: false, owner_id: user2.id, form_content: '{ "foo": "bar" }')
          visit '/document/open?owner=test2&recordname=test2%20doc'
          expect(page).to have_content %!{"valid":false,"message":"error.permissions"}!
        end

        scenario 'anonymous user can open a document shared by another person while providing a run key' do
          user2 = FactoryGirl.create(:user, username: 'test2', email: 'test2@email.com')
          doc2 = FactoryGirl.create(:document, title: "test2 doc", shared: true, owner_id: user2.id, form_content: '{ "foo": "bar" }')
          visit '/document/open?owner=test2&recordname=test2%20doc&runKey=foo'
          expect(page).to have_content %!{"foo":"bar"}!
        end

        scenario 'anonymous user can open an owner-less document with a matching run_key' do
          doc = FactoryGirl.create(:document, title: "test2 doc", shared: false, owner_id: nil, run_key: 'run1', form_content: '{ "foo": "bar2" }')
          visit '/document/open?runKey=run1&recordname=test2%20doc'
          expect(page).to have_content %!{"foo":"bar2"}!
        end

        scenario 'anonymous user can open an owner-less document with a matching run_key (second url)' do
          doc = FactoryGirl.create(:document, title: "test2 doc", shared: false, owner_id: nil, run_key: 'run1', form_content: '{ "foo": "bar2" }')
          visit '/document/open?runKey=run1&owner=&recordname=test2%20doc'
          expect(page).to have_content %!{"foo":"bar2"}!
        end

        scenario 'anonymous user can not open an owner-less document with a non-matching run_key' do
          doc = FactoryGirl.create(:document, title: "test2 doc", shared: false, owner_id: nil, run_key: 'run2', form_content: '{ "foo": "bar2" }')
          visit '/document/open?runKey=run1&recordname=test2%20doc'
          expect(page).to have_content %!{"valid":false,"message":"error.notFound"}!
        end

        scenario 'anonymous user can not open a document owned by another person even with the correct run_key' do
          user2 = FactoryGirl.create(:user, username: 'test2', email: 'test2@email.com')
          doc2 = FactoryGirl.create(:document, title: "test2 doc", shared: false, owner_id: user2.id, run_key: 'run2', form_content: '{ "foo": "bar" }')
          visit '/document/open?runKey=run2&owner=test2&recordname=test2%20doc'
          expect(page).to have_content %!{"valid":false,"message":"error.permissions"}!
        end

        scenario 'logged in user can open a non-shared document owned by anonymous with the correct run key' do
          user = FactoryGirl.create(:user, username: 'test3', email: 'test3@email.com')
          doc = FactoryGirl.create(:document, title: "test3 doc", shared: false, owner_id: nil, run_key: 'biz', form_content: '{ "foo": "baz" }')
          signin(user.email, user.password)
          visit '/document/open?recordname=test3%20doc&runKey=biz'
          expect(page).to have_content %!{"foo":"baz"}!
        end

        scenario 'logged in user can open a non-shared document owned by anonymous with the correct run key (second url)' do
          user = FactoryGirl.create(:user, username: 'test3', email: 'test3@email.com')
          doc = FactoryGirl.create(:document, title: "test3 doc", shared: false, owner_id: nil, run_key: 'biz', form_content: '{ "foo": "baz" }')
          signin(user.email, user.password)
          visit '/document/open?owner=&recordname=test3%20doc&runKey=biz'
          expect(page).to have_content %!{"foo":"baz"}!
        end

        scenario 'logged in user cannot open a non-shared document owned by anonymous with the incorrect run key' do
          user = FactoryGirl.create(:user, username: 'test3', email: 'test3@email.com')
          doc = FactoryGirl.create(:document, title: "test3 doc", shared: false, owner_id: nil, run_key: 'biz', form_content: '{ "foo": "baz" }')
          signin(user.email, user.password)
          visit '/document/open?recordname=test3%20doc&runKey=baz'
          expect(page).to have_content %!{"valid":false,"message":"error.notFound"}!
        end

        scenario 'logged in user cannot open a non-shared document owned by anonymous with the incorrect run key (second url)' do
          user = FactoryGirl.create(:user, username: 'test3', email: 'test3@email.com')
          doc = FactoryGirl.create(:document, title: "test3 doc", shared: false, owner_id: nil, run_key: 'biz', form_content: '{ "foo": "baz" }')
          signin(user.email, user.password)
          visit '/document/open?owner=&recordname=test3%20doc&runKey=baz'
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
          visit '/document/open?owner=test2&recordname=something'
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
        page.driver.browser.submit :post, '/document/save?recordname=newdoc', '{ "def": [1,2,3,4] }'
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
        page.driver.browser.submit :post, '/document/save?recordname=newdoc', '{ "def": [1,2,3,4] }'
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
        page.driver.browser.submit :post, '/document/save?recordname=newdoc', '{ "def": [1,2,3,4] }'
        doc.reload
        expect(doc).not_to be_nil
        expect(doc.content).to match({"def" => [1,2,3,4] })
      end

      scenario 'when a document is saved for the first time, original_content is set' do
        user = FactoryGirl.create(:user, username: 'test')
        signin(user.email, user.password)
        page.driver.browser.submit :post, '/document/save?recordname=newdoc', '{ "def": [1,2,3,4] }'
        doc = Document.find_by(title: "newdoc")
        expect(doc).not_to be_nil
        expect(doc.original_content).to match({"def" => [1,2,3,4] })
      end

      scenario 'when a document is saved for the second or later time, original_content is not updated' do
        user = FactoryGirl.create(:user, username: 'test')
        signin(user.email, user.password)
        page.driver.browser.submit :post, '/document/save?recordname=newdoc', '{ "def": [1,2,3,4] }'
        page.driver.browser.submit :post, '/document/save?recordname=newdoc', '{ "def": [1,2,3,4,5,6] }'
        doc = Document.find_by(title: "newdoc")
        expect(doc).not_to be_nil
        expect(doc.original_content).to match({"def" => [1,2,3,4] })
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
      before(:each) do
        DocumentsController.run_key_generator = lambda { return 'foo' }
      end
      scenario 'user can launch a document via owner and recordname' do
        user = FactoryGirl.create(:user, username: 'test2')
        doc  = FactoryGirl.create(:document, title: "something", shared: true, owner_id: user.id, form_content: '{ "foo": "bar" }')
        visit '/document/launch?owner=test2&recordname=something&server=http://foo.com/'
        expect(page).to have_selector('.launch-button', count: 1)
        expect(page).to have_selector "a.launch-button[href='http://foo.com/?doc=something&documentServer=http%3A%2F%2Fwww.example.com%2F&owner=test2&runKey=foo']"
      end
      scenario 'user can launch a document via owner and doc' do
        user = FactoryGirl.create(:user, username: 'test2')
        doc  = FactoryGirl.create(:document, title: "something2", shared: true, owner_id: user.id, form_content: '{ "foo": "bar" }')
        visit '/document/launch?owner=test2&doc=something2&server=http://foo.com/'
        expect(page).to have_selector('.launch-button', count: 1)
        expect(page).to have_selector "a.launch-button[href='http://foo.com/?doc=something2&documentServer=http%3A%2F%2Fwww.example.com%2F&owner=test2&runKey=foo']"
      end
      scenario 'user can launch a document via moreGames' do
        visit '/document/launch?server=http://foo.com/&moreGames=%5B%7B%7D%5D'
        expect(page).to have_selector('.launch-button', count: 1)
        expect(page).to have_selector "a.launch-button[href='http://foo.com/?documentServer=http%3A%2F%2Fwww.example.com%2F&moreGames=%5B%7B%7D%5D&runKey=foo']"
      end
      scenario 'user can be logged in to launch' do
        # really, the requirement is that we don't need to be logged in, but that's already tested above,
        # so might as well test the inverse.
        user = FactoryGirl.create(:user, username: 'test2')
        doc  = FactoryGirl.create(:document, title: "something2", shared: true, owner_id: user.id, form_content: '{ "foo": "bar" }')
        user2 = FactoryGirl.create(:user, username: 'test3')
        signin(user2.email, user2.password)
        visit '/document/launch?owner=test2&recordname=something2&server=http://foo.com/'
        expect(page).to have_selector('.launch-button', count: 1)
        expect(page).to have_selector "a.launch-button[href='http://foo.com/?doc=something2&documentServer=http%3A%2F%2Fwww.example.com%2F&owner=test2&runKey=foo']"
      end
      scenario 'the document needs to exist to launch' do
        r = SecureRandom.hex
        visit "document/launch?owner=test2&recordname=#{r}&server=http://foo.com/"
        expect(page).to have_selector('.launch-button', count: 0)
        expect(page).to have_content "Error: The requested document could not be found."
      end
      describe 'run key provided' do
        describe 'anonymous' do
          scenario 'can launch a document via owner and recordname' do
            user = FactoryGirl.create(:user, username: 'test2')
            doc  = FactoryGirl.create(:document, title: "something", shared: true, owner_id: user.id, form_content: '{ "foo": "bar" }')
            visit '/document/launch?owner=test2&recordname=something&runKey=bar&server=http://foo.com/'
            expect(page).to have_selector('.launch-button', count: 1)
            expect(page).to have_selector "a.launch-button[href='http://foo.com/?doc=something&documentServer=http%3A%2F%2Fwww.example.com%2F&owner=test2&runKey=bar']"
          end
          scenario 'also has a single document that matches the run key, a link to it is displayed too' do
            user = FactoryGirl.create(:user, username: 'test2')
            doc  = FactoryGirl.create(:document, title: "something", shared: true, owner_id: user.id, form_content: '{ "foo": "bar" }')
            doc2  = FactoryGirl.create(:document, title: "something", shared: false, owner_id: nil, run_key: 'bar', form_content: '{ "foo": "bar" }')
            visit '/document/launch?owner=test2&recordname=something&runKey=bar&server=http://foo.com/'
            expect(page).to have_selector('.launch-button', count: 1)
            expect(page).to have_selector 'a.original-reset[href="http://foo.com/?doc=something&documentServer=http%3A%2F%2Fwww.example.com%2F&owner=test2&runKey=bar"]'
            expect(page).to have_selector "a.launch-button[href='http://foo.com/?doc=something&documentServer=http%3A%2F%2Fwww.example.com%2F&runKey=bar']"
          end
          scenario 'also has multiple documents that match the run key, a link to each of them is displayed too' do
            user = FactoryGirl.create(:user, username: 'test2')
            doc  = FactoryGirl.create(:document, title: "something", shared: true, owner_id: user.id, form_content: '{ "foo": "bar" }')
            doc2  = FactoryGirl.create(:document, title: "something", shared: false, owner_id: nil, run_key: 'bar', form_content: '{ "foo": "bar" }')
            doc3  = FactoryGirl.create(:document, title: "something3", shared: false, owner_id: nil, run_key: 'bar', form_content: '{ "foo": "bar" }')
            doc4  = FactoryGirl.create(:document, title: "something4", shared: false, owner_id: nil, run_key: 'bar', form_content: '{ "foo": "bar" }')
            doc5  = FactoryGirl.create(:document, title: "something5", shared: false, owner_id: nil, run_key: 'bar', form_content: '{ "foo": "bar" }')
            visit '/document/launch?owner=test2&recordname=something&server=http://foo.com/&runKey=bar'
            expect(page).to have_selector('.launch-button', count: 1)
            expect(page).to have_selector "a.original-reset[href='http://foo.com/?doc=something&documentServer=http%3A%2F%2Fwww.example.com%2F&owner=test2&runKey=bar']"
            expect(page).to have_selector "a.launch-button[href='http://foo.com/?doc=something5&documentServer=http%3A%2F%2Fwww.example.com%2F&runKey=bar']"
          end
          scenario 'also has documents that do not match the run key, a link to each of them is not also displayed' do
            user = FactoryGirl.create(:user, username: 'test2')
            doc  = FactoryGirl.create(:document, title: "something", shared: true, owner_id: user.id, form_content: '{ "foo": "bar" }')
            doc2  = FactoryGirl.create(:document, title: "something", shared: false, owner_id: nil, run_key: 'bar', form_content: '{ "foo": "bar" }')
            doc3  = FactoryGirl.create(:document, title: "something3", shared: false, owner_id: nil, run_key: 'bar', form_content: '{ "foo": "bar" }')
            doc4  = FactoryGirl.create(:document, title: "something4", shared: false, owner_id: nil, run_key: 'baz', form_content: '{ "foo": "bar" }')
            doc5  = FactoryGirl.create(:document, title: "something5", shared: false, owner_id: nil, run_key: 'baz', form_content: '{ "foo": "bar" }')
            visit '/document/launch?owner=test2&recordname=something&server=http://foo.com/&runKey=bar'
            expect(page).to have_selector('.launch-button', count: 1)
            expect(page).to have_selector "a.original-reset[href='http://foo.com/?doc=something&documentServer=http%3A%2F%2Fwww.example.com%2F&owner=test2&runKey=bar']"
            expect(page).to have_selector "a.launch-button[href='http://foo.com/?doc=something3&documentServer=http%3A%2F%2Fwww.example.com%2F&runKey=bar']"
          end
          scenario 'moreGames in url and no documents with run key, only a link to the moregames url is present' do
            visit '/document/launch?moreGames=%5B%7B%7D%5D&server=http://foo.com/&runKey=bar'
            expect(page).to have_selector('.launch-button', count: 1)
            expect(page).to have_selector "a.launch-button[href='http://foo.com/?documentServer=http%3A%2F%2Fwww.example.com%2F&moreGames=%5B%7B%7D%5D&runKey=bar']"
          end
          scenario 'moreGames in url and one document with run key, 2 links are present' do
            user4 = FactoryGirl.create(:user, username: 'test4')
            doc2  = FactoryGirl.create(:document, title: "something", shared: false, owner_id: nil, run_key: 'bar', form_content: '{ "foo": "bar" }')
            visit '/document/launch?moreGames=%5B%7B%7D%5D&server=http://foo.com/&runKey=bar'
            expect(page).to have_selector('.launch-button', count: 1)
            expect(page).to have_selector "a.original-reset[href='http://foo.com/?documentServer=http%3A%2F%2Fwww.example.com%2F&moreGames=%5B%7B%7D%5D&runKey=bar']"
            expect(page).to have_selector "a.launch-button[href='http://foo.com/?doc=something&documentServer=http%3A%2F%2Fwww.example.com%2F&runKey=bar']"
          end
          scenario 'moreGames in url and multiple documents with run key, all links are present' do
            user4 = FactoryGirl.create(:user, username: 'test4')
            doc2  = FactoryGirl.create(:document, title: "something", shared: false, owner_id: nil, run_key: 'bar', form_content: '{ "foo": "bar" }')
            doc3  = FactoryGirl.create(:document, title: "something3", shared: false, owner_id: nil, run_key: 'bar', form_content: '{ "foo": "bar" }')
            doc4  = FactoryGirl.create(:document, title: "something4", shared: false, owner_id: nil, run_key: 'bar', form_content: '{ "foo": "bar" }')
            doc5  = FactoryGirl.create(:document, title: "something5", shared: false, owner_id: nil, run_key: 'baz', form_content: '{ "foo": "bar" }')
            visit '/document/launch?moreGames=%5B%7B%7D%5D&server=http://foo.com/&runKey=bar'
            expect(page).to have_selector('.launch-button', count: 1)
            expect(page).to have_selector "a.original-reset[href='http://foo.com/?documentServer=http%3A%2F%2Fwww.example.com%2F&moreGames=%5B%7B%7D%5D&runKey=bar']"
            expect(page).to have_selector "a.launch-button[href='http://foo.com/?doc=something4&documentServer=http%3A%2F%2Fwww.example.com%2F&runKey=bar']"
          end
        end
        describe 'logged in user' do
          scenario 'can launch a document via owner and recordname' do
            user = FactoryGirl.create(:user, username: 'test2')
            doc  = FactoryGirl.create(:document, title: "something", shared: true, owner_id: user.id, form_content: '{ "foo": "bar" }')
            user4 = FactoryGirl.create(:user, username: 'test4')
            signin(user4.email, user4.password)
            visit '/document/launch?owner=test2&recordname=something&server=http://foo.com/&runKey=bar'
            expect(page).to have_selector('.launch-button', count: 1)
            expect(page).to have_selector "a.launch-button[href='http://foo.com/?doc=something&documentServer=http%3A%2F%2Fwww.example.com%2F&owner=test2&runKey=bar']"
          end
          scenario 'also has a single document that matches the run key, a link to it is displayed too' do
            user = FactoryGirl.create(:user, username: 'test2')
            doc  = FactoryGirl.create(:document, title: "something", shared: true, owner_id: user.id, form_content: '{ "foo": "bar" }')
            user4 = FactoryGirl.create(:user, username: 'test4')
            doc2  = FactoryGirl.create(:document, title: "something", shared: false, owner_id: user4.id, run_key: 'bar', form_content: '{ "foo": "bar" }')
            signin(user4.email, user4.password)
            visit '/document/launch?owner=test2&recordname=something&server=http://foo.com/&runKey=bar'
            expect(page).to have_selector('.launch-button', count: 1)
            expect(page).to have_selector "a.original-reset[href='http://foo.com/?doc=something&documentServer=http%3A%2F%2Fwww.example.com%2F&owner=test2&runKey=bar']"
            expect(page).to have_selector "a.launch-button[href='http://foo.com/?doc=something&documentServer=http%3A%2F%2Fwww.example.com%2F&owner=test4&runKey=bar']"
          end
          scenario 'also has multiple documents that match the run key, a link to each of them is displayed too' do
            user = FactoryGirl.create(:user, username: 'test2')
            doc  = FactoryGirl.create(:document, title: "something", shared: true, owner_id: user.id, form_content: '{ "foo": "bar" }')
            user4 = FactoryGirl.create(:user, username: 'test4')
            doc2  = FactoryGirl.create(:document, title: "something", shared: false, owner_id: user4.id, run_key: 'bar', form_content: '{ "foo": "bar" }')
            doc3  = FactoryGirl.create(:document, title: "something3", shared: false, owner_id: user4.id, run_key: 'bar', form_content: '{ "foo": "bar" }')
            doc4  = FactoryGirl.create(:document, title: "something4", shared: false, owner_id: user4.id, run_key: 'bar', form_content: '{ "foo": "bar" }')
            doc5  = FactoryGirl.create(:document, title: "something5", shared: false, owner_id: user4.id, run_key: 'bar', form_content: '{ "foo": "bar" }')
            signin(user4.email, user4.password)
            visit '/document/launch?owner=test2&recordname=something&server=http://foo.com/&runKey=bar'
            expect(page).to have_selector('.launch-button', count: 1)
            expect(page).to have_selector "a.original-reset[href='http://foo.com/?doc=something&documentServer=http%3A%2F%2Fwww.example.com%2F&owner=test2&runKey=bar']"
            expect(page).to have_selector "a.launch-button[href='http://foo.com/?doc=something5&documentServer=http%3A%2F%2Fwww.example.com%2F&owner=test4&runKey=bar']"
          end
          scenario 'also has documents that do not match the run key, a link to each of them is not also displayed' do
            user = FactoryGirl.create(:user, username: 'test2')
            doc  = FactoryGirl.create(:document, title: "something", shared: true, owner_id: user.id, form_content: '{ "foo": "bar" }')
            user4 = FactoryGirl.create(:user, username: 'test4')
            doc2  = FactoryGirl.create(:document, title: "something", shared: false, owner_id: user4.id, run_key: 'bar', form_content: '{ "foo": "bar" }')
            doc3  = FactoryGirl.create(:document, title: "something3", shared: false, owner_id: user4.id, run_key: 'bar', form_content: '{ "foo": "bar" }')
            doc4  = FactoryGirl.create(:document, title: "something4", shared: false, owner_id: user4.id, run_key: 'baz', form_content: '{ "foo": "bar" }')
            doc5  = FactoryGirl.create(:document, title: "something5", shared: false, owner_id: user4.id, run_key: 'baz', form_content: '{ "foo": "bar" }')
            signin(user4.email, user4.password)
            visit '/document/launch?owner=test2&recordname=something&server=http://foo.com/&runKey=bar'
            expect(page).to have_selector('.launch-button', count: 1)
            expect(page).to have_selector "a.original-reset[href='http://foo.com/?doc=something&documentServer=http%3A%2F%2Fwww.example.com%2F&owner=test2&runKey=bar']"
            expect(page).to have_selector "a.launch-button[href='http://foo.com/?doc=something3&documentServer=http%3A%2F%2Fwww.example.com%2F&owner=test4&runKey=bar']"
          end
          scenario 'moreGames in url and no documents with run key, only a link to the moregames url is present' do
            user4 = FactoryGirl.create(:user, username: 'test4')
            signin(user4.email, user4.password)
            visit '/document/launch?moreGames=%5B%7B%7D%5D&server=http://foo.com/&runKey=bar'
            expect(page).to have_selector('.launch-button', count: 1)
            expect(page).to have_selector "a.launch-button[href='http://foo.com/?documentServer=http%3A%2F%2Fwww.example.com%2F&moreGames=%5B%7B%7D%5D&runKey=bar']"
          end
          scenario 'moreGames in url and one document with run key, 2 links are present' do
            user4 = FactoryGirl.create(:user, username: 'test4')
            doc2  = FactoryGirl.create(:document, title: "something", shared: false, owner_id: user4.id, run_key: 'bar', form_content: '{ "foo": "bar" }')
            signin(user4.email, user4.password)
            visit '/document/launch?moreGames=%5B%7B%7D%5D&server=http://foo.com/&runKey=bar'
            expect(page).to have_selector('.launch-button', count: 1)
            expect(page).to have_selector "a.original-reset[href='http://foo.com/?documentServer=http%3A%2F%2Fwww.example.com%2F&moreGames=%5B%7B%7D%5D&runKey=bar']"
            expect(page).to have_selector "a.launch-button[href='http://foo.com/?doc=something&documentServer=http%3A%2F%2Fwww.example.com%2F&owner=test4&runKey=bar']"
          end
          scenario 'moreGames in url and multiple documents with run key, all links are present' do
            user4 = FactoryGirl.create(:user, username: 'test4')
            doc2  = FactoryGirl.create(:document, title: "something", shared: false, owner_id: user4.id, run_key: 'bar', form_content: '{ "foo": "bar" }')
            doc3  = FactoryGirl.create(:document, title: "something3", shared: false, owner_id: user4.id, run_key: 'bar', form_content: '{ "foo": "bar" }')
            doc4  = FactoryGirl.create(:document, title: "something4", shared: false, owner_id: user4.id, run_key: 'bar', form_content: '{ "foo": "bar" }')
            doc5  = FactoryGirl.create(:document, title: "something5", shared: false, owner_id: user4.id, run_key: 'baz', form_content: '{ "foo": "bar" }')
            signin(user4.email, user4.password)
            visit '/document/launch?moreGames=%5B%7B%7D%5D&server=http://foo.com/&runKey=bar'
            expect(page).to have_selector('.launch-button', count: 1)
            expect(page).to have_selector "a.original-reset[href='http://foo.com/?documentServer=http%3A%2F%2Fwww.example.com%2F&moreGames=%5B%7B%7D%5D&runKey=bar']"
            expect(page).to have_selector "a.launch-button[href='http://foo.com/?doc=something4&documentServer=http%3A%2F%2Fwww.example.com%2F&owner=test4&runKey=bar']"
          end
        end
      end
      describe 'auto authentication' do
        scenario 'the user will be authenticated if auth_provider is set and the user is not logged in' do
          user = FactoryGirl.create(:user, username: 'test2')
          doc  = FactoryGirl.create(:document, title: "something2", shared: true, owner_id: user.id, form_content: '{ "foo": "bar" }')
          expect {
            visit '/document/launch?owner=test2&recordname=something2&server=http://foo.com/&auth_provider=http://bar.com'
          }.to raise_error(ActionController::RoutingError) # capybara doesn't handle the redirects well
          expect(page.current_url).to match 'http://bar.com/auth/concord_id/authorize'
        end
        scenario 'the user will not be authenticated if auth_provider is set and the user is logged in' do
          user = FactoryGirl.create(:user, username: 'test2')
          doc  = FactoryGirl.create(:document, title: "something2", shared: true, owner_id: user.id, form_content: '{ "foo": "bar" }')
          user2 = FactoryGirl.create(:user, username: 'test4')
          signin(user2.email, user2.password)
          visit '/document/launch?owner=test2&recordname=something2&server=http://foo.com/&auth_provider=http://bar.com/'
          expect(page).to have_selector "a.launch-button[href='http://foo.com/?doc=something2&documentServer=http%3A%2F%2Fwww.example.com%2F&owner=test2&runKey=foo']"
        end
      end
      describe 'LARA integration' do
        scenario 'page has correct iframe phone code' do
          user = FactoryGirl.create(:user, username: 'test2')
          doc  = FactoryGirl.create(:document, title: "something", shared: true, owner_id: user.id, form_content: '{ "foo": "bar" }')
          visit '/document/launch?owner=test2&doc=something&server=http://foo.com/'
          expect(page.html).to have_text(
            <<-JS
              phone.addListener('getLearnerUrl', function () {
                phone.post('setLearnerUrl', 'http://www.example.com/document/launch?doc=something&owner=test2&runKey=foo&server=http%3A%2F%2Ffoo.com%2F');
                phone.post('getAuthInfo');
              });
            JS
          )
          expect(page.html).to have_text(
            <<-JS
              phone.addListener('getInteractiveState', function () {
                phone.post('interactiveState', {runKey: 'foo'});
              });
            JS
          )
          expect(page.html).to have_text("phone.addListener('authInfo', function(info) {")
          expect(page.html).to have_text("phone.addListener('getExtendedSupport', function() {")
        end
        scenario 'page has correct iframe phone code when the runKey is supplied' do
          user = FactoryGirl.create(:user, username: 'test2')
          doc  = FactoryGirl.create(:document, title: "something", shared: true, owner_id: user.id, form_content: '{ "foo": "bar" }')
          visit '/document/launch?owner=test2&doc=something&server=http://foo.com/&runKey=bar'
          expect(page.html).to have_text(
            <<-JS
              phone.addListener('getLearnerUrl', function () {
                phone.post('setLearnerUrl', 'http://www.example.com/document/launch?doc=something&owner=test2&runKey=bar&server=http%3A%2F%2Ffoo.com%2F');
                phone.post('getAuthInfo');
              });
            JS
          )
          expect(page.html).to have_text(
            <<-JS
              phone.addListener('getInteractiveState', function () {
                phone.post('interactiveState', {runKey: 'bar'});
              });
            JS
          )
          expect(page.html).to have_text("phone.addListener('authInfo', function(info) {")
          expect(page.html).to have_text("phone.addListener('getExtendedSupport', function() {")
        end
      end
    end

    describe 'delete' do
      scenario 'user can delete their own document' do
        user = FactoryGirl.create(:user, username: 'test')
        doc  = FactoryGirl.create(:document, title: "something-unique", owner_id: user.id, form_content: '{ "foo": "bar" }')
        signin(user.email, user.password)
        visit '/document/delete?doc=something-unique'
        expect(page).to have_content('{"success":true}')
        doc2 = Document.find_by(title: "something-unique", owner: user)
        expect(doc2).to be_nil
      end

      scenario 'user can not delete a document owned by someone else' do
        user = FactoryGirl.create(:user, username: 'test')
        user2 = FactoryGirl.create(:user, username: 'test2')
        doc2 = FactoryGirl.create(:document, title: "newdoc", shared: false, owner_id: user2.id, form_content: '{ "foo": "bar" }')
        signin(user.email, user.password)
        visit '/document/delete?doc=newdoc&owner=test2'
        expect(page).to have_content %!{"valid":false,"message":"error.notFound"}!
        doc = Document.find_by(title: "newdoc", owner: user2)
        expect(doc).not_to be_nil
      end

      scenario 'user deletes the document with a matching run key' do
        user = FactoryGirl.create(:user, username: 'test')
        doc  = FactoryGirl.create(:document, title: "something", owner_id: user.id, form_content: '{ "foo": "bar" }')
        doc2 = FactoryGirl.create(:document, title: "something", owner_id: user.id, form_content: '{ "foo": "bar" }', run_key: 'foo')
        doc3 = FactoryGirl.create(:document, title: "something", owner_id: user.id, form_content: '{ "foo": "bar" }', run_key: 'bar')
        signin(user.email, user.password)
        visit '/document/delete?doc=something&runKey=foo'
        expect(page).to have_content('{"success":true}')
        docs = Document.where(owner: user, title: 'something').order(:run_key)
        expect(docs.size).to eq 2
        expect(docs[0].run_key).to eq 'bar'
        expect(docs[1].run_key).to be_nil
        visit '/document/delete?doc=something'
        expect(page).to have_content('{"success":true}')
        docs = Document.where(owner: user, title: 'something')
        expect(docs.size).to eq 1
        expect(docs[0].run_key).to eq 'bar'
      end

      scenario 'user gets an error when a matching document does not exist' do
        user = FactoryGirl.create(:user, username: 'test')
        doc  = FactoryGirl.create(:document, title: "something", owner_id: user.id, form_content: '{ "foo": "bar" }')
        signin(user.email, user.password)
        visit '/document/delete?doc=something2'
        expect(page).to have_content %!{"valid":false,"message":"error.notFound"}!
      end

      describe 'anonymous' do
        scenario 'user cannot delete documents when no run_key is present' do
          doc  = FactoryGirl.create(:document, title: "something", owner_id: nil, form_content: '{ "foo": "bar" }')
          visit '/document/delete?doc=something'
          expect(page).to have_content %!{"valid":false,"message":"error.permissions"}!
          doc2 = Document.find_by(title: "something", owner_id: nil)
          expect(doc2).not_to be_nil
        end

        scenario 'user can delete documents when a run_key is present' do
          doc  = FactoryGirl.create(:document, title: "something", owner_id: nil, form_content: '{ "foo": "bar" }', run_key: 'foo')
          visit '/document/delete?doc=something&runKey=foo'
          expect(page).to have_content('{"success":true}')
          doc2 = Document.find_by(title: "something", owner_id: nil)
          expect(doc2).to be_nil
        end

        scenario 'user deletes the document with a matching run key' do
          doc  = FactoryGirl.create(:document, title: "something", owner_id: nil, form_content: '{ "foo": "bar" }', run_key: 'baz')
          doc2 = FactoryGirl.create(:document, title: "something", owner_id: nil, form_content: '{ "foo": "bar" }', run_key: 'foo')
          doc3 = FactoryGirl.create(:document, title: "something", owner_id: nil, form_content: '{ "foo": "bar" }', run_key: 'bar')
          visit '/document/delete?doc=something&runKey=foo'
          expect(page).to have_content('{"success":true}')
          docs = Document.where(owner_id: nil, title: 'something').order(:run_key)
          expect(docs.size).to eq 2
          expect(docs[0].run_key).to eq 'bar'
          expect(docs[1].run_key).to eq 'baz'
          visit '/document/delete?doc=something&runKey=baz'
          expect(page).to have_content('{"success":true}')
          docs = Document.where(owner_id: nil, title: 'something')
          expect(docs.size).to eq 1
          expect(docs[0].run_key).to eq 'bar'
        end

        scenario 'user gets an error when a matching document does not exist' do
          user = FactoryGirl.create(:user, username: 'test')
          doc  = FactoryGirl.create(:document, title: "something", owner_id: user.id, form_content: '{ "foo": "bar" }', run_key: 'bar')
          signin(user.email, user.password)
          visit '/document/delete?doc=something2'
          expect(page).to have_content %!{"valid":false,"message":"error.notFound"}!
          visit '/document/delete?doc=something&runKey=foo'
          expect(page).to have_content %!{"valid":false,"message":"error.notFound"}!
        end
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
      scenario 'logged in users have accurate info' do
        user = FactoryGirl.create(:user, username: 'test')
        signin(user.email, user.password)
        visit "/user/info"
        expect(page.status_code).to eq(200)
        expect(page).to have_content %!{"valid":true,"sessionToken":"abc123","enableLogging":false,"privileges":0,"useCookie":false,"enableSave":true,"username":"test","name":"Test User"}!
      end
    end
  end
end

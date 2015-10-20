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
      describe 'by record id' do
        scenario 'user can open their own document' do
          user = FactoryGirl.create(:user, username: 'test')
          doc1 = FactoryGirl.create(:document, title: 'testDoc', owner_id: user.id, content: '[1, 2, 3]')
          signin(user.email, user.password)
          visit "/document/open?recordid=#{doc1.id}"
          expect(page).to have_content %![1,2,3]!
          expect(page.response_headers['X-CODAP-Will-Overwrite']).to be_nil
        end
        scenario 'expect Document-Id header to be set correctly' do
          user = FactoryGirl.create(:user, username: 'test')
          doc1 = FactoryGirl.create(:document, title: 'testDoc', owner_id: user.id, content: '[1, 2, 3]')
          signin(user.email, user.password)
          visit "/document/open?recordid=#{doc1.id}"
          expect(page).to have_content %![1,2,3]!
          expect(page.response_headers['Document-Id']).to eq("#{doc1.id}")
        end
        scenario 'user can open a document shared by someone else' do
          user = FactoryGirl.create(:user, username: 'test')
          user2 = FactoryGirl.create(:user, username: 'test2', email: 'test2@email.com')
          doc1 = FactoryGirl.create(:document, owner_id: user.id)
          doc2 = FactoryGirl.create(:document, title: "test2 doc", shared: true, owner_id: user2.id, form_content: '{ "foo": "bar" }')
          signin(user.email, user.password)
          visit "/document/open?recordid=#{doc2.id}"
          expect(page).to have_content %!{"foo":"bar"}!
          expect(page.response_headers['X-CODAP-Will-Overwrite']).to be_nil
        end
        scenario 'another user\'s shared doc will not be shared when opened' do
          user = FactoryGirl.create(:user, username: 'test')
          user2 = FactoryGirl.create(:user, username: 'test2', email: 'test2@email.com')
          doc1 = FactoryGirl.create(:document, owner_id: user.id)
          doc2 = FactoryGirl.create(:document, title: "test2 doc", shared: true, owner_id: user2.id, form_content: '{ "foo": "bar", "_permissions": 1 }')
          signin(user.email, user.password)
          visit "/document/open?recordid=#{doc2.id}"
          expect(page).to have_content %!{"foo":"bar","_permissions":0}!
        end
        scenario 'user can not open a document not shared by someone else' do
          user = FactoryGirl.create(:user, username: 'test')
          user2 = FactoryGirl.create(:user, username: 'test2', email: 'test2@email.com')
          doc1 = FactoryGirl.create(:document, owner_id: user.id)
          doc2 = FactoryGirl.create(:document, title: "test2 doc", shared: false, owner_id: user2.id, form_content: '{ "foo": "bar" }')
          signin(user.email, user.password)
          visit "/document/open?recordid=#{doc2.id}"
          expect(page.status_code).to eq(403)
          expect(page).to have_content %!{"valid":false,"message":"error.permissions"}!
        end
        scenario 'user will always get the other person\'s document content when opening a doc shared by someone else' do
          user = FactoryGirl.create(:user, username: 'test')
          user2 = FactoryGirl.create(:user, username: 'test2', email: 'test2@email.com')
          doc1 = FactoryGirl.create(:document, title: "test2 doc", owner_id: user.id, form_content: '{ "nice": "content" }')
          doc2 = FactoryGirl.create(:document, title: "test2 doc", shared: true, owner_id: user2.id, form_content: '{ "foo": "bar" }')
          signin(user.email, user.password)
          visit "/document/open?recordid=#{doc2.id}"
          expect(page).to have_content %!{"foo":"bar"}!
          expect(page.response_headers['X-CODAP-Will-Overwrite']).to eq("true")
        end
      end

      scenario 'user can open their own document' do
        user = FactoryGirl.create(:user, username: 'test')
        doc1 = FactoryGirl.create(:document, title: 'testDoc', owner_id: user.id, content: '[1, 2, 3]')
        signin(user.email, user.password)
        visit "/document/open?owner=#{user.username}&recordname=#{doc1.title}"
        expect(page).to have_content %![1,2,3]!
        expect(page.response_headers['X-CODAP-Will-Overwrite']).to be_nil
      end

      scenario 'user can open a document shared by another person' do
        user = FactoryGirl.create(:user, username: 'test')
        user2 = FactoryGirl.create(:user, username: 'test2', email: 'test2@email.com')
        doc1 = FactoryGirl.create(:document, owner_id: user.id)
        doc2 = FactoryGirl.create(:document, title: "test2 doc", shared: true, owner_id: user2.id, form_content: '{ "foo": "bar" }')
        signin(user.email, user.password)
        visit '/document/open?owner=test2&recordname=test2%20doc'
        expect(page).to have_content %!{"foo":"bar"}!
        expect(page.response_headers['X-CODAP-Will-Overwrite']).to be_nil
      end

      scenario 'another user\'s shared doc will not be shared when opened' do
        user = FactoryGirl.create(:user, username: 'test')
        user2 = FactoryGirl.create(:user, username: 'test2', email: 'test2@email.com')
        doc1 = FactoryGirl.create(:document, owner_id: user.id)
        doc2 = FactoryGirl.create(:document, title: "test2 doc", shared: true, owner_id: user2.id, form_content: '{ "foo": "bar", "_permissions": 1 }')
        signin(user.email, user.password)
        visit '/document/open?owner=test2&recordname=test2%20doc'
        expect(page).to have_content %!{"foo":"bar","_permissions":0}!
      end

      scenario 'user will always get the other person\'s document content when opening a doc shared by someone else' do
        user = FactoryGirl.create(:user, username: 'test')
        user2 = FactoryGirl.create(:user, username: 'test2', email: 'test2@email.com')
        doc1 = FactoryGirl.create(:document, title: "test2 doc", owner_id: user.id, form_content: '{ "nice": "content" }')
        doc2 = FactoryGirl.create(:document, title: "test2 doc", shared: true, owner_id: user2.id, form_content: '{ "foo": "bar" }')
        signin(user.email, user.password)
        visit "/document/open?owner=test2&recordname=test2%20doc"
        expect(page).to have_content %!{"foo":"bar"}!
        expect(page.response_headers['X-CODAP-Will-Overwrite']).to eq("true")
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

      scenario 'user can request the original content for their own document' do
        user = FactoryGirl.create(:user, username: 'test')
        signin(user.email, user.password)
        page.driver.browser.submit :post, '/document/save?recordname=testDoc', '{ "def": [1,2,3,4] }'
        page.driver.browser.submit :post, '/document/save?recordname=testDoc', '{ "def": [1,2,3,4,5,6] }'
        visit "/document/open?owner=test&recordname=testDoc&original=true"
        expect(page).to have_content %!{"def":[1,2,3,4]}!
      end

      scenario 'user can not request the original content for document owned by someone else' do
        user = FactoryGirl.create(:user, username: 'test')
        user2 = FactoryGirl.create(:user, username: 'test2')
        signin(user.email, user.password)
        page.driver.browser.submit :post, '/document/save?recordname=testDoc', '{ "def": [1,2,3,4], "_permissions": 1 }'
        doc = Document.find_by(title: 'testDoc', owner: user)
        page.driver.browser.submit :post, "/document/save?recordid=#{doc.id}", '{ "def": [1,2,3,4,5,6], "_permissions": 1 }'
        signout
        signin(user2.email, user2.password)
        visit "/document/open?owner=test&recordname=testDoc&original=true"
        expect(page).to have_content %!{"def":[1,2,3,4,5,6],"_permissions":0}!
      end

      scenario 'if original content has not been defined, return the current content' do
        user = FactoryGirl.create(:user, username: 'test')
        signin(user.email, user.password)
        doc2 = FactoryGirl.create(:document, title: "testDoc", shared: false, owner_id: user.id, form_content: '{ "foo": "bar" }')
        page.driver.browser.submit :post, "/document/save?recordid=#{doc2.id}", '{ "def": [1,2,3,4,5,6] }'
        visit "/document/open?owner=test&recordname=testDoc&original=true"
        doc2.reload
        expect(doc2.original_content).to be_nil
        expect(page).to have_content %!{"def":[1,2,3,4,5,6]}!
      end

      describe 'anonymous' do
        scenario 'anonymous user can open a document shared by another person' do
          user2 = FactoryGirl.create(:user, username: 'test2', email: 'test2@email.com')
          doc2 = FactoryGirl.create(:document, title: "test2 doc", shared: true, owner_id: user2.id, form_content: '{ "foo": "bar" }')
          visit '/document/open?owner=test2&recordname=test2%20doc'
          expect(page).to have_content %!{"foo":"bar"}!
          expect(page.response_headers['X-CODAP-Will-Overwrite']).to be_nil
        end

        scenario 'another user\'s shared doc will not be shared when opened' do
          user2 = FactoryGirl.create(:user, username: 'test2', email: 'test2@email.com')
          doc2 = FactoryGirl.create(:document, title: "test2 doc", shared: true, owner_id: user2.id, form_content: '{ "foo": "bar", "_permissions": 1 }')
          visit '/document/open?owner=test2&recordname=test2%20doc'
          expect(page).to have_content %!{"foo":"bar","_permissions":0}!
        end

        scenario 'anonymous will always get the other person\'s document content when opening a doc shared by someone else' do
          user2 = FactoryGirl.create(:user, username: 'test2', email: 'test2@email.com')
          doc1 = FactoryGirl.create(:document, title: "test2 doc", form_content: '{ "nice": "content" }')
          doc2 = FactoryGirl.create(:document, title: "test2 doc", shared: true, owner_id: user2.id, form_content: '{ "foo": "bar" }')
          visit "/document/open?owner=test2&recordname=test2%20doc"
          expect(page).to have_content %!{"foo":"bar"}!
          expect(page.response_headers['X-CODAP-Will-Overwrite']).to be_nil
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
          expect(page.response_headers['X-CODAP-Will-Overwrite']).to be_nil
        end

        scenario 'anonymous will always get the other person\'s document content when opening a doc shared by someone else (wih a run key)' do
          user2 = FactoryGirl.create(:user, username: 'test2', email: 'test2@email.com')
          doc1 = FactoryGirl.create(:document, title: "test2 doc", owner_id: nil, form_content: '{ "nice": "content" }', run_key: 'biz')
          doc2 = FactoryGirl.create(:document, title: "test2 doc", shared: true, owner_id: user2.id, form_content: '{ "foo": "bar" }')
          visit "/document/open?owner=test2&recordname=test2%20doc&runKey=biz"
          expect(page).to have_content %!{"foo":"bar"}!
          expect(page.response_headers['X-CODAP-Will-Overwrite']).to eq("true")
        end

        scenario 'anonymous user can open an owner-less document with a matching run_key' do
          doc = FactoryGirl.create(:document, title: "test2 doc", shared: false, owner_id: nil, run_key: 'run1', form_content: '{ "foo": "bar2" }')
          visit '/document/open?runKey=run1&recordname=test2%20doc'
          expect(page).to have_content %!{"foo":"bar2"}!
          expect(page.response_headers['X-CODAP-Will-Overwrite']).to be_nil
        end

        scenario 'anonymous user can open an owner-less document with a matching run_key (second url)' do
          doc = FactoryGirl.create(:document, title: "test2 doc", shared: false, owner_id: nil, run_key: 'run1', form_content: '{ "foo": "bar2" }')
          visit '/document/open?runKey=run1&owner=&recordname=test2%20doc'
          expect(page).to have_content %!{"foo":"bar2"}!
          expect(page.response_headers['X-CODAP-Will-Overwrite']).to be_nil
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
          expect(page.response_headers['X-CODAP-Will-Overwrite']).to be_nil
        end

        scenario 'logged in user can open a non-shared document owned by someone else with the correct run key' do
          user  = FactoryGirl.create(:user, username: 'test3', email: 'test3@email.com')
          user2 = FactoryGirl.create(:user, username: 'test4')
          doc = FactoryGirl.create(:document, title: "test3 doc", shared: false, owner_id: user2.id, run_key: 'biz', form_content: '{ "foo": "baz" }')
          signin(user.email, user.password)
          visit '/document/open?owner=test4&recordname=test3%20doc&runKey=biz'
          expect(page).to have_content %!{"foo":"baz"}!
          expect(page.response_headers['X-CODAP-Will-Overwrite']).to be_nil
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

        scenario 'anonymous user can request the original content for their own document' do
          page.driver.browser.submit :post, '/document/save?recordname=testDoc&runKey=foo', '{ "def": [1,2,3,4] }'
          page.driver.browser.submit :post, '/document/save?recordname=testDoc&runKey=foo', '{ "def": [1,2,3,4,5,6] }'
          visit "/document/open?recordname=testDoc&runKey=foo&original=true"
          expect(page).to have_content %!{"def":[1,2,3,4]}!
        end

        scenario 'anoymous user can not request the original content for document owned by someone else' do
          user = FactoryGirl.create(:user, username: 'test')
          signin(user.email, user.password)
          page.driver.browser.submit :post, '/document/save?recordname=testDoc', '{ "def": [1,2,3,4], "_permissions": 1 }'
          doc = Document.find_by(title: 'testDoc', owner: user)
          page.driver.browser.submit :post, "/document/save?recordid=#{doc.id}", '{ "def": [1,2,3,4,5,6], "_permissions": 1 }'
          signout
          visit "/document/open?owner=test&recordname=testDoc&runKey=foo&original=true"
          expect(page).to have_content %!{"def":[1,2,3,4,5,6],"_permissions":0}!
        end

        scenario 'if original content has not been defined, return the current content' do
          doc2 = FactoryGirl.create(:document, title: "testDoc", shared: false, owner_id: nil, form_content: '{ "foo": "bar" }', run_key: 'bar')
          page.driver.browser.submit :post, '/document/save?recordname=testDoc&runKey=bar', '{ "def": [1,2,3,4,5,6] }'
          visit "/document/open?recordname=testDoc&original=true&runKey=bar"
          doc2.reload
          expect(doc2.original_content).to be_nil
          expect(page).to have_content %!{"def":[1,2,3,4,5,6]}!
        end

      end

      describe 'errors' do
        scenario 'user gets 403 when they open a document by id and do not own it' do
          user = FactoryGirl.create(:user, username: 'test')
          user2 = FactoryGirl.create(:user, username: 'test2', email: 'test2@email.com')
          doc1 = FactoryGirl.create(:document, title: 'testDoc', owner_id: user.id, content: '[1, 2, 3]')
          doc2 = FactoryGirl.create(:document, title: "test2 doc", owner_id: user2.id, form_content: '{ "foo": "bar" }')
          signin(user.email, user.password)
          visit "/document/open?recordid=#{doc2.id}"
          expect(page.status_code).to eq(403)
          expect(page).to have_content %!{"valid":false,"message":"error.permissions"}!
        end

        scenario 'user gets 404 when they open a document by id and it does not exist' do
          user = FactoryGirl.create(:user, username: 'test')
          signin(user.email, user.password)
          visit "/document/open?username=test&recordid=99999"
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
      describe 'by record id' do
        scenario 'user can save their own document' do
          user = FactoryGirl.create(:user, username: 'test')
          doc = FactoryGirl.create(:document, title: "newdoc", shared: false, owner_id: user.id, form_content: '{ "foo": "bar" }')
          signin(user.email, user.password)
          page.driver.browser.submit :post, "/document/save?recordid=#{doc.id}", '{ "def": [1,2,3,4] }'
          doc = Document.find(doc.id)
          expect(doc).not_to be_nil
          expect(doc.title).to eq("newdoc")
          expect(doc.content).to match({"def" => [1,2,3,4] })
        end
        scenario 'save should return the document id' do
          user = FactoryGirl.create(:user, username: 'test')
          doc = FactoryGirl.create(:document, title: "newdoc", shared: false, owner_id: user.id, form_content: '{ "foo": "bar" }')
          signin(user.email, user.password)
          page.driver.browser.submit :post, "/document/save?recordid=#{doc.id}", '{ "def": [1,2,3,4] }'
          expect(page).to have_content %!{"status":"Created","valid":true,"id":#{doc.id}}!
        end
        scenario 'user can not save over a document owned by someone else' do
          user = FactoryGirl.create(:user, username: 'test')
          user2 = FactoryGirl.create(:user, username: 'test2', email: 'test2@email.com')
          doc2 = FactoryGirl.create(:document, title: "newdoc", shared: false, owner_id: user2.id, form_content: '{ "foo": "bar" }')
          expect(Document.find_by(title: "newdoc", owner_id: user.id)).to be_nil
          expect(Document.find_by(title: "newdoc", owner_id: user2.id)).not_to be_nil
          signin(user.email, user.password)
          page.driver.browser.submit :post, "/document/save?recordid=#{doc2.id}", '{ "def": [1,2,3,4] }'
          doc = Document.find_by(title: "newdoc", owner_id: user.id)
          doc2 = Document.find_by(title: "newdoc", owner_id: user2.id)
          expect(doc).to be_nil
          expect(doc2).not_to be_nil
          expect(doc2.content).to match({"foo" => "bar" })
          expect(page).to have_content %!{"valid":false,"message":"error.permissions"}!
        end

        scenario 'when a document is saved for the second or later time, original_content is not updated' do
          user = FactoryGirl.create(:user, username: 'test')
          signin(user.email, user.password)
          page.driver.browser.submit :post, '/document/save?recordname=newdoc', '{ "def": [1,2,3,4] }'
          doc = Document.find_by(title: "newdoc")
          page.driver.browser.submit :post, "/document/save?recordid=#{doc.id}", '{ "def": [1,2,3,4,5,6] }'
          doc.reload
          expect(doc).not_to be_nil
          expect(doc.content).to match({"def" => [1,2,3,4,5,6] })
          expect(doc.original_content).to match({"def" => [1,2,3,4] })
        end

        scenario 'a document can be associated with a parent document' do
          user = FactoryGirl.create(:user, username: 'test')
          doc = FactoryGirl.create(:document, title: "newdoc", shared: false, owner_id: user.id, form_content: '{ "foo": "bar" }')
          doc2 = FactoryGirl.create(:document, title: "newdoc-context", shared: false, owner_id: user.id, form_content: '{ "foo": "bar" }')
          signin(user.email, user.password)
          page.driver.browser.submit :post, "/document/save?recordid=#{doc2.id}&parentDocumentId=#{doc.id}", '{ "def": [1,2,3,4] }'
          doc.reload
          doc2.reload
          expect(doc.children.size).to eq(1)
          expect(doc.children.first).to eq(doc2)
          expect(doc2.parent).to eq(doc)
        end
      end

      describe 'by record name' do
        scenario 'user can save their own new document' do
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
        scenario 'save should return the document id' do
          user = FactoryGirl.create(:user, username: 'test')
          expect(Document.find_by(title: "newdoc")).to be_nil
          signin(user.email, user.password)
          page.driver.browser.submit :post, '/document/save?recordname=newdoc', '{ "def": [1,2,3,4] }'
          doc = Document.find_by(title: "newdoc")
          expect(page).to have_content %!{"status":"Created","valid":true,"id":#{doc.id}}!
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

        scenario 'user gets an overwrite error if a document by the same name exists' do
          user = FactoryGirl.create(:user, username: 'test')
          doc = FactoryGirl.create(:document, title: "newdoc", shared: false, owner_id: user.id, form_content: '{ "foo": "bar" }')
          signin(user.email, user.password)
          page.driver.browser.submit :post, '/document/save?recordname=newdoc', '{ "def": [1,2,3,4] }'
          doc.reload
          expect(doc).not_to be_nil
          expect(doc.content).to match({"foo" => "bar" })
          expect(page).to have_content %!{"valid":false,"message":"error.duplicate"}!
        end

        scenario 'when a document is saved for the first time, original_content is set' do
          user = FactoryGirl.create(:user, username: 'test')
          signin(user.email, user.password)
          page.driver.browser.submit :post, '/document/save?recordname=newdoc', '{ "def": [1,2,3,4] }'
          doc = Document.find_by(title: "newdoc")
          expect(doc).not_to be_nil
          expect(doc.original_content).to match({"def" => [1,2,3,4] })
        end

        scenario 'a document can be associated with a parent document' do
          user = FactoryGirl.create(:user, username: 'test')
          doc = FactoryGirl.create(:document, title: "newdoc", shared: false, owner_id: user.id, form_content: '{ "foo": "bar" }')
          signin(user.email, user.password)
          page.driver.browser.submit :post, "/document/save?recordname=newdoc-context&parentDocumentId=#{doc.id}", '{ "def": [1,2,3,4] }'
          doc.reload
          doc2 = Document.find_by(title: 'newdoc-context', owner_id: user.id)
          expect(doc.children.size).to eq(1)
          expect(doc.children.first).to eq(doc2)
          expect(doc2.parent).to eq(doc)
        end
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

        scenario 'a document can be associated with a parent document' do
          doc = FactoryGirl.create(:document, title: "newdoc", shared: false, owner_id: nil, form_content: '{ "foo": "bar" }')
          page.driver.browser.submit :post, "/document/save?recordname=newdoc-context&runKey=bar&parentDocumentId=#{doc.id}", '{ "def": [1,2,3,4] }'
          doc.reload
          doc2 = Document.find_by(title: 'newdoc-context', owner_id: nil)
          expect(doc.children.size).to eq(1)
          expect(doc.children.first).to eq(doc2)
          expect(doc2.parent).to eq(doc)
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
        expect(page).to have_selector "a.launch-button[href='http://foo.com/?documentServer=http%3A%2F%2Fwww.example.com%2F&recordid=#{doc.id}&runKey=foo']"
      end
      scenario 'user can launch a document via owner and doc' do
        user = FactoryGirl.create(:user, username: 'test2')
        doc  = FactoryGirl.create(:document, title: "something2", shared: true, owner_id: user.id, form_content: '{ "foo": "bar" }')
        visit '/document/launch?owner=test2&doc=something2&server=http://foo.com/'
        expect(page).to have_selector('.launch-button', count: 1)
        expect(page).to have_selector "a.launch-button[href='http://foo.com/?documentServer=http%3A%2F%2Fwww.example.com%2F&recordid=#{doc.id}&runKey=foo']"
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
        expect(page).to have_selector "a.launch-button[href='http://foo.com/?documentServer=http%3A%2F%2Fwww.example.com%2F&recordid=#{doc.id}&runKey=foo']"
      end
      scenario 'the document needs to exist to launch' do
        r = SecureRandom.hex
        visit "/document/launch?owner=test2&recordname=#{r}&server=http://foo.com/"
        expect(page).to have_selector('.launch-button', count: 0)
        expect(page).to have_content "Error: The requested document could not be found."
      end
      describe 'run key provided' do
        describe 'anonymous' do
          scenario 'can launch a document via owner and recordname' do
            user = FactoryGirl.create(:user, username: 'test2')
            doc  = FactoryGirl.create(:document, title: "something", shared: true, owner_id: user.id, form_content: '{ "foo": "bar", "appName": "name", "appVersion": "version", "appBuildNum": 1 }')
            visit '/document/launch?owner=test2&recordname=something&runKey=bar&server=http://foo.com/'
            expect(page).to have_selector('.launch-button', count: 1)
            expect(page).to have_selector "a.launch-button[href='http://foo.com/?documentServer=http%3A%2F%2Fwww.example.com%2F&recordid=#{doc.id}&runKey=bar']"
          end
          scenario 'also has a single document that matches the run key, a link to it is displayed too' do
            user = FactoryGirl.create(:user, username: 'test2')
            doc  = FactoryGirl.create(:document, title: "something", shared: true, owner_id: user.id, form_content: '{ "foo": "bar", "appName": "name", "appVersion": "version", "appBuildNum": 1 }')
            doc2  = FactoryGirl.create(:document, title: "something", shared: false, owner_id: nil, run_key: 'bar', form_content: '{ "foo": "bar", "appName": "name", "appVersion": "version", "appBuildNum": 1 }')
            visit '/document/launch?owner=test2&recordname=something&runKey=bar&server=http://foo.com/'
            expect(page).to have_selector('.launch-button', count: 1)
            expect(page).to have_selector "a.original-reset[href='http://foo.com/?documentServer=http%3A%2F%2Fwww.example.com%2F&recordid=#{doc.id}&runKey=bar']"
            expect(page).to have_selector  "a.launch-button[href='http://foo.com/?documentServer=http%3A%2F%2Fwww.example.com%2F&recordid=#{doc2.id}&runKey=bar']"
          end
          scenario 'also has multiple documents that match the run key, a link to each of them is displayed too' do
            user = FactoryGirl.create(:user, username: 'test2')
            doc  = FactoryGirl.create(:document, title: "something", shared: true, owner_id: user.id, form_content: '{ "foo": "bar" }')
            doc2  = FactoryGirl.create(:document, title: "something", shared: false, owner_id: nil, run_key: 'bar', form_content: '{ "foo": "bar", "appName": "name", "appVersion": "version", "appBuildNum": 1 }')
            doc3  = FactoryGirl.create(:document, title: "something3", shared: false, owner_id: nil, run_key: 'bar', form_content: '{ "foo": "bar", "appName": "name", "appVersion": "version", "appBuildNum": 1 }')
            doc4  = FactoryGirl.create(:document, title: "something4", shared: false, owner_id: nil, run_key: 'bar', form_content: '{ "foo": "bar", "appName": "name", "appVersion": "version", "appBuildNum": 1 }')
            doc5  = FactoryGirl.create(:document, title: "something5", shared: false, owner_id: nil, run_key: 'bar', form_content: '{ "foo": "bar", "appName": "name", "appVersion": "version", "appBuildNum": 1 }')
            visit '/document/launch?owner=test2&recordname=something&server=http://foo.com/&runKey=bar'
            expect(page).to have_selector('.launch-button', count: 1)
            expect(page).to have_selector "a.original-reset[href='http://foo.com/?documentServer=http%3A%2F%2Fwww.example.com%2F&recordid=#{doc.id}&runKey=bar']"
            expect(page).to have_selector "a.launch-button[href='http://foo.com/?documentServer=http%3A%2F%2Fwww.example.com%2F&recordid=#{doc5.id}&runKey=bar']"
          end
          scenario 'also has documents that do not match the run key, a link to each of them is not also displayed' do
            user = FactoryGirl.create(:user, username: 'test2')
            doc  = FactoryGirl.create(:document, title: "something", shared: true, owner_id: user.id, form_content: '{ "foo": "bar", "appName": "name", "appVersion": "version", "appBuildNum": 1 }')
            doc2  = FactoryGirl.create(:document, title: "something", shared: false, owner_id: nil, run_key: 'bar', form_content: '{ "foo": "bar", "appName": "name", "appVersion": "version", "appBuildNum": 1 }')
            doc3  = FactoryGirl.create(:document, title: "something3", shared: false, owner_id: nil, run_key: 'bar', form_content: '{ "foo": "bar", "appName": "name", "appVersion": "version", "appBuildNum": 1 }')
            doc4  = FactoryGirl.create(:document, title: "something4", shared: false, owner_id: nil, run_key: 'baz', form_content: '{ "foo": "bar", "appName": "name", "appVersion": "version", "appBuildNum": 1 }')
            doc5  = FactoryGirl.create(:document, title: "something5", shared: false, owner_id: nil, run_key: 'baz', form_content: '{ "foo": "bar", "appName": "name", "appVersion": "version", "appBuildNum": 1 }')
            visit '/document/launch?owner=test2&recordname=something&server=http://foo.com/&runKey=bar'
            expect(page).to have_selector('.launch-button', count: 1)
            expect(page).to have_selector "a.original-reset[href='http://foo.com/?documentServer=http%3A%2F%2Fwww.example.com%2F&recordid=#{doc.id}&runKey=bar']"
            expect(page).to have_selector "a.launch-button[href='http://foo.com/?documentServer=http%3A%2F%2Fwww.example.com%2F&recordid=#{doc3.id}&runKey=bar']"
          end
          scenario 'moreGames in url and no documents with run key, only a link to the moregames url is present' do
            visit '/document/launch?moreGames=%5B%7B%7D%5D&server=http://foo.com/&runKey=bar'
            expect(page).to have_selector('.launch-button', count: 1)
            expect(page).to have_selector "a.launch-button[href='http://foo.com/?documentServer=http%3A%2F%2Fwww.example.com%2F&moreGames=%5B%7B%7D%5D&runKey=bar']"
          end
          scenario 'moreGames in url and one document with run key, 2 links are present' do
            user4 = FactoryGirl.create(:user, username: 'test4')
            doc2  = FactoryGirl.create(:document, title: "something", shared: false, owner_id: nil, run_key: 'bar', form_content: '{ "foo": "bar", "appName": "name", "appVersion": "version", "appBuildNum": 1 }')
            visit '/document/launch?moreGames=%5B%7B%7D%5D&server=http://foo.com/&runKey=bar'
            expect(page).to have_selector('.launch-button', count: 1)
            expect(page).to have_selector "a.original-reset[href='http://foo.com/?documentServer=http%3A%2F%2Fwww.example.com%2F&moreGames=%5B%7B%7D%5D&runKey=bar']"
            expect(page).to have_selector "a.launch-button[href='http://foo.com/?documentServer=http%3A%2F%2Fwww.example.com%2F&recordid=#{doc2.id}&runKey=bar']"
          end
          scenario 'moreGames in url and multiple documents with run key, all links are present' do
            user4 = FactoryGirl.create(:user, username: 'test4')
            doc2  = FactoryGirl.create(:document, title: "something", shared: false, owner_id: nil, run_key: 'bar', form_content: '{ "foo": "bar", "appName": "name", "appVersion": "version", "appBuildNum": 1 }')
            doc3  = FactoryGirl.create(:document, title: "something3", shared: false, owner_id: nil, run_key: 'bar', form_content: '{ "foo": "bar", "appName": "name", "appVersion": "version", "appBuildNum": 1 }')
            doc4  = FactoryGirl.create(:document, title: "something4", shared: false, owner_id: nil, run_key: 'bar', form_content: '{ "foo": "bar", "appName": "name", "appVersion": "version", "appBuildNum": 1 }')
            doc5  = FactoryGirl.create(:document, title: "something5", shared: false, owner_id: nil, run_key: 'baz', form_content: '{ "foo": "bar", "appName": "name", "appVersion": "version", "appBuildNum": 1 }')
            visit '/document/launch?moreGames=%5B%7B%7D%5D&server=http://foo.com/&runKey=bar'
            expect(page).to have_selector('.launch-button', count: 1)
            expect(page).to have_selector "a.original-reset[href='http://foo.com/?documentServer=http%3A%2F%2Fwww.example.com%2F&moreGames=%5B%7B%7D%5D&runKey=bar']"
            expect(page).to have_selector "a.launch-button[href='http://foo.com/?documentServer=http%3A%2F%2Fwww.example.com%2F&recordid=#{doc4.id}&runKey=bar']"
          end
        end
        describe 'logged in user' do
          scenario 'can launch a document via owner and recordname' do
            user = FactoryGirl.create(:user, username: 'test2')
            doc  = FactoryGirl.create(:document, title: "something", shared: true, owner_id: user.id, form_content: '{ "foo": "bar", "appName": "name", "appVersion": "version", "appBuildNum": 1 }')
            user4 = FactoryGirl.create(:user, username: 'test4')
            signin(user4.email, user4.password)
            visit '/document/launch?owner=test2&recordname=something&server=http://foo.com/&runKey=bar'
            expect(page).to have_selector('.launch-button', count: 1)
            expect(page).to have_selector "a.launch-button[href='http://foo.com/?documentServer=http%3A%2F%2Fwww.example.com%2F&recordid=#{doc.id}&runKey=bar']"
          end
          scenario 'also has a single document that matches the run key, a link to it is displayed too' do
            user = FactoryGirl.create(:user, username: 'test2')
            doc  = FactoryGirl.create(:document, title: "something", shared: true, owner_id: user.id, form_content: '{ "foo": "bar", "appName": "name", "appVersion": "version", "appBuildNum": 1 }')
            user4 = FactoryGirl.create(:user, username: 'test4')
            doc2  = FactoryGirl.create(:document, title: "something", shared: false, owner_id: user4.id, run_key: 'bar', form_content: '{ "foo": "bar", "appName": "name", "appVersion": "version", "appBuildNum": 1 }')
            signin(user4.email, user4.password)
            visit '/document/launch?owner=test2&recordname=something&server=http://foo.com/&runKey=bar'
            expect(page).to have_selector('.launch-button', count: 1)
            expect(page).to have_selector "a.original-reset[href='http://foo.com/?documentServer=http%3A%2F%2Fwww.example.com%2F&recordid=#{doc.id}&runKey=bar']"
            expect(page).to have_selector "a.launch-button[href='http://foo.com/?documentServer=http%3A%2F%2Fwww.example.com%2F&recordid=#{doc2.id}&runKey=bar']"
          end
          scenario 'also has multiple documents that match the run key, a link to each of them is displayed too' do
            user = FactoryGirl.create(:user, username: 'test2')
            doc  = FactoryGirl.create(:document, title: "something", shared: true, owner_id: user.id, form_content: '{ "foo": "bar", "appName": "name", "appVersion": "version", "appBuildNum": 1 }')
            user4 = FactoryGirl.create(:user, username: 'test4')
            doc2  = FactoryGirl.create(:document, title: "something", shared: false, owner_id: user4.id, run_key: 'bar', form_content: '{ "foo": "bar", "appName": "name", "appVersion": "version", "appBuildNum": 1 }')
            doc3  = FactoryGirl.create(:document, title: "something3", shared: false, owner_id: user4.id, run_key: 'bar', form_content: '{ "foo": "bar", "appName": "name", "appVersion": "version", "appBuildNum": 1 }')
            doc4  = FactoryGirl.create(:document, title: "something4", shared: false, owner_id: user4.id, run_key: 'bar', form_content: '{ "foo": "bar", "appName": "name", "appVersion": "version", "appBuildNum": 1 }')
            doc5  = FactoryGirl.create(:document, title: "something5", shared: false, owner_id: user4.id, run_key: 'bar', form_content: '{ "foo": "bar", "appName": "name", "appVersion": "version", "appBuildNum": 1 }')
            signin(user4.email, user4.password)
            visit '/document/launch?owner=test2&recordname=something&server=http://foo.com/&runKey=bar'
            expect(page).to have_selector('.launch-button', count: 1)
            expect(page).to have_selector "a.original-reset[href='http://foo.com/?documentServer=http%3A%2F%2Fwww.example.com%2F&recordid=#{doc.id}&runKey=bar']"
            expect(page).to have_selector "a.launch-button[href='http://foo.com/?documentServer=http%3A%2F%2Fwww.example.com%2F&recordid=#{doc5.id}&runKey=bar']"
          end
          scenario 'also has documents that do not match the run key, a link to each of them is not also displayed' do
            user = FactoryGirl.create(:user, username: 'test2')
            doc  = FactoryGirl.create(:document, title: "something", shared: true, owner_id: user.id, form_content: '{ "foo": "bar", "appName": "name", "appVersion": "version", "appBuildNum": 1 }')
            user4 = FactoryGirl.create(:user, username: 'test4')
            doc2  = FactoryGirl.create(:document, title: "something", shared: false, owner_id: user4.id, run_key: 'bar', form_content: '{ "foo": "bar", "appName": "name", "appVersion": "version", "appBuildNum": 1 }')
            doc3  = FactoryGirl.create(:document, title: "something3", shared: false, owner_id: user4.id, run_key: 'bar', form_content: '{ "foo": "bar", "appName": "name", "appVersion": "version", "appBuildNum": 1 }')
            doc4  = FactoryGirl.create(:document, title: "something4", shared: false, owner_id: user4.id, run_key: 'baz', form_content: '{ "foo": "bar", "appName": "name", "appVersion": "version", "appBuildNum": 1 }')
            doc5  = FactoryGirl.create(:document, title: "something5", shared: false, owner_id: user4.id, run_key: 'baz', form_content: '{ "foo": "bar", "appName": "name", "appVersion": "version", "appBuildNum": 1 }')
            signin(user4.email, user4.password)
            visit '/document/launch?owner=test2&recordname=something&server=http://foo.com/&runKey=bar'
            expect(page).to have_selector('.launch-button', count: 1)
            expect(page).to have_selector "a.original-reset[href='http://foo.com/?documentServer=http%3A%2F%2Fwww.example.com%2F&recordid=#{doc.id}&runKey=bar']"
            expect(page).to have_selector "a.launch-button[href='http://foo.com/?documentServer=http%3A%2F%2Fwww.example.com%2F&recordid=#{doc3.id}&runKey=bar']"
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
            doc2  = FactoryGirl.create(:document, title: "something", shared: false, owner_id: user4.id, run_key: 'bar', form_content: '{ "foo": "bar", "appName": "name", "appVersion": "version", "appBuildNum": 1 }')
            signin(user4.email, user4.password)
            visit '/document/launch?moreGames=%5B%7B%7D%5D&server=http://foo.com/&runKey=bar'
            expect(page).to have_selector('.launch-button', count: 1)
            expect(page).to have_selector "a.original-reset[href='http://foo.com/?documentServer=http%3A%2F%2Fwww.example.com%2F&moreGames=%5B%7B%7D%5D&runKey=bar']"
            expect(page).to have_selector "a.launch-button[href='http://foo.com/?documentServer=http%3A%2F%2Fwww.example.com%2F&recordid=#{doc2.id}&runKey=bar']"
          end
          scenario 'moreGames in url and multiple documents with run key, all links are present' do
            user4 = FactoryGirl.create(:user, username: 'test4')
            doc2  = FactoryGirl.create(:document, title: "something", shared: false, owner_id: user4.id, run_key: 'bar', form_content: '{ "foo": "bar", "appName": "name", "appVersion": "version", "appBuildNum": 1 }')
            doc3  = FactoryGirl.create(:document, title: "something3", shared: false, owner_id: user4.id, run_key: 'bar', form_content: '{ "foo": "bar", "appName": "name", "appVersion": "version", "appBuildNum": 1 }')
            doc4  = FactoryGirl.create(:document, title: "something4", shared: false, owner_id: user4.id, run_key: 'bar', form_content: '{ "foo": "bar", "appName": "name", "appVersion": "version", "appBuildNum": 1 }')
            doc5  = FactoryGirl.create(:document, title: "something5", shared: false, owner_id: user4.id, run_key: 'baz', form_content: '{ "foo": "bar", "appName": "name", "appVersion": "version", "appBuildNum": 1 }')
            signin(user4.email, user4.password)
            visit '/document/launch?moreGames=%5B%7B%7D%5D&server=http://foo.com/&runKey=bar'
            expect(page).to have_selector('.launch-button', count: 1)
            expect(page).to have_selector "a.original-reset[href='http://foo.com/?documentServer=http%3A%2F%2Fwww.example.com%2F&moreGames=%5B%7B%7D%5D&runKey=bar']"
            expect(page).to have_selector "a.launch-button[href='http://foo.com/?documentServer=http%3A%2F%2Fwww.example.com%2F&recordid=#{doc4.id}&runKey=bar']"
          end
        end
      end
      describe 'auto authentication' do
        scenario 'the user will be authenticated if auth_provider is set and the user is not logged in' do
          user = FactoryGirl.create(:user, username: 'test2')
          doc  = FactoryGirl.create(:document, title: "something2", shared: true, owner_id: user.id, form_content: '{ "foo": "bar", "appName": "name", "appVersion": "version", "appBuildNum": 1 }')
          expect {
            visit '/document/launch?owner=test2&recordname=something2&server=http://foo.com/&auth_provider=http://bar.com'
          }.to raise_error(ActionController::RoutingError) # capybara doesn't handle the redirects well
          expect(page.current_url).to match 'http://bar.com/auth/concord_id/authorize'
        end
        scenario 'the user will not be authenticated if auth_provider is set and the user is logged in' do
          user = FactoryGirl.create(:user, username: 'test2')
          doc  = FactoryGirl.create(:document, title: "something2", shared: true, owner_id: user.id, form_content: '{ "foo": "bar", "appName": "name", "appVersion": "version", "appBuildNum": 1 }')
          user2 = FactoryGirl.create(:user, username: 'test4')
          signin(user2.email, user2.password)
          visit '/document/launch?owner=test2&recordname=something2&server=http://foo.com/&auth_provider=http://bar.com/'
          expect(page).to have_selector "a.launch-button[href='http://foo.com/?documentServer=http%3A%2F%2Fwww.example.com%2F&recordid=#{doc.id}&runKey=foo']"
        end
      end
      describe 'LARA integration' do
        scenario 'page has correct iframe phone code' do
          user = FactoryGirl.create(:user, username: 'test2')
          user2 = FactoryGirl.create(:user, username: 'test4')
          doc  = FactoryGirl.create(:document, title: "something", shared: true, owner_id: user.id, form_content: '{ "foo": "bar", "appName": "name", "appVersion": "version", "appBuildNum": 1 }')
          l_url = launch_url(doc: doc.title, owner: user.username, runKey: 'foo', server: 'http://foo.com/')
          r_url = report_url(doc: doc.title, owner: user.username, reportUser: user2.username, runKey: 'foo', server: 'http://foo.com/')
          signin(user2.email, user2.password)
          visit launch_path(doc: doc.title, owner: user.username, server: 'http://foo.com/')
          expect(page.html).to have_text("state = {runKey: runKey, lara_options: { reporting_url: reportingUrl }};")
          expect(page.html).to have_text(
            <<-JS
              var runKey = 'foo',
                reportingUrl = '#{r_url}',
                learnerUrl = '#{l_url}',
                areLoggedIn = true,
                currentEmail = '#{user2.email}',
                authFailed = false;
            JS
          )
          expect(page.html).to have_text(
            <<-JS
              phone.addListener('getExtendedSupport', function() {
                phone.post('extendedSupport', { reset: false });
              });
            JS
          )
          expect(page.html).to have_text(
            <<-JS
              phone.addListener('getInteractiveState', function () {
                phone.post('interactiveState', 'nochange');
              });
            JS
          )
          expect(page.html).to have_text("phone.addListener('authInfo', function(info) {")
          expect(page.html).to have_text("phone.addListener('getExtendedSupport', function() {")
        end
        scenario 'page has correct iframe phone code when the runKey is supplied' do
          user = FactoryGirl.create(:user, username: 'test2')
          user2 = FactoryGirl.create(:user, username: 'test4')
          doc  = FactoryGirl.create(:document, title: "something", shared: true, owner_id: user.id, form_content: '{ "foo": "bar" }')
          l_url = launch_url(doc: doc.title, owner: user.username, runKey: 'bar', server: 'http://foo.com/')
          r_url = report_url(doc: doc.title, owner: user.username, reportUser: user2.username, runKey: 'bar', server: 'http://foo.com/')

          signin(user2.email, user2.password)
          visit launch_path(doc: doc.title, owner: user.username, runKey: 'bar', server: 'http://foo.com/')
          expect(page.html).to have_text(
            <<-JS
              var runKey = 'bar',
                reportingUrl = '#{r_url}',
                learnerUrl = '#{l_url}',
                areLoggedIn = true,
                currentEmail = '#{user2.email}',
                authFailed = false;
            JS
          )
        end
        scenario 'page has correct iframe phone code when anonymous' do
          user = FactoryGirl.create(:user, username: 'test2')
          doc  = FactoryGirl.create(:document, title: "something", shared: true, owner_id: user.id, form_content: '{ "foo": "bar" }')
          l_url = launch_url(doc: doc.title, owner: user.username, runKey: 'foo', server: 'http://foo.com/')
          r_url = report_url(doc: doc.title, owner: user.username, runKey: 'foo', server: 'http://foo.com/')
          visit launch_path(doc: doc.title, owner: user.username, server: 'http://foo.com/')
          expect(page.html).to have_text(
            <<-JS
              var runKey = 'foo',
                reportingUrl = '#{r_url}',
                learnerUrl = '#{l_url}',
                areLoggedIn = false,
                currentEmail = null,
                authFailed = false;
            JS
          )
        end
        scenario 'page has correct iframe phone code when the runKey is supplied when anonymous' do
          user = FactoryGirl.create(:user, username: 'test2')
          doc  = FactoryGirl.create(:document, title: "something", shared: true, owner_id: user.id, form_content: '{ "foo": "bar" }')
          l_url = launch_url(doc: doc.title, owner: user.username, runKey: 'bar', server: 'http://foo.com/')
          r_url = report_url(doc: doc.title, owner: user.username, runKey: 'bar', server: 'http://foo.com/')

          visit launch_path(doc: doc.title, owner: user.username, runKey: 'bar', server: 'http://foo.com/')
          expect(page.html).to have_text(
            <<-JS
              var runKey = 'bar',
                reportingUrl = '#{r_url}',
                learnerUrl = '#{l_url}',
                areLoggedIn = false,
                currentEmail = null,
                authFailed = false;
            JS
          )
        end
      end
    end

    describe 'report' do
      let(:author)   { FactoryGirl.create(:user, username: 'author') }
      let(:student)  { FactoryGirl.create(:user, username: 'student') }
      let(:teacher)  { FactoryGirl.create(:user, username: 'teacher') }
      let(:template) { FactoryGirl.create(:document, title: "template", shared: true, owner_id: author.id, form_content: '{ "foo": "bar", "appName": "name", "appVersion": "version", "appBuildNum": 1 }') }
      let(:student_doc1a) { FactoryGirl.create(:document, title: "student1a", shared: false, owner_id: student.id, form_content: '{ "foo": "baz1a", "appName": "name", "appVersion": "version", "appBuildNum": 1 }', run_key: 'foo') }
      let(:student_doc1b) { FactoryGirl.create(:document, title: "student1b", shared: false, owner_id: student.id, form_content: '{ "foo": "baz1b", "appName": "name", "appVersion": "version", "appBuildNum": 1 }', run_key: 'foo') }
      let(:student_doc1c) { FactoryGirl.create(:document, title: "student1c", shared: false, owner_id: student.id, form_content: '{ "foo": "baz1c", "appName": "name", "appVersion": "version", "appBuildNum": 1 }', run_key: 'foo') }
      let(:student_doc2a) { FactoryGirl.create(:document, title: "student2a", shared: false, owner_id: student.id, form_content: '{ "foo": "baz2a", "appName": "name", "appVersion": "version", "appBuildNum": 1 }', run_key: 'bar') }
      let(:student_doc2b) { FactoryGirl.create(:document, title: "student2b", shared: false, owner_id: student.id, form_content: '{ "foo": "baz2b", "appName": "name", "appVersion": "version", "appBuildNum": 1 }', run_key: 'bar') }
      let(:student_doc2c) { FactoryGirl.create(:document, title: "student2c", shared: false, owner_id: student.id, form_content: '{ "foo": "baz2c", "appName": "name", "appVersion": "version", "appBuildNum": 1 }', run_key: 'bar') }
      let(:anon_doc1a) { FactoryGirl.create(:document, title: "anon1a", shared: false, owner_id: nil, form_content: '{ "foo": "baz1a", "appName": "name", "appVersion": "version", "appBuildNum": 1 }', run_key: 'foo') }
      let(:anon_doc1b) { FactoryGirl.create(:document, title: "anon1b", shared: false, owner_id: nil, form_content: '{ "foo": "baz1b", "appName": "name", "appVersion": "version", "appBuildNum": 1 }', run_key: 'foo') }
      let(:anon_doc1c) { FactoryGirl.create(:document, title: "anon1c", shared: false, owner_id: nil, form_content: '{ "foo": "baz1c", "appName": "name", "appVersion": "version", "appBuildNum": 1 }', run_key: 'foo') }
      let(:anon_doc2a) { FactoryGirl.create(:document, title: "anon2a", shared: false, owner_id: nil, form_content: '{ "foo": "baz2a", "appName": "name", "appVersion": "version", "appBuildNum": 1 }', run_key: 'bar') }
      let(:anon_doc2b) { FactoryGirl.create(:document, title: "anon2b", shared: false, owner_id: nil, form_content: '{ "foo": "baz2b", "appName": "name", "appVersion": "version", "appBuildNum": 1 }', run_key: 'bar') }
      let(:anon_doc2c) { FactoryGirl.create(:document, title: "anon2c", shared: false, owner_id: nil, form_content: '{ "foo": "baz2c", "appName": "name", "appVersion": "version", "appBuildNum": 1 }', run_key: 'bar') }
      let(:server)   { 'http://foo.com/' }

      scenario 'user needs to be logged in to view non-anonymous work' do
        url = doc_url(server, {recordid: student_doc1a.id, documentServer: 'http://www.example.com/', runKey: 'foo'})
        visit report_path(owner: author.username, recordname: template.title, server: server, reportUser: student.username, runKey: 'foo')
        expect(page).to have_content 'No documents have been saved!'
        signin(teacher.email, teacher.password)
        visit report_path(owner: author.username, recordname: template.title, server: server, reportUser: student.username, runKey: 'foo')
        expect(page).to have_selector('.launch-button', count: 1)
        expect(page).to have_selector "a.launch-button[href='#{url}']"
      end
      scenario 'user does not need to be logged in to view anonymous work' do
        url1 = doc_url(server, {recordid: anon_doc1a.id, documentServer: 'http://www.example.com/', runKey: 'foo', runAsGuest: 'true'})
        url2 = doc_url(server, {recordid: anon_doc1a.id, documentServer: 'http://www.example.com/', runKey: 'foo'})
        visit report_path(owner: author.username, recordname: template.title, server: server, runKey: 'foo')
        expect(page).to have_selector('.launch-button', count: 1)
        expect(page).to have_selector "a.launch-button[href='#{url1}']"
        signin(teacher.email, teacher.password)
        visit report_path(owner: author.username, recordname: template.title, server: server, runKey: 'foo')
        expect(page).to have_selector('.launch-button', count: 1)
        expect(page).to have_selector "a.launch-button[href='#{url2}']"
      end
      scenario 'the template document needs to exist' do
        signin(teacher.email, teacher.password)
        visit report_path(owner: author.username, recordname: template.title + "2", server: server, reportUser: student.username, runKey: 'foo')
        expect(page).to have_content "Error: The requested document could not be found."
        visit report_path(owner: author.username, recordname: template.title, server: server, reportUser: student.username, runKey: 'foo')
        expect(page).to have_content 'No documents have been saved!'
      end
      scenario 'runKey needs to be provided' do
        signin(teacher.email, teacher.password)
        expect {
          visit report_path(owner: author.username, recordname: template.title, server: server, reportUser: student.username)
        }.to raise_error(ActiveRecord::RecordNotFound)
        visit report_path(owner: author.username, recordname: template.title, server: server, reportUser: student.username, runKey: 'foo')
        expect(page).to have_content 'No documents have been saved!'
      end
      scenario 'server needs to be provided' do
        signin(teacher.email, teacher.password)
        expect {
          visit report_path(owner: author.username, recordname: template.title, reportUser: student.username, runKey: 'foo')
        }.to raise_error(ActiveRecord::RecordNotFound)
        visit report_path(owner: author.username, recordname: template.title, server: server, reportUser: student.username, runKey: 'foo')
        expect(page).to have_content 'No documents have been saved!'
      end
      scenario 'user can report a document via owner and recordname' do
        signin(teacher.email, teacher.password)
        url = doc_url(server, {recordid: student_doc1a.id, documentServer: 'http://www.example.com/', runKey: 'foo'})
        visit report_path(owner: author.username, recordname: template.title, server: server, reportUser: student.username, runKey: 'foo')
        expect(page).to have_selector('.launch-button', count: 1)
        expect(page).to have_selector "a.launch-button[href='#{url}']"
      end
      scenario 'user can report a document via owner and doc' do
        signin(teacher.email, teacher.password)
        url = doc_url(server, {recordid: student_doc1a.id, documentServer: 'http://www.example.com/', runKey: 'foo'})
        visit report_path(owner: author.username, doc: template.title, server: server, reportUser: student.username, runKey: 'foo')
        expect(page).to have_selector('.launch-button', count: 1)
        expect(page).to have_selector "a.launch-button[href='#{url}']"
      end
      scenario 'user can report a document via recordid' do
        signin(teacher.email, teacher.password)
        url = doc_url(server, {recordid: student_doc1a.id, documentServer: 'http://www.example.com/', runKey: 'foo'})
        visit report_path(owner: author.username, recordid: template.id, server: server, reportUser: student.username, runKey: 'foo')
        expect(page).to have_selector('.launch-button', count: 1)
        expect(page).to have_selector "a.launch-button[href='#{url}']"
      end
      scenario 'user can report a document via moreGames' do
        signin(teacher.email, teacher.password)
        visit report_path(server: server, moreGames: '[{}]', runKey: 'foo', reportUser: student.username)
        expect(page).to have_content 'No documents have been saved!'
      end
      scenario 'reportUser also has multiple documents that match the run key, a link to each of them is displayed too' do
        signin(teacher.email, teacher.password)
        url1 = doc_url(server, {recordid: student_doc1a.id, documentServer: 'http://www.example.com/', runKey: 'foo'})
        url2 = doc_url(server, {recordid: student_doc1b.id, documentServer: 'http://www.example.com/', runKey: 'foo'})
        visit report_path(owner: author.username, recordname: template.title, server: server, reportUser: student.username, runKey: 'foo')
        expect(page).to have_selector('.launch-button', count: 2)
        expect(page).to have_selector "a.launch-button[href='#{url1}']"
        expect(page).to have_selector "a.launch-button[href='#{url2}']"
      end
      scenario 'reportUser also has documents that do not match the run key, a link to each of them is not also displayed' do
        signin(teacher.email, teacher.password)
        url1 = doc_url(server, {recordid: student_doc1a.id, documentServer: 'http://www.example.com/', runKey: 'foo'})
        url2 = doc_url(server, {recordid: student_doc1b.id, documentServer: 'http://www.example.com/', runKey: 'foo'})
        url3 = doc_url(server, {recordid: student_doc1c.id, documentServer: 'http://www.example.com/', runKey: 'foo'})
        url4 = doc_url(server, {recordid: student_doc2a.id, documentServer: 'http://www.example.com/', runKey: 'foo'})
        url5 = doc_url(server, {recordid: student_doc2b.id, documentServer: 'http://www.example.com/', runKey: 'foo'})
        visit report_path(owner: author.username, recordname: template.title, server: server, reportUser: student.username, runKey: 'foo')
        expect(page).to have_selector('.launch-button', count: 3)
        expect(page).to have_selector "a.launch-button[href='#{url1}']"
        expect(page).to have_selector "a.launch-button[href='#{url2}']"
        expect(page).to have_selector "a.launch-button[href='#{url3}']"
      end
      scenario 'moreGames in url and one document with run key, 1 link is present' do
        signin(teacher.email, teacher.password)
        url = doc_url(server, {recordid: student_doc1a.id, documentServer: 'http://www.example.com/', runKey: 'foo'})
        visit report_path(server: server, moreGames: '[{}]', runKey: 'foo', reportUser: student.username)
        expect(page).to have_selector('.launch-button', count: 1)
        expect(page).to have_selector "a.launch-button[href='#{url}']"
      end
      scenario 'moreGames in url and multiple documents with run key, all links are present' do
        signin(teacher.email, teacher.password)
        url1 = doc_url(server, {recordid: student_doc1a.id, documentServer: 'http://www.example.com/', runKey: 'foo'})
        url2 = doc_url(server, {recordid: student_doc1c.id, documentServer: 'http://www.example.com/', runKey: 'foo'})
        visit report_path(server: server, moreGames: '[{}]', runKey: 'foo', reportUser: student.username)
        expect(page).to have_selector('.launch-button', count: 2)
        expect(page).to have_selector "a.launch-button[href='#{url1}']"
        expect(page).to have_selector "a.launch-button[href='#{url2}']"
      end
      describe 'anonymous' do
        scenario 'user can report a document via owner and recordname' do
          signin(teacher.email, teacher.password)
          url = doc_url(server, {recordid: anon_doc1a.id, documentServer: 'http://www.example.com/', runKey: 'foo'})
          visit report_path(owner: author.username, recordname: template.title, server: server, runKey: 'foo')
          expect(page).to have_selector('.launch-button', count: 1)
          expect(page).to have_selector "a.launch-button[href='#{url}']"
        end
        scenario 'user can report a document via owner and doc' do
          signin(teacher.email, teacher.password)
          url = doc_url(server, {recordid: anon_doc1a.id, documentServer: 'http://www.example.com/', runKey: 'foo'})
          visit report_path(owner: author.username, doc: template.title, server: server, runKey: 'foo')
          expect(page).to have_selector('.launch-button', count: 1)
          expect(page).to have_selector "a.launch-button[href='#{url}']"
        end
        scenario 'user can report a document via recordid' do
          signin(teacher.email, teacher.password)
          url = doc_url(server, {recordid: anon_doc1a.id, documentServer: 'http://www.example.com/', runKey: 'foo'})
          visit report_path(owner: author.username, recordid: template.id, server: server, runKey: 'foo')
          expect(page).to have_selector('.launch-button', count: 1)
          expect(page).to have_selector "a.launch-button[href='#{url}']"
        end
        scenario 'user can report a document via moreGames' do
          signin(teacher.email, teacher.password)
          visit report_path(server: server, moreGames: '[{}]', runKey: 'foo')
          expect(page).to have_content 'No documents have been saved!'
        end
        scenario 'reportUser also has multiple documents that match the run key, a link to each of them is displayed too' do
          signin(teacher.email, teacher.password)
          url1 = doc_url(server, {recordid: anon_doc1a.id, documentServer: 'http://www.example.com/', runKey: 'foo'})
          url2 = doc_url(server, {recordid: anon_doc1b.id, documentServer: 'http://www.example.com/', runKey: 'foo'})
          visit report_path(owner: author.username, recordname: template.title, server: server, runKey: 'foo')
          expect(page).to have_selector('.launch-button', count: 2)
          expect(page).to have_selector "a.launch-button[href='#{url1}']"
          expect(page).to have_selector "a.launch-button[href='#{url2}']"
        end
        scenario 'reportUser also has documents that do not match the run key, a link to each of them is not also displayed' do
          signin(teacher.email, teacher.password)
          url1 = doc_url(server, {recordid: anon_doc1a.id, documentServer: 'http://www.example.com/', runKey: 'foo'})
          url2 = doc_url(server, {recordid: anon_doc1b.id, documentServer: 'http://www.example.com/', runKey: 'foo'})
          url3 = doc_url(server, {recordid: anon_doc1c.id, documentServer: 'http://www.example.com/', runKey: 'foo'})
          url4 = doc_url(server, {recordid: anon_doc2a.id, documentServer: 'http://www.example.com/', runKey: 'foo'})
          url5 = doc_url(server, {recordid: anon_doc2b.id, documentServer: 'http://www.example.com/', runKey: 'foo'})
          visit report_path(owner: author.username, recordname: template.title, server: server, runKey: 'foo')
          expect(page).to have_selector('.launch-button', count: 3)
          expect(page).to have_selector "a.launch-button[href='#{url1}']"
          expect(page).to have_selector "a.launch-button[href='#{url2}']"
          expect(page).to have_selector "a.launch-button[href='#{url3}']"
        end
        scenario 'moreGames in url and one document with run key, 1 link is present' do
          signin(teacher.email, teacher.password)
          url = doc_url(server, {recordid: anon_doc1a.id, documentServer: 'http://www.example.com/', runKey: 'foo'})
          visit report_path(server: server, moreGames: '[{}]', runKey: 'foo')
          expect(page).to have_selector('.launch-button', count: 1)
          expect(page).to have_selector "a.launch-button[href='#{url}']"
        end
        scenario 'moreGames in url and multiple documents with run key, all links are present' do
          signin(teacher.email, teacher.password)
          url1 = doc_url(server, {recordid: anon_doc1a.id, documentServer: 'http://www.example.com/', runKey: 'foo'})
          url2 = doc_url(server, {recordid: anon_doc1c.id, documentServer: 'http://www.example.com/', runKey: 'foo'})
          visit report_path(server: server, moreGames: '[{}]', runKey: 'foo')
          expect(page).to have_selector('.launch-button', count: 2)
          expect(page).to have_selector "a.launch-button[href='#{url1}']"
          expect(page).to have_selector "a.launch-button[href='#{url2}']"
        end
      end
      describe 'auto authentication' do
        scenario 'the user will not be authenticated if auth_provider is set and the user is not logged in' do
          visit report_path(auth_provider: 'http://bar.com', owner: author.username, recordname: template.title, server: server, reportUser: student.username, runKey: 'foo')
          expect(page).to have_content 'No documents have been saved!'
        end
        scenario 'the user will be authenticated if referrer is set and the user is not logged in' do
          Capybara.current_session.driver.header 'Referer', 'http://bar.com/portal/offerings/1/report'
          expect {
            visit report_path(owner: author.username, recordname: template.title, server: server, reportUser: student.username, runKey: 'foo')
          }.to raise_error(ActionController::RoutingError) # capybara doesn't handle the redirects well
          expect(page.current_url).to match 'http://bar.com/auth/concord_id/authorize'
        end
        scenario 'the user will not be authenticated if auth_provider is set and the user is logged in' do
          signin(teacher.email, teacher.password)
          url = doc_url(server, {recordid: student_doc1a.id, documentServer: 'http://www.example.com/', runKey: 'foo'})
          visit report_path(auth_provider: 'http://bar.com', owner: author.username, recordname: template.title, server: server, reportUser: student.username, runKey: 'foo')
          expect(page).to have_selector('.launch-button', count: 1)
          expect(page).to have_selector "a.launch-button[href='#{url}']"
        end
      end
    end

    describe 'rename' do
      scenario 'user can rename their own document' do
        user = FactoryGirl.create(:user, username: 'test')
        doc  = FactoryGirl.create(:document, title: "something-unique", owner_id: user.id, form_content: '{ "foo": "bar" }')
        signin(user.email, user.password)
        visit '/document/rename?owner=test&doc=something-unique&newRecordname=somethingelse'
        expect(page).to have_content('{"success":true}')
        doc2 = Document.find_by(title: "something-unique", owner: user)
        expect(doc2).to be_nil
        doc3 = Document.find_by(title: "somethingelse", owner: user)
        expect(doc3).not_to be_nil
      end

      scenario 'user can not rename a document owned by someone else' do
        user = FactoryGirl.create(:user, username: 'test')
        user2 = FactoryGirl.create(:user, username: 'test2')
        doc2 = FactoryGirl.create(:document, title: "newdoc", shared: false, owner_id: user2.id, form_content: '{ "foo": "bar" }')
        signin(user.email, user.password)
        visit '/document/rename?owner=test2&doc=newdoc&owner=test2&newRecordname=somethingelse'
        expect(page).to have_content %!{"valid":false,"message":"error.permissions"}!
        doc = Document.find_by(title: "newdoc", owner: user2)
        expect(doc).not_to be_nil
      end

      scenario 'user renames the document with a matching run key' do
        user = FactoryGirl.create(:user, username: 'test')
        doc  = FactoryGirl.create(:document, title: "something", owner_id: user.id, form_content: '{ "foo": "bar" }')
        doc2 = FactoryGirl.create(:document, title: "something", owner_id: user.id, form_content: '{ "foo": "bar" }', run_key: 'foo')
        doc3 = FactoryGirl.create(:document, title: "something", owner_id: user.id, form_content: '{ "foo": "bar" }', run_key: 'bar')
        signin(user.email, user.password)
        visit '/document/rename?owner=test&doc=something&runKey=foo&newRecordname=somethingelse'
        expect(page).to have_content('{"success":true}')
        docs = Document.where(owner: user, title: 'something').order(:run_key)
        expect(docs.size).to eq 2
        expect(docs[0].run_key).to eq 'bar'
        expect(docs[1].run_key).to be_nil
        visit '/document/rename?owner=test&doc=something&newRecordname=somethingelse'
        expect(page).to have_content('{"success":true}')
        docs = Document.where(owner: user, title: 'something')
        expect(docs.size).to eq 1
        expect(docs[0].run_key).to eq 'bar'
      end

      scenario 'user gets an error when a matching document does not exist' do
        user = FactoryGirl.create(:user, username: 'test')
        doc  = FactoryGirl.create(:document, title: "something", owner_id: user.id, form_content: '{ "foo": "bar" }')
        signin(user.email, user.password)
        visit '/document/rename?owner=test&doc=something2&newRecordname=somethingelse'
        expect(page).to have_content %!{"valid":false,"message":"error.notFound"}!
      end

      scenario 'user gets an error when the new document name already exists' do
        user = FactoryGirl.create(:user, username: 'test')
        doc  = FactoryGirl.create(:document, title: "something-unique", owner_id: user.id, form_content: '{ "foo": "bar" }')
        doc2 = FactoryGirl.create(:document, title: "somethingelse", owner_id: user.id, form_content: '{ "foo": "baz" }')
        signin(user.email, user.password)
        visit '/document/rename?owner=test&doc=something-unique&newRecordname=somethingelse'
        expect(page).to have_content('{"valid":false,"message":"error.duplicate"}')
        doc2 = Document.find_by(title: "something-unique", owner: user)
        expect(doc2).not_to be_nil
        doc3 = Document.find_by(title: "somethingelse", owner: user)
        expect(doc3).not_to be_nil
        expect(doc3.content).to match({"foo" => "baz" })
      end

      scenario 'renamed document has same attributes as the original document' do
        user = FactoryGirl.create(:user, username: 'test')
        signin(user.email, user.password)
        page.driver.browser.submit :post, '/document/save?recordname=something-unique', '{ "def": [1,2,3,4] }'
        page.driver.browser.submit :post, '/document/save?recordname=something-unique', '{ "def": [1,2,3,4,5,6] }'
        doc  = Document.find_by(title: "something-unique", owner: user)
        doc_data = {id: doc.id, content: doc.content, original_content: doc.original_content }
        visit '/document/rename?owner=test&doc=something-unique&newRecordname=somethingelse'
        expect(page).to have_content('{"success":true}')
        doc2 = Document.find_by(title: "something-unique", owner: user)
        expect(doc2).to be_nil
        doc3 = Document.find_by(title: "somethingelse", owner: user)
        expect(doc3).not_to be_nil
        expect(doc3.id).to eq(doc_data[:id])
        expect(doc3.content).to match(doc_data[:content])
        expect(doc3.original_content).to match(doc_data[:original_content])
      end

      describe 'anonymous' do
        scenario 'user cannot rename documents when no run_key is present' do
          doc  = FactoryGirl.create(:document, title: "something", owner_id: nil, form_content: '{ "foo": "bar" }')
          visit '/document/rename?doc=something'
          expect(page).to have_content %!{"valid":false,"message":"error.permissions"}!
          doc2 = Document.find_by(title: "something", owner_id: nil)
          expect(doc2).not_to be_nil
        end

        scenario 'user can rename documents when a run_key is present' do
          doc  = FactoryGirl.create(:document, title: "something", owner_id: nil, form_content: '{ "foo": "bar" }', run_key: 'foo')
          visit '/document/rename?doc=something&runKey=foo&newRecordname=somethingelse'
          expect(page).to have_content('{"success":true}')
          doc2 = Document.find_by(title: "something", owner_id: nil)
          expect(doc2).to be_nil
          doc2 = Document.find_by(title: "somethingelse", owner_id: nil)
          expect(doc2).not_to be_nil
        end

        scenario 'user renames the document with a matching run key' do
          doc  = FactoryGirl.create(:document, title: "something", owner_id: nil, form_content: '{ "foo": "bar" }', run_key: 'baz')
          doc2 = FactoryGirl.create(:document, title: "something", owner_id: nil, form_content: '{ "foo": "bar" }', run_key: 'foo')
          doc3 = FactoryGirl.create(:document, title: "something", owner_id: nil, form_content: '{ "foo": "bar" }', run_key: 'bar')
          visit '/document/rename?doc=something&runKey=foo&newRecordname=somethingelse'
          expect(page).to have_content('{"success":true}')
          docs = Document.where(owner_id: nil, title: 'something').order(:run_key)
          expect(docs.size).to eq 2
          expect(docs[0].run_key).to eq 'bar'
          expect(docs[1].run_key).to eq 'baz'
          visit '/document/rename?doc=something&runKey=baz&newRecordname=somethingelse'
          expect(page).to have_content('{"success":true}')
          docs = Document.where(owner_id: nil, title: 'something')
          expect(docs.size).to eq 1
          expect(docs[0].run_key).to eq 'bar'
        end

        scenario 'user gets an error when a matching document does not exist' do
          user = FactoryGirl.create(:user, username: 'test')
          doc  = FactoryGirl.create(:document, title: "something", owner_id: user.id, form_content: '{ "foo": "bar" }', run_key: 'bar')
          signin(user.email, user.password)
          visit '/document/rename?doc=something2&newRecordname=somethingelse'
          expect(page).to have_content %!{"valid":false,"message":"error.notFound"}!
          visit '/document/rename?doc=something&runKey=foo&newRecordname=somethingelse'
          expect(page).to have_content %!{"valid":false,"message":"error.notFound"}!
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


feature 'Document', :codap do
  describe 'CODAP API' do
    describe 'all' do
      scenario 'user can list documents' do
        user = FactoryGirl.create(:user, username: 'test')
        doc1 = FactoryGirl.create(:document, owner_id: user.id)
        visit 'document/all?username=test'
        expect(page).to have_content %![{"name":"MyText","id":#{doc1.id},"_permissions":0}]!
      end

      scenario 'user can only list documents their own documents' do
        user = FactoryGirl.create(:user, username: 'test')
        user2 = FactoryGirl.create(:user, username: 'test2', email: 'test2@email.com')
        doc1 = FactoryGirl.create(:document, owner_id: user.id)
        doc2 = FactoryGirl.create(:document, owner_id: user2.id)
        visit 'document/all?username=test2'
        expect(page).to have_content %![{"name":"MyText","id":#{doc2.id},"_permissions":0}]!
      end
    end

    describe 'open' do
      scenario 'user can open their own document' do
        user = FactoryGirl.create(:user, username: 'test')
        doc1 = FactoryGirl.create(:document, title: 'testDoc', owner_id: user.id, content: '[1, 2, 3]')
        visit "document/open?username=test&recordid=#{doc1.id}"
        expect(page).to have_content %![1,2,3]!
      end

      scenario 'user can open a document shared by another person' do
        user = FactoryGirl.create(:user, username: 'test')
        user2 = FactoryGirl.create(:user, username: 'test2', email: 'test2@email.com')
        doc1 = FactoryGirl.create(:document, owner_id: user.id)
        doc2 = FactoryGirl.create(:document, title: "test2 doc", shared: true, owner_id: user2.id, form_content: '{ "foo": "bar" }')
        visit 'document/open?owner=test2&recordname=test2%20doc'
        expect(page).to have_content %!{"foo":"bar"}!
      end

      scenario 'user cannot open a document that is not shared by another person' do
        user = FactoryGirl.create(:user, username: 'test')
        user2 = FactoryGirl.create(:user, username: 'test2', email: 'test2@email.com')
        doc1 = FactoryGirl.create(:document, owner_id: user.id)
        doc2 = FactoryGirl.create(:document, title: "test2 doc", shared: false, owner_id: user2.id, form_content: '{ "foo": "bar" }')
        expect {
          visit 'document/open?owner=test2&recordname=test2%20doc'
        }.to raise_error(ActiveRecord::RecordNotFound)
      end

      describe 'errors' do
        scenario 'user gets 404 when they open a document by id and do not own it' do
          user = FactoryGirl.create(:user, username: 'test')
          user2 = FactoryGirl.create(:user, username: 'test2', email: 'test2@email.com')
          doc1 = FactoryGirl.create(:document, title: 'testDoc', owner_id: user.id, content: '[1, 2, 3]')
          doc2 = FactoryGirl.create(:document, title: "test2 doc", owner_id: user2.id, form_content: '{ "foo": "bar" }')
          expect {
            visit "document/open?username=test&recordid=#{doc2.id}"
          }.to raise_error(ActiveRecord::RecordNotFound)
        end

        scenario 'user gets 404 when they open a document by id and it does not exist' do
          user = FactoryGirl.create(:user, username: 'test')
          expect {
            visit "document/open?username=test&recordid=99999"
          }.to raise_error(ActiveRecord::RecordNotFound)
        end

        scenario 'user gets 404 when they open a document by another person that does not exist' do
          user = FactoryGirl.create(:user, username: 'test')
          user2 = FactoryGirl.create(:user, username: 'test2', email: 'test2@email.com')
          doc1 = FactoryGirl.create(:document, owner_id: user.id)
          doc2 = FactoryGirl.create(:document, title: "test2 doc", shared: false, owner_id: user2.id, form_content: '{ "foo": "bar" }')
          expect {
            visit 'document/open?owner=test2&recordname=something'
          }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end
    end

    describe 'save' do
      scenario 'user can save their own document' do
        user = FactoryGirl.create(:user, username: 'test')
        expect(Document.find_by(title: "newdoc")).to be_nil
        page.driver.post 'document/save?username=test&recordname=newdoc', '{ "def": [1,2,3,4] }'
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
        page.driver.post 'document/save?username=test&recordname=newdoc', '{ "def": [1,2,3,4] }'
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
        page.driver.post 'document/save?username=test&recordname=newdoc', '{ "def": [1,2,3,4] }'
        doc.reload
        expect(doc).not_to be_nil
        expect(doc.content).to match({"def" => [1,2,3,4] })
      end
    end
  end
end

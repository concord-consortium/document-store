feature 'Document', :codap do
  describe 'report' do
    let(:author)   { FactoryGirl.create(:user, username: 'author') }
    let(:student)  { FactoryGirl.create(:user, username: 'student') }
    let(:dup_student1)  {
      # need to skip validations to create duplicate user
      user = FactoryGirl.build(:user, username: 'dup-student', email: 'dup.student1@example.com')
      user.save(validate: false)
      user }
    let(:dup_student2)  {
      # need to skip validations to create duplicate user
      user = FactoryGirl.build(:user, username: 'dup-student', email: 'dup.student2@example.com')
      user.save(validate: false)
      user }
    let(:template) { FactoryGirl.create(:document,
      title: "template", shared: true, owner_id: author.id,
      form_content: '{ "foo": "bar", "appName": "name", "appVersion": "version", "appBuildNum": 1 }') }
    let(:student_doc1a) { FactoryGirl.create(:document,
      title: "student1a", shared: false, owner_id: student.id,
      form_content: '{ "foo": "baz1a", "appName": "name", "appVersion": "version", "appBuildNum": 1 }',
      run_key: 'foo') }
    let(:student_doc1b) { FactoryGirl.create(:document,
      title: "student1b", shared: false, owner_id: student.id,
      form_content: '{ "foo": "baz1b", "appName": "name", "appVersion": "version", "appBuildNum": 1 }',
      run_key: 'foo') }
    let(:student_doc1c) { FactoryGirl.create(:document,
      title: "student1c", shared: false, owner_id: student.id,
      form_content: '{ "foo": "baz1c", "appName": "name", "appVersion": "version", "appBuildNum": 1 }',
      run_key: 'foo') }
    let(:student_doc2a) { FactoryGirl.create(:document,
      title: "student2a", shared: false, owner_id: student.id,
      form_content: '{ "foo": "baz2a", "appName": "name", "appVersion": "version", "appBuildNum": 1 }',
      run_key: 'bar') }
    let(:student_doc2b) { FactoryGirl.create(:document,
      title: "student2b", shared: false, owner_id: student.id,
      form_content: '{ "foo": "baz2b", "appName": "name", "appVersion": "version", "appBuildNum": 1 }',
      run_key: 'bar') }
    let(:student_doc2c) { FactoryGirl.create(:document,
      title: "student2c", shared: false, owner_id: student.id,
      form_content: '{ "foo": "baz2c", "appName": "name", "appVersion": "version", "appBuildNum": 1 }',
      run_key: 'bar') }
    let(:dup_student1_doc) { FactoryGirl.create(:document,
        title: "dup_student1", shared: false, owner_id: dup_student1.id,
        form_content: '{ "foo": "baz1", "appName": "name", "appVersion": "version", "appBuildNum": 1 }',
        run_key: 'bar') }
    let(:dup_student2_doc) { FactoryGirl.create(:document,
        title: "dup_student2", shared: false, owner_id: dup_student2.id,
        form_content: '{ "foo": "baz2", "appName": "name", "appVersion": "version", "appBuildNum": 1 }',
        run_key: 'foo') }
    let(:anon_doc1a) { FactoryGirl.create(:document,
      title: "anon1a", shared: false, owner_id: nil,
      form_content: '{ "foo": "baz1a", "appName": "name", "appVersion": "version", "appBuildNum": 1 }',
      run_key: 'foo') }
    let(:anon_doc1b) { FactoryGirl.create(:document,
      title: "anon1b", shared: false, owner_id: nil,
      form_content: '{ "foo": "baz1b", "appName": "name", "appVersion": "version", "appBuildNum": 1 }',
      run_key: 'foo') }
    let(:anon_doc1c) { FactoryGirl.create(:document,
      title: "anon1c", shared: false, owner_id: nil,
      form_content: '{ "foo": "baz1c", "appName": "name", "appVersion": "version", "appBuildNum": 1 }',
      run_key: 'foo') }
    let(:anon_doc2a) { FactoryGirl.create(:document,
      title: "anon2a", shared: false, owner_id: nil,
      form_content: '{ "foo": "baz2a", "appName": "name", "appVersion": "version", "appBuildNum": 1 }',
      run_key: 'bar') }
    let(:anon_doc2b) { FactoryGirl.create(:document,
      title: "anon2b", shared: false, owner_id: nil,
      form_content: '{ "foo": "baz2b", "appName": "name", "appVersion": "version", "appBuildNum": 1 }',
      run_key: 'bar') }
    let(:anon_doc2c) { FactoryGirl.create(:document,
      title: "anon2c", shared: false, owner_id: nil,
      form_content: '{ "foo": "baz2c", "appName": "name", "appVersion": "version", "appBuildNum": 1 }',
      run_key: 'bar') }
    let(:server)   { 'http://foo.com/' }

    scenario 'the template document needs to exist' do
      visit report_path(owner: author.username, recordname: template.title + "2", server: server, reportUser: student.username, runKey: 'foo')
      expect(page).to have_content "Error: The requested document could not be found."
      visit report_path(owner: author.username, recordname: template.title, server: server, reportUser: student.username, runKey: 'foo')
      expect(page).to have_content 'No documents have been saved!'
    end
    scenario 'runKey needs to be provided' do
      expect {
        visit report_path(owner: author.username, recordname: template.title, server: server, reportUser: student.username)
      }.to raise_error(ActiveRecord::RecordNotFound)
      visit report_path(owner: author.username, recordname: template.title, server: server, reportUser: student.username, runKey: 'foo')
      expect(page).to have_content 'No documents have been saved!'
    end
    scenario 'server needs to be provided' do
      expect {
        visit report_path(owner: author.username, recordname: template.title, reportUser: student.username, runKey: 'foo')
      }.to raise_error(ActiveRecord::RecordNotFound)
      visit report_path(owner: author.username, recordname: template.title, server: server, reportUser: student.username, runKey: 'foo')
      expect(page).to have_content 'No documents have been saved!'
    end
    scenario 'user can report a document via owner and recordname' do
      url = doc_url(server, {recordid: student_doc1a.id, documentServer: 'https://www.example.com/', runKey: 'foo'})
      visit report_path(owner: author.username, recordname: template.title, server: server, reportUser: student.username, runKey: 'foo')
      expect(page).to have_selector('.launch-button', count: 1)
      expect(page).to have_selector "a.launch-button[href='#{url}']"
    end
    scenario 'user can report a document via owner and doc' do
      url = doc_url(server, {recordid: student_doc1a.id, documentServer: 'https://www.example.com/', runKey: 'foo'})
      visit report_path(owner: author.username, doc: template.title, server: server, reportUser: student.username, runKey: 'foo')
      expect(page).to have_selector('.launch-button', count: 1)
      expect(page).to have_selector "a.launch-button[href='#{url}']"
    end
    scenario 'user can report a document via recordid' do
      url = doc_url(server, {recordid: student_doc1a.id, documentServer: 'https://www.example.com/', runKey: 'foo'})
      visit report_path(owner: author.username, recordid: template.id, server: server, reportUser: student.username, runKey: 'foo')
      expect(page).to have_selector('.launch-button', count: 1)
      expect(page).to have_selector "a.launch-button[href='#{url}']"
    end
    scenario 'user can report a document via moreGames' do
      visit report_path(server: server, moreGames: '[{}]', runKey: 'foo', reportUser: student.username)
      expect(page).to have_content 'No documents have been saved!'
    end
    scenario 'reportUser also has multiple documents that match the run key, a link to each of them is displayed too' do
      url1 = doc_url(server, {recordid: student_doc1a.id, documentServer: 'https://www.example.com/', runKey: 'foo'})
      url2 = doc_url(server, {recordid: student_doc1b.id, documentServer: 'https://www.example.com/', runKey: 'foo'})
      visit report_path(owner: author.username, recordname: template.title, server: server, reportUser: student.username, runKey: 'foo')
      expect(page).to have_selector('.launch-button', count: 2)
      expect(page).to have_selector "a.launch-button[href='#{url1}']"
      expect(page).to have_selector "a.launch-button[href='#{url2}']"
    end
    scenario 'reportUser also has documents that do not match the run key, a link to each of them is not also displayed' do
      url1 = doc_url(server, {recordid: student_doc1a.id, documentServer: 'https://www.example.com/', runKey: 'foo'})
      url2 = doc_url(server, {recordid: student_doc1b.id, documentServer: 'https://www.example.com/', runKey: 'foo'})
      url3 = doc_url(server, {recordid: student_doc1c.id, documentServer: 'https://www.example.com/', runKey: 'foo'})
      url4 = doc_url(server, {recordid: student_doc2a.id, documentServer: 'https://www.example.com/', runKey: 'foo'})
      url5 = doc_url(server, {recordid: student_doc2b.id, documentServer: 'https://www.example.com/', runKey: 'foo'})
      visit report_path(owner: author.username, recordname: template.title, server: server, reportUser: student.username, runKey: 'foo')
      expect(page).to have_selector('.launch-button', count: 3)
      expect(page).to have_selector "a.launch-button[href='#{url1}']"
      expect(page).to have_selector "a.launch-button[href='#{url2}']"
      expect(page).to have_selector "a.launch-button[href='#{url3}']"
    end
    describe 'multiple users with the same username' do
      scenario 'report should show report for "bar" runKey' do
        url1 = doc_url(server, {recordid: dup_student1_doc.id, documentServer: 'https://www.example.com/', runKey: 'bar'})
        url2 = doc_url(server, {recordid: dup_student2_doc.id, documentServer: 'https://www.example.com/', runKey: 'foo'})
        visit report_path(owner: author.username, recordname: template.title, server: server, reportUser: dup_student1.username, runKey: 'bar')
        expect(page).to have_selector('.launch-button', count: 1)
        expect(page).to have_selector "a.launch-button[href='#{url1}']"
      end
      scenario 'report should show report for "foo" runKey' do
        url1 = doc_url(server, {recordid: dup_student1_doc.id, documentServer: 'https://www.example.com/', runKey: 'bar'})
        url2 = doc_url(server, {recordid: dup_student2_doc.id, documentServer: 'https://www.example.com/', runKey: 'foo'})
        visit report_path(owner: author.username, recordname: template.title, server: server, reportUser: dup_student2.username, runKey: 'foo')
        expect(page).to have_selector('.launch-button', count: 1)
        expect(page).to have_selector "a.launch-button[href='#{url2}']"
      end
    end
    scenario 'moreGames in url and one document with run key, 1 link is present' do
      url = doc_url(server, {recordid: student_doc1a.id, documentServer: 'https://www.example.com/', runKey: 'foo'})
      visit report_path(server: server, moreGames: '[{}]', runKey: 'foo', reportUser: student.username)
      expect(page).to have_selector('.launch-button', count: 1)
      expect(page).to have_selector "a.launch-button[href='#{url}']"
    end
    scenario 'moreGames in url and multiple documents with run key, all links are present' do
      url1 = doc_url(server, {recordid: student_doc1a.id, documentServer: 'https://www.example.com/', runKey: 'foo'})
      url2 = doc_url(server, {recordid: student_doc1c.id, documentServer: 'https://www.example.com/', runKey: 'foo'})
      visit report_path(server: server, moreGames: '[{}]', runKey: 'foo', reportUser: student.username)
      expect(page).to have_selector('.launch-button', count: 2)
      expect(page).to have_selector "a.launch-button[href='#{url1}']"
      expect(page).to have_selector "a.launch-button[href='#{url2}']"
    end
    describe 'anonymous' do
      scenario 'user can report a document via owner and recordname' do
        url = doc_url(server, {recordid: anon_doc1a.id, documentServer: 'https://www.example.com/', runKey: 'foo'})
        visit report_path(owner: author.username, recordname: template.title, server: server, runKey: 'foo')
        expect(page).to have_selector('.launch-button', count: 1)
        expect(page).to have_selector "a.launch-button[href='#{url}']"
      end
      scenario 'user can report a document via owner and doc' do
        url = doc_url(server, {recordid: anon_doc1a.id, documentServer: 'https://www.example.com/', runKey: 'foo'})
        visit report_path(owner: author.username, doc: template.title, server: server, runKey: 'foo')
        expect(page).to have_selector('.launch-button', count: 1)
        expect(page).to have_selector "a.launch-button[href='#{url}']"
      end
      scenario 'user can report a document via recordid' do
        url = doc_url(server, {recordid: anon_doc1a.id, documentServer: 'https://www.example.com/', runKey: 'foo'})
        visit report_path(owner: author.username, recordid: template.id, server: server, runKey: 'foo')
        expect(page).to have_selector('.launch-button', count: 1)
        expect(page).to have_selector "a.launch-button[href='#{url}']"
      end
      scenario 'user can report a document via moreGames' do
        visit report_path(server: server, moreGames: '[{}]', runKey: 'foo')
        expect(page).to have_content 'No documents have been saved!'
      end
      scenario 'reportUser also has multiple documents that match the run key, a link to each of them is displayed too' do
        url1 = doc_url(server, {recordid: anon_doc1a.id, documentServer: 'https://www.example.com/', runKey: 'foo'})
        url2 = doc_url(server, {recordid: anon_doc1b.id, documentServer: 'https://www.example.com/', runKey: 'foo'})
        visit report_path(owner: author.username, recordname: template.title, server: server, runKey: 'foo')
        expect(page).to have_selector('.launch-button', count: 2)
        expect(page).to have_selector "a.launch-button[href='#{url1}']"
        expect(page).to have_selector "a.launch-button[href='#{url2}']"
      end
      scenario 'reportUser also has documents that do not match the run key, a link to each of them is not also displayed' do
        url1 = doc_url(server, {recordid: anon_doc1a.id, documentServer: 'https://www.example.com/', runKey: 'foo'})
        url2 = doc_url(server, {recordid: anon_doc1b.id, documentServer: 'https://www.example.com/', runKey: 'foo'})
        url3 = doc_url(server, {recordid: anon_doc1c.id, documentServer: 'https://www.example.com/', runKey: 'foo'})
        url4 = doc_url(server, {recordid: anon_doc2a.id, documentServer: 'https://www.example.com/', runKey: 'foo'})
        url5 = doc_url(server, {recordid: anon_doc2b.id, documentServer: 'https://www.example.com/', runKey: 'foo'})
        visit report_path(owner: author.username, recordname: template.title, server: server, runKey: 'foo')
        expect(page).to have_selector('.launch-button', count: 3)
        expect(page).to have_selector "a.launch-button[href='#{url1}']"
        expect(page).to have_selector "a.launch-button[href='#{url2}']"
        expect(page).to have_selector "a.launch-button[href='#{url3}']"
      end
      scenario 'moreGames in url and one document with run key, 1 link is present' do
        url = doc_url(server, {recordid: anon_doc1a.id, documentServer: 'https://www.example.com/', runKey: 'foo'})
        visit report_path(server: server, moreGames: '[{}]', runKey: 'foo')
        expect(page).to have_selector('.launch-button', count: 1)
        expect(page).to have_selector "a.launch-button[href='#{url}']"
      end
      scenario 'moreGames in url and multiple documents with run key, all links are present' do
        url1 = doc_url(server, {recordid: anon_doc1a.id, documentServer: 'https://www.example.com/', runKey: 'foo'})
        url2 = doc_url(server, {recordid: anon_doc1c.id, documentServer: 'https://www.example.com/', runKey: 'foo'})
        visit report_path(server: server, moreGames: '[{}]', runKey: 'foo')
        expect(page).to have_selector('.launch-button', count: 2)
        expect(page).to have_selector "a.launch-button[href='#{url1}']"
        expect(page).to have_selector "a.launch-button[href='#{url2}']"
      end
    end
  end
end